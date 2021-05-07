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
start_print="\["
end_print="\]"
end_theme="\e[m"
reset="\e[0m"

# Regular
black="\e[0;30m" # Black
red="\e[0;31m" # Red
green="\e[0;32m" # Green
yellow="\e[0;33m" # 
blue="\e[0;34m" # Blue
purple="\e[0;35m" # Purple
cyan="\e[0;36m" # Cyan
white="\e[0;37m" # White

# Bold
black_bold="\e[1;30m" # Black
red_bold="\e[1;31m" # Red
green_bold="\e[1;32m" # Green
yellow_bold="\e[1;33m" # 
blue_bold="\e[1;34m" # Blue
purple_bold="\e[1;35m" # Purple
cyan_bold="\e[1;36m" # Cyan
