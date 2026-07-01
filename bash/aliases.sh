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
    new | add | tmp | temp)
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

  local repo
  repo="$(
    {
      local path
      for path in "${paths[@]}"; do
        [[ -d "$path" ]] || continue

        find "$path" -mindepth 2 -maxdepth 2 -type d ! -name "*.worktrees"
        find "$path" -mindepth 2 -maxdepth 2 -type d -name "*.worktrees" \
          -exec find {} -mindepth 1 -maxdepth 1 -type d \;
      done
    } | awk 'NF && !seen[$0]++' | fzf --prompt="Your repositories > "
  )" || return

  [[ -n "$repo" ]] && cd "$repo"
}
