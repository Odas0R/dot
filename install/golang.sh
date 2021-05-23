#!/bin/sh

release=$(
  curl --silent https://golang.org/doc/devel/release.html |
    grep -Eo 'go[0-9]+(\.[0-9]+)+' |
    sort -V |
    uniq |
    tail -1
)
os="linux"
arch="amd64"
tarFile=$release.$os-$arch.tar.gz

sudo rm -rf /usr/local/go &&
  curl https://storage.googleapis.com/golang/$tarFile --output $tarFile &&
  sudo tar -C /usr/local -xzf $tarFile &&
  sudo rm $tarFile

echo "Dont forget to: export PATH=PATH:/usr/local/go/bin"
