#!/usr/bin/env bash
# =============================================================================
# wsl-firstrun — interactive zsh configuration wizard.
# Runs automatically on the first interactive login and can be re-run anytime
# with `wsl-firstrun`. Writes: ~/.config/wsl/plugins.conf, keybind.zsh, and
# ~/.config/starship.toml (chosen preset, kubernetes module kept enabled).
# =============================================================================
set -euo pipefail

WSL_DIR="$HOME/.config/wsl"
STARSHIP_CFG="$HOME/.config/starship.toml"
MARKER="$WSL_DIR/.firstrun-done"
mkdir -p "$WSL_DIR"

bold() { printf '\033[1m%s\033[0m\n' "$1"; }
rule() { printf '\033[2m%s\033[0m\n' "----------------------------------------------------------------"; }

ask_yn() { # $1 prompt  $2 default(y/n) -> echoes 1/0
  local p="$1" d="${2:-y}" ans
  local hint="[Y/n]"; [ "$d" = n ] && hint="[y/N]"
  read -r -p "$p $hint " ans || true
  ans="${ans:-$d}"
  case "$ans" in [Yy]*) echo 1;; *) echo 0;; esac
}

clear || true
bold "Welcome — let's configure your zsh environment."
echo "You can re-run this anytime with: wsl-firstrun"
rule

# --- 1. starship prompt preset ---------------------------------------------
bold "1) Prompt style (starship)"
echo "   1) default        (bundled, balanced)"
echo "   2) pastel-powerline"
echo "   3) nerd-font-symbols   (needs a Nerd Font in your terminal)"
echo "   4) plain-text-symbols  (no icons)"
echo "   5) tokyo-night"
read -r -p "Choose [1-5] (default 1): " preset_choice || true
case "${preset_choice:-1}" in
  2) preset="pastel-powerline";;
  3) preset="nerd-font-symbols";;
  4) preset="plain-text-symbols";;
  5) preset="tokyo-night";;
  *) preset="default";;
esac

if [ "$preset" != "default" ]; then
  tmp="$(mktemp)"
  if starship preset "$preset" -o "$tmp" 2>/dev/null; then
    # Enforce kubernetes module ON: strip any existing [kubernetes*] block, re-add.
    awk '
      /^\[kubernetes/ { skip=1; next }
      /^\[/           { skip=0 }
      !skip           { print }
    ' "$tmp" > "$STARSHIP_CFG"
    cat >> "$STARSHIP_CFG" <<'EOF'

# kubernetes module kept enabled by wsl-firstrun
[kubernetes]
disabled = false
format = 'on [⎈ $context\($namespace\)](bold blue) '
EOF
    echo "   -> applied '$preset' preset (kubernetes module enabled)."
  else
    echo "   !! could not generate preset; keeping current prompt."
  fi
  rm -f "$tmp"
else
  echo "   -> keeping the default bundled prompt."
fi
rule

# --- 2. zap plugin toggles --------------------------------------------------
bold "2) Shell plugins"
a=$(ask_yn "   Enable autosuggestions (grey inline history hints)?" y)
s=$(ask_yn "   Enable syntax highlighting?" y)
c=$(ask_yn "   Enable extra completions?" y)
cat > "$WSL_DIR/plugins.conf" <<EOF
# Written by wsl-firstrun. 1 = enabled, 0 = disabled.
WSL_PLUGIN_AUTOSUGGESTIONS=$a
WSL_PLUGIN_SYNTAX=$s
WSL_PLUGIN_COMPLETIONS=$c
EOF
echo "   -> saved plugin choices."
rule

# --- 3. keybinding mode -----------------------------------------------------
bold "3) Keybindings"
read -r -p "   Use (e)macs or (v)i keybindings? [E/v] " kb || true
if [ "${kb:-e}" = v ] || [ "${kb:-e}" = V ]; then
  echo "bindkey -v" > "$WSL_DIR/keybind.zsh"
  echo "   -> vi keybindings."
else
  echo "bindkey -e" > "$WSL_DIR/keybind.zsh"
  echo "   -> emacs keybindings."
fi
rule

touch "$MARKER"
bold "All set! Reloading your shell..."
echo "Tip: run 'wsltools' or 'man wsltools' to see everything that's installed."

# Reload into a fresh zsh so choices take effect (only when interactive).
if [ -t 1 ]; then
  exec zsh
fi
