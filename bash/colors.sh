#!/bin/bash

# Color Syntax:
#
# '\[\e[x;ym $ \e[m\]'
#
#	\e[ - Start color scheme
# x,y - Color pair to use(x;y)
# $ - Can be any text, information (example: username)
# \e[m - Stop color scheme
#
# \[ - start of non-printing sequence
# \] - end of non-printing sequence

#
# Colors
#

# Utils
export start_print="\["
export end_print="\]"
export end_theme="\e[m"
export reset="\e[0m"

# Regular
export black="\e[0;30m"  # Black
export red="\e[0;31m"    # Red
export green="\e[0;32m"  # Green
export yellow="\e[0;33m" #
export blue="\e[0;34m"   # Blue
export purple="\e[0;35m" # Purple
export cyan="\e[0;36m"   # Cyan
export white="\e[0;37m"  # White

# Bold
export black_bold="\e[1;30m"  # Black
export red_bold="\e[1;31m"    # Red
export green_bold="\e[1;32m"  # Green
export yellow_bold="\e[1;33m" #
export blue_bold="\e[1;34m"   # Blue
export purple_bold="\e[1;35m" # Purple
export cyan_bold="\e[1;36m"   # Cyan
