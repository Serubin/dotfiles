#!/bin/bash

dotfilesDir=$(pwd)
source ./zsh/.zsh/01-os

sudo bash ./setup/$DISTRO

stowOptions="-t $HOME --ignore setup -R"

tools=("git" "zsh")

for tool in "${tools[@]}"; do
    echo " ==== Setting up $tool ==== "
    cd $tool

    sudo bash setup/common
    sudo bash setup/$DISTRO
    cd $dotfilesDir

    echo "stow $tool $stowOptions"
    stow $tool $stowOptions
done
