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

gitName=$(cat ~/.dotfiles.info | perl -lne '/git-name{(.*)}/gi && print $1')
gitEmail=$(cat ~/.dotfiles.info | perl -lne '/git-email{(.*)}/gi && print $1')

sed -i -e 's/%git-name%/'$gitName'/g' ${PACKAGE_INSTALL}/config/.gitconfig
sed -i -e 's/%git-email%/'$gitEmail'/g' ${PACKAGE_INSTALL}/config/.gitconfig

ln -sfv "${PACKAGE_INSTALL}/config/.gitconfig" ~
ln -sfv "${PACKAGE_INSTALL}/install/git/config/.gitignore_global" ~
