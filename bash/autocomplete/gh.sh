#!/usr/bin/env bash

# autocomplete for gh
if type gh &>/dev/null; then
  eval "$(gh completion -s bash)"
fi
