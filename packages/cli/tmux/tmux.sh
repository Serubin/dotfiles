#!/bin/bash

########################################
# Base install of vim
# ViImproved
########################################

echo "Backing up previous tmux config"

if [ -r "${HOME}/.tmux.conf" ]; then
        mv ${HOME}/.tmux.conf ${HOME}/.dotfiles-bak/
fi

#config install
ln -sfv "${PACKAGE_INSTALL}/config/.tmux.conf" ~

