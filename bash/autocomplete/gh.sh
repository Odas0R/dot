#!/usr/bin/env bash

if type gh &>/dev/null; then
  eval "$(gh completion -s bash)"
fi
