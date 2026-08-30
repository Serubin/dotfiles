#!/usr/bin/env bash
# One-time split of the single ~/.claude config dir into per-account dirs.
#
# Claude Code keys auth, .claude.json, projects and history off CLAUDE_CONFIG_DIR, so two
# logins need two dirs. ~/.claude stays the shared asset root (CLAUDE.md, skills/,
# settings.json, statusline) that both accounts symlink into; this seeds ~/.claude-personal
# with the state that was already there, so the existing login, project list and history
# survive the switch. ~/.claude-work starts empty on purpose -- `claude --work` logs in.
#
# Copies rather than moves: ~/.claude keeps working for anything launched without
# CLAUDE_CONFIG_DIR (a GUI editor, cron). Prune the duplicated state by hand once verified.
#
# run_after runs once every file is written, so the symlinks and the merged settings.json
# already exist in the destination -- hence the skip list below. run_once re-runs only if
# this script changes; the guard makes it a no-op regardless.
set -euo pipefail

src="$HOME/.claude"
dst="$HOME/.claude-personal"

# Nothing to migrate on a fresh machine, and .claude.json in place means it already ran.
if [ ! -d "$src" ] || [ -e "$dst/.claude.json" ]; then
    exit 0
fi

mkdir -p "$dst"

# The account itself lives here: oauthAccount, the project list, MCP servers, onboarding
# state. Without CLAUDE_CONFIG_DIR this file sits at $HOME, not inside the config dir.
if [ -f "$HOME/.claude.json" ]; then
    cp -p "$HOME/.claude.json" "$dst/.claude.json"
fi

# Everything except the chezmoi-managed names, which `apply` just wrote as symlinks and a
# merged settings.json. Explicit loop rather than rsync --exclude: no extra dependency for
# the Debian container.
shopt -s dotglob nullglob
for entry in "$src"/*; do
    case "${entry##*/}" in
        CLAUDE.md|CLAUDE.md.old|skills|settings.json|statusline-command.sh|plugins|.DS_Store)
            continue ;;
    esac
    cp -R "$entry" "$dst/"
done
shopt -u dotglob nullglob

echo "migrated: seeded ~/.claude-personal from ~/.claude (originals left in place)"
