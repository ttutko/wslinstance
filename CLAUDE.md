# CLAUDE.md — maintainer quick reference

Airgapped **WSL2 / Debian 12** image builder. A network-connected machine builds a
container, exports its rootfs, and bundles it for `wsl --import` on an airgapped host.
Everything (apt pkgs, GitHub-release binaries, LazyVim plugins/parsers/LSPs, tldr cache)
is baked in at build time so the result works with **no network**.

## Build / test (this environment)

```bash
CONTAINER_CLI=nerdctl ./build.sh          # build → offline self-test gate → export → bundle/
CONTAINER_CLI=nerdctl ./build.sh --no-cache
CONTAINER_CLI=nerdctl ./build.sh --skip-test   # skip the --network none gate
```

- **Use `nerdctl`, not docker** here: the `docker` context points at a missing
  `/var/run/docker.sock`; Rancher Desktop's real socket is `~/.rd/docker.sock`.
  `build.sh` auto-detects nerdctl→docker→podman.
- Container commands need the **sandbox disabled** (containerd + network access).
- The build re-runs the **whole** Ansible playbook every time (no ansible-level caching);
  the Docker bootstrap layer is cached. Full build ≈ 12–20 min (two .NET SDKs dominate).
- Output: `bundle/debian-wsl-airgap.tar.gz` (~1 GB) + `import.ps1` + `SHA256SUMS` + docs + tests.

### Offline self-test
`tests/test-offline.sh` (baked in as `wsl-selftest`) runs each entry in
`tests/expected-tools.txt` (`label <TAB> command`, exit 0 = pass). `build.sh` runs it under
`nerdctl run --network none` as a hard gate. Run standalone:
```bash
nerdctl run --rm --network none debian-wsl-airgap /usr/local/bin/wsl-selftest
```

## Where things live — how to add/remove a tool

| Kind of tool | Edit | Notes |
|---|---|---|
| apt package | `ansible/roles/apt_tools/tasks/main.yml` | Debian 12 (bookworm) pkgs only. |
| GitHub/GitLab release binary | `ansible/vars/versions.yml` → `github_bins:` | See recipe below. |
| neovim / .NET / pwsh / tree-sitter CLI / tealdeer versions | `ansible/vars/versions.yml` (top vars) | Specialised roles read these. |
| shell/prompt/aliases | `config/zshrc`, `config/aliases.zsh`, `config/starship.toml` | Deployed to `/root` + `/etc/skel`. |
| LazyVim config | `config/nvim/**` | `nvim`=vanilla; `vim`/`lvim`=LazyVim (NVIM_APPNAME=lvim). |
| treesitter parsers | `config/nvim/lua/plugins/treesitter.lua` **and** `ansible/roles/neovim/files/prime-ts.lua` (`langs`) | Both lists must match; parsers compile at build. |
| Mason LSPs/formatters | `config/nvim/lua/plugins/mason.lua` **and** `ansible/roles/neovim/files/prime.lua` (`tools`) | Prebuilt-binary tools only (see gotcha). |
| first-run wizard | `firstrun/wsl-firstrun.sh` | Prompts: starship preset / plugin toggles / keybinds. |
| docs (man + `wsltools`) | `docs/tools.tsv` (single source) | Add a row; man page is generated from it. |
| self-test | `tests/expected-tools.txt` | Add a `label <TAB> cmd` line for any new tool. |

**When adding a tool, update it in three places:** the install location, `docs/tools.tsv`,
and `tests/expected-tools.txt`.

### `github_bins:` recipe (`ansible/vars/versions.yml`)
The list is loaded eagerly, so URLs must contain the literal token `__VER__` (NOT Jinja);
`roles/github_bins/tasks/install_one.yml` substitutes `item.version`.
```yaml
- name: toolname
  version: "1.2.3"
  url: "https://github.com/owner/repo/releases/download/v__VER__/tool_v__VER___linux_x86_64.tar.gz"
  type: tar.gz            # raw | tar.gz | zip | deb
  bin_src: tool           # path inside archive (tar.gz/zip)
  bin_dest: /usr/local/bin/tool
  # bins: [{src, dest}, ...]   # for multi-binary archives (see yazi, bw)
  # symlinks: [/usr/local/bin/alias]
  # sha256: "..."          # optional; verified if set
```
Verify every pinned URL at once (HEAD checks) before a long build:
`python3` loop over `github_bins` doing HEAD requests — see git history / do a quick script.

## Gotchas already solved (don't re-discover)

- **nvim ≥ 0.11.2 required by LazyVim.** Too-old nvim → LazyVim prints "Press any key to
  exit" which **deadlocks headless priming forever**. Pinned nvim `0.11.7`.
- **tree-sitter CLI glibc.** nvim-treesitter `main` branch compiles parsers via the
  `tree-sitter` CLI. Mason's prebuilt CLI needs **glibc 2.39**; Debian 12 has **2.36**.
  We install a glibc-compatible CLI (`0.25.6`/`0.25.10` work; **0.25.0 does not**) to
  `/usr/local/bin` in the neovim role, and set Mason `PATH="append"` so it wins.
- **Two priming passes.** `prime.lua` (plugins+Mason) and `prime-ts.lua` (treesitter) run as
  **separate** `nvim --headless` invocations. Doing treesitter in the same session as Mason
  leaves the parser registry uninitialised (`config.list is nil`). Both wrapped in `timeout`.
  `install()` returns an async Task that must be captured and `:wait()`-ed.
- **Mason offline set = prebuilt binaries only** (lua-language-server, stylua, shfmt,
  shellcheck, taplo, marksman). npm/pip-based servers (pyright, bash/yaml/json LSP) need a
  Node/Python **runtime** to execute — not installed — so they'd fail offline. To add them,
  install the runtime in the image first.
- **Dockerfile slim step must NOT `apt-get autoremove`** — it cascades through Python and
  removes httpie/bpytop. And **preserve `/root/.cache/tealdeer`** (the offline tldr cache);
  only clear `/root/.cache/pip`.
- **tldr = tealdeer**, pinned `1.8.1` (older pins have dead pages-archive URLs). `tldr --update`
  builds the cache at build time.
- **cht.sh** needs a reachable server → not truly offline; documented, `tldr` is the offline
  cheatsheet. **Nerd Font** for icons is a Windows-terminal (client-side) setting.

## Fast iteration on neovim priming (avoid full rebuilds)

Test just the LazyVim priming in a throwaway container (mount repo at `/provision`, feed script
via stdin because only `/home/ttutko` is shared into the lima VM):
```bash
nerdctl run --rm -i -v "$PWD":/provision:ro debian:12-slim bash -s < prime-test.sh
```
where `prime-test.sh` installs nvim 0.11.7 + tree-sitter CLI + gcc, copies `config/nvim`, then
runs `prime.lua` then `prime-ts.lua` (see git history for the exact script). Confirms parser
count > 0 and Mason tools in minutes instead of a full playbook run.

## Reproducibility
Everything non-apt is pinned in `ansible/vars/versions.yml`. If a release URL 404s at build
time, the build **fails loudly** (never silent) — bump that tool's `version`.
