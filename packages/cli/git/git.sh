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

sed -i -e 's/%git-name%/'$git_name'/g' ${PACKAGE_INSTALL}/config/.gitconfig
sed -i -e 's/%git-email%/'$git_email'/g' ${PACKAGE_INSTALL}/config/.gitconfig

ln -sfv "${PACKAGE_INSTALL}/config/.gitconfig" ~
ln -sfv "${PACKAGE_INSTALL}/config/.gitignore_global" ~

# Removes file that appears from the void
rm "${PACKAGE_INSTALL}/config/.gitconfig-e"

