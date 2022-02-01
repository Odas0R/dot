#! /usr/local/bin/bash

if [[ -x "$(command -v nr)" ]]; then
  complete -C nr nr
fi
