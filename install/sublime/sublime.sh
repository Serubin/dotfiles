#!/bin/sh

if [ $DISTRO == "Debian" | $DISTRO == "Ubuntu" ]; then
	source $DOTFILES_DIR/install/sublime/sublime.debian
elif [ $DISTRO = "Darwin" ]; then
	source $DOTFILES_DIR/install/sublime/sublime.osx
else
	echo "ERROR: This os doesn't support sublime installations."
fi

