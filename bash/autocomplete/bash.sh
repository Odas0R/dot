#!/usr/bin/env bash

# macos
[[ -r "/usr/local/etc/profile.d/bash_completion.sh" ]] && . "/usr/local/etc/profile.d/bash_completion.sh"

# debian,...
[[ -f "/usr/share/bash-completion/bash_completion" ]] && . "/usr/share/bash-completion/bash_completion"
