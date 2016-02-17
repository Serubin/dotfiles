#!/bin/bash

########################################
# Build from source, git
# Version Control
########################################

echo "Building git from source"

# Install dependencies
sudo apt-get install -y curl libcurl4-openssl-dev libexpat1-dev gettext libz-dev libssl-dev build-essential

# Download and compile from source - Ubuntu and Debian repos are annoyingly out of date
git_version="2.7.1"

cd /tmp
curl -L --progress https://www.kernel.org/pub/software/scm/git/git-${git_version}.tar.gz | tar xz
cd git-${git_version}/

./configure
make prefix=/usr/local all

# Install into /usr/local/bin
sudo make prefix=/usr/local install

cd ..

echo "Removing temporary files"
rm -rf git-${git_version}/

cd $PACKAGE_INSTALL

