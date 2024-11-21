[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'

PS1=''
if [[ -n $SSH_TTY ]]; then
  PS1+='\[\e[33m\]\h\[\e[0m\] '
fi
PS1+='\[\e[2m\]\w\[\e[0m\] '
PS1+='\[\e[34;1m\]> \[\e[0m\]'

export RIPGREP_CONFIG_PATH="$HOME/.config/ripgrep/ripgreprc"

export VISUAL="nvim"
export EDITOR="$VISUAL"

alias g='git'
alias gc='git commit'
alias ga='git add'
alias gap='git add --patch'
alias go='git checkout'
alias gop='git checkout --patch'

function n() {
  nvim --server "$NVIM" --remote "$@"
  exit
}
