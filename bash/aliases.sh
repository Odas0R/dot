# Variables
DESKTOP="/mnt/c/Users/guilh/Desktop"

alias open="explorer.exe"
alias desktop="cd $DESKTOP"
alias rmidn="rm -r **/*:Zone.Identifier && rm -R **/.*:Zone.Identifier"
alias vi="vim"
alias v="vim"

alias la="ls -la"
alias ls="ls --format=single-column --classify --color --group-directories-first"
alias ..="cd .."
cd() {
	builtin cd "$@" && ls
}

alias rm="rm -i"
alias cp="cp -i"
alias mv="mv -i"

alias gs="git status -s"
alias ga="git add ."
alias gc="git commit"
alias gp="git push"
alias gb="git branch -a -l -v"
alias gf="git fetch origin"
alias gl="git log --pretty=format:'%C(blue)%h%C(red)%d %C(white)%s - %C(cyan)%cn,%C(green)%cr'"
alias gd="git diff"

gcp() {
	ga && gc && gp
}

# Get the pid of a locahost:$1
pid() {
	ss -lptn "sport = :$1"
}
