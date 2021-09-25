#!/usr/bin/env bash

# Vi
alias vim="nvim"
alias vi="nvim"
alias v="nvim"
alias vimdiff="nvim -d"

# Source bash
alias sb="source ~/.bashrc"

# Utils
alias la="ls -la"

if [[ $OSTYPE == "darwin"* ]]; then
  alias ls="ls"
  alias find="/usr/local/bin/gfind"
else
  alias ls="ls --format=single-column --classify --color --group-directories-first"
fi

alias ..="cd .."

# you can't cd on the current shell process by "cd-ing" on a shell script
# https://stackoverflow.com/questions/255414/why-cant-i-change-directories-using-cd-in-a-script
jump() {
  [ -h "$MARKPATH/$1" ] && cd "$(readlink "${MARKPATH}/${1}")" || exit 1
}
