#!/bin/bash

########################################
# Base install of LaTeX
# A Markup Language
########################################


mkdir -p ${HOME}/.config/nvim/ftplugin
mkdir -p ${HOME}/.config/zathura/
ln -sfv "${PACKAGE_INSTALL}/config/.latexmkrc" ${HOME}
ln -sfv "${PACKAGE_INSTALL}/config/zathurarc" ${HOME}/.config/zathura/
ln -sfv "${PACKAGE_INSTALL}/config/latex.vim" ${HOME}/.config/nvim/ftplugin/tex.vim

# Vimtex needs --remote in vim, so this puts it back for neovim
pip install --user neovim-remote

# Reinstall plugins for vimtex
nvim +PluginInstall +qall
echo "NOTE: For spell checking to run properly \":set spell\" (without quotes) will need to be run the first time a .tex file is opened. After that, it will work properly."
