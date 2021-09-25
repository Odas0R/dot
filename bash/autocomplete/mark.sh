#!/usr/bin/env bash

_mark() {
  curw=${COMP_WORDS[COMP_CWORD]}
  wordlist=$(find $MARKPATH -type l -printf '%f\n')
  COMPREPLY=($(compgen -W '${wordlist[@]}' -- "$curw"))
  return 0
}

# Complete marks commands
complete -F _mark jump unmark
