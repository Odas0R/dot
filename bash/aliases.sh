#!/usr/bin/env bash

alias ..="cd .."
alias ls="ls --format=single-column --classify --color --group-directories-first"
alias la="ls --format=single-column --classify --color --group-directories-first -la"
alias sb="source ~/.bashrc"

alias luamake="$HOME/tools/lua-language-server/3rd/luamake/luamake"
alias android-studio="$HOME/tools/android-studio/bin/studio.sh"

alias yarn="yarnpkg"

wt() {
  case "${1:-}" in
    cd)
      shift
      local worktree_path
      worktree_path="$(command wt path "$@")" || return
      [[ -n "$worktree_path" ]] && cd "$worktree_path"
      ;;
    new | add)
      local subcommand target_path
      subcommand="$1"
      shift
      target_path="$(command wt "$subcommand" "$@")" || return
      [[ -n "$target_path" ]] && cd "$target_path"
      ;;
    finish)
      shift
      local target_path
      target_path="$(command wt finish "$@")" || return
      [[ -n "$target_path" ]] && cd "$target_path"
      ;;
    *)
      command wt "$@"
      ;;
  esac
}

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
