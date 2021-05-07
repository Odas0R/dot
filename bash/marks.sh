export MARKPATH=$HOME/.marks

function _wordlist() {
	find $MARKPATH -type l -printf "%f\n"
}

jump() {
	[[ -d $MARKPATH/$1 && $1 ]] && cd -P $MARKPATH/$1 || echo -e ${red}Available:${reset} $(_wordlist)
}

cmark() {
	[[ -d $MARKPATH/$1 && $1 ]] && code $MARKPATH/$1 || echo -e ${red}Available:${reset} $(_wordlist)
}

vmark() {
 [[ ! -f $MARKPATH/$1/$2 && $2 ]] && vim "$MARKPATH/$1/$2" || [[ -d $MARKPATH/$1 && $1 ]] && vim -c "Files $MARKPATH/$1" || echo -e ${red}Available:${reset} $(_wordlist)
}

cpmark() {
	[[ -d $MARKPATH/$1 && $1 && $2 && -d $2 ]] && rsync -a -P -r --exclude="node_modules" $MARKPATH/$1/ $2 || echo -e ${red}Available:${reset} $(_wordlist)
}

mark() {
	mkdir -p $MARKPATH
	ln -s "$(pwd)" "$MARKPATH/$1"
}

unmark() {
	rm -i "$MARKPATH/$1"
}

marks() {
	ls -l "$MARKPATH" | sed 's/  / /g' | cut -d' ' -f9- | sed 's/ -/\t-/g' && echo
}

_marksCompletion() {
	local curw=${COMP_WORDS[COMP_CWORD]}
	local wordlist=$(_wordlist)
	COMPREPLY=($(compgen -W '${wordlist[@]}' -- "$curw"))
	return 0
}

complete -F _marksCompletion jump unmark cmark cpmark vmark
