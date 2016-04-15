#!/bin/bash

########################################
# Base install of vim
# ViImproved
########################################

echo "Backing up previous nvim config"

# TODO not working for sum reason.
if [ -r "${HOME}/.config/nvim" ]; then
    if [ -r "${HOME}/.dotfiles-bak/.nvim" ]; then
        rm -rf ${HOME}/.dotfiles-bak/.nvim 2> /dev/null
    fi

	mv -f ${HOME}/.config/nvim ${HOME}/.dotfiles-bak/ 2> /dev/null
fi

# config install

mkdir -p ${HOME}/.config/nvim/
ln -sfv "${PACKAGE_INSTALL}/config/nvim/vundle.vim" ~/.config/nvim/
ln -sfv "${PACKAGE_INSTALL}/config/nvim/init.vim" ~/.config/nvim/

cp "${PACKAGE_INSTALL}/config/nvim/python.vim" ~/.config/nvim/

if [ "$DISTRO" == "Arch" ]; then # work around for arch, because smart python linking.
    python2_path=`which python2`
else
    python2_path=`which python`
fi
sed -i -e 's#%python-path%#'${python2_path}'#g' ~/.config/nvim/python.vim


BUNDLE_DIR=${HOME}/.config/nvim/bundle

# Install/update Vundle
mkdir -p "${BUNDLE_DIR}" && (git clone https://github.com/VundleVim/Vundle.vim.git "${BUNDLE_DIR}/vundle" || (cd "${BUNDLE_DIR}/vundle" && git pull origin master))

# Install bundles
nvim +PluginInstall +qall

echo "Compiling ycm"
# Compile YouCompleteMe
cd "${BUNDLE_DIR}/YouCompleteMe"

if [ "$DISTRO" == "Arch" ]; then # work around for arch, because smart python linking.
    python2 install.py
else
    python install.py
fi

cd -

# Installs Monokia theme (Molokia)
mkdir ${HOME}/.config/nvim/colors
curl -G https://raw.githubusercontent.com/tomasr/molokai/master/colors/molokai.vim -o ${HOME}/.config/nvim/colors/molokia.vim

# Removing variables
unset BUNDLE_DIR
