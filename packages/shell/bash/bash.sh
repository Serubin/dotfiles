#/bin/bash

########################################
# Bash
# Bash shell
########################################

# Backing up current configurations
echo "Moving previous configurations to dotfiles/bak/"
mkdir -p ${HOME}/.dotfiles-bak

if [ -r "${HOME}/.bash_profile" ]; then
    mv ${HOME}/.bash_profile ${HOME}/.dotfiles-bak/
fi

if [ -r "$HOME/.bashrc" ]; then
    mv ${HOME}/.bashrc ${HOME}/.dotfiles-bak/
fi

# Sets shell
perl -p -i -e 's/DOTFILES_SHELL=".*"/DOTFILES_SHELL="bash"/g;' ${HOME}/.dotfiles.info

echo "Creating symlinks"
# Bunch of symlinks
ln -sfv "${PACKAGE_INSTALL}/config/.bashrc" ~
ln -sfv "${PACKAGE_INSTALL}/config/.bash_profile" ~

# Copy .custom if not exist
if [ ! -r "${HOME}/.custom" ]; then
    cp ${DOTFILES_DIR}/common/.custom ~
fi

if [[ `getInputBoolean "Set as default shell?"` == "1" ]]; then
    chsh -s /bin/zsh
fi

