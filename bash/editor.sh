#!/usr/bin/env bash

_hasDuckyKeyboard() {
  test -n "$(lsusb -v 2>/dev/null | grep -E '(^Bus|Keyboard)' | grep -w 'Varmilo Keyboard')"
}


# remap capslock for whole system to ESC (X only)
if [ -n "${DISPLAY}" ]; then
  # setxkbmap -option caps:swapescape
  setxkbmap -option caps:escape
  if _hasDuckyKeyboard; then
  # https://gist.github.com/jatcwang/ae3b7019f219b8cdc6798329108c9aee
  setxkbmap -layout pt -model macbook79
  fi
  # setxkbmap -option caps:escape
  setxkbmap -layout pt
fi

export HRULEWIDTH=73

# Define the editor
export VISUAL=/usr/bin/nvim
export EDITOR="$VISUAL"
