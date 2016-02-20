#!/bin/bash

########################################
# Base install of LaTeX
# A Markup Language
########################################

# back up old files
if [ -r "${HOME}/.latexmkrc" ]; then
	mv ${HOME}/.latexmkrc ${HOME}/.dotfiles-bak/
fi

if [ -r "${HOME}/.config/zathura/zathurarc" ]; then
	mv ${HOME}/.config/zathura/zathurarc ${HOME}/.dotfiles-bak/
fi

if [ -r "${HOME}/.vim/latex.vim" ]; then
	mv ${HOME}/.vim/latex.vim ${HOME}/.dotfiles-bak/
fi


ln -sfv "${PACKAGE_INSTALL}/config/.latexmkrc" ~
ln -sfv "${PACKAGE_INSTALL}/config/zathurarc" ~/.config/zathura/
ln -sfv "${PACKAGE_INSTALL}/config/latex.vim" ~/.vim/

# Reinstall plugins for vimtex
vim +PluginInstall +qall
