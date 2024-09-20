[[ $- != *i* ]] && return

set -o vi

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

export FZF_DEFAULT_OPTS="--color 16"
eval "$(fzf --bash)"

export VISUAL=vim

