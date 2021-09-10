#!/bin/bash

# Shortcuts
alias todos="vim ~/zet/todos.md"
alias tech="vim ~/zet/tech.md"
alias habits="vim ~/zet/habits.md"
alias goals="vim ~/zet/goals.md"
alias workflow="vim ~/zet/workflow.md"

# NeoVim
alias vim="nvim"
alias vi="nvim"
alias v="nvim"
alias vimdiff="nvim -d"

# Source bash
alias sb="source ~/.bashrc"

# Utils
alias la="ls -la"
alias ls="ls --format=single-column --classify --color --group-directories-first"
alias ..="cd .."

# cd doesn't work on shell scripts
# https://stackoverflow.com/questions/255414/why-cant-i-change-directories-using-cd-in-a-script
jump() {
  [ -h "$MARKPATH/$1" ] && cd "$(readlink "${MARKPATH}/${1}")" || exit
}
