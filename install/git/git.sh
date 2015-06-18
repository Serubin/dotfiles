#!/bin/sh

echo " -- Installing Git"


if [ -r "$HOME/.gitconfig" ]; then
	mv $HOME/.gitconfig $HOME/.dotfiles-bak/
fi

if [ -r "$HOME/.gitconfig_global" ]; then
	mv $HOME/.gitconfig_global $HOME/.dotfiles-bak/
fi

if [ $DISTRO == "Debian" ] || [ $DISTRO == "Ubuntu" ]; then
	source install/git/git.debian
elif [ $DISTRO = "Darwin" ]; then
	source install/git/git.osx
else
	echo "ERROR: This os doesn't support sublime installations."
fi

ln -sfv "install/git/config/.gitconfig" ~
ln -sfv "install/git/config/.gitignore_global" ~ # needs creation