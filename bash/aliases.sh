#!/bin/bash

export DESKTOP="/mnt/c/Users/guilh/Desktop"
export BROWSER="/mnt/c/Program Files/BraveSoftware/Brave-Browser/Application/brave.exe"

# Shortcuts
alias distractions="vim $HOME/zet/todos.md"
alias tech="vim $HOME/zet/tech.md"
alias habits="vim $HOME/zet/habits.md"

# Vim
alias vi="vim"
alias v="vim"

# Source bash
alias sb="source ~/.bashrc"

# Utils
alias la="ls -la"
alias ls="ls --format=single-column --classify --color --group-directories-first"
alias ..="cd .."
cd() {
  builtin cd "$@" && ls
}

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
