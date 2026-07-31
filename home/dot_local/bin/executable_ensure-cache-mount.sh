#!/usr/bin/env bash
# Mount /mnt/cache (the EBS Bazel build cache) once per SSH connection, if it is
# not already mounted. The actual work -- EBS attach, `aws sso login`, mkfs,
# fstab, mount -- belongs to ~/.local/bin/mount-cache-dir; this only decides
# WHETHER to run it and repairs the environment it needs.
#
# Why it is invoked from tmux-devel.sh and not a shell rc file: Coder's agent
# serves SSH itself (there is no sshd on this box), so ForceCommand and
# ~/.ssh/rc do not exist. iTerm2 runs ~/.local/bin/tmux-devel.sh as the SSH
# *command*, and the agent runs command sessions as `zsh -c` -- non-login and
# non-interactive -- so ~/.zprofile and ~/.zlogin never fire on that path.
# tmux-devel.sh is therefore the one hook that runs exactly once per connection.
# tmux panes (`default-command "/usr/bin/env zsh"`) never re-run it, which is why
# this does not fire on each new terminal.
#
# Degrades LOUDLY, never fatally: it must never block the tmux attach, so every
# exit is 0 and failures are recorded in a STATUS marker that the ~/.zsh startup
# banner surfaces in new panes. A message printed here would be invisible --
# tmux -CC switches the pty into control mode immediately afterward and eats it.
#
# Managed by chezmoi (source: home/dot_local/bin/executable_ensure-cache-mount.sh),
# work-devbox only. Deliberately not `set -e`.
#
# Usage: ensure-cache-mount.sh
#   SKIP_CACHE_MOUNT=1    bypass entirely (escape hatch)
#   CACHE_MOUNTPOINT=...  override the mountpoint (testing)
#   CACHE_MOUNT_SCRIPT=.. override the delegate script (testing)

: "${CACHE_MOUNTPOINT:=/mnt/cache}"
: "${CACHE_MOUNT_SCRIPT:=$HOME/.local/bin/mount-cache-dir}"

STATE_DIR="$HOME/.local/state/cache-mount"
STATUS="$STATE_DIR/STATUS"   # sticky failure marker; read by the ~/.zsh banner
LOG="$STATE_DIR/mount.log"

set_status() {
    mkdir -p "$STATE_DIR" 2>/dev/null || return 0
    printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" >"$STATUS" 2>/dev/null || true
}

clear_status() { rm -f "$STATUS" 2>/dev/null || true; }

log() {
    mkdir -p "$STATE_DIR" 2>/dev/null || return 0
    printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" >>"$LOG" 2>/dev/null || true
}

# Escape hatch: a wedged mount must never make the box hard to get into.
[[ -n "$SKIP_CACHE_MOUNT" ]] && exit 0

# The common case on every reconnect. `mountpoint` rather than the [[ -b /dev/sdj ]]
# test mount-cache-dir uses, because on Nitro the volume attached as /dev/sdj
# actually surfaces as an /dev/nvme*n1 device.
if mountpoint -q "$CACHE_MOUNTPOINT"; then
    clear_status
    exit 0
fi

if [[ ! -x "$CACHE_MOUNT_SCRIPT" ]]; then
    log "missing: $CACHE_MOUNT_SCRIPT is not executable"
    set_status "$CACHE_MOUNTPOINT not mounted; $CACHE_MOUNT_SCRIPT is missing or not executable"
    exit 0
fi

# Restore the two environment variables an interactive shell would have set but a
# `zsh -c` command session does not, both of which mount-cache-dir depends on:
#
#   AWS_PROFILE -- ~/.custom sets devtest-admin, but ~/.custom is sourced from
#     ~/.zshrc (interactive only). Unset, the aws CLI falls back to the [default]
#     profile, which is lw-readonly-role and CANNOT ec2 attach-volume.
#   BROWSER -- /etc/motd_fetcher.sh and ~/.custom both set fwd-browse, again
#     interactive-only. Without it `aws sso login` cannot open a browser on the Mac.
export AWS_PROFILE="${AWS_PROFILE:-devtest-admin}"
export BROWSER="${BROWSER:-fwd-browse}"

printf '\n=== %s is not mounted; running %s ===\n' "$CACHE_MOUNTPOINT" "$CACHE_MOUNT_SCRIPT"
log "running $CACHE_MOUNT_SCRIPT (AWS_PROFILE=$AWS_PROFILE)"

# Ctrl-C at the `aws sso login` prompt is a legitimate "skip this", but SIGINT
# reaches this script too and would kill it before the check below runs -- no
# marker, no banner, and a whole session built against a cold cache. Record the
# skip so it stays visible, then let the attach proceed.
on_interrupt() {
    log "INTERRUPTED: mount skipped by user"
    set_status "$CACHE_MOUNTPOINT not mounted; skipped with Ctrl-C -- run: $CACHE_MOUNT_SCRIPT"
    printf '\n[cache-mount] interrupted; %s left unmounted\n' "$CACHE_MOUNTPOINT"
    exit 0
}
trap on_interrupt INT

# Foreground, inheriting this pty, so the `aws sso login` prompt is interactive.
"$CACHE_MOUNT_SCRIPT"
trap - INT

# Trust the mount, not the exit status: mount-cache-dir ends with
# `df -h | rg 'cache|coder|Use%'`, and rg exits 1 when it matches nothing.
if mountpoint -q "$CACHE_MOUNTPOINT"; then
    log "ok: $CACHE_MOUNTPOINT mounted"
    clear_status
else
    log "FAILED: $CACHE_MOUNTPOINT still not mounted"
    set_status "$CACHE_MOUNTPOINT not mounted; run: $CACHE_MOUNT_SCRIPT"
    printf '\n!! %s still not mounted -- see %s\n' "$CACHE_MOUNTPOINT" "$LOG"
fi

exit 0
