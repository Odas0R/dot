#!/bin/sh

# Browser, Desktop, ...
if [[ $OSTYPE == "darwin"* ]]; then
  export BROWSER="/Applications/Brave\ Browser.app/Contents/MacOS/Brave\ Browser"
else
  export DESKTOP="/mnt/c/Users/guilh/Desktop"
  export BROWSER="/mnt/c/Program Files/BraveSoftware/Brave-Browser/Application/brave.exe"
fi

# Utils
export MARKPATH="$HOME/.marks"
export SNIPPETS="$HOME/snippets"
export LOCAL_SCRIPTS="$HOME/.local/bin/scripts" # $HOME/.local/bin is the PATH for global scripts
export TOOLS="$HOME/tools"

#NVM (Node Version Manager) (OLD)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm

# Java
export JAVA_HOME="/usr/lib/jvm/java-8-openjdk-amd64"

# Go
export GOROOT="/usr/local/go"
export GOPATH="$HOME/go"

# Cargo
export CARGOPATH="/home/odas0r/.cargo"

# Perl on WSL
if [ -n "$WSL_DISTRO_NAME" ]; then
  export PERLPATH="/home/odas0r/perl5"
  export PERL5LIB="/home/odas0r/perl5/lib/perl5${PERL5LIB:+:${PERL5LIB}}"
  export PERL_LOCAL_LIB_ROOT="/home/odas0r/perl5${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"
  export PERL_MB_OPT='--install_base "/home/odas0r/perl5"'
  export PERL_MM_OPT="INSTALL_BASE=/home/odas0r/perl5"
fi

# Tools
if [[ $OSTYPE == "darwin"* ]]; then
  export LUA_LSP="$TOOLS/lua-language-server/bin/macOS"
else
  export LUA_LSP="$TOOLS/lua-language-server/bin/Linux"
fi

# Global Path
export PATH="$PATH:/bin:/usr/local/bin:$GOROOT/bin:$GOPATH/bin:$CARGOPATH/bin:$PERLPATH/bin:$LOCAL_SCRIPTS:$LUA_LSP"
