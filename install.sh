#!/bin/bash

echo "-------- Setting up Serubin's Dotfiles --------"

# Get current dir (so run this script from anywhere)
export DOTFILES_DIR="$( \cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

mkdir -p ${HOME}/.dotfiles-bak 2> /dev/null

if [ ! -r "${HOME}/.dotfiles.info" ]; then
	echo "-------- Git Author Info --------"
	echo "Please enter your git author information. (name and email)."
	echo "If you want to change this later you can edit '~/dotfiles.info'"

	cp ${DOTFILES_DIR}/util/dotfiles.info-template ${HOME}/.dotfiles.info
	read -p "Name: " git_name
	sed -i -e 's/%git-name%/'${git_name}'/g' ${HOME}/.dotfiles.info

	read -p "Email: " git_email
	git_email=$(echo ${git_email} | sed -e 's/[@&]/\\&/g') # escapes @ sign
	sed -i -e 's/%git-email%/'${git_email}'/g' ${HOME}/.dotfiles.info
fi

source ${HOME}/.dotfiles.info

# saves dotfile location
sed -i -e 's#%location%#'${DOTFILES_DIR}'#g' ${HOME}/.dotfiles.info

# Source install functions
source ${DOTFILES_DIR}/util/inputFunc.sh
source ${DOTFILES_DIR}/packages/install_package.sh 

# Get *nix distro
source ${DOTFILES_DIR}/util/detectos.sh

# Update dotfiles itself first - 
echo "Fetching latest from git:"
[ -d "${DOTFILES_DIR}/.git" ] && git --work-tree="${DOTFILES_DIR}" --git-dir="${DOTFILES_DIR}/.git" pull --recurse-submodules=yes origin master && git submodule init && git submodule update


# Get sudo up to avoid typing it in mid script
echo ""
echo "------------ Sudo/Root Required ------------"
echo "Root or sudo is required to install most packages. Please sudo up:"
sudo echo 'Running in sudo mode'
echo ""

# Give Arch users a chance to abort
if [[ ${DISTRO} == "Arch" ]]; then
	echo "====> WARNING <===="
	echo "This script will perform a full system upgrade"
	if [ `getInputBoolean "Do you wish to continue?"` == "0" ]; then
		return;
	fi
fi

ln -sfv "${DOTFILES_DIR}/common/dircolors-solarized/dircolors.256dark" ~/.dir_colors

# package installations
registerPackage "cli" "required" # required packages

echo "Which shell would you like to use? It's recommend to select ONE."
registerPackage "shell" "bash"
registerPackage "shell" "zsh"

registerPackage "cli" "git"
registerPackage "cli" "vim"
registerPackage "cli" "nvim"
registerPackage "cli" "tmux"
registerPackage "cli" "htop"
registerPackage "cli" "archey"
registerPackage "cli" "vhdl"

# Prompt for desktop
if [[ `getInputBoolean "Would you like to install desktop packages?"` == "1" ]]; then
	registerPackage "desktop" "sublime"
	registerPackage "desktop" "i3"
    registerPackage "desktop" "latex"
fi

echo "------------ Installing "
installPackage

cd $DOTFILES_DIR

# Removing variables
unset DOTFILES_DIR
