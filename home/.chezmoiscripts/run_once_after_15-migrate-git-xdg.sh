#!/usr/bin/env bash
# One-time migration to the XDG git layout ~/.config/git/{config,ignore}. git
# reads ~/.gitconfig at HIGHER precedence, so a leftover would silently shadow the
# new file — and chezmoi does not auto-delete a target when its source entry goes
# away. Drop the legacy paths once the new ones exist.
#
# Each legacy file is removed only when its XDG replacement is present, so this is
# a safe no-op on fresh machines. run_after runs once all files are written, so those
# replacements already exist here; run_once re-runs only if this script changes.
set -euo pipefail

if [ -f "$HOME/.config/git/config" ] && [ -e "$HOME/.gitconfig" ]; then
    rm -f "$HOME/.gitconfig" && echo "migrated: removed legacy ~/.gitconfig"
fi

if [ -f "$HOME/.config/git/ignore" ] && [ -e "$HOME/.gitignore_global" ]; then
    rm -f "$HOME/.gitignore_global" && echo "migrated: removed legacy ~/.gitignore_global"
fi
