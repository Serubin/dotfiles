#!/bin/bash
########################################
# Build from source, nvim
# A better Vi Improved
########################################

sudo apt-get -y install build-essential libtool libtool-bin autoconf automake cmake g++ pkg-config unzip python-dev python3-dev xsel 

cd /tmp # Move to tmp
git clone https://github.com/neovim/neovim.git neovim
cd neovim

make
sudo make install


echo "Removing temporary files"
cd ..
rm -rf neovim

cd $PACKAGE_INSTALL
