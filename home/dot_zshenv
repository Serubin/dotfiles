# Sourced for ALL zsh invocations (login, interactive, non-interactive, scripts).
# Anything here applies to subshells launched by GUI apps (Cursor's embedded nvim,
# git editors, etc.) — not just interactive terminals where .zshrc runs.

# Raise the per-process FD soft limit. macOS launchd defaults to 256, which is
# trivially exhausted by Neovim plugins that spawn many subprocesses
# (gitsigns -> git, conform/lint formatters, LSP), producing
# `EMFILE: too many open files` from vim/_core/system.lua.
# Only raise — never lower — so this composes correctly with the
# limit.maxfiles LaunchDaemon (which sets soft=65536) and any other tool
# that may already have set a higher limit.
_cur_nofile=$(ulimit -Sn)
if [ "$_cur_nofile" != "unlimited" ] && [ "$_cur_nofile" -lt 65536 ]; then
    ulimit -Sn 65536 2>/dev/null
fi
unset _cur_nofile
