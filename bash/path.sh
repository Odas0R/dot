#!/usr/bin/env bash

# Followed this to install openssl 1.1.1, which is needed on some applications.
# If some problem related to openssl happens this might be the cause, since I
# replaced the v3.X.X with openssl.old
#
# https://askubuntu.com/questions/1126893/how-to-install-openssl-1-1-1-and-libssl-package#1127228
export LD_LIBRARY_PATH="/opt/openssl/lib:${LD_LIBRARY_PATH}"

# Utils
export MARKPATH="$HOME/.marks"
export SNIPPETS="$HOME/snippets"
export LOCAL_BIN="$HOME/.local/bin"
export LOCAL_SCRIPTS="$HOME/.local/bin/scripts" # $HOME/.local/bin is the PATH for global scripts
export TOOLS="$HOME/tools"

# Dot Path
export DOT="$HOME/github.com/odas0r/dot"

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
export LUA_LANGUAGE_SERVER="$TOOLS/lua-language-server/bin"

# Perl
export PERLPATH="/hom/odas0r/perl5"
export PERL5LIB="/home/odas0r/perl5/lib/perl5${PERL5LIB:+:${PERL5LIB}}"
export PERL_LOCAL_LIB_ROOT="/home/odas0r/perl5${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"
export PERL_MB_OPT='--install_base "/home/odas0r/perl5"'
export PERL_MM_OPT="INSTALL_BASE=/home/odas0r/perl5"

# Global Path
PATH="$PATH:/bin:/usr/local/bin:"
PATH+="$GOROOT/bin:$GOPATH/bin:"
PATH+="$CARGOPATH/bin:"
PATH+="$PERLPATH/bin:"
PATH+="$LOCAL_BIN:$LOCAL_SCRIPTS:"
PATH+="$LUA_LANGUAGE_SERVER:"
PATH+="$GNU_UTILS:"
PATH+="$LD_LIBRARY_PATH"

export PATH
