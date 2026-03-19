#!/bin/bash

## Script options
stowOptions="-t $HOME --ignore setup -R -v"
tools=("git" "zsh" "tmux" "nvim")
configTools=("nvim")

## Check for flags
# Check for '-v' flag
verbose=false
for arg in "$@"; do
  if [ "$arg" == "-v" ]; then
    verbose=true
    break
  fi
  if [ "$arg" == "--uninstall" ]; then
    remove=true
    break
  fi
done

redirect=/dev/stdout
[ "$verbose" = false ] && redirect=/dev/null

## Install logic
dotfilesDir="$(cd "$(dirname "$0")" && pwd)"
_HOME=$HOME

# Set current directory the dotfiles directory
cd $dotfilesDir

source ./zsh/.zsh/00-os

echo "Setting up $DISTRO..."
bash ./setup/$DISTRO >$redirect 2>&1

function install_tool() {
  local tool=$1
  echo " ==== Setting up $tool ==== "
  echo -n "Stowing $tool... "

  if [[ " ${configTools[@]} " =~ " $tool " ]]; then
    configOption="-t $HOME/.config/"
  fi

  # Unstow the tool to clean up any old config before stowing
  stow -D $tool $stowOptions $configOption >$redirect 2>&1
  stow $tool $stowOptions $configOption >$redirect 2>&1

  if [ $? -ne 0 ]; then
    echo "Failed!"
    echo ">>>>> $tool was not installed <<<<<"
    return
  fi;

  cd $tool

  echo -n "Running install for $tool... "
  [ -f "setup/$DISTRO" ] && bash setup/$DISTRO >$redirect 2>&1
  [ -f "setup/common" ] && bash setup/common >$redirect 2>&1
  cd $dotfilesDir

  echo "Done"
}

function remove_tool() {
  local tool=$1
  echo " ==== Removing $tool ==== "
  echo -n "Removing $tool... (unstowing)"

  stow -D $tool $stowOptions $configOption

  echo "Done"
}

for tool in "${tools[@]}"; do
  if [ "$remove" = true ]; then
    remove_tool $tool
  else
    install_tool $tool
  fi
done

if [ "$remove" = true ]; then
  echo "All tools removed"
else
  echo "All tools installed"
fi
