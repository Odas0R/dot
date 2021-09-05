#!/bin/bash

# Shortcuts
alias todos="vim $HOME/zet/todos.md"
alias tech="vim $HOME/zet/tech.md"
alias habits="vim $HOME/zet/habits.md"
alias goals="vim $HOME/zet/goals.md"
alias workflow="vim $HOME/zet/workflow.md"

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

# Github
alias gs="git status -s"
alias ga="git add ."
alias gc="git commit"
alias gp="git push"
alias gb="git branch -a -l -v"
alias gf="git fetch origin"
alias gl="git log --pretty=format:'%C(blue)%h%C(red)%d %C(white)%s - %C(cyan)%cn,%C(green)%cr'"

# cd doesn't work on shell scripts
# https://stackoverflow.com/questions/255414/why-cant-i-change-directories-using-cd-in-a-script
jump() {
  [ -h "$MARKPATH/$1" ] && cd "$(readlink "${MARKPATH}/${1}")" || exit
}
