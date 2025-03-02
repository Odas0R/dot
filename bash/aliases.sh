#!/bin/bash

# Utils
alias ..="cd .."
alias ls="ls --format=single-column --classify --color --group-directories-first"
alias la="ls -la"
alias sb="source ~/.bashrc"

alias hosts="sudoedit /etc/hosts"
alias luamake="/home/odas0r/tools/lua-language-server/3rd/luamake/luamake"
alias android-studio="/home/odas0r/tools/android-studio/bin/studio.sh"

# alias ssh="ssh.exe"
# alias ssh-add="ssh-add.exe"

repos() {
  local paths=(
    "$HOME/github.com"
    "$HOME/gitlab.com"
  )

  local all_repos=""
  for path in "${paths[@]}"; do
    if [[ -d "$path" ]]; then
      if [[ -z "$all_repos" ]]; then
        all_repos=$(find "$path" -mindepth 2 -maxdepth 2 -type d)
      else
        all_repos="$all_repos"$'\n'"$(find "$path" -mindepth 2 -maxdepth 2 -type d)"
      fi
    fi
  done

  repo=$(echo "$all_repos" | fzf-tmux -p 40% --multi --prompt="Your repositories > ")
  [ -n "$repo" ] && cd "$repo" || return
}
