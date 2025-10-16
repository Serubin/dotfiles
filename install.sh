#!/bin/bash

## Script options
stowOptions="-t $HOME --ignore setup -R -v"
tools=("git" "zsh" "tmux")

## Check for flags
# Check for '-v' flag
verbose=false
for arg in "$@"; do
    if [ "$arg" == "-v" ]; then
        verbose=true
        break
    fi
done

redirect=/dev/stdout
[ "$verbose" = false ] && redirect=/dev/null

## Install logic
dotfilesDir=$(pwd)
_HOME=$HOME
source ./zsh/.zsh/01-os

echo "Setting up $DISTRO..."
sudo HOME=$HOME bash ./setup/$DISTRO > $redirect 2>&1

for tool in "${tools[@]}"; do
    echo " ==== Setting up $tool ==== "
    echo -n "Stowing $tool... "
    stow $tool $stowOptions

    cd $tool


    echo -n "Running install for $tool... "
    [ -f "setup/$DISTRO" ] && sudo HOME=$HOME bash setup/$DISTRO > $redirect 2>&1
    [ -f "setup/common" ] && sudo HOME=$HOME bash setup/common > $redirect 2>&1
    cd $dotfilesDir

    echo "Done"
done

echo "All tools installed"
