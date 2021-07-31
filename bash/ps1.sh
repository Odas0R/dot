#!/bin/bash

parse_git_branch() {
  git_folder="./.git"

  if [ -d $git_folder ]; then
    if ! git diff-index --quiet HEAD --; then
      git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/[\1 ⚡] /'
    else
      git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/[\1] /'
    fi
  fi
}

# Prints 👻 if invalid command,🚀 if valid.
PS1="\`if [ \$? = 0 ]; then echo "🚀"; else echo "👻"; fi\` "
PS1+="$start_print$cyan_bold$end_print/\W$start_print$end_theme$end_print"
PS1+=" $start_print$purple_bold$end_print\$(parse_git_branch)$start_print$end_theme$end_print"
PS1+="$ "

PS2="📝keep typing...> "
