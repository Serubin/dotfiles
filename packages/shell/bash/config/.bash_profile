#!/bin/bash

source ${HOME}/.bashrc

[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx
