#!/usr/bin/env bash

export SHELL="/usr/local/bin/bash"

eval "$(/opt/homebrew/bin/brew shellenv)"

# source all files
for file in $HOME/.bash/*.sh; do
	. $file
done

# # source all completion files
for file in $HOME/.bash/autocomplete/*.sh; do
  . $file
done
