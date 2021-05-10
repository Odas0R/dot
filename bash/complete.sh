# autocomplete for gh
if type gh &>/dev/null; then
	eval "$(gh completion -s bash)"
fi


_config() {
  local wordList=$(config --bash-completion)
	local curw=${COMP_WORDS[COMP_CWORD]}
	COMPREPLY=($(compgen -W '${wordList[@]}' -- "$curw"))
	return 0
}

_mark() {
	local curw=${COMP_WORDS[COMP_CWORD]}
	local wordlist=$(find $MARKPATH -type l -printf "%f\n")
	COMPREPLY=($(compgen -W '${wordlist[@]}' -- "$curw"))
	return 0
}

complete -F _mark jump unmark cpmark vmark

complete -F _config config

