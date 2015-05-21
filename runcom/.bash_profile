# Assumes dotfiles will be located in $HOME/.dotfiles
DOTFILES_DIR="$HOME/.dotfiles"

if [ -d $DOTFILES_DIR/installed ]; then
	echo "===================="
	echo "dotfiles warning: dotfile package was not installed correctly."
	echo "consider rerunning install.sh or replacing your bash_profile"
	echo "===================="
fi
# source all bash base files
for DOTFILE in "$DOTFILES_DIR"/bash/.*; do
	[ -f "$DOTFILE" ] && source "$DOTFILE"
done

# source all git files
for DOTFILE in "$DOTFILES_DIR"/git/.*; do
	[ -f "$DOTFILE" ] && source "$DOTFILE"
done

# source all vim files
for DOTFILE in "$DOTFILES_DIR"/vim/.*; do
	[ -f "$DOTFILE" ] && source "$DOTFILE"
done