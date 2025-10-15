#!/bin/bash

bash ./setup/$DISTRO

stowOptions="-t $HOME --ignore setup -R"

tools=()

for tool in "${tools[@]}"; do
    echo " ==== Setting up $tool ==== "
    cd $tool
    bash setup/common
    bash setup/$DISTRO
    cd -
    echo "stow $tool $stowOptions"
    stow $tool $stowOptions
done
