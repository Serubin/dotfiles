#!/bin/bash

# determin distro        
if [ "$DISTRO" == "Debian" ] || [ "$DISTRO" == "Ubuntu" ]; then
        source $DOTFILES_DIR/install/optional/optional.debian
elif [ "$DISTRO" == "Darwin" ]; then
        source $DOTFILES_DIR/install/optional/optional.osx
else
        echo "ERROR: This os doesn't support the optinal installations."
fi

