#!/usr/bin/env python3
"""HEAD-check every pinned download URL in ansible/vars/versions.yml.

Run this before a long build after bumping versions — it catches 404s / renamed
release assets in seconds instead of failing minutes into the Ansible run.

    python3 dev/check-urls.py

Exit code is non-zero if any URL is not reachable (HTTP 200).
Requires PyYAML (pip install pyyaml) and network access.
"""
import os
import sys
import urllib.request
import urllib.error

try:
    import yaml
except ImportError:
    sys.exit("PyYAML required: pip install pyyaml")

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VERSIONS = os.path.join(REPO, "ansible", "vars", "versions.yml")


def head(url: str):
    """Return HTTP status (int) or an error string."""
    req = urllib.request.Request(url, method="HEAD")
    try:
        return urllib.request.urlopen(req, timeout=20).status
    except urllib.error.HTTPError as e:
        return e.code
    except Exception as e:  # noqa: BLE001
        return str(e)


def main() -> int:
    data = yaml.safe_load(open(VERSIONS))
    bad = 0

    print("== github_bins ==")
    for it in data.get("github_bins", []):
        url = it["url"].replace("__VER__", str(it["version"]))
        st = head(url)
        ok = st == 200
        bad += 0 if ok else 1
        print(f"  {it['name']:>22}  {st}{'' if ok else '   <<< BAD'}")

    # Specialised roles build their URLs themselves; mirror them here.
    nv = data["neovim_version"]
    pw = data["powershell_version"]
    te = data["tealdeer_version"]
    tsc = data["treesitter_cli_version"]
    extra = {
        "neovim": f"https://github.com/neovim/neovim/releases/download/v{nv}/nvim-linux-x86_64.tar.gz",
        "powershell": f"https://github.com/PowerShell/PowerShell/releases/download/v{pw}/powershell-{pw}-linux-x64.tar.gz",
        "tealdeer": f"https://github.com/dbrgn/tealdeer/releases/download/v{te}/tealdeer-linux-x86_64-musl",
        "tree-sitter-cli": f"https://github.com/tree-sitter/tree-sitter/releases/download/v{tsc}/tree-sitter-linux-x64.gz",
    }
    print("== specialised roles ==")
    for name, url in extra.items():
        st = head(url)
        ok = st == 200
        bad += 0 if ok else 1
        print(f"  {name:>22}  {st}{'' if ok else '   <<< BAD'}")

    print()
    print("All URLs reachable." if bad == 0 else f"{bad} URL(s) unreachable — fix versions.yml.")
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
