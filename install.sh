#!/bin/bash

echo "-------- Setting up Serubin's Dotfiles --------"

# Get current dir (so run this script from anywhere)
export DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ ! -r "${HOME}/.dotfiles.info" ]; then
	echo "-------- Git Author Info --------"
	echo "Please enter your git author information. (name and email)."
	echo "If you want to change this later you can edit '~/dotfiles.info'"

	cp ${DOTFILES_DIR}/util/dotfiles.info-template ${HOME}/.dotfiles.info
	read -p "Name: " gitName
	perl -p -i -e 's/git-name{(.*)}/git-name{'${gitName}'}/x' ~/.dotfiles.info

	read -p "Email: " gitEmail
	gitEmail=$(echo $gitEmail | sed -e 's/[@&]/\\&/g') # escapes @ sign
	perl -p -i -e 's/git-email{.*}/git-email{Serubin\@serubin.net}/x'  ~/.dotfiles.info
fi

# saves dotfile location
perl -p -i -e 's#location{(.*)}#location{'${DOTFILES_DIR}'}#' ~/.dotfiles.info

# Source install functions
source ${DOTFILES_DIR}/util/inputFunc.sh
source ${DOTFILES_DIR}/packages/install_package.sh 

# Get *nix distro
source ${DOTFILES_DIR}/util/detectos.sh

# Update dotfiles itself first - 
echo "Fetching latest from git:"
[ -d "${DOTFILES_DIR}/.git" ] && git --work-tree="${DOTFILES_DIR}" --git-dir="${DOTFILES_DIR}/.git" pull origin master

# Get sudo up to avoid typing it in mid script
echo ""
echo "------------ Sudo/Root Required ------------"
echo "Root or sudo is required to install most packages. Please sudo up:"
sudo echo 'Running in sudo mode'
echo ""

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

# Copy .custom if not exist
if [ ! -r "${HOME}/.custom" ]; then
	cp ${DOTFILES_DIR}/bash/.custom  ~
fi

# Give Arch users a chance to abort
if [ ${DISTRO} == "Arch" ]; then
	echo "====> WARNING <===="
	echo "This script will perform a full system upgrade"
	if [ `getInputBoolean "Do you wish to continue?"` == "0" ]; then
		exit 0
	fi
fi

# package installations
installPackage "" "required" # required packages

installPackage "cli" "git"
installPackage "cli" "vim"
installPackage "cli" "htop"
installPackage "cli" "archey"

# Prompt for desktop
if [ `getInputBoolean "Would you like to install desktop packages?"` == "1" ]; then
	installPackage "desktop" "sublime"
	installPackage "desktop" "i3"
fi

source ~/.bashrc

cd $DOTFILES_DIR

# Removing variables
unset DOTFILES_DIR
