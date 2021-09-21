#!/bin/bash

if [ -e /etc/bashrc ]; then
  source /etc/bashrc
fi

# source all files
for file in $HOME/.bash/*.sh; do
  . $file
done

# source all autocomplete
for file in $HOME/.bash/autocomplete/*.sh; do
  . $file
done

alias luamake=/home/odas0r/.config/nvim/lua-language-server/3rd/luamake/luamake
