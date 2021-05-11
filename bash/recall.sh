export REMINDERSPATH=$HOME/notes/reminders

# Take it this way:
#
#   Retrieving information using active recall helps you remember it.
#   It’s much better than simply recognizing an answer, re-reading
#   information, note-taking, or concept mapping.

recall() {
  local file="${REMINDERSPATH}/${1}.md"

  [ ! -n "${1}" ] && printf "usage: recall <topic> \n" && return

  if [ ! -f "${file}" ]; then
    printf "# ${2}\n\n" >"${file}"
    vim $file
  else
    vim $file
  fi
}

forget() {
  local file="${REMINDERSPATH}/${1}.md"
  local forgotten="${REMINDERSPATH}/forgotten"

  [ ! -d "${forgotten}" ] && mkdir $forgotten

  [ ! -n "${1}" ] && printf "usage: recall <topic> \n" && return

  if [ -f "${file}" ]; then
    mv $file $forgotten
  else
    echo "topic doesn't exist. \n"
  fi

  echo "usage: recall <topic> \n"
}

_recall() {
  local wordlist=$(find $REMINDERSPATH -iname "*.md" -exec sh -c 'for f
do basename -- "$f" .md;done' sh {} +)
  local curw=${COMP_WORDS[COMP_CWORD]}
  COMPREPLY=($(compgen -W '${wordlist[@]}' -- "$curw"))
  return 0
}

complete -F _recall recall forget
