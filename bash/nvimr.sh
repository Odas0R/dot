#!/bin/bash

if [[ "$TERM" == "xterm-kitty" ]]; then
  panel_pid=$(kitty @ ls | jq '.[] | .tabs[] | .windows[] | select(.is_self == true) | .pid')
  panel_title=$(kitty @ ls | jq '.[] | .tabs[] | .windows[] | select(.is_self == true) | .title')

  # trim all the newlines, since the output of kitty @ ls is multiline
  panel_pid=$(echo "$panel_pid" | tr -d '\n' | tr -d ' ')
  panel_title=$(echo "$panel_title" | tr -d '"' | tr -d ' ')

  export NVIM_SOCKET="$HOME/.cache/nvim/nvim_socket.${panel_pid}.${panel_title}.pipe"
elif [[ -n "$TMUX" ]]; then
  export NVIM_SOCKET="$HOME/.cache/nvim/nvim_socket.pane_${TMUX_PANE}.pipe"
else
  export NVIM_SOCKET="$HOME/.cache/nvim/nvim_socket.pipe"
fi
