#!/usr/bin/env bash

declare magenta="\e[1;35m"
declare yellow="\e[1;33m"
declare cyan="\e[1;36m"
declare green="\e[1;32m"
declare red="\e[1;31m"
declare reset="\e[0m"

parse_git_branch() {
  # 1. Exit immediately if not a git repository.
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    return
  fi

  # 2. Check for uncommitted changes ("dirty" state).
  local color=$magenta
  if ! git diff --quiet --ignore-submodules HEAD &>/dev/null; then
    color=$yellow
  fi

  # 3. Get the current branch name or commit hash for detached HEAD.
  local branch=$(git branch --show-current 2>/dev/null)
  if [[ -z "$branch" ]]; then
    # In detached HEAD state, show the short commit hash.
    branch="($(git rev-parse --short HEAD))"
  fi

  # 4. Print the final, formatted output.
  echo -e "${color}[${branch}]${reset}"
}

parse_docker_context() {
  local DANGEROUS_CONTEXTS=("muxit" "mypolis")
  local context=$(docker context show 2>/dev/null)

  if [[ -n "$context" ]]; then
    local is_dangerous=false
    for dangerous_ctx in "${DANGEROUS_CONTEXTS[@]}"; do
      if [[ "$context" == "$dangerous_ctx" ]]; then
        is_dangerous=true
        break
      fi
    done

    if [[ "$is_dangerous" == true ]]; then
      echo -e "${red}[🐳${context}]${reset}" # Red for dangerous contexts
    else
      echo -e "${green}[🐳${context}]${reset}" # Green for safe contexts
    fi
  fi
}

# --- Prompt Assembly ---

ret=$?
PS1=$(if [[ ${ret} = 0 ]]; then echo "🚀 "; else echo "🔥 "; fi)
PS1+="$cyan/\W$reset"
PS1+=" \$(parse_git_branch)"
PS1+=" \$(parse_docker_context) " # <-- This is the new line
PS1+="$ "

PS2="Keep typing...> "
