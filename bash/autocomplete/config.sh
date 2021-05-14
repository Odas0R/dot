_config() {
  local wordList=$(config --bash-completion)
  local curw=${COMP_WORDS[COMP_CWORD]}
  COMPREPLY=($(compgen -W '${wordList[@]}' -- "$curw"))
  return 0
}

# Complete config commands
complete -F _config config
