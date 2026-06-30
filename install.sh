#!/usr/bin/env bash
#
# Bootstrap these dotfiles with chezmoi.
#
#   Fresh machine (one-liner):
#     sh -c "$(curl -fsLS https://raw.githubusercontent.com/Serubin/dotfiles/main/install.sh)"
#
#   From a local clone:
#     git clone https://github.com/Serubin/dotfiles.git && dotfiles/install.sh
#
# Installs chezmoi if needed, then runs `chezmoi init --apply`. When invoked from
# inside a checkout of this repo, that checkout is used as the chezmoi source;
# otherwise the repo is cloned from GitHub. chezmoi then prompts once for your git
# identity, clears any legacy GNU Stow symlinks, installs packages for your OS,
# and writes the managed files into $HOME.
#
# Override the repo with DOTFILES_REPO=owner/name.
set -eu

GITHUB_REPO="${DOTFILES_REPO:-Serubin/dotfiles}"

# 1. Ensure chezmoi is available.
if ! command -v chezmoi >/dev/null 2>&1; then
    echo "==> Installing chezmoi..."
    if command -v brew >/dev/null 2>&1; then
        brew install chezmoi
    else
        bindir="${HOME}/.local/bin"
        sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "${bindir}"
        PATH="${bindir}:${PATH}"
    fi
fi

# 2. Use this checkout as the source if we're running inside one; else clone from
#    GitHub. (.chezmoiroot only exists at the root of this repo.)
self="${0:-}"
here=""
case "$self" in
    */*) here="$(cd "$(dirname "$self")" 2>/dev/null && pwd || true)" ;;
    *)   [ -f "./.chezmoiroot" ] && here="$(pwd)" ;;
esac

if [ -n "$here" ] && [ -f "${here}/.chezmoiroot" ]; then
    echo "==> chezmoi init --apply (local source: ${here})"
    exec chezmoi init --apply --source="${here}"
else
    echo "==> chezmoi init --apply ${GITHUB_REPO}"
    exec chezmoi init --apply "${GITHUB_REPO}"
fi
