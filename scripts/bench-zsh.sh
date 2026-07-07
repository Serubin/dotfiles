#!/usr/bin/env bash
# Benchmark zsh interactive startup and prompt-render time for these dotfiles.
#
#   scripts/bench-zsh.sh [startup_runs] [prompt_runs]
#
# Startup = `zsh -i -c exit` (sources ~/.zsh/* + loads zinit plugins), warmed.
#           Uses hyperfine if installed, otherwise a zsh timing loop.
# Prompt  = the precmd chain, timed under a pseudo-tty so gitstatus's background
#           daemon is live, run inside a git repo, with a per-component breakdown.
set -euo pipefail

startup_runs="${1:-30}"
prompt_runs="${2:-200}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"

echo "== zsh startup (zsh -i -c exit, warmed) =="
if command -v hyperfine >/dev/null 2>&1; then
    hyperfine --warmup 5 --min-runs "$startup_runs" -N 'zsh -i -c exit'
else
    zsh -fc "
        zmodload zsh/datetime
        repeat 5 { zsh -i -c exit 2>/dev/null }          # warmup
        integer n=$startup_runs
        float sum=0 min=1e9 max=0 d
        for i in {1..\$n}; do
            s=\$EPOCHREALTIME; zsh -i -c exit 2>/dev/null; e=\$EPOCHREALTIME
            d=\$(( (e-s)*1000 )); (( sum+=d )); (( d<min )) && min=d; (( d>max )) && max=d
        done
        printf '  min=%.1f  mean=%.1f  max=%.1f ms  (n=%d)\n' \$min \$((sum/n)) \$max \$n
    "
fi

echo
echo "== zsh prompt render (pty; gitstatus live; cwd=$repo_root) =="
# The prompt uses gitstatus, whose daemon needs job control — so run interactive
# zsh under a pseudo-tty via `script` (BSD and util-linux arg orders differ).
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
cat > "$tmp" <<PROMPTEOF
zmodload zsh/datetime
cd $repo_root
prompt_precmd >/dev/null 2>&1                             # warm gitstatus + caches
tb() { local n=$prompt_runs s e; s=\$EPOCHREALTIME; repeat \$n { eval "\$1" }; e=\$EPOCHREALTIME; printf '  %-22s %.3f ms\n' "\$2" \$(( (e-s)/n*1000.0 )); }
tb 'gitstatus_query PROMPT >/dev/null 2>&1' 'gitstatus_query'
tb 'git_stat >/dev/null 2>&1'               'git_stat'
tb 'pre_cmd >/dev/null 2>&1'                'pre_cmd'
tb 'prompt_precmd >/dev/null 2>&1'          'prompt_precmd (full)'
PROMPTEOF

if script --version 2>/dev/null | grep -qi util-linux; then
    script -qec "zsh -ic 'source $tmp'" /dev/null
else
    script -q /dev/null zsh -ic "source $tmp"
fi
