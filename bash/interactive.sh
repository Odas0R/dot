# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# Disable XON/XOFF flow control
# stty -ixon
