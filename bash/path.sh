#!/bin/sh

# Utils
export MARKPATH="$HOME/.marks"
export SNIPPETS="$HOME/snippets"
export LOCAL_SCRIPTS="$HOME/.local/bin/scripts" # $HOME/.local/bin is the PATH for global scripts
export DESKTOP="/mnt/c/Users/guilh/Desktop"
export BROWSER="/mnt/c/Program Files/BraveSoftware/Brave-Browser/Application/brave.exe"

#NVM (Node Version Manager) (OLD)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm

# Java
export JAVA_HOME="/usr/lib/jvm/java-8-openjdk-amd64"

# Go
export GOROOT="/usr/local/go"
export GOPATH="$HOME/go"

# Perl
export PERLPATH="/home/odas0r/perl5"
export PERL5LIB="/home/odas0r/perl5/lib/perl5${PERL5LIB:+:${PERL5LIB}}"
export PERL_LOCAL_LIB_ROOT="/home/odas0r/perl5${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"
export PERL_MB_OPT="--install_base \"/home/odas0r/perl5\""
export PERL_MM_OPT="INSTALL_BASE=/home/odas0r/perl5"

# Global Path
export PATH="$PATH:$GOROOT/bin:$GOPATH/bin:$PERLPATH/bin:$LOCAL_SCRIPTS"
