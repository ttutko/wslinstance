# Airgapped Debian 12 WSL instance — Import Guide

This bundle contains a self-contained WSL2 distribution. Everything is baked in;
**no network is required** on this machine.

## Contents

| File | Purpose |
|------|---------|
| `debian-wsl-airgap.tar.gz` | The WSL rootfs (import this). |
| `import.ps1` | PowerShell helper that imports + verifies the checksum. |
| `SHA256SUMS` | Checksum of the tarball. |
| `docs/tools.tsv` | Reference list of installed tools. |
| `tests/` | Offline self-test (also baked into the image as `wsl-selftest`). |

## Requirements

- Windows 10 2004+ / Windows 11 with **WSL2** enabled
  (`wsl --install --no-distribution` once, or `wsl --set-default-version 2`).

## Import

### Option A — helper script
```powershell
powershell -ExecutionPolicy Bypass -File .\import.ps1
```

### Option B — manual
```powershell
wsl --import DebianAirgap C:\WSL\DebianAirgap debian-wsl-airgap.tar.gz --version 2
wsl -d DebianAirgap
```

## First launch

- You start as **root** (this instance's default).
- A short **first-run wizard** configures your zsh options: prompt/starship
  preset, plugin toggles, and emacs/vi keybindings. Re-run it anytime with
  `wsl-firstrun`.

## Discover what's installed

```bash
wsltools          # colorized, grouped list with examples
man wsltools      # full reference
tldr <command>    # offline, example-driven help for most commands
```

## Verify offline

```bash
wsl-selftest      # runs every tool with no network and reports PASS/FAIL
```

## Notes / limitations

- **Icons** (in `exa`, starship, yazi) need a **Nerd Font** selected in your
  Windows terminal — that's a client-side setting, not part of the image.
- **cht.sh / chtsh** queries a remote server, so it does **not** return content
  on a fully airgapped host. Use `tldr` for offline cheatsheets. If you need
  cht.sh offline, stand up a local `cheat.sh` server and point `CHTSH_URL` at it.
- **Editors:** `nvim` is vanilla Neovim; `vim` / `lvim` launch the LazyVim IDE
  config (plugins, treesitter parsers, and LSP servers are all pre-installed).

## Uninstall

```powershell
wsl --unregister DebianAirgap
```
