# Variables
desktop="/mnt/c/Users/guilh/Desktop"

# Utils
alias open="explorer.exe"
alias desktop="cd $desktop"
alias rmidn="rm -r **/*:Zone.Identifier && rm -R **/.*:Zone.Identifier"
alias vi="vim"

# Most used files
alias todos="vim ~/notes/TODOS.md"

# Create a new script file
newx() {
	[[ -f ~/.bash/$1.sh ]] && echo "$1.sh already exists!" || (touch ~/.bash/$1.sh && vim ~/.bash/$1.sh)
}
# Get the pid of a locahost:$1
pid() {
	ss -lptn "sport = :$1"
}

# Commands Shortcuts
alias la="ls -la"
alias ls="ls --format=single-column --classify --color --group-directories-first"
alias ..="cd .."
cd() {
	builtin cd "$@" && ls
}

# Change Dotfiles
alias ev="vim ~/.vimrc"
alias evp="vim ~/.vim/config/plugins.vim"
alias eb="vim ~/.bashrc"
alias eba="vim ~/.bash/aliases.sh"
alias sb="source ~/.bashrc"

# Security
alias rm="rm -i"
alias cp="cp -i"
alias mv="mv -i"

# Git Shortcuts
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
