#!/bin/sh

# sublime install for osx

# install sublime
brew cask install caskroom/versions/sublime-text3

ln -s"`perl -e 'print readlink($ARGV[0]) . "\n"' ~/Applications/Sublime\ Text.app`" "/Applications/Sublime Text.app"