# wslinstance — Airgapped Debian 13 WSL builder

Builds a **fully self-contained WSL2 distribution** (Debian 13) preloaded with a
curated toolset, ready to `wsl --import` onto an **airgapped machine**. All
downloads happen once, at build time, on a network-connected machine; the
resulting image needs no network.

## Quick start

On a machine with a **container runtime** (nerdctl, Docker, or Podman) and
network access:

```bash
./build.sh
```

The runtime is auto-detected (nerdctl → docker → podman); force one with
`CONTAINER_CLI=nerdctl ./build.sh`.

This builds the image, proves it works offline (runs the self-test inside
`docker run --network none`), exports a rootfs tarball, and assembles everything
into `bundle/`. Copy `bundle/` to the airgapped machine and follow
[`bundle-assets/README-IMPORT.md`](bundle-assets/README-IMPORT.md).

```
./build.sh [--skip-test] [--no-cache]
```

## How it works

```
build.sh ──> docker build (Dockerfile)
                 └─ Ansible playbook (local connection) provisions everything
             docker run --network none  <selftest>     # offline gate
             docker export | gzip  ──>  bundle/*.tar.gz # rootfs for wsl --import
             + import.ps1 + README-IMPORT.md + docs + tests + SHA256SUMS
```

Provisioning is **Ansible**, run inside the Docker build. The same playbook can
be applied to a running container after the fact:

```bash
docker run -d --name wsl-build debian:13-slim sleep infinity
# (install ansible in it, copy this repo to /provision, then:)
ansible-playbook -i 'localhost,' -c local ansible/playbook.yml
```

## Layout

| Path | What |
|------|------|
| [`build.sh`](build.sh) | Single entrypoint: build → test → export → bundle. |
| [`Dockerfile`](Dockerfile) | Debian 13 base; installs Ansible; runs the playbook. |
| [`ansible/vars/versions.yml`](ansible/vars/versions.yml) | **Pinned versions** for every non-apt tool. Bump here. |
| [`ansible/roles/`](ansible/roles/) | One role per concern (apt, kube, neovim, dotnet, shell, …). |
| [`config/`](config/) | Editable source config: zshrc, starship.toml, aliases, LazyVim. |
| [`firstrun/`](firstrun/) | The first-run zsh wizard. |
| [`docs/`](docs/) | `tools.tsv` (single source), `wsltools` command, man-page generator. |
| [`tests/`](tests/) | Offline self-test + expected-tools list. |
| [`bundle-assets/`](bundle-assets/) | Import helper + import README templated into `bundle/`. |

## Installed software

The full list lives in [`included_software.txt`](included_software.txt) and is
rendered in-instance by `wsltools` / `man wsltools`. Highlights:

- **Shell:** zsh (default) + zap plugins, starship (k8s module on), zoxide, fzf, tmux (system-clipboard yank), eza, duf, bpytop
- **Editors:** Neovim (`nvim` vanilla; `vim`/`lvim` = LazyVim, primed for offline) with LSP autocompletion (Tab to accept) for Python, TS/JS, HTML/CSS, JSON, YAML, Bash, Docker, Lua, C#
- **Kubernetes:** kubectl, kubecolor, kubectx/kubens, kubie, k9s, stern, helm, popeye, resource-capacity, kubectl-neat
- **Containers:** skopeo, oras, dive
- **Git:** git, lazygit, glab
- **Dev:** .NET SDK 8 + 10, Node.js 22, PowerShell, gcc/build-essential, pipx/poetry/pipenv
- **Misc:** ripgrep, fd, jq, httpie, tcpdump, bitwarden CLI, yazi, tldr (offline cache), cht.sh

## Customizing

- **Add/upgrade a binary:** edit its `version` (or `url`) in
  [`ansible/vars/versions.yml`](ansible/vars/versions.yml) and rebuild.
- **Add an apt package:** append to `ansible/roles/apt_tools/tasks/main.yml`.
- **Change shell/prompt/aliases:** edit files in [`config/`](config/).
- **Tune LazyVim:** edit [`config/nvim/`](config/nvim/); add treesitter parsers
  in `lua/plugins/treesitter.lua` and LSP servers in `lua/plugins/mason.lua`
  (then register them in `opts.servers`, see `lua/plugins/langs.lua`), then
  rebuild so they're re-primed for offline use.
- **Add a tool to the docs/tests:** add a row to
  [`docs/tools.tsv`](docs/tools.tsv) and a line to
  [`tests/expected-tools.txt`](tests/expected-tools.txt).

## Notes

- **Default user is root** (WSL import default). Create a user later with
  `adduser` and set `[user] default=` in `/etc/wsl.conf` if desired.
- **cht.sh** needs a reachable server; on a true airgap use `tldr` (bundled
  offline) as the cheatsheet source. See the import README.
- **Nerd Font** required (Windows-side) for icons in eza/starship/yazi.
- Image is large (~3–5 GB) — two .NET SDKs + LSP servers dominate.
- Versions in `versions.yml` are pins as of authoring; if a release URL 404s at
  build time, bump that tool's version (the build fails loudly, never silently).
