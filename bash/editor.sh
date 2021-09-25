#!/usr/bin/env bash

# remap capslock for whole system to ESC (X only)
if [ -n "${DISPLAY}" ]; then
  setxkbmap -option caps:swapescape
  # setxkbmap -option caps:escape
  setxkbmap -layout pt
fi

export HRULEWIDTH=73

# Define the editor
if [ ! -x "$(command -v nvim)" ]; then
  export VISUAL=/usr/bin/vim
  export EDITOR="$VISUAL"
else
  if [[ $OSTYPE == "darwin"* ]]; then
    export VISUAL=/usr/local/bin/nvim
    export EDITOR="$VISUAL"
  else
    export VISUAL=/usr/bin/nvim
    export EDITOR="$VISUAL"
  fi
fi
