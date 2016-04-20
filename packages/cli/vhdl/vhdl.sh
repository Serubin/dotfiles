#!/bin/bash

########################################
# Arch install of VHDL
# Very hard description language
########################################

if [ ! -d "${HOME}/.config/nvim/UltiSnips/" ]; then
    mkdir ${HOME}/.config/nvim/UltiSnips/
fi

ln -sfv "${PACKAGE_INSTALL}/config/vhdl.vim" ~/.config/nvim/
ln -sfv "${PACKAGE_INSTALL}/config/vhdl.snippets" ~/.config/nvim/UltiSnips/

# Reinstall plugins for vhdl
nvim +PluginInstall +qall

