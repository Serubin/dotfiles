#/bin/bash

########################################
# Zsh
# Z Shell
########################################

# Backing up current configurations
echo "Moving previous configurations to dotfiles/bak/"

if [ -r "{$HOME}/.zshrc" ]; then
    mv ${HOME}/.zshrc ${HOME}/.dotfiles-bak/
fi

# Sets shell
perl -p -i -e 's/DOTFILES_SHELL=".*"/DOTFILES_SHELL="zsh"/g;' ${HOME}/.dotfiles.info

echo "Creating symlinks"
# Bunch of symlinks
ln -sfv "${DOTFILES_DIR}/packages/shell/common/.rc" ~/.zshrc

# Copy .custom if not exist
if [ ! -r "${HOME}/.custom" ]; then
    cp ${DOTFILES_DIR}/common/.custom ~
fi

echo ${PACKAGE_INSTALL}

if [[ `getInputBoolean "Set as default shell?"` == "1" ]]; then
    chsh -s /bin/zsh
fi
