#!/bin/sh

# Get current dir (so run this script from anywhere)

export DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Update dotfiles itself first

[ -d "$DOTFILES_DIR/.git" ] && git --work-tree="$DOTFILES_DIR" --git-dir="$DOTFILES_DIR/.git" pull origin master

# Backing up current configurations
echo "Moving previous configurations to dotfiles/bak/"
mkdir $DOTFILES_DIR/bak

if [ -d "$HOME/.bashrc" ]; then
	mv $HOME/.bashrc $DOTFILES_DIR/bak/.bashrc
fi

if [ -d "$HOME/.inputrc" ]; then
	mv $HOME/.inputrc $DOTFILES_DIR/bak/.inputrc
fi

if [ -d "$HOME/.gitconfig" ]; then
	mv $HOME/.gitconfig $DOTFILES_DIR/bak/.gitconfig
fi

if [ -d "$HOME/.gitconfig_global" ]; then
	mv $HOME/.gitconfig_global $DOTFILES_DIR/bak/.gitconfig_global
fi

if [ -d "$HOME/.gitconfig_global" ]; then
	mv $HOME/.vim $DOTFILES_DIR/bak/.vim
fi

if [ -d "$HOME/.gitconfig_global" ]; then
	mv $HOME/.vimrc $DOTFILES_DIR/bak/.vimrc
fi
# Bunch of symlinks

ln -sfv "$DOTFILES_DIR/runcom/.bash_profile" ~
ln -sfv "$DOTFILES_DIR/runcom/.inputrc" ~
ln -sfv "$DOTFILES_DIR/git/.gitconfig" ~
ln -sfv "$DOTFILES_DIR/git/.gitignore_global" ~
ln -sfv "$DOTFILES_DIR/etc/mackup/.mackup.cfg" ~
