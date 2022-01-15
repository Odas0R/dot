#!/usr/bin/env bash

shopt -s progcomp

_zet() {
  local cur prev firstword lastword complete_words

  # Don't break words at : and =, see [1] and [2]
  COMP_WORDBREAKS=${COMP_WORDBREAKS//[:=]/}

  cur=${COMP_WORDS[COMP_CWORD]}
  prev=${COMP_WORDS[COMP_CWORD - 1]}
  firstword=$(_get_firstword)
  lastword=$(_get_lastword)

  GLOBAL_COMMANDS="\
    help\
    n\
    new\
    q\
    query\
    qp\
    query-project\
    link\
    orphans\
    rename\
    p\
    project"

  # Un-comment this for debug purposes:
  # echo -e "\nprev = $prev, cur = $cur, firstword = $firstword, lastword = $lastword\n"

  case "${firstword}" in
  p | project | qp | query-project)
    PROJECTS="$HOME/zet/projects"

    # get all projects from $ZET/projects
    complete_words=$(find "$PROJECTS" -mindepth 1 -maxdepth 1 -type d -printf '%f\n')
    ;;
  *)
    complete_words="$GLOBAL_COMMANDS"
    ;;
  esac

  # Either display words or options, depending on the user input
  # Note: Don't double quote this. It will fuck up the autocompletion
  COMPREPLY=($(compgen -W "$complete_words" -- $cur))

  return 0
}

# Determines the first non-option word of the command line. This
# is usually the command
_get_firstword() {
  local firstword i

  firstword=
  for ((i = 1; i < ${#COMP_WORDS[@]}; ++i)); do
    if [[ ${COMP_WORDS[i]} != -* ]]; then
      firstword=${COMP_WORDS[i]}
      break
    fi
  done

  echo "$firstword"
}

# Determines the last non-option word of the command line. This
# is usally a sub-command
_get_lastword() {
  local lastword i

  lastword=
  for ((i = 1; i < ${#COMP_WORDS[@]}; ++i)); do
    if [[ ${COMP_WORDS[i]} != -* ]] && [[ -n ${COMP_WORDS[i]} ]] && [[ ${COMP_WORDS[i]} != $cur ]]; then
      lastword=${COMP_WORDS[i]}
    fi
  done

  echo "$lastword"
}

complete -F _zet zet
