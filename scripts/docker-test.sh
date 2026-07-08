#!/usr/bin/env bash
# Interactive test-harness entrypoint, baked into the Debian image as
# `dotfiles-test` (see Dockerfile). Runs the real chezmoi bootstrap against the
# source mounted at /workspace, then drops you into a login zsh so you can
# actually USE the configured environment (prompt, aliases, tmux, ...).
#
# First run prompts for environment/class/git identity, exactly like a real
# machine. Seed them non-interactively via DOTFILES_ENV / DOTFILES_CLASS (see the
# commented `environment:` block in docker-compose.yml); when seeded with no TTY,
# chezmoi's --promptDefaults fills the remaining (git identity) prompts.
set -euo pipefail

SOURCE="${DOTFILES_SOURCE:-/workspace}"

# No TTY (e.g. `docker compose exec -T`, CI) can't answer the git-identity
# prompts, which fire on a fresh init even when env/class are seeded — fall back
# to chezmoi's prompt defaults so init can't hang. Mirrors install.sh.
init_flags=""
[ -t 0 ] || init_flags="--promptDefaults"

# chezmoi reads /workspace/.chezmoiroot and uses /workspace/home as the source.
# Idempotent: re-running won't re-trigger run_once installs (e.g. the Neovim
# build), so this doubles as a fast re-apply.
echo "==> chezmoi init --apply (source: ${SOURCE})"
chezmoi init --apply ${init_flags} --source="${SOURCE}"

echo "==> entering login zsh (exit to return to the container shell)"
exec zsh -l
