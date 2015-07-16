#!/bin/bash

echo "-- Installing htop"

if [ "$DISTRO" == "Debian" ] || [ "$DISTRO" == "Ubuntu" ]; then
        source $DOTFILES_DIR/install/htop/htop.debian
elif [ "$DISTRO" == "Darwin" ]; then
	source $DOTFILES_DIR/install/htop/htop.osx
else
	echo "ERROR: This os doesn't support htop installations."
fi
			
