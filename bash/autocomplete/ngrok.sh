#!/usr/bin/env bash

if command -v ngrok &>/dev/null; then
    eval "$(ngrok completion)"
  fi
