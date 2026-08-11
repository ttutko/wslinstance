# CLAUDE.md — maintainer quick reference

Airgapped **WSL2 / Debian 13** image builder. A network-connected machine builds a
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
| apt package | `ansible/roles/apt_tools/tasks/main.yml` | Debian 13 (trixie) pkgs only. |
| GitHub/GitLab release binary | `ansible/vars/versions.yml` → `github_bins:` | See recipe below. |
| neovim / .NET / pwsh / tree-sitter CLI / tealdeer versions | `ansible/vars/versions.yml` (top vars) | Specialised roles read these. |
| shell/prompt/aliases | `config/zshrc`, `config/aliases.zsh`, `config/starship.toml` | Deployed to `/root` + `/etc/skel`. |
| LazyVim config | `config/nvim/**` | `nvim`=vanilla; `vim`/`lvim`=LazyVim (NVIM_APPNAME=lvim). |
| treesitter parsers | `config/nvim/lua/plugins/treesitter.lua` **and** `ansible/roles/neovim/files/prime-ts.lua` (`langs`) | Both lists must match; parsers compile at build. |
| Mason LSPs/formatters | `config/nvim/lua/plugins/mason.lua` **and** `ansible/roles/neovim/files/prime.lua` (`tools`) | Node/pip/dotnet-runtime servers now OK (runtimes are baked — see below). |
| LazyVim language wiring (LSP servers, formatters, dap) | `config/nvim/lua/plugins/csharp.lua` (C#), `langs.lua` (Python/Web/DevOps) | Hand-rolled: registers servers in `nvim-lspconfig` `opts.servers`, conform formatters, dap. Still must add each tool to `mason.lua`+`prime.lua` and parsers to `treesitter.lua`+`prime-ts.lua`. |
| Node.js runtime | `ansible/roles/nodejs/` (version in `versions.yml` → `node_version`) | Permanent; runs npm-based LSP servers. Role is ordered BEFORE `neovim` so Mason can `npm install` them during priming. |
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
`python3 dev/check-urls.py`.

## Gotchas already solved (don't re-discover)

- **nvim ≥ 0.11.2 required by LazyVim.** Too-old nvim → LazyVim prints "Press any key to
  exit" which **deadlocks headless priming forever**. Pinned nvim `0.11.7`.
- **tree-sitter CLI — prebuilt download.** nvim-treesitter `main` branch compiles parsers via
  the `tree-sitter` CLI. The prebuilt GitHub release binary needs **glibc 2.39**; Debian 13
  (trixie) ships **glibc 2.41**, so the neovim role just downloads `tree-sitter-linux-x64.gz` to
  `/usr/local/bin` (no source build). Currently pinned **`0.26.11`**. Mason is `PATH="append"`
  so this `/usr/local` CLI wins. `dev/prime-test.sh` downloads it the same way and is the compat
  gate. (History: on the old Debian-12/glibc-2.36 base no prebuilt ≥0.26 ran, so it was compiled
  from source via rustup+cargo — the trixie upgrade removed all of that.)
- **Two priming passes.** `prime.lua` (plugins+Mason) and `prime-ts.lua` (treesitter) run as
  **separate** `nvim --headless` invocations. Doing treesitter in the same session as Mason
  leaves the parser registry uninitialised (`config.list is nil`). Both wrapped in `timeout`.
  `install()` returns an async Task that must be captured and `:wait()`-ed.
- **Mason is FLAKY on trixie — most LSP tooling bypasses it.** mason.nvim (v2.3.1, unchanged
  since it worked in build4) intermittently leaves a random install stuck each headless build —
  npm servers hang, and even binary/pip tools (`ruff`, `debugpy`, `omnisharp`) fail some runs.
  Underlying downloads/pip all work fine; it's mason's installer. So:
  - **npm LSP servers → plain `npm install -g`** (neovim role): pyright, typescript-language-server,
    vscode-langservers-extracted (html/css/json), yaml-language-server, prettier,
    dockerfile-language-server-nodejs, @microsoft/compose-language-service, bash-language-server —
    symlinked onto PATH; `langs.lua` registers each with `mason = false`.
  - **ruff → `github_bins`** (`versions.yml`), **debugpy → a pip venv** at `/opt/debugpy-venv`
    (neovim role); `langs.lua` sets `ruff = { mason = false }` and points nvim-dap-python at that
    venv. Self-test checks these via `command -v` / `import debugpy`.
  - **Mason keeps ONLY prebuilt binaries** (lua-language-server, stylua, shfmt, shellcheck, taplo,
    marksman, omnisharp, netcoredbg) — and even those run in a **retry loop** (the "Prime pass 1"
    task re-runs `prime.lua` in fresh nvim sessions up to 4× until all are present, since a fresh
    session re-downloads a stuck straggler cleanly). Mirror any change in `dev/prime-test.sh`.
  - (`csharpier` and the `gitcommit` parser hit the analogous flakiness and were dropped.) The
    durable fix for all of this is pinning plugins (lazy-lock) — deferred.
  - A Mason-baked server must be in `prime.lua` (bake) **and** `opts.servers` (start); a
    bypassed one must be on PATH **and** `opts.servers` with `mason = false`.
- **C# (`config/nvim/lua/plugins/csharp.lua`).** C#-only (F# half of LazyVim's `lang.dotnet`
  extra deliberately dropped). Mason tools: `omnisharp`, `netcoredbg` — both prebuilt-binary
  downloads that install without dotnet. **`csharpier` is deliberately NOT used:** its Mason
  installer is a `dotnet tool` that **hangs indefinitely in headless priming** (raw
  `dotnet tool install csharpier` works fine, but Mason's path does not) — so it broke the
  build gate. OmniSharp formats C# via the LSP, so nothing is lost. If you ever want csharpier,
  install it directly in the neovim role (`dotnet tool install --tool-path … csharpier`), not
  via Mason. **Caveat to verify:** Mason's `omnisharp` may ship the `net6.0` build; the image
  has .NET 8/10, so omnisharp may need `DOTNET_ROLL_FORWARD=Major` to launch — confirm by
  opening a `.cs` file in a real instance.
- **Dockerfile slim step must NOT `apt-get autoremove`** — it cascades through Python and
  removes httpie/bpytop. And **preserve `/root/.cache/tealdeer`** (the offline tldr cache);
  only clear `/root/.cache/pip`.
- **tldr = tealdeer**, pinned `1.8.1` (older pins have dead pages-archive URLs). `tldr --update`
  builds the cache at build time.
- **cht.sh** needs a reachable server → not truly offline; documented, `tldr` is the offline
  cheatsheet. **Nerd Font** for icons is a Windows-terminal (client-side) setting.

## Fast iteration on neovim priming (avoid full rebuilds)

```bash
dev/prime-test.sh          # exercises prime.lua + prime-ts.lua in a throwaway container
```
Installs nvim + tree-sitter CLI + gcc, copies `config/nvim`, runs both priming passes, and
reports plugin/parser/Mason counts — in ~2-4 min instead of a full playbook run. Versions come
from `ansible/vars/versions.yml`. See `dev/README.md`.

## Reproducibility
Everything non-apt is pinned in `ansible/vars/versions.yml`. If a release URL 404s at build
time, the build **fails loudly** (never silent) — bump that tool's `version`.
