# Assumes dotfiles will be located in $HOME/.dotfiles
DOTFILES_DIR="$HOME/.dotfiles"


# source all bash base files
for DOTFILE in "$DOTFILES_DIR"/bash/.*; do
	[ -f "$DOTFILE" ] && source "$DOTFILE"
done