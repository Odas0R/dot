#!/usr/bin/env bash

# Vi
alias vimdiff="nvim -d"

# ngrok aliases
alias ng-pg="ngrok tcp --region=eu --remote-addr=3.tcp.eu.ngrok.io:22146 5432"

# Shortcuts
alias fonts="open ~/.local/share/fonts"
alias horario="open ~/zet/assets/horario.png"
alias kitty="nvim ~/.config/kitty/kitty.conf"

alias lazydocker="TERM=xterm-kitty lazydocker"

# Utils
alias ..="cd .."
alias ls="ls --format=single-column --classify --color --group-directories-first"
alias la="ls -la"
alias sb="source ~/.bashrc"

if [[ $OSTYPE == "darwin"* ]]; then
  alias ls="/usr/local/bin/gls --format=single-column --classify --color --group-directories-first"
  alias la="/usr/local/bin/gls --format=single-column --classify --color --group-directories-first -la"
  alias find="/usr/local/bin/gfind"
fi

# you can't cd on the current shell process by "cd-ing" on a shell script
# https://stackoverflow.com/questions/255414/why-cant-i-change-directories-using-cd-in-a-script
jump() {
  [ -h "$MARKPATH/$1" ] && cd "$(readlink "${MARKPATH}/${1}")" || exit 1
}

#  Use nvr to avoid nesting nvim in Terminal buffers.
alias nvim="nvim-nvr"
