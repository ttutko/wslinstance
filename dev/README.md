# dev/ — maintainer helper scripts

Not part of the image build; these speed up editing and validating the builder.

| Script | What it does |
|--------|--------------|
| [`check-urls.py`](check-urls.py) | HEAD-checks every pinned download URL in `ansible/vars/versions.yml`. Run after bumping versions to catch 404s / renamed release assets in seconds, before a long build. `python3 dev/check-urls.py` (needs PyYAML + network). |
| [`prime-test.sh`](prime-test.sh) | Exercises the LazyVim **offline priming** (both `prime.lua` + `prime-ts.lua`) in a throwaway container in ~2-4 min, instead of a full `./build.sh`. Reports plugin/parser/Mason counts. Use it when iterating on `config/nvim/**` or the neovim role. Runtime auto-detected; needs network + sandbox access. |

Typical loop when changing tools or LazyVim config:

```bash
# 1. bump/add versions, edit config
python3 dev/check-urls.py          # all URLs reachable?
dev/prime-test.sh                  # LazyVim still primes offline? (neovim changes)
CONTAINER_CLI=nerdctl ./build.sh   # full build + offline self-test gate
```

See [`../CLAUDE.md`](../CLAUDE.md) for where each kind of tool lives and the solved gotchas.
