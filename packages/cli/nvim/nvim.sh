#!/bin/bash

########################################
# Base install of vim
# ViImproved
########################################

echo "Backing up previous vim config"

if [ -r "${HOME}/.vim" ]; then
    if [ -r "${HOME}/.dotfiles-bak/.vim" ]; then
        rm -rf ${HOME}/.dotfiles-bak/.vim 2> /dev/null
    fi

	mv -f ${HOME}/.config/nvim ${HOME}/.dotfiles-bak/ 2> /dev/null
fi

if [ -r "${HOME}/.config/nvim/init.vim" ]; then
	mv ${HOME}/.config/nvim/init.vim ${HOME}/.dotfiles-bak/ 2> /dev/null
fi

# config install
#ln -sfv "${PACKAGE_INSTALL}/config/.vimrc" ~
mkdir -p ${HOME}/.config/nvim/
ln -sfv "${PACKAGE_INSTALL}/config/nvim/vundle.vim" ~/.config/nvim/
ln -sfv "${PACKAGE_INSTALL}/config/nvim/init.vim" ~/.config/nvim/

BUNDLE_DIR=${HOME}/.config/nvim/bundle

# Install/update Vundle
mkdir -p "${BUNDLE_DIR}" && (git clone https://github.com/VundleVim/Vundle.vim.git "${BUNDLE_DIR}/vundle" || (cd "${BUNDLE_DIR}/vundle" && git pull origin master))

# Install bundles
nvim +PluginInstall +qall

echo "Compiling ycm"
# Compile YouCompleteMe
cd "${BUNDLE_DIR}/YouCompleteMe"

if [ "$DISTRO" == "Arch" ]; then # work around for arch, because smart python linking.
    python2 install.py --clang-completer --system-libclang
else
    python install.py
fi

cd -

# Installs Monokia theme (Molokia)
mkdir ${HOME}/.config/nvim/colors
curl -G https://raw.githubusercontent.com/tomasr/molokai/master/colors/molokai.vim -o ${HOME}/.config/nvim/colors/molokia.vim

# Removing variables
unset BUNDLE_DIR
