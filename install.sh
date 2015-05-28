#!/bin/sh

echo "Starting Serubin's dotfile install..."
# Get current dir (so run this script from anywhere)
export DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Update dotfiles itself first
[ -d "$DOTFILES_DIR/.git" ] && git --work-tree="$DOTFILES_DIR" --git-dir="$DOTFILES_DIR/.git" pull origin master

# Backing up current configurations
echo "Moving previous configurations to dotfiles/bak/"
mkdir $DOTFILES_DIR/bak

if [ -e "$HOME/.bash_profile" ]; then
	mv $HOME/.bash_profile $DOTFILES_DIR/bak/.bash_profile
fi

if [ -e "$HOME/.bashrc" ]; then
	mv $HOME/.bashrc $DOTFILES_DIR/bak/.bashrc
fi

if [ -e "$HOME/.inputrc" ]; then
	mv $HOME/.inputrc $DOTFILES_DIR/bak/.inputrc
fi

if [ -e "$HOME/.gitconfig" ]; then
	mv $HOME/.gitconfig $DOTFILES_DIR/bak/.gitconfig
fi

if [ -e "$HOME/.gitconfig_global" ]; then
	mv $HOME/.gitconfig_global $DOTFILES_DIR/bak/.gitconfig_global
fi

if [ -e "$HOME/.vim" ]; then
	mv $HOME/.vim $DOTFILES_DIR/bak/.vim
fi

if [ -e "$HOME/.vimrc" ]; then
	mv $HOME/.vimrc $DOTFILES_DIR/bak/.vimrc
fi

echo "Creating symlinks"
# Bunch of symlinks
ln -sfv "$DOTFILES_DIR/runcom/.bash_profile" ~
ln -sfv "$DOTFILES_DIR/runcom/.inputrc" ~
ln -sfv "$DOTFILES_DIR/git/.gitconfig" ~
ln -sfv "$DOTFILES_DIR/git/.gitignore_global" ~ # needs creation
ln -sfv "$DOTFILES_DIR/vim/.vimrc" ~
mkdir -p ~/.vim/
ln -sfv "$DOTFILES_DIR/vim/vundle.vim" ~/.vim/

if [ ! -e "$HOME/.custom" ]; then
	mv $DOTFILES_DIR/bash/.custom  ~
fi
source install/vim.sh

source ~/.bash_profile
