export COMMANDSPATH=$HOME/notes/commands

_cmds() {
  find $COMMANDSPATH -mindepth 1 -maxdepth 1 -type d -printf "%f\n"
}

cmd() {
 [[ -d $COMMANDSPATH/$1 && $1 ]] && vim $COMMANDSPATH/$1/$1.md || echo -e ${red}Available:${reset} $(_cmds)
}

addcmd() {
  [[ ! -d $COMMANDSPATH/$1 && $1 ]] && (mkdir $COMMANDSPATH/$1 && echo "# $1 commands" > $COMMANDSPATH/$1/$1.md && vim $COMMANDSPATH/$1/$1.md) || echo -e ${purple}Error:${reset} command already exists or bad input.
}

rmcmd() {
  [[ -d $COMMANDSPATH/$1 && $1 ]] && rm -rf $COMMANDSPATH/$1 || echo -e ${red}Available:${reset} $(_cmds)
}

_completeCommand() {
  local curw=${COMP_WORDS[COMP_CWORD]}
  local wordlist=$(_cmds)
  COMPREPLY=($(compgen -W '${wordlist[@]}' -- "$curw"))
  return 0
}

complete -F _completeCommand cmd rmcmd
