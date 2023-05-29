#!/usr/bin/env bash

# Editor Aliases (incase you misspell)
alias nv="nvimr"
alias nvr="nvimr"
alias nv="nvimr"

# Utils
alias ..="cd .."
alias ls="ls --format=single-column --classify --color --group-directories-first"
alias la="ls -la"
alias sb="source ~/.bashrc"

alias hosts="sudoedit /etc/hosts"

alias luamake=/home/odas0r/tools/lua-language-server/3rd/luamake/luamake

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

# nvm automatically switches to the correct node version
load-nvmrc() {
  local node_version
  local nvmrc_path
  local nvmrc_node_version

  node_version="$(nvm version)"
  nvmrc_path="$(nvm_find_nvmrc)"

  if [[ -n "$nvmrc_path" ]]; then
    nvmrc_node_version=$(nvm version "$(cat "${nvmrc_path}")")

    if [[ "$nvmrc_node_version" = "N/A" ]]; then
      nvm install
    elif [[ "$nvmrc_node_version" != "$node_version" ]]; then
      nvm use
    fi
  elif [[ "$node_version" != "$(nvm version default)" ]]; then
    echo "Reverting to nvm default version"
    nvm use default
  fi
}
cd() {
  builtin cd "$@" || exit 1
  load-nvmrc
}
