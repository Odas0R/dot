#!/usr/bin/env bash

if [[ "$(uname)" == "Darwin" ]]; then
  # https://docs.docker.com/engine/cli/completion/#bash
  [[ -r "/opt/homebrew/etc/profile.d/bash_completion.sh" ]] && . "/opt/homebrew/etc/profile.d/bash_completion.sh"
else
  [[ -f "/usr/share/bash-completion/bash_completion" ]] && . "/usr/share/bash-completion/bash_completion"
fi
