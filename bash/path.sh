#!/bin/bash
# Custom Path Variables
export MARKPATH=$HOME/.marks
export SNIPPETS=$HOME/snippets

# NVM (Node Version Manager)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm

export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export GOPATH="$HOME/go"

# Global Path
export PATH="$PATH:/usr/local/go/bin:$GOPATH/bin:$HOME/.local/bin/scripts"
