#!/bin/bash

parse_git_branch() {
  if ! git rev-parse HEAD -- >/dev/null 2>&1; then
    git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/[\1 ⚡] /'
  else
    git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/[\1] /'
  fi
}

# Prints 👻 if invalid command,🚀 if valid.
PS1="\`if [ \$? = 0 ]; then echo "🚀"; else echo "👻"; fi\` "
PS1+="$start_print$cyan_bold$end_print/\W$start_print$end_theme$end_print"
PS1+=" $start_print$purple_bold$end_print\$(parse_git_branch)$start_print$end_theme$end_print"
PS1+="$ "

PS2="📝keep typing...> "
