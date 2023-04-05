#!/usr/bin/env bash

# https://github.com/azate/simple-indication-of-workspaces

dconf write /org/gnome/mutter/dynamic-workspaces false

dconf write /org/gnome/desktop/wm/preferences/num-workspaces 5

for i in {1..10}; do
  dconf write "/org/gnome/desktop/wm/keybindings/switch-to-workspace-${i}" "['<Super>$i']"
  dconf write "/org/gnome/shell/keybindings/switch-to-application-${i}" "@as []"
done
