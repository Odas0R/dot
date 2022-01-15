#!/usr/bin/env bash

# if test -n "$KITTY_INSTALLATION_DIR"; then
#   export KITTY_SHELL_INTEGRATION="enabled"
#   source "$KITTY_INSTALLATION_DIR/shell-integration/bash/kitty.bash"
# fi

if test -n "$KITTY_INSTALLATION_DIR" -a -e "$KITTY_INSTALLATION_DIR/shell-integration/bash/kitty.bash"; then
  source "$KITTY_INSTALLATION_DIR/shell-integration/bash/kitty.bash"
fi
