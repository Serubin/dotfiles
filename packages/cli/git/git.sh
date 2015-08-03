#!/bin/bash

########################################
# Base install of git
# Version Control
########################################

# back up old files
if [ -r "${HOME}/.gitconfig" ]; then
	mv ${HOME}/.gitconfig ${HOME}/.dotfiles-bak/
fi

if [ -r "${HOME}/.gitconfig_global" ]; then
	mv ${HOME}/.gitconfig_global ${HOME}/.dotfiles-bak/
fi

ln -sfv "${PACKAGE_INSTALL}/config/.gitconfig" ~
ln -sfv "${PACKAGE_INSTALL}/install/git/config/.gitignore_global" ~
