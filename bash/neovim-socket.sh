if [[ -z "$TMUX" ]]; then
  export NVIM_SOCKET="$HOME/.cache/nvim/nvim_socket.pane_${TMUX_PANE}.pipe"
else
  export NVIM_SOCKET="$HOME/.cache/nvim/nvim_socket.pipe"
fi
