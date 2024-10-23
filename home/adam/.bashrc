[[ $- != *i* ]] && return

set -o vi

alias ls='ls --color=auto'
alias grep='grep --color=auto'

PS1=''
if [[ -n $SSH_TTY ]]; then
  PS1+='\[\e[33m\]\h\[\e[0m\] '
fi
PS1+='\[\e[2m\]\w\[\e[0m\] '
PS1+='\[\e[34;1m\]> \[\e[0m\]'

export RIPGREP_CONFIG_PATH="$HOME/.config/ripgrep/ripgreprc"
export FZF_DEFAULT_COMMAND="rg --files"
export FZF_DEFAULT_OPTS='--border'
#%= FZF_DEFAULT_OPTS+=' --color bg:#$GRAY_01'
#%= FZF_DEFAULT_OPTS+=' --color fg:#$GRAY_10'
#%= FZF_DEFAULT_OPTS+=' --color preview-fg:#$GRAY_11'
#%= FZF_DEFAULT_OPTS+=' --color hl:#$GRAY_11'
#%= FZF_DEFAULT_OPTS+=' --color current-bg:#$GRAY_02'
#%= FZF_DEFAULT_OPTS+=' --color current-fg:#$GRAY_11'
#%= FZF_DEFAULT_OPTS+=' --color current-hl:#$GRAY_12'
#%= FZF_DEFAULT_OPTS+=' --color border:#$GRAY_06'
#%= FZF_DEFAULT_OPTS+=' --color info:#$GRAY_10'
#%= FZF_DEFAULT_OPTS+=' --color prompt:#$BLUE_11'
#%= FZF_DEFAULT_OPTS+=' --color pointer:#$GRAY_08'
#%= FZF_DEFAULT_OPTS+=' --color marker:#$BLUE_11'

export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

eval "$(fzf --bash)"

export VISUAL=nvim

