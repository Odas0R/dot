#!/usr/bin/env bash

# Read the instructions
# https://github.com/posener/complete/tree/master

if [[ ! -x "$(command -v gocomplete)" ]]; then
  echo "You need to install gocomplete"
  exit 1
fi

complete -C /home/odas0r/go/bin/gocomplete go
