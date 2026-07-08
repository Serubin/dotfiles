#!/usr/bin/env bash
# One-time migration: git config moved from ~/.gitconfig + ~/.gitignore_global to
# the XDG layout ~/.config/git/{config,ignore}. Because ~/.gitconfig is read at a
# HIGHER precedence than ~/.config/git/config, a leftover ~/.gitconfig would
# silently shadow the new file — and chezmoi does not auto-delete a target when
# its source entry is removed. So drop the legacy paths once the new ones exist.
#
# Guarded + idempotent: each legacy file is removed only when its XDG replacement
# is present, making this a safe no-op on fresh machines. run_after scripts run
# after all file writes, so the new files already exist here. run_once re-runs
# only if this script's content changes.
set -euo pipefail

if [ -f "$HOME/.config/git/config" ] && [ -e "$HOME/.gitconfig" ]; then
    rm -f "$HOME/.gitconfig" && echo "migrated: removed legacy ~/.gitconfig"
fi

if [ -f "$HOME/.config/git/ignore" ] && [ -e "$HOME/.gitignore_global" ]; then
    rm -f "$HOME/.gitignore_global" && echo "migrated: removed legacy ~/.gitignore_global"
fi
