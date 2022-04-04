#!/usr/bin/env bash

declare magenta="\e[1;35m"
declare cyan="\e[1;36m"
declare reset="\e[0m"

parse_git_branch() {
  if ! git rev-parse HEAD -- >/dev/null 2>&1; then
    git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/[\1 ⚡] /'
  else
    git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/[\1] /'
  fi
}

# ret=$?
# PS1=$(if [[ ${ret} = 0 ]]; then echo "👋 "; else echo "🐞 "; fi)
PS1="=> "
PS1+="$cyan/\W$reset"
PS1+=" $magenta\$(parse_git_branch)$reset"
PS1+="$ "

PS2="Keep typing...> "
