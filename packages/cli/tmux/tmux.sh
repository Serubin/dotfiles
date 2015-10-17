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

as_shell=`getInputBoolean "Do you want tmux to launch as your main shell?"`

if [ "$as_shell" == "1" ]; then
	echo "tmux_as_shell=1" >> ${HOME}/.dotfiles.info
fi



