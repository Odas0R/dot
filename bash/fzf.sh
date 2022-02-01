#!/usr/bin/env bash

# source "/usr/share/doc/fzf/examples/key-bindings.bash"
# source "/usr/share/doc/fzf/examples/completion.bash"
[ -f ~/.fzf.bash ] && source ~/.fzf.bash

FD_OPTIONS="--follow --exclude .git --exclude node_modules"
FZF_BINDS="--bind 'f2:toggle-preview,ctrl-d:half-page-down,ctrl-u:half-page-up,ctrl-/:toggle-all'"
FZF_STYLES="--height=90% --layout=reverse --preview-window right:60%"

FZF_TOKYO_THEME='
	--color=fg:#c0caf5,bg:#1a1b26,hl:#bb9af7
	--color=fg+:#c0caf5,bg+:#1a1b26,hl+:#7dcfff
	--color=info:#7aa2f7,prompt:#7dcfff,pointer:#7dcfff
	--color=marker:#9ece6a,spinner:#9ece6a,header:#9ece6a'

export FZF_DEFAULT_OPTS="--no-mouse ${FZF_STYLES} ${FZF_BINDS} ${FZF_TOKYO_THEME}"

export FZF_DEFAULT_COMMAND="fd --type f --type l ${FD_OPTIONS}"
export FZF_CTRL_T_COMMAND="fd ${FD_OPTIONS}"
export FZF_ALT_C_COMMAND="fd --type d ${FD_OPTIONS}"

# Bindings
bind -x '"\C-p": vf'
bind -x '"\\": nvim .'

# To install fd
# sudo apt install fd-find
# ln -s $(which fdfind) ~/.local/bin/fd
# Make sure that $HOME/.local/bin is in your $PATH.
