# Aliases & integrations (baked in; edit here or override in ~/.zshrc.local).

# exa replaces ls with the requested layout.
if command -v exa >/dev/null; then
  alias ls='exa --group-directories-first -a -l --icons'
  alias ll='exa --group-directories-first -a -l --icons'
  alias lt='exa --group-directories-first -a --icons --tree --level=2'
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
