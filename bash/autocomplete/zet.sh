#!/usr/bin/env bash

if [[ -x "$(command -v nr)" ]]; then
  complete -C zet zet
fi
