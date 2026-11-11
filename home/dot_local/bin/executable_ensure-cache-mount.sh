#!/usr/bin/env bash
# Mount /mnt/cache (the EBS Bazel build cache) if it is not already mounted. The
# actual work -- EBS attach, `aws sso login`, mkfs, fstab, mount -- belongs to
# ~/.local/bin/mount-cache-dir; this only decides WHETHER to run it and repairs the
# environment it needs.
#
# Three callers, because no shell rc file marks "a human just arrived": Coder's agent
# runs SSH commands as a non-login `zsh -c`, and orcad restores Orca panes (each a
# `zsh -l` that auto-runs `claude --resume`) with nobody at the keyboard.
#   - devbox-up: the manual "I'm back" command; interactive, may run `aws sso login`.
#   - tmux-devel.sh: iTerm2's SSH command, once per connection; interactive too.
#   - cron (--cron, installed by ~/personalize): retries with cached SSO credentials
#     only, so a restart within the SSO token's lifetime needs no human at all.
#
# Degrades LOUDLY, never fatally: every exit is 0 and failures land in a STATUS
# marker that the ~/.zsh startup banner and the Claude SessionStart hook surface. A
# message printed from tmux-devel.sh would be invisible -- tmux -CC switches the pty
# into control mode immediately afterward and eats it.
#
# chezmoi-managed, work-devbox only. Deliberately not `set -e`.
#
# Usage: ensure-cache-mount.sh [--cron]
#   --cron                unattended: never prompts, never prints, skips if busy
#   SKIP_CACHE_MOUNT=1    bypass entirely (escape hatch)
#   CACHE_MOUNTPOINT=...  override the mountpoint (testing)
#   CACHE_MOUNT_SCRIPT=.. override the delegate script (testing)

: "${CACHE_MOUNTPOINT:=/mnt/cache}"
: "${CACHE_MOUNT_SCRIPT:=$HOME/.local/bin/mount-cache-dir}"

STATE_DIR="$HOME/.local/state/cache-mount"
STATUS="$STATE_DIR/STATUS"   # sticky failure marker; read by the banner and hook
LOG="$STATE_DIR/mount.log"
LOCK="$STATE_DIR/lock"
CRON_OUT="$STATE_DIR/last-cron.log"

CRON=
[[ "$1" == --cron ]] && CRON=1

set_status() {
    mkdir -p "$STATE_DIR" 2>/dev/null || return 0
    printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" >"$STATUS" 2>/dev/null || true
}

clear_status() { rm -f "$STATUS" 2>/dev/null || true; }

current_status() { local s; s=$(tail -n1 "$STATUS" 2>/dev/null) && printf '%s' "${s#* }"; }

log() {
    mkdir -p "$STATE_DIR" 2>/dev/null || return 0
    printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" >>"$LOG" 2>/dev/null || true
}

# Cron retries every few minutes, so it only logs and restamps when the outcome changes.
fail() {
    if [[ -n "$CRON" && "$(current_status)" == "$1" ]]; then
        return 0
    fi
    log "FAILED${CRON:+ (cron)}: $1"
    set_status "$1"
}

# Escape hatch: a wedged mount must never make the box hard to get into.
[[ -n "$SKIP_CACHE_MOUNT" ]] && exit 0

# `mountpoint`, not mount-cache-dir's [[ -b /dev/sdj ]]: on Nitro, a volume
# attached as /dev/sdj surfaces as /dev/nvme*n1.
if mountpoint -q "$CACHE_MOUNTPOINT"; then
    clear_status
    exit 0
fi

if [[ ! -x "$CACHE_MOUNT_SCRIPT" ]]; then
    fail "$CACHE_MOUNTPOINT not mounted; $CACHE_MOUNT_SCRIPT is missing or not executable"
    exit 0
fi

mkdir -p "$STATE_DIR" 2>/dev/null
exec 9>>"$LOCK"
if [[ -n "$CRON" ]]; then
    flock -n 9 || exit 0
elif ! flock -n 9; then
    # Short: tmux-devel.sh blocks the SSH attach on this; a normal mount takes ~40s.
    printf '\n=== another %s run holds %s; waiting ===\n' "$CACHE_MOUNTPOINT" "$LOCK"
    if ! flock -w 90 9; then
        fail "$CACHE_MOUNTPOINT not mounted; another mount run is stuck -- see $LOG, then run: devbox-up"
        printf '!! gave up waiting for %s\n' "$LOCK"
        exit 0
    fi
fi

# Whoever held the lock may have just mounted it.
if mountpoint -q "$CACHE_MOUNTPOINT"; then
    clear_status
    exit 0
fi

# Restore the two variables mount-cache-dir depends on that an interactive shell
# would set but a `zsh -c` command session does not:
#
#   AWS_PROFILE -- set by ~/.custom, which ~/.zshrc sources only when interactive.
#     Unset, the aws CLI falls back to [default] = lw-readonly-role, which CANNOT
#     ec2 attach-volume.
#   BROWSER -- /etc/motd_fetcher.sh and ~/.custom both set fwd-browse, again
#     interactive-only. Without it `aws sso login` cannot open a browser on the Mac.
export AWS_PROFILE="${AWS_PROFILE:-devtest-admin}"
export BROWSER="${BROWSER:-fwd-browse}"

if [[ -n "$CRON" ]]; then
    export PATH="/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin"
    # timeout: mount-cache-dir waits forever for the device node after an attach.
    CACHE_MOUNT_NO_LOGIN=1 timeout 600 "$CACHE_MOUNT_SCRIPT" 9>&- </dev/null >"$CRON_OUT" 2>&1
    if mountpoint -q "$CACHE_MOUNTPOINT"; then
        log "ok (cron): $CACHE_MOUNTPOINT mounted with cached SSO credentials"
        clear_status
    else
        fail "$CACHE_MOUNTPOINT not mounted; run: devbox-up"
    fi
    exit 0
fi

printf '\n=== %s is not mounted; running %s ===\n' "$CACHE_MOUNTPOINT" "$CACHE_MOUNT_SCRIPT"
log "running $CACHE_MOUNT_SCRIPT (AWS_PROFILE=$AWS_PROFILE)"

# Ctrl-C at the SSO prompt means "skip"; without this the SIGINT kills us before
# the check below, leaving no marker and no banner.
on_interrupt() {
    log "INTERRUPTED: mount skipped by user"
    set_status "$CACHE_MOUNTPOINT not mounted; skipped with Ctrl-C -- run: devbox-up"
    printf '\n[cache-mount] interrupted; %s left unmounted\n' "$CACHE_MOUNTPOINT"
    exit 0
}
trap on_interrupt INT

# Foreground, inheriting this pty, so the `aws sso login` prompt is interactive.
"$CACHE_MOUNT_SCRIPT" 9>&-
trap - INT

# Trust the mount, not the exit status: mount-cache-dir ends with
# `df -h | rg 'cache|coder|Use%'`, and rg exits 1 when it matches nothing.
if mountpoint -q "$CACHE_MOUNTPOINT"; then
    log "ok: $CACHE_MOUNTPOINT mounted"
    clear_status
else
    log "FAILED: $CACHE_MOUNTPOINT still not mounted"
    set_status "$CACHE_MOUNTPOINT not mounted; run: devbox-up"
    printf '\n!! %s still not mounted -- see %s\n' "$CACHE_MOUNTPOINT" "$LOG"
fi

exit 0
