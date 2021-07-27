#!/bin/bash

export DESKTOP="/mnt/c/Users/guilh/Desktop"
export BROWSER="/mnt/c/Program\ Files/Mozilla\ Firefox/firefox.exe"

# Paths
alias desktop="cd ${DESKTOP}"

# Shortcuts
alias todos="vim $HOME/zet/todos.md"
alias goals="vim $HOME/zet/goals.md"
alias tech="vim $HOME/zet/tech.md"

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

# really can't understand why this wont work as a script.
jump() {
  if [ -h "$MARKPATH/$1" ]; then
    cd -P "${MARKPATH}/${1}" && gitsync &
  else
    echo "mark not found"
  fi
}
