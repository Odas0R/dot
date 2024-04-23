#!/usr/bin/env bash

if [[ -n "$WSL_DISTRO_NAME" ]]; then
  if [[ -z "$TMUX" ]]; then
    echo "Starting tmux session..."
    tmux attach -t wsl || tmux new -s wsl
  fi
fi

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
