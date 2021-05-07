note() {
 echo "# $2" > ~/notes/$1.md && vim ~/notes/$1.md
}

ni() {
  touch ~/notes/inbox-$1.md && vim ~/notes/inbox-$1.md
}
