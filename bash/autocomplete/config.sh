#!/bin/sh

_config() {
  wordList=$(config --bash-completion)
  curw=${COMP_WORDS[COMP_CWORD]}
  COMPREPLY=($(compgen -W '${wordList[@]}' -- "$curw"))
  return 0
}
# Complete config commands
complete -F _config config
