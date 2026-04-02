#!/usr/bin/env bash

for file in /opt/homebrew/etc/bash_completion.d/*; do
  if [[ -f $file ]]; then
    source "$file"
  fi
done
