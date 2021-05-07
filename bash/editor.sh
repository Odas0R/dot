# remap capslock for whole system to ESC (X only)
if [ -n "${DISPLAY}" ];then
  setxkbmap -option caps:escape
fi

export HRULEWIDTH=73
export EDITOR=vi
export VISUAL=vi
export EDITOR_PREFIX=vi
