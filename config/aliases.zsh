# Aliases & integrations (baked in; edit here or override in ~/.zshrc.local).

# eza replaces ls with the requested layout.
if command -v eza >/dev/null; then
  alias ls='eza --group-directories-first -a -l --icons'
  alias ll='eza --group-directories-first -a -l --icons'
  alias lt='eza --group-directories-first -a --icons --tree --level=2'
fi

# kubecolor as a drop-in for kubectl (colorised output).
if command -v kubecolor >/dev/null; then
  alias kubectl='kubecolor'
  alias k='kubecolor'
else
  alias k='kubectl'
fi

# kubectx / kubens short forms
alias kctx='kubectx'
alias kns='kubens'

# Handy defaults
alias vi='vim'                 # vim -> LazyVim wrapper
alias cat='cat'               # (bat not installed; keep cat)
alias df='duf'                # nicer disk usage
alias top='bpytop'
alias lg='lazygit'
