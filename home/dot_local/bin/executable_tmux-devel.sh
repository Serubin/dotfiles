#!/usr/bin/env bash
# Connect to the `devel` tmux session for the iTerm2 -CC integration.
# Managed by chezmoi (source: home/dot_local/bin/executable_tmux-devel.sh).

# Remount /mnt/cache if the host restarted since the last connection; a no-op when
# it is already mounted. Runs BEFORE the stale-client kill on purpose: the mount
# can block on `aws sso login`, and if that is aborted we must not have already
# killed the working client the user still has.
#
# This is the only per-SSH-connection hook available -- iTerm2 runs this script as
# the SSH command, which Coder's agent executes as a non-login `zsh -c`, so
# ~/.zprofile and ~/.zlogin never fire. See the helper's header for details.
#
# The no-op SIGINT handler keeps a Ctrl-C at the SSO prompt from aborting this
# script before the attach -- insurance, not a fix for a reproduced drop. It must
# be a handler and not `trap '' INT`: an *ignored* SIGINT is inherited by children,
# which would make the `aws sso login` prompt itself uninterruptible.
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
# wins, and can lose by up to ServerAlive 15x3 = 45s when the old ssh is half-open
# after a lid close. Unsetting makes iTerm2 mint a fresh GUID. Giving up its guard is
# fine: the kill above and `-D` already enforce single-client. No-op on a cold start:
# `new -A` creates the session below and iTerm2 stamps a fresh GUID anyway.
tmux set-option -t devel -u @iterm2_id 2>/dev/null || true
exec tmux -CC new -A -D -s devel
