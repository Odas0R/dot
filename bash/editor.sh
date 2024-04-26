#!/usr/bin/env bash

_hasDuckyKeyboard() {
  test -n "$(lsusb -v 2>/dev/null | grep -E '(^Bus|Keyboard)' | grep -w 'Varmilo Keyboard')"
}

if [[ -z "${WSL_DISTRO_NAME}" ]]; then
  # remap capslock for whole system to ESC (X only)
  if [[ -n "${DISPLAY}" ]]; then
    # https://gist.github.com/jatcwang/ae3b7019f219b8cdc6798329108c9aee
    if _hasDuckyKeyboard; then
      setxkbmap -layout pt -model macintosh
    else
      setxkbmap -layout pt -model asus_laptop
    fi

    # Default Options
    setxkbmap -option caps:escape
  fi
fi

export HRULEWIDTH=73

# Define the editor
export VISUAL="nvimr"
export EDITOR="$VISUAL"

if [[ -n "${WSL_DISTRO_NAME}" ]]; then
  # execute this to symlink the chrome program
  # ln -sf "/mnt/c/Program Files/Google/Chrome/Application/chrome.exe" ~/.local/bin/chrome
  export BROWSER="$HOME/.local/bin/chrome"
fi
