#!/usr/bin/env bash
# Attach-independent periodic snapshot of tmux state via tmux-resurrect.
# WHY: tmux-continuum's periodic save rides status-line #() interpolation, which
# tmux does NOT evaluate under iTerm2 control mode (-CC) -- so its timer never
# fires in our workflow. cron runs this every few minutes regardless of attach
# state. Managed by chezmoi (source: home/dot_local/bin/executable_tmux-periodic-save.sh);
# the */5 cron entry is (re)installed at startup by ~/personalize (the crontab does
# not survive a host restart, so scheduling lives there rather than at chezmoi apply).
set -uo pipefail
SAVE="$HOME/.tmux/plugins/tmux-resurrect/scripts/save.sh"
RESURRECT_DIR="$HOME/.local/share/tmux/resurrect"
LOCK="/tmp/tmux-periodic-save.lock"
MIN_SERVER_UPTIME=120   # skip until past continuum's restore-on-start window
KEEP=200                # snapshots to retain
[ -x "$SAVE" ] || exit 0
exec 9>"$LOCK" || exit 0
flock -n 9 || exit 0
pid="$(tmux display-message -p '#{pid}' 2>/dev/null)" || exit 0
[ -n "$pid" ] || exit 0
up="$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ')"
[ -n "$up" ] && [ "$up" -ge "$MIN_SERVER_UPTIME" ] || exit 0
"$SAVE" quiet >/dev/null 2>&1 || exit 0
# Prune oldest snapshots (sorted by filename timestamp), never the `last` target.
last_path="$RESURRECT_DIR/$(readlink "$RESURRECT_DIR/last" 2>/dev/null)"
ls -1 "$RESURRECT_DIR"/tmux_resurrect_*.txt 2>/dev/null | sort -r | tail -n +"$((KEEP + 1))" \
  | grep -vxF "$last_path" | xargs -r rm -f
# Success regardless of prune outcome (empty prune makes grep exit 1 under pipefail).
exit 0
