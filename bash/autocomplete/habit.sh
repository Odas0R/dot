#!/usr/bin/env bash

if [[ -x "$(command -v habit)" ]]; then
  complete -C habit habit
fi
