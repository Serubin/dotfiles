#!/bin/zsh

# Skip if non-interactive
[[ $- != *i* ]] && return

# Determins dot file location
if [ -r "${HOME}/.dotfiles.info" ]; then # checks for stored location
	source "${HOME}/.dotfiles.info"
else # otherwise assumes the following
	DOTFILES_DIR="${HOME}/.dotfiles"
fi

source $DOTFILES_DIR/util/detectos.sh

# source all bash base files
for DOTFILE in "$DOTFILES_DIR"/packages/shell/zsh/config/run/.*; do
	[[ -d "$DOTFILE" ]] && continue;
	source "$DOTFILE"
done

if [ -r ~/.custom ]; then
	source ~/.custom;
fi

if [ -r ~/.dir_colors ]; then
    eval $(dircolors ~/.dir_colors);
fi

