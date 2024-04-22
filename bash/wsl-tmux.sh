#!/bin/bash

# start tmux session if not already running in wsl

if [[ -n "$WSL_DISTRO_NAME" ]]; then
  if [[ -z "$TMUX" ]]; then
    echo "Starting tmux session..."
    tmux attach -t wsl || tmux new -s wsl
  fi
fi
