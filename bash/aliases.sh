#!/usr/bin/env bash

alias ..="cd .."
alias ls="ls --format=single-column --classify --color --group-directories-first"
alias la="ls --format=single-column --classify --color --group-directories-first -la"
alias sb="source ~/.bashrc"

alias luamake="$HOME/tools/lua-language-server/3rd/luamake/luamake"
alias android-studio="$HOME/tools/android-studio/bin/studio.sh"

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

  repo=$(echo "$all_repos" | fzf --multi --prompt="Your repositories > ")
  [ -n "$repo" ] && cd "$repo" || return
}
