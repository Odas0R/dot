#!/usr/bin/env bash

# Utils
alias ..="cd .."
alias ls="ls --format=single-column --classify --color --group-directories-first"
alias la="ls -la"
alias sb="source ~/.bashrc"

alias hosts="sudoedit /etc/hosts"

# you can't cd on the current shell process by "cd-ing" on a shell script
# https://stackoverflow.com/questions/255414/why-cant-i-change-directories-using-cd-in-a-script
jump() {
  [ -h "$MARKPATH/$1" ] && cd "$(readlink "${MARKPATH}/${1}")" || echo "mark not found :("
}

# cd into repos where you'll want to work on
repos() {
  local GITHUB_PATH="$HOME/github.com"

  repo=$(
    find "$GITHUB_PATH" -mindepth 2 -maxdepth 2 -type d |
      fzf-tmux -p 40% --multi --prompt="Your repositories > "
  )

  cd "$repo" || return
}
