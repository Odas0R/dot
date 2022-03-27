#!/usr/bin/env bash

# Utils
export MARKPATH="$HOME/.marks"
export SNIPPETS="$HOME/snippets"
export LOCAL_BIN="$HOME/.local/bin"
export LOCAL_SCRIPTS="$HOME/.local/bin/scripts" # $HOME/.local/bin is the PATH for global scripts
export TOOLS="$HOME/tools"

#NVM (Node Version Manager) (OLD)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm

# Java
# export JAVA_HOME=$(/usr/libexec/java_home -v 17)
# export JUNIT_HOME="$HOME/java"
# export CLASSPATH="$CLASSPATH:$JUNIT_HOME/junit-4.13.2.jar:$JUNIT_HOME/hamcrest-core-1.3.jar"

# Go
export GOROOT="/usr/local/go"
export GOPATH="$HOME/go"

# Cargo
export CARGOPATH="/home/odas0r/.cargo"

# Tools
export LUA_LSP="$TOOLS/lua-language-server/bin/Linux"

# MacOS Shit
if [[ $OSTYPE == "darwin"* ]]; then
  # CoreUtils for macos
  # brew install coreutils
  export GNU_UTILS="/usr/local/opt/coreutils/libexec/gnubin"

  # Tools
  export LUA_LSP="$TOOLS/lua-language-server/bin/macOS"

fi

# Global Path
export PATH="$PATH:/bin:/usr/local/bin:$GOROOT/bin:$GOPATH/bin:$CARGOPATH/bin:$PERLPATH/bin:$LOCAL_BIN:$LOCAL_SCRIPTS:$LUA_LSP:$GNU_UTILS"
