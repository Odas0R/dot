#!/bin/bash

# vi or die
set -o vi

export HISTCONTROL=ignoreboth
export HISTFILESIZE=10000
export HISTSIZE=${HISTFILESIZE}
