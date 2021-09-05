#!/bin/bash

# remap capslock for whole system to ESC (X only)
if [ -n "${DISPLAY}" ]; then
  setxkbmap -option caps:escape
  setxkbmap -layout pt
fi

export HRULEWIDTH=73

# Define the editor
if [ ! -x "$(command -v nvim)" ]; then
  export VISUAL=vim
  export EDITOR="$VISUAL"
else
  export VISUAL=nvim
  export EDITOR="$VISUAL"
fi
