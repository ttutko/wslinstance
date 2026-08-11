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

# Inner script runs inside debian:13-slim with the repo mounted read-only at
# /provision. Fed via stdin because only shared host paths are visible in the VM.
"$CLI" run --rm -i -v "$REPO":/provision:ro debian:13-slim bash -s -- "$NVIM_VER" "$TS_VER" "$NODE_VER" <<'INNER'
set -euxo pipefail
NVIM_VER="$1"; TS_VER="$2"; NODE_VER="$3"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
# gcc/g++/make compile the treesitter parsers. unzip is needed by Mason to
# extract .zip-packaged tools (stylua, omnisharp). python3(+venv) for debugpy.
# libicu76 lets the .NET-based tools (marksman) RUN so Mason's install verifies —
# the real image gets it from the powershell role; the slim base doesn't ship it.
apt-get install -y --no-install-recommends curl ca-certificates git tar gzip unzip gcc g++ make libc6-dev python3 python3-venv python3-pip libicu76 >/dev/null

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
# npm-based LSP servers via plain npm (Mason's npm installer hangs). Mirrors the
# neovim role.
npm install -g \
  pyright typescript-language-server typescript vscode-langservers-extracted \
  yaml-language-server prettier dockerfile-language-server-nodejs \
  @microsoft/compose-language-service bash-language-server >/dev/null 2>&1
for b in pyright pyright-langserver typescript-language-server \
         vscode-html-language-server vscode-css-language-server vscode-json-language-server \
         yaml-language-server prettier docker-langserver docker-compose-langserver \
         bash-language-server; do
  ln -sf "$(npm prefix -g)/bin/$b" "/usr/local/bin/$b"
done
# ruff (github_bins in the real build) + debugpy (pip venv) — Mason's installers
# fail for these on trixie. Mirror the neovim role (ruff 0.16.2 pinned in versions.yml).
curl -fsSL -o /tmp/ruff.tar.gz "https://github.com/astral-sh/ruff/releases/download/0.16.2/ruff-x86_64-unknown-linux-gnu.tar.gz"
tar -C /tmp -xzf /tmp/ruff.tar.gz
install -m0755 /tmp/ruff-x86_64-unknown-linux-gnu/ruff /usr/local/bin/ruff
python3 -m venv /opt/debugpy-venv
/opt/debugpy-venv/bin/python -m pip install --quiet debugpy >/dev/null 2>&1
# tree-sitter CLI: prebuilt binary (Debian 13's glibc 2.41 satisfies the release
# binary's glibc 2.39 requirement). Mirrors the neovim role. prime-test.sh stays
# the compat gate: if parsers don't compile on this trixie container, the build
# won't either.
curl -fsSL -o /tmp/ts.gz "https://github.com/tree-sitter/tree-sitter/releases/download/v${TS_VER}/tree-sitter-linux-x64.gz"
gunzip -f /tmp/ts.gz && install -m0755 /tmp/ts /usr/local/bin/tree-sitter && rm -f /tmp/ts
# config
mkdir -p /root/.config/lvim
cp -a /provision/config/nvim/. /root/.config/lvim/

export NVIM_APPNAME=lvim HOME=/root GIT_TERMINAL_PROMPT=0
export GIT_SSH_COMMAND="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new"
P=/provision/ansible/roles/neovim/files
echo "=== PASS 1 (plugins + Mason), retrying stragglers ==="
# Mirror the neovim role: mason installers are occasionally flaky, so retry
# prime.lua in fresh sessions until all mason tools land.
MTOOLS="lua-language-server stylua shfmt shellcheck taplo marksman omnisharp netcoredbg"
for attempt in 1 2 3 4; do
  echo "--- prime.lua attempt $attempt ---"
  timeout 2400 nvim --headless -c "luafile $P/prime.lua" || true
  miss=""
  for t in $MTOOLS; do [ -d "/root/.local/share/lvim/mason/packages/$t" ] || miss="$miss $t"; done
  [ -z "$miss" ] && { echo "all mason tools present after attempt $attempt"; break; }
  echo "attempt $attempt missing:$miss — retrying"
done
echo "=== PASS 2 (treesitter) ==="
timeout 1800 nvim --headless -c "luafile $P/prime-ts.lua"

echo "=== RESULTS ==="
test -d /root/.local/share/lvim/lazy/LazyVim && echo "OK LazyVim present" || echo "FAIL LazyVim missing"
echo "PLUGIN COUNT:  $(ls /root/.local/share/lvim/lazy | wc -l)"
echo "PARSER COUNT:  $(find /root/.local/share/lvim -path '*parser*' -name '*.so' | wc -l)"
# c_sharp parser proves the tree-sitter CLI runs on this trixie (glibc 2.41) container.
find /root/.local/share/lvim -path '*parser*' -name 'c_sharp.so' | grep -q . \
  && echo "OK c_sharp parser compiled" || echo "FAIL c_sharp parser missing"
echo "MASON PACKAGES (prebuilt binaries — reliable):"
# Only prebuilt-binary tools are Mason-managed. npm servers (npm install -g),
# ruff (github_bins), and debugpy (pip venv) bypass Mason — its installers are
# flaky/hang for them on trixie. csharpier is not baked (OmniSharp formats C#).
for t in lua-language-server stylua shfmt shellcheck taplo marksman \
         omnisharp netcoredbg; do
  test -d "/root/.local/share/lvim/mason/packages/$t" && echo "  OK $t" || echo "  MISSING $t"
done
echo "DIRECT INSTALLS (not Mason):"
command -v ruff >/dev/null 2>&1 && echo "  OK ruff (github_bins)" || echo "  MISSING ruff"
/opt/debugpy-venv/bin/python -c 'import debugpy' 2>/dev/null && echo "  OK debugpy (venv)" || echo "  MISSING debugpy"
echo "NPM LSP SERVERS (on PATH, not Mason):"
for b in pyright-langserver typescript-language-server vscode-html-language-server \
         vscode-css-language-server vscode-json-language-server yaml-language-server \
         prettier docker-langserver docker-compose-langserver bash-language-server; do
  command -v "$b" >/dev/null 2>&1 && echo "  OK $b" || echo "  MISSING $b"
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
