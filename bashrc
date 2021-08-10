#!/bin/sh
if [ -e /etc/bashrc ]; then
  source /etc/bashrc
fi

# source all files
for file in $HOME/.bash/*.sh; do
  . $file
done

# Bug on VSCode terminal
# source default bash_completion
. /usr/share/bash-completion/bash_completion

# source all autocomplete
for file in $HOME/.bash/autocomplete/*.sh; do
  . $file
done
