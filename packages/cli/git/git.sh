#!/bin/bash

########################################
# Base install of git
# Version Control
########################################

# back up old files
if [ -r "${HOME}/.gitconfig" ]; then
	mv ${HOME}/.gitconfig ${HOME}/.dotfiles-bak/ 2> /dev/null
fi

if [ -r "${HOME}/.gitconfig_global" ]; then
	mv ${HOME}/.gitconfig_global ${HOME}/.dotfiles-bak/ 2> /dev/null
fi

rm ${HOME}/.gitconfig 2> /dev/null
cp -v "${PACKAGE_INSTALL}/config/.gitconfig" ${HOME}/.gitconfig

sed -i -e "s/%git-name%/${git_name}/g" ${HOME}/.gitconfig
sed -i -e "s/%git-email%/${git_email}/g" ${HOME}/.gitconfig

ln -sfv "${PACKAGE_INSTALL}/config/.gitignore_global" ~

# Removes file that appears from the void
rm "${PACKAGE_INSTALL}/config/.gitconfig-e" 2> /dev/null
