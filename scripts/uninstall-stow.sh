#!/usr/bin/env bash
# Remove the legacy GNU Stow symlinks created by the pre-chezmoi install.sh.
#
# Use this when migrating a machine from the old Stow setup to chezmoi: it clears
# the symlinks in $HOME that point into the .dotfiles repo so `chezmoi apply` can
# write real managed files onto clean paths. Only SYMLINKS resolving into
# .dotfiles are removed — real files and directories are never touched.
# Idempotent; a no-op on a machine that was never stowed.
#
# (chezmoi also runs this automatically via the run_once_before hook on first
# apply; this standalone copy is kept for manual/explicit use.)
set -euo pipefail

targets=(.gitconfig .gitignore_global .zshrc .zshenv .zsh .tmux.conf
         .config/nvim .claude/settings.json .claude/skills)

for rel in "${targets[@]}"; do
    t="$HOME/$rel"
    # Plain readlink (one level, no -f): BSD readlink lacks -f, and Stow targets
    # are literal (e.g. .dotfiles/zsh/.zsh or ../.dotfiles/nvim/nvim).
    if [ -L "$t" ] && case "$(readlink "$t")" in *.dotfiles*) true ;; *) false ;; esac; then
        rm -f "$t" && echo "unstowed: $rel"
    fi
done

echo "Done. Legacy Stow symlinks removed (if any). Run 'chezmoi apply' next."
