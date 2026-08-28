#!/usr/bin/env bash
# Cache the eager /etc/zsh version-manager init on the work-devbox Coder image:
# 874ms of a 1018ms tmux pane. The AMI runs `goenv init -`, `pyenv init -` and sources
# nvm.sh on every shell, and /etc/zsh/zshrc re-sources /etc/zsh/zprofile.d even for
# login shells that /etc/zprofile already covered.
#
# That output is deterministic apart from the selected Go/Python/node versions, which
# are baked at generation time -- re-run this by hand after switching one. The
# goenv()/pyenv() functions and the pyenv-virtualenv precmd hook survive; goenv's
# automatic rehash and nvm's eager load do not.
#
# /etc is wiped on a host restart, so ~/personalize re-runs this at startup.
#
# Every step is guarded on the image's current content and skips loudly if it changed;
# the whole run reverts unless every command still resolves identically afterward.
set -uo pipefail

MARK='# managed by apply-etc-zsh-perf (dotfiles) -- regenerated at workspace start'
ZPD=/etc/zsh/zprofile.d
BAK="$HOME/.local/state/apply-etc-zsh-perf"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

log()  { echo "[apply-etc-zsh-perf] $*"; }
warn() { echo "[apply-etc-zsh-perf] $*" >&2; }

# The version managers must be callable to generate their own cached output, and this
# script may run from a startup context with a minimal PATH.
export GOENV_ROOT="${GOENV_ROOT:-/opt/goenv}"
export PYENV_ROOT="${PYENV_ROOT:-/opt/pyenv}"
export NVM_DIR="${NVM_DIR:-/opt/nvm}"
export PATH="$GOENV_ROOT/bin:$PYENV_ROOT/bin:$PATH"

# --- helpers ---------------------------------------------------------------------

