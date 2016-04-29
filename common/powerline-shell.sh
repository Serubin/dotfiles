function _update_ps1() {
    PS1="$(${DOTFILES_DIR}/common/powerline-shell/powerline-shell.py --cwd-mode plain $? 2> /dev/null)"
}

if [ "$TERM" != "linux" ]; then
    PROMPT_COMMAND="_update_ps1; $PROMPT_COMMAND"
fi
