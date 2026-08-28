#!/usr/bin/env bash
#
# Bootstrap these dotfiles with chezmoi.
#
#   Fresh machine (one-liner):
#     sh -c "$(curl -fsLS https://raw.githubusercontent.com/Serubin/dotfiles/main/install.sh)"
#
#   From a local clone:
#     git clone https://github.com/Serubin/dotfiles.git ~/.dotfiles && ~/.dotfiles/install.sh
#
# Installs chezmoi if needed, then runs `chezmoi init --apply`. The source dir is
# pinned to ~/.dotfiles via `sourceDir` in the config: run from a checkout there
# to use it in place, otherwise
# the repo is cloned from GitHub. chezmoi then prompts once for machine
# environment/class + git identity, clears legacy GNU Stow symlinks, installs
# packages for your OS, and writes the managed files into $HOME.
#
# Machine targeting: --env / --class (or $DOTFILES_ENV / $DOTFILES_CLASS) seed the
# values the chezmoi config template reads:
#     dotfiles/install.sh --env work
#     dotfiles/install.sh --env work --class work-ci
#     DOTFILES_ENV=work DOTFILES_CLASS=work-ci sh -c "$(curl -fsLS .../install.sh)"
#
# Override the repo with DOTFILES_REPO=owner/name.
set -eu

GITHUB_REPO="${DOTFILES_REPO:-Serubin/dotfiles}"

usage() {
    cat >&2 <<'USAGE'
usage: install.sh [--env personal|work] [--class NAME] [personal|work]
  --env    machine environment (personal|work); seeds $DOTFILES_ENV
  --class  machine class (free-form, e.g. work-ci); seeds $DOTFILES_CLASS
USAGE
}

# Flags (plus a backward-compatible bare `personal|work`) seed $DOTFILES_ENV /
# $DOTFILES_CLASS; a flag overrides a value already in the environment.
DOTFILES_ENV="${DOTFILES_ENV:-}"
DOTFILES_CLASS="${DOTFILES_CLASS:-}"
while [ $# -gt 0 ]; do
    case "$1" in
        --env)     [ $# -ge 2 ] || { echo "--env needs a value" >&2; exit 2; }; DOTFILES_ENV="$2"; shift 2 ;;
        --env=*)   DOTFILES_ENV="${1#*=}"; shift ;;
        --class)   [ $# -ge 2 ] || { echo "--class needs a value" >&2; exit 2; }; DOTFILES_CLASS="$2"; shift 2 ;;
        --class=*) DOTFILES_CLASS="${1#*=}"; shift ;;
        personal|work) DOTFILES_ENV="$1"; shift ;;   # backward-compat shorthand
        -h|--help) usage; exit 0 ;;
        *) echo "unknown argument: $1" >&2; usage; exit 2 ;;
    esac
done

# The config template validates too; fail early with a clearer message. Class is
# deliberately free-form and unvalidated.
case "$DOTFILES_ENV" in
    ""|personal|work) ;;
    *) echo "invalid --env '$DOTFILES_ENV' (want personal|work)" >&2; exit 2 ;;
esac
if [ -n "$DOTFILES_ENV" ];   then export DOTFILES_ENV;   fi
if [ -n "$DOTFILES_CLASS" ]; then export DOTFILES_CLASS; fi

# No TTY (curl | sh, CI) would hang on the git-identity prompts, which fire on a
# fresh init even when env/class are supplied. Fall back to chezmoi's defaults;
# env/class still win in the template.
init_flags=""
[ -t 0 ] || init_flags="--promptDefaults"

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
    set -- chezmoi init --apply ${init_flags} --source="${here}"
else
    echo "==> chezmoi init --apply --source ~/.dotfiles ${GITHUB_REPO}"
    set -- chezmoi init --apply ${init_flags} --source="${HOME}/.dotfiles" "${GITHUB_REPO}"
fi

# git-repo externals (zinit/gitstatus/tpm) can flake on the first heavy apply, so
# retry once rather than leave onboarding half-done. Cheap: cloned externals are
# cached and run_once scripts already recorded, so nothing re-installs.
if ! "$@"; then
    echo "==> first apply failed; retrying once (transient external clone?)..." >&2
    "$@"
fi