# Snapshot $PATH plus the name -> winning-path map for every reachable executable.
# Resolution is the invariant, not the PATH string: dropping the duplicate goenv
# snippet legitimately reorders entries.
snapshot() {  # $1 = zsh flags, $2 = output file (stderr goes to $2.err)
    env -i HOME="$HOME" TERM=dumb USER="$(id -un)" /usr/bin/zsh $1 -c '
        print -r -- "PATH=$PATH"
        typeset -A seen
        local d f n
        for d in $path; do
            for f in $d/*(N-*); do
                n=${f:t}
                [[ -n ${seen[$n]:-} ]] || seen[$n]=$f
            done
        done
        for n in ${(ko)seen}; do print -r -- "cmd $n $seen[$n]"; done
    ' >"$2" 2>"$2.err"
    [ -s "$2" ]
}

# Fatal if resolution changes or PATH gains/loses an entry; pure reordering is allowed.
compare() {  # $1 = before file, $2 = after file, $3 = label
    local b=$1 a=$2 label=$3 rc=0 line
    if ! diff <(grep '^cmd ' "$b") <(grep '^cmd ' "$a") >"$TMP/diff.$label" 2>&1; then
        warn "$label: command resolution changed --"
        while IFS= read -r line; do warn "    $line"; done < <(head -20 "$TMP/diff.$label")
        rc=1
    fi
    if [ "$(grep '^PATH=' "$b" | tr ':' '\n' | sort)" != "$(grep '^PATH=' "$a" | tr ':' '\n' | sort)" ]; then
        warn "$label: \$PATH entries were added or removed"
        rc=1
    elif [ "$(grep '^PATH=' "$b")" != "$(grep '^PATH=' "$a")" ]; then
        log "$label: \$PATH reordered, same entries, no command resolves differently"
    fi
    # Catches a snippet in the wrong shell dialect, which resolution alone misses.
    # Diffed rather than required-empty: this env -i context has benign warnings of its own.
    if [ -f "$b.err" ] && [ -f "$a.err" ] && ! diff -q "$b.err" "$a.err" >/dev/null 2>&1; then
        warn "$label: new output on stderr --"
        while IFS= read -r line; do warn "    $line"; done < <(diff "$b.err" "$a.err" | grep '^>' | head -10)
        rc=1
    fi
    return $rc
}

# Keep the pristine AMI copy, never our own output. Mirrors the absolute path under $BAK
# so restore is a prefix strip rather than a lossy separator encoding.
backup_pristine() {  # $1 = path
    local f=$1 dest="$BAK$1"
    [ -e "$f" ] || return 0
    grep -qF "$MARK" "$f" 2>/dev/null && return 0   # already ours; the backup is the pristine one
    mkdir -p "$(dirname "$dest")" && cp -a "$f" "$dest"
}

restore_all() {
    local dest f
    # -type l too: pristine goenv.zsh is a symlink, and skipping it would leave ours.
    while IFS= read -r dest; do
        f=${dest#"$BAK"}
        sudo rm -f "$f" && sudo cp -a "$dest" "$f" && warn "restored $f"
    done < <(find "$BAK" \( -type f -o -type l \) 2>/dev/null)
}

# Write only when content differs, so a re-run is a no-op.
install_if_changed() {  # $1 = new file, $2 = target
    if [ -f "$2" ] && cmp -s "$1" "$2"; then
        log "$2 already current"
        return 0
    fi
    sudo install -m 0644 -o root -g root "$1" "$2" && log "wrote $2"
}

# --- capture the "before" state -------------------------------------------------

if ! snapshot -li "$TMP/before.login" || ! snapshot -i "$TMP/before.pane"; then
    warn "could not snapshot zsh's command resolution; refusing to touch /etc"
    exit 1
fi
log "baseline: $(grep -c '^cmd ' "$TMP/before.login") commands reachable from a login shell"

# --- 1. drop the duplicate goenv snippet ----------------------------------------
# goenv.sh and the goenv.zsh symlink both match the loader's *sh* glob, so goenv inits
# twice. The directory's README documents the .zsh symlinks as intended, so the plain
# copy is the accident.
if [ -f "$ZPD/goenv.sh" ] && [ ! -L "$ZPD/goenv.sh" ]; then
    if cmp -s "$ZPD/goenv.sh" /etc/goenv.sh; then
        backup_pristine "$ZPD/goenv.sh"
        sudo rm -f "$ZPD/goenv.sh" && log "removed duplicate $ZPD/goenv.sh (was identical to /etc/goenv.sh)"
    else
        warn "$ZPD/goenv.sh differs from /etc/goenv.sh -- leaving both (AMI changed?)"
    fi
else
    log "goenv duplicate already absent"
fi

# --- 2. goenv: cache `goenv init -`, bake GOROOT/GOPATH -------------------------
# Replaces the goenv.zsh symlink with a regular file. /etc/goenv.sh is left alone:
# /etc/profile.d/goenv.sh symlinks to it, so editing it would feed zsh text to bash.
if command -v goenv >/dev/null 2>&1; then
    # `zsh` is passed explicitly: these snippets are sourced by zsh but this generator
    # runs under bash, and both tools sniff their caller. Without it they emit
    # `GOENV_SHELL=bash` plus `source .../completions/goenv.bash`, whose `complete`
    # builtin does not exist in zsh -- every new shell then errors.
    goenv_init="$(goenv init - zsh 2>/dev/null)"
    goenv_paths="$(goenv sh-rehash --only-manage-paths 2>/dev/null)"
    if [ -z "$goenv_init" ] || ! printf '%s\n' "$goenv_paths" | grep -q '^export GOROOT='; then
        warn "goenv init/sh-rehash output not recognized -- skipping goenv"
    else
        {
            printf '%s\n\n' "$MARK"
            printf '%s\n' '# Cached /etc/goenv.sh (which stays, for bash via /etc/profile.d/goenv.sh).'
            printf '%s\n' '# The two `goenv rehash` forks (~170ms/shell) are dropped and the GOROOT/GOPATH'
            printf '%s\n' '# they set are baked below, so `goenv rehash` is now manual.'
            printf '\n'
            printf '%s\n' 'export GOENV_ROOT=/opt/goenv'
            printf '%s\n' 'export PATH="$GOENV_ROOT/bin:$PATH"'
            printf '\n'
            printf '%s\n' "$goenv_init" | grep -Ev '^[[:space:]]*(command[[:space:]]+)?goenv rehash'
            printf '\n'
            printf '%s\n' "$goenv_paths"
            printf '\n'
            printf '%s\n' 'export PATH="$GOROOT/bin:$PATH"'
            printf '%s\n' 'export PATH="$PATH:$GOPATH/bin"'
        } > "$TMP/goenv.zsh"
        backup_pristine "$ZPD/goenv.zsh"
        # The target is currently a symlink; remove it so install writes a regular file.
        [ -L "$ZPD/goenv.zsh" ] && sudo rm -f "$ZPD/goenv.zsh"
        install_if_changed "$TMP/goenv.zsh" "$ZPD/goenv.zsh"
    fi
else
    warn "goenv not found -- skipping goenv"
fi

# --- 3. pyenv: cache both inits, drop the bash fork -----------------------------
# `pyenv init -` opens with a 5-line `bash --norc` fork that only drops an existing shims
# entry; replaced below with a zsh array op (zprofile.d is zsh-only).
if command -v pyenv >/dev/null 2>&1; then
    # Explicit `zsh` for the same reason as goenv above.
    pyenv_init="$(pyenv init - zsh 2>/dev/null)"
    pyenv_venv="$(pyenv virtualenv-init - zsh 2>/dev/null)"
    head1="$(printf '%s\n' "$pyenv_init" | sed -n '1p')"
    head5="$(printf '%s\n' "$pyenv_init" | sed -n '5p')"
    if [[ $head1 != 'PATH="$(bash --norc'* ]] || [[ $head5 != *'echo "${paths[*]}"'* ]]; then
        warn "pyenv init - preamble not the expected 5-line fork -- skipping pyenv"
    elif [ -z "$pyenv_venv" ]; then
        warn "pyenv virtualenv-init - produced nothing -- skipping pyenv"
    else
        {
            printf '%s\n\n' "$MARK"
            printf '%s\n' '# Cached AMI pyenv.sh: pyenv() and the virtualenv precmd hook are kept, only'
            printf '%s\n' '# the per-shell forks go. `pyenv rehash` is manual now, as with goenv.'
            printf '\n'
            printf '%s\n' 'export PYENV_ROOT=/opt/pyenv'
            printf '%s\n' 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"'
            printf '\n'
            printf '%s\n' '# Stands in for `pyenv init -`s first 5 lines: a `bash --norc` fork that only'
            printf '%s\n' '# removes an existing shims entry so the next line can re-prepend it.'
            printf '%s\n' 'path=(${path:#/opt/pyenv/shims})'
            printf '\n'
            # `command pyenv rehash` regenerates the shims on every shell: 46ms of a
            # 145ms pane. The pyenv() function's own rehash branch is untouched, so an
            # explicit `pyenv rehash` still works.
            printf '%s\n' "$pyenv_init" | tail -n +6 |
                grep -Ev '^[[:space:]]*(command[[:space:]]+)?pyenv rehash[[:space:]]*$'
            printf '\n'
            printf '%s\n' "$pyenv_venv"
        } > "$TMP/pyenv.sh"
        backup_pristine "$ZPD/pyenv.sh"
        install_if_changed "$TMP/pyenv.sh" "$ZPD/pyenv.sh"
    fi
else
    warn "pyenv not found -- skipping pyenv"
fi

# --- 4. nvm: bake the default node bin, load nvm lazily -------------------------
# Sourcing nvm.sh eagerly costs ~244ms. Only its PATH entry is needed up front (`claude`
# lives there), so bake that and defer the library to the first `nvm` call.
nvm_default="$(bash -c '. "$NVM_DIR/nvm.sh" >/dev/null 2>&1 && nvm version default' 2>/dev/null)"
if [[ $nvm_default != v[0-9]* ]] || [ ! -d "$NVM_DIR/versions/node/$nvm_default/bin" ]; then
    warn "could not resolve nvm default version (got '${nvm_default:-}') -- skipping nvm"
else
    {
        printf '%s\n\n' "$MARK"
        printf '%s\n' '# The AMI sourced nvm.sh here (~244ms) only so `nvm use default` set the node'
        printf '%s\n' '# bin on PATH. Baked below instead; the library loads on first `nvm` call.'
        printf '%s\n' "# Resolved from \`nvm version default\` at generation time: $nvm_default"
        printf '\n'
        printf '%s\n' 'export NVM_DIR="/opt/nvm"'
        printf '%s\n' "export PATH=\"\$NVM_DIR/versions/node/$nvm_default/bin:\$PATH\""
        printf '\n'
        printf '%s\n' 'nvm() {'
        printf '%s\n' '    unset -f nvm'
        printf '%s\n' '    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'
        printf '%s\n' '    nvm "$@"'
        printf '%s\n' '}'
    } > "$TMP/nvm.sh"
    backup_pristine "$ZPD/nvm.sh"
    install_if_changed "$TMP/nvm.sh" "$ZPD/nvm.sh"
fi

# --- 5. stop /etc/zshrc re-sourcing zprofile.d for login shells -----------------
# That block exists for non-login shells; login shells already got it from /etc/zprofile,
# so the second pass is ~845ms of pure duplication per ssh login.
if grep -q 'apply-etc-zsh-perf' /etc/zsh/zshrc; then
    log "/etc/zsh/zshrc already guarded"
elif grep -q '^if \[\[ -d /etc/zsh/zprofile.d \]\]; then$' /etc/zsh/zshrc; then
    backup_pristine /etc/zsh/zshrc
    sudo sed -i 's|^if \[\[ -d /etc/zsh/zprofile.d \]\]; then$|# apply-etc-zsh-perf: /etc/zprofile already sourced these for login shells.\nif [[ ! -o login ]] \&\& [[ -d /etc/zsh/zprofile.d ]]; then|' /etc/zsh/zshrc \
        && log "guarded /etc/zsh/zshrc's zprofile.d loop on non-login shells"
else
    warn "/etc/zsh/zshrc's zprofile.d loop not in the expected form -- leaving it alone"
fi

# --- validate, or put everything back -------------------------------------------

if ! snapshot -li "$TMP/after.login" || ! snapshot -i "$TMP/after.pane"; then
    warn "zsh no longer starts cleanly -- restoring /etc"
    restore_all
    exit 1
fi

ok=0
compare "$TMP/before.login" "$TMP/after.login" login || ok=1
compare "$TMP/before.pane"  "$TMP/after.pane"  pane  || ok=1
if [ "$ok" -ne 0 ]; then
    warn "validation failed -- restoring /etc"
    restore_all
    exit 1
fi

log "done; every command still resolves to the same path in login and non-login shells"
