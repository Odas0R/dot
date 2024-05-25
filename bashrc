#!/usr/bin/env bash

# source all files
for file in $HOME/.bash/*.sh; do
  . $file
done

# source all completion files
for file in $HOME/.bash/autocomplete/*.sh; do
  . $file
done

# *BECAREFUL:*
#
# Tmux does not modify the PATH env var. It does cache the PATH from the first
# client to create a session, so all the PATH modifications should be done
# before starting tmux.
#
if [[ -n "$WSL_DISTRO_NAME" ]]; then
  if [[ "$TERM" != "xterm-kitty" ]] && [[ -z "$TMUX" ]]; then
    echo "Starting tmux session..."
    tmux attach -t wsl || tmux new -s wsl
  fi
fi
