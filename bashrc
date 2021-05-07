export LS_COLORS="di=1;36"

# Paths
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export GOPATH="$HOME/go"
export
PATH="$PATH:/usr/local/go/bin:$GOPATH/bin:$HOME/.local/bin/scripts"

# first whatever the system has (required for completion, etc.)
if [ -e /etc/bashrc ]; then
    source /etc/bashrc
fi

# source all files
for file in "$HOME/.bash/*.sh"; do
  source $file
done





