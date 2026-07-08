#!/usr/bin/env bash
# Connect to the `devel` tmux session for the iTerm2 -CC integration.
# Free `devel` of any client already attached BEFORE we attach. Safe by timing:
# at connect time any pre-existing client is the stale one. Kill the PROCESS
# (not `-D` soft-detach) so a wedged/paused post-lid-close client actually goes;
# the client-detached hook still fires a save. Managed by chezmoi
# (source: home/dot_local/bin/executable_tmux-devel.sh).
tmux list-clients -t devel -F '#{client_pid}' 2>/dev/null | xargs -r kill 2>/dev/null
exec tmux -CC new -A -D -s devel
