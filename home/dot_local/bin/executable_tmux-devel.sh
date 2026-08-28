#!/usr/bin/env bash
# Connect to the `devel` tmux session for the iTerm2 -CC integration.
# Managed by chezmoi (source: home/dot_local/bin/executable_tmux-devel.sh).

# Remount /mnt/cache if the host restarted since the last connection. This runs
# BEFORE the stale-client kill below on purpose: the mount can block for a while
# on `aws sso login`, and if it is aborted we must not have already killed the
# working client the user still has. It is a no-op when /mnt/cache is mounted.
#
# This is the only per-SSH-connection hook available -- iTerm2 runs this script as
# the SSH command, which Coder's agent executes as a non-login `zsh -c`, so
# ~/.zprofile and ~/.zlogin never fire. See the helper's header for the details.
#
# No-op SIGINT handler so a Ctrl-C at the SSO prompt cannot abort this script
# before the attach. Bash was measured to reach the attach either way, so this is
# propagation insurance, not a fix for a reproduced dropped connection. It must
# be a handler and not `trap '' INT`: an *ignored* SIGINT is inherited by
# children, which would make the `aws sso login` prompt itself uninterruptible.
# The helper reports the skip and sets the marker that raises the shell banner.
if [[ -x "$HOME/.local/bin/ensure-cache-mount.sh" ]]; then
    trap ':' INT
    "$HOME/.local/bin/ensure-cache-mount.sh" || true
    trap - INT
fi

# Free `devel` of any client already attached BEFORE we attach. Safe by timing:
# at connect time any pre-existing client is the stale one. Kill the PROCESS
# (not `-D` soft-detach) so a wedged/paused post-lid-close client actually goes;
# the client-detached hook still fires a save.
tmux list-clients -t devel -F '#{client_pid}' 2>/dev/null | xargs -r kill 2>/dev/null

# Rotate iTerm2's session GUID so its double-attach guard cannot false-positive.
# iTerm2 tags the tmux session with the user option @iterm2_id and, on attach, runs
# `show -v -q -t $N @iterm2_id`; if that GUID matches a TmuxController still live in
# THIS iTerm2 process it refuses with "This instance of iTerm2 is already attached to
# this session". The kill above frees the session remotely, but the local controller
# only unregisters once the old ssh pipe closes -- a race the new connection usually
# wins, and one the local side can lose by up to ServerAlive 15x3 = 45s when the old
# ssh is half-open after a lid close. Unsetting makes iTerm2 mint a fresh GUID instead.
# We give up its double-attach guard; single-client is already enforced above by the
# kill and `-D`. No-op on a cold start: `new -A` creates the session below and iTerm2
# stamps a fresh GUID anyway.
tmux set-option -t devel -u @iterm2_id 2>/dev/null || true
exec tmux -CC new -A -D -s devel
