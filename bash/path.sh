#!/usr/bin/env bash

export DOT="$HOME/github.com/odas0r/dot"

export LOCAL_BIN="$HOME/.local/bin"
export LOCAL_BIN_SCRIPTS="$HOME/.local/bin/scripts"

export PNPM_HOME="$HOME/.local/share/pnpm"
export NODE_HOME="$HOME/nodejs/current"

export ZET="$HOME/github.com/odas0r/zet"

# Go
export GOROOT="/usr/local/go"
export GOPATH="$HOME/go"

# emsdk
export EMSDK_ROOT="$HOME/emsdk"
export EMSCRIPTEN_ROOT="$HOME/emsdk/upstream/emscripten"

# opencode
export OPEN_CODE="$HOME/.opencode/bin"

# bun
export BUN_INSTALL="$HOME/.bun"

# gcloud
export GCLOUD="/opt/homebrew/share/google-cloud-sdk"

# Fixing GNU utils in macOS
#
# brew install coreutils findutils gnu-sed gawk grep gnu-tar
#
GNU_UTILS=""
GNU_UTILS+="/opt/homebrew/opt/coreutils/libexec/gnubin:" # coreutils
GNU_UTILS+="/opt/homebrew/opt/findutils/libexec/gnubin:" # find
GNU_UTILS+="/opt/homebrew/opt/grep/libexec/gnubin:"      # grep
GNU_UTILS+="/opt/homebrew/opt/gawk/libexec/gnubin:"      # awk
GNU_UTILS+="/opt/homebrew/opt/gnu-sed/libexec/gnubin:"   # sed
GNU_UTILS+="/opt/homebrew/opt/gnu-tar/libexec/gnubin"    # tar

# Global Path
PATH="$GNU_UTILS:$PATH:/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin:"

PATH+="$LOCAL_BIN:$LOCAL_BIN_SCRIPTS:"
PATH+="$GOROOT/bin:$GOPATH/bin:"
PATH+="$GCLOUD/bin:"
PATH+="$PNPM_HOME:"
PATH+="$NODE_HOME/bin:"
PATH+="$BUN_INSTALL/bin:"
PATH+="$EMSDK_ROOT:"
PATH+="$EMSCRIPTEN_ROOT:"
PATH+="$OPEN_CODE"

export PATH
