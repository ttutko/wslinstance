#!/usr/bin/env bash
# =============================================================================
# dev/prime-test.sh — validate the LazyVim OFFLINE priming in isolation, in a
# throwaway container, WITHOUT a full ./build.sh run.
#
# Why: the neovim role is the fragile part (nvim version, tree-sitter CLI glibc,
# two-pass priming). This exercises exactly that path in ~2-4 min instead of the
# 12-20 min full build, so you can iterate on config/nvim/** and the prime*.lua
# scripts quickly.
#
# Usage:   dev/prime-test.sh
# Runtime: auto-detected (nerdctl -> docker -> podman); needs network + sandbox
#          access. Versions are read from ansible/vars/versions.yml so this stays
#          in sync with the real build.
# =============================================================================
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
VERSIONS="$REPO/ansible/vars/versions.yml"

val() { grep -E "^$1:" "$VERSIONS" | sed -E 's/.*"([^"]+)".*/\1/'; }
NVIM_VER="$(val neovim_version)"
TS_VER="$(val treesitter_cli_version)"
NODE_VER="$(val node_version)"

CLI="${CONTAINER_CLI:-}"
if [ -z "$CLI" ]; then
  for c in nerdctl docker podman; do
    command -v "$c" >/dev/null 2>&1 && "$c" info >/dev/null 2>&1 && { CLI="$c"; break; }
  done
fi
[ -n "$CLI" ] || { echo "no working container runtime" >&2; exit 1; }

echo ">> runtime=$CLI  neovim=$NVIM_VER  tree-sitter-cli=$TS_VER  node=$NODE_VER"

# Inner script runs inside debian:12-slim with the repo mounted read-only at
# /provision. Fed via stdin because only shared host paths are visible in the VM.
"$CLI" run --rm -i -v "$REPO":/provision:ro debian:12-slim bash -s -- "$NVIM_VER" "$TS_VER" "$NODE_VER" <<'INNER'
set -euxo pipefail
NVIM_VER="$1"; TS_VER="$2"; NODE_VER="$3"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
# clang + libclang-dev are for building the tree-sitter CLI from source (its
# rquickjs-sys dep runs bindgen, which needs libclang). unzip is needed by Mason
# to extract .zip-packaged tools (stylua, omnisharp). python3(+venv+pip) lets
# Mason install debugpy — the real image already has these; the slim base
# doesn't. The rest match the build.
apt-get install -y --no-install-recommends curl ca-certificates git tar gzip unzip gcc g++ make libc6-dev clang libclang-dev python3 python3-venv python3-pip >/dev/null

# neovim
curl -fsSL -o /tmp/nvim.tar.gz "https://github.com/neovim/neovim/releases/download/v${NVIM_VER}/nvim-linux-x86_64.tar.gz"
tar -C /opt -xzf /tmp/nvim.tar.gz
ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim
# Node.js runtime (needed by the npm-based LSP servers Mason installs). Mirrors
# the nodejs ansible role.
curl -fsSL -o /tmp/node.tar.gz "https://nodejs.org/dist/v${NODE_VER}/node-v${NODE_VER}-linux-x64.tar.gz"
tar -C /opt -xzf /tmp/node.tar.gz
ln -sf "/opt/node-v${NODE_VER}-linux-x64/bin/node" /usr/local/bin/node
ln -sf "/opt/node-v${NODE_VER}-linux-x64/bin/npm"  /usr/local/bin/npm
ln -sf "/opt/node-v${NODE_VER}-linux-x64/bin/npx"  /usr/local/bin/npx
# tree-sitter CLI built FROM SOURCE against this container's glibc 2.36 — no
# prebuilt 0.26.x works on Debian 12 (all need glibc 2.39). Mirrors the neovim
# role. This is what makes prime-test.sh a true glibc-compat gate for the CLI.
export RUSTUP_HOME=/tmp/rustup CARGO_HOME=/tmp/cargo
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
  | sh -s -- -y --profile minimal --default-toolchain stable --no-modify-path
"$CARGO_HOME/bin/cargo" install tree-sitter-cli --version "${TS_VER}" --root /usr/local
rm -rf /tmp/rustup /tmp/cargo /root/.cargo /root/.rustup
# config
mkdir -p /root/.config/lvim
cp -a /provision/config/nvim/. /root/.config/lvim/

export NVIM_APPNAME=lvim HOME=/root GIT_TERMINAL_PROMPT=0
export GIT_SSH_COMMAND="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new"
P=/provision/ansible/roles/neovim/files
echo "=== PASS 1 (plugins + Mason) ==="
timeout 1500 nvim --headless -c "luafile $P/prime.lua"
echo "=== PASS 2 (treesitter) ==="
timeout 900  nvim --headless -c "luafile $P/prime-ts.lua"

echo "=== RESULTS ==="
test -d /root/.local/share/lvim/lazy/LazyVim && echo "OK LazyVim present" || echo "FAIL LazyVim missing"
echo "PLUGIN COUNT:  $(ls /root/.local/share/lvim/lazy | wc -l)"
echo "PARSER COUNT:  $(find /root/.local/share/lvim -path '*parser*' -name '*.so' | wc -l)"
# c_sharp parser proves tree-sitter CLI runs on this glibc-2.36 container.
find /root/.local/share/lvim -path '*parser*' -name 'c_sharp.so' | grep -q . \
  && echo "OK c_sharp parser compiled" || echo "FAIL c_sharp parser missing"
echo "MASON PACKAGES:"
# node+python ARE installed above, so the node/pip-based servers below install
# just like the real build. (csharpier is not baked at all — its Mason installer
# hangs headless; OmniSharp formats C# instead.)
for t in lua-language-server stylua shfmt shellcheck taplo marksman \
         omnisharp netcoredbg \
         pyright ruff debugpy \
         typescript-language-server html-lsp css-lsp json-lsp yaml-language-server prettier \
         bash-language-server dockerfile-language-server docker-compose-language-service; do
  test -d "/root/.local/share/lvim/mason/packages/$t" && echo "  OK $t" || echo "  MISSING $t"
done

echo "=== CHECKHEALTH ==="
# Capture LazyVim's :checkhealth (lazy / treesitter / lsp / mason etc.) so the
# maintainer can spot real errors. Runs after priming so plugins/parsers exist.
nvim --headless "+checkhealth" "+write! /tmp/health.md" "+qa" 2>/dev/null || true
if [ -f /tmp/health.md ]; then
  cat /tmp/health.md
  echo "--- checkhealth ERROR lines ---"
  grep -nE 'ERROR' /tmp/health.md || echo "(no ERROR lines)"
else
  echo "FAIL checkhealth produced no output"
fi
INNER
