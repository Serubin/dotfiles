#!/usr/bin/env bash
# Interactive test-harness entrypoint, baked into the Debian image as
# `dotfiles-test` (see Dockerfile). Bootstraps chezmoi against the source mounted
# at /workspace, then drops into a login zsh so the configured environment
# (prompt, aliases, tmux) can actually be used.
#
# First run prompts for environment/class/git identity, like a real machine. Seed
# via DOTFILES_ENV / DOTFILES_CLASS (see the commented `environment:` block in
# docker-compose.yml); with no TTY, --promptDefaults fills the rest.
set -euo pipefail

SOURCE="${DOTFILES_SOURCE:-/workspace}"

# No TTY (`docker compose exec -T`, CI) can't answer the git-identity prompts, which
# fire on a fresh init even when env/class are seeded -- fall back to chezmoi's prompt
# defaults so init can't hang. Mirrors install.sh.
init_flags=""
[ -t 0 ] || init_flags="--promptDefaults"

# chezmoi reads /workspace/.chezmoiroot and uses /workspace/home as the source.
# Idempotent: a re-run won't re-trigger run_once installs (e.g. the Neovim
# build), so this doubles as a fast re-apply.
echo "==> chezmoi init --apply (source: ${SOURCE})"
chezmoi init --apply ${init_flags} --source="${SOURCE}"

echo "==> entering login zsh (exit to return to the container shell)"
exec zsh -l
