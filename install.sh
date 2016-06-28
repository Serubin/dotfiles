#!/bin/bash

echo "-------- Setting up Serubin's Dotfiles --------"

source ${HOME}/.dotfiles.info

export flag_help=0
export flag_update=0
export flag_list=0
export flag_install=""

export installed=""
export installed_len+=0

# process arguments
set -- $(getopt "huli:" "$@")

while [ $# -gt 0 ]; do
    case "$1" in
        (-h) flag_help=1                            ;;
        (-u) flag_update=1                          ;;
        (-l) flag_list=1                            ;;
        (-i) flag_install="$flag_install $2"; shift ;;
        (--) shift; break                           ;;
        (*)  break                                  ;;
    esac
    shift
done

# Help options
if [[ ${flag_help} == "1" ]]; then
    echo "usage: ./install -huli:<install>"
    echo "    -h                        Usage"
    echo "    -u                        Update all currently installed packages"
    echo "    -l                        List all currently installed packages"
    echo "    -i <package,package2>     Installs given packages"

    exit
fi

# Update flag
if [[ ${flag_update} == "1" ]]; then
    export installed=(${DOTFILES_INSTALLED})
    export installed_len=${DOTFILES_INSTALLED_LEN}
fi

# List flag
if [[ ${flag_list} == "1" ]]; then
    echo "Not yet implemented"
    exit
fi
# Install flag
if [[ ${flag_install} != "" ]]; then
    echo "Not yet implemented"
    exit
fi
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
if [[ ${flag_update} != "1" ]]; then # if update, don't prompt
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
    echo 's/DOTFILES_INSTALLED=".*"/DOTFILES_INSTALLED="'${installed[@]}'"/g' 
    echo $installed_len
    sed -i -e 's/DOTFILES_INSTALLED=".*"/DOTFILES_INSTALLED="'${installed[@]}'"/g' ${HOME}/.dotfiles.info
    sed -i -e 's/DOTFILES_INSTALLED_LEN=".*"/DOTFILES_INSTALLED_LEN="'${installed_len}'"/g' ${HOME}/.dotfiles.info

    echo "------------ Installing "
    installPackage "" ""
fi

# package updates
if [[ ${flag_update} == "1" ]]; then # if update, don't prompt
    echo "------------ Updating "

    installPackage ${installed_len} ${installed[@]}
fi
cd $DOTFILES_DIR

# Removing variables
unset flag_update flat_install DOTFILES_DIR
