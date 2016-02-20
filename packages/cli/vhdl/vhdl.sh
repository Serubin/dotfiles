#!/bin/bash

########################################
# Base install of LaTeX
# A Markup Language
########################################

# back up old files
if [ -r "${HOME}/.vim/vhdl.vim" ]; then
	mv ${HOME}/.vim/vhdl.vim ${HOME}/.dotfiles-bak/
fi

if [ -r "${HOME}/.vim/UltiSnips/vhdl.snippets" ]; then
	mv ${HOME}/.vim/UltiSnips/vhdl.snippets ${HOME}/.dotfiles-bak/
fi

if [ ! -d "${HOME}/.vim/UltiSnips/" ]; then
    mkdir ${HOME}/.vim/UltiSnips/
fi

ln -sfv "${PACKAGE_INSTALL}/config/vhdl.vim" ~/.vim/
ln -sfv "${PACKAGE_INSTALL}/config/vhdl.snippets" ~/.vim/UltiSnips/

# Reinstall plugins for vhdl
vim +PluginInstall +qall

