#!/usr/bin/env bash

# shellcheck disable=SC2155


if [[ -n "${WSL_DISTRO_NAME}" ]]; then
  # execute this to symlink the chrome program
  # ln -sf "/mnt/c/Program Files/Google/Chrome/Application/chrome.exe" ~/.local/bin/chrome
  export BROWSER="$HOME/.local/bin/chrome"
  export CHROME_EXECUTABLE="$HOME/.local/bin/chrome"
fi

# export XDG_CONFIG_HOME="$HOME/.config"
export DOT_FILES="$HOME/github.com/odas0r/dot"
export SPDLOG_LEVEL=debug

# Followed this to install openssl 1.1.1, which is needed on some applications.
# If some problem related to openssl happens this might be the cause, since I
# replaced the v3.X.X with openssl.old
#
# https://askubuntu.com/questions/1126893/how-to-install-openssl-1-1-1-and-libssl-package#1127228
export LD_LIBRARY_PATH="/opt/openssl/lib:${LD_LIBRARY_PATH}"

# Utils
export MARKPATH="$HOME/.marks"
export SNIPPETS="$HOME/snippets"
export LOCAL_BIN="$HOME/.local/bin"
export LOCAL_BIN_SCRIPTS="$HOME/.local/bin/scripts" # $HOME/.local/bin is the PATH for global scripts
export TOOLS="$HOME/tools"

# Dot Path
export DOT="$HOME/github.com/odas0r/dot"

# Deno
export DENO_INSTALL="/home/odas0r/.deno"

# pnpm package manager
export PNPM_HOME="/home/odas0r/.local/share/pnpm"

export VOLTA_HOME="$HOME/.volta"

# Java
# export JAVA_HOME=$(/usr/libexec/java_home -v 17)
# export JUNIT_HOME="$HOME/java"
# export CLASSPATH="$CLASSPATH:$JUNIT_HOME/junit-4.13.2.jar:$JUNIT_HOME/hamcrest-core-1.3.jar"

# zet path
export ZET="$HOME/github.com/odas0r/zet"

# Go
export GOROOT="/usr/local/go"
export GOPATH="$HOME/go"

# Ruby
export GEM_HOME="$HOME/.gem"

# CBUILD
# export CPATH="$HOME/llvm-project/build/lib/clang/19/include:$CPATH"
# export C_INCLUDE_PATH="$HOME/llvm-project/build/lib/clang/19/include:$C_INCLUDE_PATH"
# export CPLUS_INCLUDE_PATH="$HOME/llvm-project/build/lib/clang/19/include:$CPLUS_INCLUDE_PATH"

# Cargo
export CARGOPATH="/home/odas0r/.cargo"

# Tools
export LUA_LANGUAGE_SERVER="$TOOLS/lua-language-server/bin"

# Perl
export PERLPATH="/hom/odas0r/perl5"
export PERL5LIB="/home/odas0r/perl5/lib/perl5${PERL5LIB:+:${PERL5LIB}}"
export PERL_LOCAL_LIB_ROOT="/home/odas0r/perl5${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"
export PERL_MB_OPT='--install_base "/home/odas0r/perl5"'
export PERL_MM_OPT="INSTALL_BASE=/home/odas0r/perl5"

# Android Studio
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_STUDIO_HOME="/home/odas0r/tools/android-studio"
export ANDROID_SDK_BUILD_TOOLS="$HOME/Android/Sdk/build-tools/33.0.0"
export ANDROID_SDK_PLATFORM_TOOLS="$HOME/Android/Sdk/platform-tools"
export ANDROID_SDK_EMULATOR="$HOME/Android/Sdk/emulator"

export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64

export FLUTTER_BIN="$HOME/flutter/bin"

# Global Path
PATH="$PATH:/bin:/usr/local/bin:"
PATH+="$GOROOT/bin:$GOPATH/bin:"
PATH+="$CARGOPATH/bin:"
PATH+="$PERLPATH/bin:"
PATH+="$DENO_INSTALL/bin:"
PATH+="$LOCAL_BIN:$LOCAL_BIN_SCRIPTS:"
PATH+="$LUA_LANGUAGE_SERVER:"
PATH+="$GNU_UTILS:"
PATH+="$LD_LIBRARY_PATH:"
PATH+="$JAVA_HOME/bin:"
PATH+="$FLUTTER_BIN:"
PATH+="$ANDROID_HOME:"
PATH+="$ANDROID_STUDIO_HOME/bin:"
PATH+="$ANDROID_SDK_BUILD_TOOLS:"
PATH+="$ANDROID_SDK_PLATFORM_TOOLS:"
PATH+="$ANDROID_SDK_EMULATOR:"
PATH+="$PNPM_HOME:"
PATH+="$VOLTA_HOME/bin:"
PATH+="$GEM_HOME/bin"

export PATH
