#!/usr/bin/env bash

# Keep npm login/auth tokens out of this dotfiles repo.
# Tracked, safe defaults live in the npm global config below.
# npm login writes credentials to the private user config below.
export NPM_CONFIG_GLOBALCONFIG="${DOT:-$HOME/github.com/odas0r/dot}/npmrc"
export NPM_CONFIG_USERCONFIG="$HOME/.config/npm/npmrc.local"
