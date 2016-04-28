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

if [ -r "${HOME}/.inputrc" ]; then
    mv ${HOME}/.inputrc ${HOME}/.dotfiles-bak/
fi


# Sets shell
sed -i -e "s/%shell%/bash/g" ${HOME}/.dotfiles.info

echo "Creating symlinks"
# Bunch of symlinks
ln -sfv "${PACKAGE_INSTALL}/runcom/.bashrc" ~
ln -sfv "${PACKAGE_INSTALL}/runcom/.bash_profile" ~
ln -sfv "${PACKAGE_INSTALL}/runcom/.inputrc" ~

# Copy .custom if not exist
if [ ! -r "${HOME}/.custom" ]; then
    cp ${PACKAGE_INSTALL}/config/.custom.bash ~
fi

