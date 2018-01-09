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
mkdir -p ~/.config/nvim/ftplugin/
ln -sfv ~/.config/nvim/bundle/hdl_plugin/ftplugin/hdl_plugin.vim ~/.config/nvim/ftplugin/vhdl.vim # Fix hdl plugin naming issue

echo "Consider installing https://github.com/ghdl/ghdl"

# Reinstall plugins for vhdl
nvim +PluginInstall +qall

