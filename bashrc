#!/usr/bin/env bash

if [ -e /etc/bashrc ]; then
  source /etc/bashrc
fi

# source all files
for file in $HOME/.bash/*.sh; do
  . $file
done

for file in $HOME/.bash/autocomplete/*.sh; do
  . $file
done

alias luamake=/home/odas0r/tools/lua-language-server/3rd/luamake/luamake

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
