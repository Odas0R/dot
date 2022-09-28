#! /usr/local/bin/bash

if [[ -x "$(command -v x)" ]]; then
  complete -C x x
fi
