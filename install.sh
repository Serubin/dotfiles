#!/bin/bash

# Get current dir (so run this script from anywhere)
export DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# saves dotfile location
echo "export DOTFILES_DIR=${DOTFILES_DIR}" > ${HOME}/.dotfiles_loc

# Source install functions
source ${DOTFILES_DIR}/util/inputFunc.sh
source ${DOTFILES_DIR}/packages/install_package.sh 

# Get *nix distro
source ${DOTFILES_DIR}/util/detectos.sh

# Update dotfiles itself first - 
[ -d "${DOTFILES_DIR}/.git" ] && git --work-tree="${DOTFILES_DIR}" --git-dir="${DOTFILES_DIR}/.git" pull origin master

# Backing up current configurations
echo "Moving previous configurations to dotfiles/bak/"
mkdir -p ${HOME}/.dotfiles-bak

if [ -r "${HOME}/.bash_profile" ]; then
	mv ${HOME}/.bash_profile ${HOME}/.dotfiles-bak/
fi

if [ -r "$HOME/.bashrc" ]; then
	mv ${HOME}/.bashrc ${HOME}/.dotfiles-bak/
fi

if [ -r "${HOME}/.inputrc" ]; then
	mv ${HOME}/.inputrc ${HOME}/.dotfiles-bak/
fi

echo "Creating symlinks"
# Bunch of symlinks
ln -sfv "${DOTFILES_DIR}/runcom/.bashrc" ~
ln -sfv "${DOTFILES_DIR}/runcom/.bash_profile" ~
ln -sfv "${DOTFILES_DIR}/runcom/.inputrc" ~

if [ ! -r "${HOME}/.custom" ]; then
	cp ${DOTFILES_DIR}/bash/.custom  ~
fi


installPackage "" "required" # required packages

installPackage "cli" "git"
installPackage "cli" "vim"
installPackage "cli" "htop"
installPackage "cli" "archey"

if [ `getInputBoolean "Would you like to install desktop packages?"` == "1" ]; then
	installPackage "desktop" "sublime"
	installPackage "desktop" "i3"
fi

source ~/.bashrc

cd $DOTFILES_DIR

# Removing variables
unset DOTFILES_DIR git vim htop sublime
