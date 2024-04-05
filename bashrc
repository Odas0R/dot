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

[ -f ~/.fzf.bash ] && source ~/.fzf.bash

alias luamake="/home/nucleus/tools/lua-language-server/3rd/luamake/luamake"
