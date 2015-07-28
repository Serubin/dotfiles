#!/bin/bash

# determin distro
if [ "$DISTRO" == "Debian" ] || [ "$DISTRO" == "Ubuntu" ]; then
	source $DOTFILES_DIR/install/i3/i3.debian
	echo "ERROR: This os doesn't support vim installations."
fi