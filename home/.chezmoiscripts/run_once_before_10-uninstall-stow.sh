#!/usr/bin/env bash
# Remove legacy GNU Stow symlinks so chezmoi can write managed files onto clean
# paths. Only SYMLINKS pointing into the old .dotfiles repo; real files and
# directories are never touched. No-op on fresh machines.
#
# Mirrors scripts/uninstall-stow.sh (the manual tool), inline so `chezmoi init
# --apply` on a still-stowed machine Just Works.
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
