#!/usr/bin/env bash

set -o vi

# export HISTCONTROL=ignoreboth
export HISTCONTROL=ignoredups:erasedups
export HISTFILESIZE=10000
export HISTSIZE=${HISTFILESIZE}
