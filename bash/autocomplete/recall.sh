_recall() {
  local wordlist=$(find $RECALLPATH -iname "*.md" -exec sh -c 'for f
do basename -- "$f" .md;done' sh {} +)
  local curw=${COMP_WORDS[COMP_CWORD]}
  COMPREPLY=($(compgen -W '${wordlist[@]}' -- "$curw"))
  return 0
}

complete -F _recall recall forget
