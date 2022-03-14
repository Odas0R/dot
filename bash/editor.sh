#!/usr/bin/env bash

# remap capslock for whole system to ESC (X only)
if [ -n "${DISPLAY}" ]; then
  setxkbmap -option caps:swapescape
  # setxkbmap -option caps:escape
  setxkbmap -layout pt
fi

export HRULEWIDTH=73

# Define the editor
if [[ ! -x "$(command -v nvim-nvr)" ]]; then
  export VISUAL=/usr/bin/vim
  export EDITOR="$VISUAL"
else
  if [[ $OSTYPE == "darwin"* ]]; then
    VISUAL=/usr/local/bin/nvim
    EDITOR="$VISUAL"

    export VISUAL
    export EDITOR
  else
    VISUAL=/usr/bin/nvim
    EDITOR="$VISUAL"

    export VISUAL
    export EDITOR
  fi
fi
