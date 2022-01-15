#!/usr/bin/env bash

if type supabase &>/dev/null; then
  eval "$(supabase completion bash)"
fi
