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
# Installs chezmoi if needed, then runs `chezmoi init --apply`. The chezmoi source
# directory is ~/.dotfiles (pinned via `sourceDir` in the config): run this from a
# ~/.dotfiles checkout to use it in place, otherwise the repo is cloned from GitHub
# into ~/.dotfiles. chezmoi then prompts once for the
# machine environment/class + your git identity, clears any legacy GNU Stow
# symlinks, installs packages for your OS, and writes the managed files into $HOME.
#
# Machine targeting: set the environment and/or class non-interactively via flags
# or env vars (both just seed $DOTFILES_ENV / $DOTFILES_CLASS, which the chezmoi
# config template reads):
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

# Flags (and a backward-compatible bare `personal|work`) just seed $DOTFILES_ENV /
# $DOTFILES_CLASS, which the chezmoi config template reads; a flag overrides a
# value already present in the environment.
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

# Validate environment (the config template validates too, but fail early with a
# clear message). Class is intentionally free-form and left unvalidated.
case "$DOTFILES_ENV" in
    ""|personal|work) ;;
    *) echo "invalid --env '$DOTFILES_ENV' (want personal|work)" >&2; exit 2 ;;
esac
if [ -n "$DOTFILES_ENV" ];   then export DOTFILES_ENV;   fi
if [ -n "$DOTFILES_CLASS" ]; then export DOTFILES_CLASS; fi

# Non-interactive installs (curl | sh pipe, CI) have no TTY: fall back to chezmoi's
# prompt defaults so init can't hang on the git-identity prompts (which fire on a
# fresh init even when env/class are supplied). Env/class still win in the template.
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

# git-repo externals (zinit/gitstatus/tpm) can flake on the first heavy
# init --apply; retry once so a transient clone hiccup doesn't leave onboarding
# half-done. The retry converges cheaply: cloned externals are cached, run_once
# scripts are already recorded, and nothing re-installs.
if ! "$@"; then
    echo "==> first apply failed; retrying once (transient external clone?)..." >&2
    "$@"
fi
