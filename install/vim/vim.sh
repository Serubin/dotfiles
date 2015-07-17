#!/bin/bash

echo " -- Installing Sublime"

echo "Backing up previous vim config"

if [ -r "$HOME/.vim" ]; then
	mv $HOME/.vim $HOME/.dotfiles-bak/
fi

if [ -r "$HOME/.vimrc" ]; then
	mv $HOME/.vimrc $HOME/.dotfiles-bak/
fi

echo "Starting vim install"

# determin distro
if [ "$DISTRO" == "Debian" ] || [ "$DISTRO" == "Ubuntu" ]; then
	source $DOTFILES_DIR/install/vim/vim.debian
elif [ "$DISTRO" == "Darwin" ]; then
	source $DOTFILES_DIR/install/vim/vim.osx
else
	echo "ERROR: This os doesn't support vim installations."
fi
# config install
ln -sfv "$DOTFILES_DIR/install/vim/config/.vimrc" ~
mkdir -p $HOME/.vim/
ln -sfv "$DOTFILES_DIR/install/vim/config/vundle.vim" ~/.vim/

BUNDLE_DIR=$HOME/.vim/bundle

# Install/update Vundle
mkdir -p "$BUNDLE_DIR" && (git clone https://github.com/gmarik/vundle.git "$BUNDLE_DIR/vundle" || (cd "$BUNDLE_DIR/vundle" && git pull origin master))

# Install bundles
vim +PluginInstall +qall

# Compile YouCompleteMe
cd "$BUNDLE_DIR/YouCompleteMe" && ./install.sh

cd -

# Installs Monokia theme (Molokia)
mkdir $HOME/.vim/colors
curl -G https://raw.githubusercontent.com/tomasr/molokai/master/colors/molokai.vim -o $HOME/.vim/colors/molokia.vim

# Removing variables
unset BUNDLE_DIR
