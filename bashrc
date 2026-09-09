#!/usr/bin/env bash

export SHELL="$BASH"

eval "$(/opt/homebrew/bin/brew shellenv)"

# source all files
for file in $HOME/.bash/*.sh; do
  . $file
done

# # source all completion files
for file in $HOME/.bash/autocomplete/*.sh; do
  . $file
done

[[ -f "$HOME/.env" ]] && source "$HOME/.env"
