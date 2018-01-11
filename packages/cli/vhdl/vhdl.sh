#!/bin/bash

########################################
# Arch install of VHDL
# Very hard description language
########################################

if [ ! -d "${HOME}/.config/nvim/UltiSnips/" ]; then
    mkdir ${HOME}/.config/nvim/UltiSnips/
fi

mkdir -p ${HOME}/.config/nvim/ftplugin/
ln -sfv "${PACKAGE_INSTALL}/config/vhdl.vim" ${HOME}/.config/nvim/ftplugin/
ln -sfv "${PACKAGE_INSTALL}/config/vhdl.snippets" ${HOME}/.config/nvim/UltiSnips/

echo "Consider installing https://github.com/ghdl/ghdl"

# Reinstall plugins for vhdl
nvim +PluginInstall +qall

# Fix VIP plugin so it only loads for VHDL files
mv ${HOME}/.config/nvim/bundle/VIP/plugin ${HOME}/.config/nvim/bundle/VIP/ftplugin
mv ${HOME}/.config/nvim/bundle/VIP/ftplugin/vip.vim ${HOME}/.config/nvim/bundle/VIP/ftplugin/vhdl.vim
