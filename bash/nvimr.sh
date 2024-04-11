#!/bin/bash

if [[ "$TERM" == "xterm-kitty" ]]; then
  # neovim socket pipe
  #
  # Will create a unique Neovim socket for each terminal process, not just each
  # terminal window.
  panel_pid=$(kitty @ ls | jq '.[] | .tabs[] | .windows[] | select(.is_self == true) | .pid')
  panel_title=$(kitty @ ls | jq '.[] | .tabs[] | .windows[] | select(.is_self == true) | .title')

  # trim all the newlines, since the output of kitty @ ls is multiline
  panel_pid=$(echo "$panel_pid" | tr -d '\n' | tr -d ' ')
  panel_title=$(echo "$panel_title" | tr -d '"' | tr -d ' ')

  export NVIM_SOCKET="$HOME/.cache/nvim/nvim_socket.${panel_pid}.${panel_title}.pipe"
fi
