#!/bin/bash

########################################
# Base install of vim
# ViImproved
########################################

echo "Backing up previous nvim config"

webdev=0
if [ -f "${HOME}/.config/nvim/webdev.vim" ]; then
    webdev=1
fi

# TODO not working for sum reason.
if [ -r "${HOME}/.config/nvim" ]; then
    if [ -r "${HOME}/.dotfiles-bak/.nvim" ]; then
        rm -rf ${HOME}/.dotfiles-bak/.nvim 2> /dev/null
    fi

	mv -f ${HOME}/.config/nvim ${HOME}/.dotfiles-bak/ 2> /dev/null
fi

if [ $webdev -eq 11 ]; then
    touch ${HOME}/.config/nvim/webdev.vim
fi

# config install

mkdir -p ${HOME}/.config/nvim/
ln -sfv "${PACKAGE_INSTALL}/config/nvim/vundle.vim" ~/.config/nvim/
ln -sfv "${PACKAGE_INSTALL}/config/nvim/init.vim" ~/.config/nvim/

cp "${PACKAGE_INSTALL}/config/nvim/python.vim" ~/.config/nvim/
cp "${PACKAGE_INSTALL}/config/nvim/custom.vim" ~/.config/nvim/

if [ "$DISTRO" == "Arch" ]; then # work around for arch, because smart python linking.
    python2_path=`which python`
else
    python2_path=`which python3`
fi
sed -i -e 's#%python-path%#'${python2_path}'#g' ~/.config/nvim/python.vim


BUNDLE_DIR=${HOME}/.config/nvim/bundle

# Install fzf
git clone --depth 1 https://github.com/junegunn/fzf.git ${BUNDLE_DIR}/.fzf

# Install/update Vundle
mkdir -p "${BUNDLE_DIR}" && (git clone https://github.com/VundleVim/Vundle.vim.git "${BUNDLE_DIR}/vundle" || (cd "${BUNDLE_DIR}/vundle" && git pull origin master))

# Install bundles
nvim +PluginInstall +qall

echo "Compiling ycm"
# Compile YouCompleteMe
cd "${BUNDLE_DIR}/YouCompleteMe"

if [ "$DISTRO" == "Arch" ]; then # work around for arch, because smart python linking.
    /usr/bin/env python install.py --clang-completer --system-libclang
else
    /usr/bin/env python3 install.py
fi

cd -

cp "${PACKAGE_INSTALL}/config/nvim/powerline.vim" "${BUNDLE_DIR}/lightline.vim/autoload/lightline/colorscheme/"

# Removing variables
unset BUNDLE_DIR
