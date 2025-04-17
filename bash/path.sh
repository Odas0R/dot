#!/usr/bin/env bash

export DOT="$HOME/github.com/odas0r/dot"

export SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

export LOCAL_BIN="$HOME/.local/bin"
# the PATH for global scripts
export LOCAL_BIN_SCRIPTS="$HOME/.local/bin/scripts"

# pnpm package manager
export PNPM_HOME="$HOME/.local/share/pnpm"
export VOLTA_HOME="$HOME/.volta"

# zet path
export ZET="$HOME/github.com/odas0r/zet"

# Go
export GOROOT="/usr/local/go"
export GOPATH="$HOME/go"

# Fixing GNU utils in macOS
#
# brew install coreutils findutils gnu-sed gawk grep gnu-tar
#
GNU_UTILS=""
GNU_UTILS+="/opt/homebrew/opt/coreutils/libexec/gnubin/man:"
GNU_UTILS+="/opt/homebrew/opt/findutils/libexec/gnubin:" # find
GNU_UTILS+="/opt/homebrew/opt/grep/libexec/gnubin:" # grep
GNU_UTILS+="/opt/homebrew/opt/gawk/libexec/gnubin:" # awk
GNU_UTILS+="/opt/homebrew/opt/gnu-sed/libexec/gnubin:" # sed
GNU_UTILS+="/opt/homebrew/opt/gnu-tar/libexec/gnubin" # tar

# Global Path
PATH="$GNU_UTILS:$PATH:/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin:"

PATH+="$LOCAL_BIN:$LOCAL_BIN_SCRIPTS:"
PATH+="$GOROOT/bin:$GOPATH/bin:"
PATH+="$PNPM_HOME:"
PATH+="$VOLTA_HOME/bin"

export PATH
