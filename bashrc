#!/bin/sh
if [ -e /etc/bashrc ]; then
  source /etc/bashrc
fi

# source all files
for file in $HOME/.bash/*.sh $HOME/.bash/autocomplete/*.sh; do
  . $file
done
