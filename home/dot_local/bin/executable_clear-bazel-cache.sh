#!/usr/bin/env bash
# Delete every Bazel output base on the /mnt/cache EBS build cache, keeping the
# repository caches and install bases. Called by ~/.local/bin/mount-cache-dir once the
# volume is mounted, which is the only moment the cache is provably live and no build
# can be running; safe to run by hand any time.
#
# Two roots because lwcode/services/.bazelrc.user sets
# `startup --output_user_root=/mnt/cache/bazel` while worktrees without that file use the
# default root -- reached through the ~/.cache/bazel/_bazel_coder symlink onto the same
# volume. Each root keeps its own repository cache.
#
# Managed by chezmoi, work-devbox only. Deliberately not `set -e`: one failing base must
# not skip the rest.
#
# Usage: clear-bazel-cache.sh [--dry-run]
#   CACHE_MOUNTPOINT=...  override the cache mountpoint (testing)

: "${CACHE_MOUNTPOINT:=/mnt/cache}"
ROOTS=("$CACHE_MOUNTPOINT/bazel" "$CACHE_MOUNTPOINT/bazel/_bazel_coder")
TRASH_PREFIX=.trash-clear-bazel-cache
LOG=/tmp/clear-bazel-cache-rm.log

DRY_RUN=
[[ ${1:-} == --dry-run ]] && DRY_RUN=1

log()  { echo "[clear-bazel-cache] $*"; }
warn() { echo "[clear-bazel-cache] $*" >&2; }

if ! mountpoint -q "$CACHE_MOUNTPOINT"; then
    warn "$CACHE_MOUNTPOINT is not mounted; refusing to run"
    exit 0
fi

# Output bases are named for the md5 of their workspace path. The depth limit is
# load-bearing: install/<md5> is the live install base and execroots hold _tmp/<md5>.
output_bases() {
    find "$1" -mindepth 1 -maxdepth 1 -type d -regextype posix-extended \
        -regex '.*/[0-9a-f]{32}$' 2>/dev/null | sort
}

# PIDs recycle, so a stale pid file must not get an unrelated process killed.
shutdown_server() {
    local base=$1 pidfile=$1/server/server.pid.txt pid
    [[ -r $pidfile ]] || return 0
    pid=$(<"$pidfile")
    [[ $pid =~ ^[0-9]+$ ]] || return 0
    grep -qz -- "--output_base=$base" "/proc/$pid/cmdline" 2>/dev/null || return 0

    log "  stopping bazel server $pid"
    kill "$pid" 2>/dev/null
    # The rename below does not stop a server that already holds the tree by fd.
    for _ in {1..30}; do
        kill -0 "$pid" 2>/dev/null || return 0
        sleep 1
    done
    kill -9 "$pid" 2>/dev/null
    sleep 1
}

for root in "${ROOTS[@]}"; do
    [[ -d $root ]] || continue

    # An abandoned trash dir is not 32-hex, so nothing else would ever find it again.
    if [[ -z $DRY_RUN ]]; then
        for stale in "$root/$TRASH_PREFIX".*; do
            [[ -d $stale ]] || continue
            log "sweeping leftover $stale"
            chmod -R u+w "$stale" 2>/dev/null
            rm -rf "$stale" || warn "could not remove $stale"
        done
    fi

    bases=$(output_bases "$root")
    [[ -n $bases ]] || continue

    trash=
    while IFS= read -r base; do
        log "$(du -sh "$base" 2>/dev/null | cut -f1)	${base#"$CACHE_MOUNTPOINT"/}"
        [[ -n $DRY_RUN ]] && continue

        shutdown_server "$base"
        [[ -n $trash ]] || trash=$(mktemp -d "$root/$TRASH_PREFIX.XXXXXX") || break
        mv "$base" "$trash/" || warn "could not move $base aside"
    done <<< "$bases"

    # Bazel leaves read-only directories through external/, which rm cannot unlink
    # through. Backgrounded: this runs on the SSH pty that is waiting to attach tmux.
    if [[ -n $trash ]]; then
        log "removing $trash in the background (log: $LOG)"
        nohup bash -c "chmod -R u+w '$trash' 2>/dev/null; \
            rm -rf '$trash' || echo '[clear-bazel-cache] FAILED to remove $trash' >&2" \
            >> "$LOG" 2>&1 &
    fi
done

[[ -n $DRY_RUN ]] && log "dry run: nothing was deleted"
exit 0
