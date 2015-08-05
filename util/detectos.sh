#!/bin/bash

# Get *nix distro
DISTRO_RAW="" # Gets raw os output
DISTRO_RAW_LOC=`echo /etc/*-release`

if [ "$DISTRO_RAW_LOC" == "/etc/*-release" ]; then
        DISTRO_RAW_LOC="";
fi

if [ "$DISTRO_RAW_LOC" != "" ]; then
        DISTRO_RAW=$(cat /etc/*-release)
else
        DISTRO_RAW=$(uname)
fi
# Parses out specific distro
export DISTRO=`echo $DISTRO_RAW | perl -lne '/(Ubuntu)|(Debian)|(Darwin)|(Arch)/gi && print $&' | head -n1`
