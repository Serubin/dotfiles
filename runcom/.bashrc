#!/bin/sh
# Assumes dotfiles will be located in $HOME/.dotfiles
DOTFILES_DIR="$HOME/.dotfiles"

# source all bash base files
for DOTFILE in "$DOTFILES_DIR"/bash/.*; do
	if
	[ -r "$DOTFILE" ] && source "$DOTFILE"
done

if [ -r ~/.custom ]; then
	source ~/.custom;
fi

clear