#!/bin/bash

########################################
# Base install of i3
# Tiled Window Manager
########################################

# i3 install with thanks to
# https://www.reddit.com/r/unixporn/comments/3efhs7/i3_gaps_a_bit_obsessed_with_material_design/
# and
# aur.sh (it's a website and a script)

# ##############################
#              i3              #
# ##############################

echo "Installing I3"

cd /tmp

# clone the repository
git clone https://www.github.com/Airblader/i3 i3-gaps
cd i3-gaps

# do this if you want the stable branch, skip it if you want the dev branch (gaps-next)
git checkout gaps && git pull

# compile & install
make
sudo make install

cd -
rm -rf /tmp/i3-gaps


mkdir -p $HOME/.i3

ln -sfv ${PACKAGE_INSTALL}/config/i3.config ${HOME}/.i3/config

# ##############################
#         XFCE Terminal        #
# ##############################

echo "Setting up xfce terminal"

mkdir -p $HOME/.config/xfce4/terminal/

ln -sfv ${PACKAGE_INSTALL}/config/terminalrc $HOME/.config/xfce4/terminal/

# ##############################
#        i3locks/status        #
# ##############################

echo "Setting up i3 lock and status"

rm $HOME/.i3/lock
ln -sfv ${PACKAGE_INSTALL}/resources/lock $HOME/.i3/lock

rm $HOME/.i3/bin
ln -sfv ${PACKAGE_INSTALL}/resources/bin $HOME/.i3/bin

chmod 775 ${PACKAGE_INSTALL}/resources/lock/lock.sh

mkdir -p $HOME/.config/i3status/

ln -sfv ${PACKAGE_INSTALL}/config/i3status.config $HOME/.config/i3status/config


# #############################
#          rofi               #
# #############################

echo "Installing Rofi menu"

cd /tmp/
git clone https://github.com/DaveDavenport/rofi.git
cd rofi

autoreconf -i                                                                                                      mkdir build/
cd build/
../configure
make
sudo make install

cd -

