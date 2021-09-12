#!/usr/bin/env bash

# Check docs for help:
# https://bats-core.readthedocs.io/en/stable/tutorial.html
setup() {
  load 'test_helper/bats-support/load'
  load 'test_helper/bats-assert/load'
}

DOT="$HOME/dot/"

@test "run git setup" {
  run "$DOT/git/setup"

  # .gitconfig must exist and be a symlink
  assert [ -h "$HOME/.gitconfig" ]

  # .gitconfig must point to gitconfig
  got="$(readlink "$HOME/.gitconfig")"
  expected="$HOME/dot/git/gitconfig"
  assert_equal "$got" "$expected"

}

@test "run tmux setup" {
  run "$DOT/tmux/setup"

  # .tmux.conf must exist and be a symlink
  assert [ -h "$HOME/.tmux.conf" ]

  # .tmux.conf must point to tmux.conf
  got="$(readlink "$HOME/.tmux.conf")"
  expected="$HOME/dot/tmux/tmux.conf"
  assert_equal "$got" "$expected"

}

@test "run gh setup" {
  run "$DOT/gh/setup"

  # has a gh config directory
  assert [ -d "$HOME/.config/gh" ]

  # config.yml must exist and be a symlink
  assert [ -h "$HOME/.config/gh/config.yml" ]

  # config/gh/config.yml must point to dot/../gh/config.yml
  got="$(readlink "$HOME/.config/gh/config.yml")"
  expected="$HOME/dot/gh/config.yml"
  assert_equal "$got" "$expected"
}

@test "install custom scripts" {
  run "$DOT/setup"

  # bin folder must exist
  assert [ -d "$HOME/.local/bin" ]

  # script must exist, be a folder and it is a symlink
  assert [ -d "$HOME/.local/bin/scripts" ]
  assert [ -h "$HOME/.local/bin/scripts" ]

  # ../.local/bin must point to ../dot/scripts
  got="$(readlink "$HOME/.local/bin/scripts")"
  expected="$HOME/dot/scripts"
  assert_equal "$got" "$expected"
}

@test "run setup neovim" {
  run "$DOT/nvim/setup"

  # nvim config directory must exist
  assert [ -d "$HOME/.config/nvim" ]

  # vimrc and neovim init.vim
  assert [ -h "$HOME/.config/nvim/init.vim" ]
  assert [ -h "$HOME/.vimrc" ]

  # spell must be a directory and a symlink
  assert [ -d "$HOME/.config/nvim/spell" ]
  assert [ -h "$HOME/.config/nvim/spell" ]

  # coc settings is a symlink
  assert [ -h "$HOME/.config/nvim/coc-settings.json" ]

  # plug must be installed
  assert [ -f "$HOME/.config/nvim/autoload/plug.vim" ]
}

@test "run setup fonts" {
  run "$DOT/fonts/setup"

  # font path must exist
  assert [ -d "$HOME/.local/share/fonts" ]

  # all fonts under ..dot/fonts must be in ../share/fonts
  readarray -d '' got < <(
    find "$HOME/.local/share/fonts" -mindepth 1 -type f -name '*.ttf'
  )
  readarray -d '' expected < <(
    find "$HOME/dot/fonts" -mindepth 1 -type f -name '*.ttf'
  )
  for (( i = 0; i < ${#expected[@]}; i++ )); do
    assert_equal "$(basename "${got[$i]}")" "$(basename "${expected[$i]}")"
  done
}

@test "run bash setup" {
  run "$DOT/setup"

  # bashrc must be a symlink
  assert [ -h "$HOME/.bashrc" ]

  # .bashrc must point to ..dot/bashrc
  got="$(readlink "$HOME/.bashrc")"
  expected="$HOME/dot/bashrc"
  assert_equal "$got" "$expected"

  # inputrc must be a symlink
  assert [ -h "$HOME/.inputrc" ]

  # .inputrc must point to ..dot/inputrc
  got="$(readlink "$HOME/.inputrc")"
  expected="$HOME/dot/inputrc"
  assert_equal "$got" "$expected"

  # .bash must be a symlink and a directory
  assert [ -d "$HOME/.bash" ]
  assert [ -h "$HOME/.bash" ]

  # .bash must point to ..dot/bash
  got="$(readlink "$HOME/.bash")"
  expected="$HOME/dot/bash"
  assert_equal "$got" "$expected"
}
