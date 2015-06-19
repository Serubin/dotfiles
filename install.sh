#!/bin/bash

echo "Starting Serubin's dotfile install..."
# Get current dir (so run this script from anywhere)
export DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# saves dotfile location
echo "export DOTFILES_DIR=${DOTFILES_DIR}" > $HOME/.dotfiles_loc

# Get *nix distro
DISTRO_RAW="" # Gets raw os output
DISTRO_RAW_LOC=`echo /etc/*-release`
if [ -r "$DISTRO_RAW_LOC" ]; then
	DISTRO_RAW=$(cat /etc/*-release)
else
	DISTRO_RAW=$(uname)
fi
# Parses out specific distro
DISTRO=`echo $DISTRO_RAW | perl -lne '/(Ubuntu)|(Debian)|(Darwin)/gi && print $&' | head -n1`
unset DISTRO_RAW # unsets util var

# Update dotfiles itself first - 
[ -d "$DOTFILES_DIR/.git" ] && git --work-tree="$DOTFILES_DIR" --git-dir="$DOTFILES_DIR/.git" pull origin master

# Backing up current configurations
echo "Moving previous configurations to dotfiles/bak/"
mkdir $HOME/.dotfiles-bak

if [ -r "$HOME/.bash_profile" ]; then
	mv $HOME/.bash_profile $HOME/.dotfiles-bak/
fi

if [ -r "$HOME/.bashrc" ]; then
	mv $HOME/.bashrc $HOME/.dotfiles-bak/
fi

if [ -r "$HOME/.inputrc" ]; then
	mv $HOME/.inputrc $HOME/.dotfiles-bak/
fi

echo "Creating symlinks"
# Bunch of symlinks
ln -sfv "$DOTFILES_DIR/runcom/.bashrc" ~
ln -sfv "$DOTFILES_DIR/runcom/.bash_profile" ~
ln -sfv "$DOTFILES_DIR/runcom/.inputrc" ~

if [ ! -r "$HOME/.custom" ]; then
	cp $DOTFILES_DIR/bash/.custom  ~
fi

source $DOTFILES_DIR/install/vim/vim.sh

source $DOTFILES_DIR/install/sublime/sublime.sh

source $DOTFILES_DIR/install/git/git.sh

source ~/.bashrc

# Removing variables
unset DOTFILES_DIR
