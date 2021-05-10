# Script Paths
export MARKPATH=$HOME/.marks

jump() {
  [ -h "$MARKPATH/$1" ] && cd -P "$MARKPATH/$1" ||  echo "mark not found"
}
