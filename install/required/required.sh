#!/bin/bash

# determin distro
if [ "$DISTRO" == "Debian" ] || [ "$DISTRO" == "Ubuntu" ]; then
        source $DOTFILES_DIR/install/required/required.debian
elif [ "$DISTRO" == "Darwin" ]; then
        source $DOTFILES_DIR/install/required/required.osx
else
        echo "ERROR: This os doesn't support vim installations."
fi
