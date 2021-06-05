# Variables
export DESKTOP="/mnt/c/Users/guilh/Desktop"
export BROWSER="/mnt/c/Program\ Files/Mozilla\ Firefox/firefox.exe"

alias desktop="cd $DESKTOP"
alias rmidn="rm -r **/*:Zone.Identifier && rm -R **/.*:Zone.Identifier"
alias sb="source ~/.bashrc"
alias fixtime="sudo ntpdate time.windows.com"

# Vim
alias vi="vim"
alias v="vim"

alias la="ls -la"
alias ls="ls --format=single-column --classify --color --group-directories-first"
alias ..="cd .."
cd() {
  builtin cd "$@" && ls
}

alias gs="git status -s"
alias ga="git add ."
alias gc="git commit"
alias gp="git push"
alias gb="git branch -a -l -v"
alias gf="git fetch origin"
alias gl="git log --pretty=format:'%C(blue)%h%C(red)%d %C(white)%s - %C(cyan)%cn,%C(green)%cr'"

# Get the pid of a locahost:$1
pid() {
  ss -lptn "sport = :$1"
}

# jump to mark
jump() {
  [ -h "$MARKPATH/$1" ] && cd -P "$MARKPATH/$1" || echo "mark not found"
}
