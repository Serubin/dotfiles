#!/usr/bin/env bash
# Coder workspace keep-alive. Holds the autostop deadline out until STOP_HOUR
# (evaluated in TZ_NAME) on weekdays, then lets the workspace autostop normally.
#
# WHY: the team's 2h autostop reclaims the workspace during long meetings / lunch
# (no activity -> deadline lapses). The Mac-side `fwd` SOCKS tunnel used to keep it
# alive by generating "activity", but closing the laptop tears `fwd` down. This runs
# SERVER-SIDE on a */15 cron, so it is independent of the laptop. It reuses the
# ambient `coder login` session (no stored token); when that session expires it
# degrades LOUDLY -- a STATUS marker + a ~/.zsh startup banner -- rather than
# silently letting the workspace die.
#
# Managed by chezmoi (source: home/dot_local/bin/executable_coder-keepalive.sh),
# work-devbox only. The */15 cron and the stable coder binary are (re)provisioned
# at each host boot by ~/personalize via `coder-keepalive.sh install`: neither the
# crontab nor the per-SSH-session /tmp coder binary survives a host restart, but
# $HOME does.
#
# Subcommands:
#   install   provision stable binary + state env + install cron + one run (boot)
#   run       cron target: extend the deadline if before STOP_HOUR on a weekday
#   --check   print the decision WITHOUT calling coder (dry-run; honors
#             KEEPALIVE_FAKE_EPOCH=<unix-seconds> to simulate the clock)
set -uo pipefail

# ---- tunables -------------------------------------------------------------
STOP_HOUR=18                     # local hour after which we stop bumping (0-23)
TZ_NAME="America/New_York"       # timezone STOP_HOUR is evaluated in
WEEKDAYS_ONLY=1                  # 1 = Mon-Fri only
CAP_MIN=115                      # max minutes to extend per tick (< the 2h TTL)
MIN_FUTURE_MIN=30                # coder rejects extends < 30 min in the future
CRON_SPEC="*/15 * * * *"         # cadence; CAP_MIN tolerates several missed ticks

# ---- paths ----------------------------------------------------------------
SELF="$HOME/.local/bin/coder-keepalive.sh"   # chezmoi-managed target of this file
STATE_DIR="$HOME/.local/state/coder-keepalive"
ENV_FILE="$STATE_DIR/env"
BIN="$STATE_DIR/coder"           # stable coder binary (PATH one is in per-session /tmp)
LOG="$STATE_DIR/keepalive.log"
STATUS="$STATE_DIR/STATUS"       # sticky failure marker; read by the ~/.zsh banner
LOCK="$STATE_DIR/lock"
LOG_MAX_LINES=500
MARKER="# coder-keepalive"       # crontab dedupe marker

# ---- small helpers --------------------------------------------------------
log() { printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >>"$LOG" 2>/dev/null || true; }
trim_log() { [ -f "$LOG" ] || return 0; tail -n "$LOG_MAX_LINES" "$LOG" >"$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG" || rm -f "$LOG.tmp"; }
set_status() { printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" >"$STATUS" 2>/dev/null || true; }
clear_status() { rm -f "$STATUS" 2>/dev/null || true; }

now_epoch() { [ -n "${KEEPALIVE_FAKE_EPOCH:-}" ] && echo "$KEEPALIVE_FAKE_EPOCH" || date +%s; }

# Run the stable coder CLI with a cron-safe environment. CODER_CONFIG_DIR pins the
# ambient login session; PATH is minimal-but-absolute. Other env (incl. a caller's
# CODER_SESSION_TOKEN, used by the failure test) is inherited.
coder_cli() { CODER_CONFIG_DIR="$HOME/.config/coderv2" PATH="/usr/local/bin:/usr/bin:/bin" "$BIN" "$@"; }

# Load machine facts captured by `install` (cron env lacks CODER_* vars).
load_env() {
    # shellcheck disable=SC1090
    [ -f "$ENV_FILE" ] && . "$ENV_FILE"
    WS="${KEEPALIVE_WS:-${CODER_WORKSPACE_NAME:-solomon-dev}}"
    DEPLOY_URL="${KEEPALIVE_URL:-${CODER_AGENT_URL:-https://devspaces2.dev.lacework.engineering/}}"
}

# ---- decision -------------------------------------------------------------
# Echo "dow mins": ET weekday (1=Mon..7=Sun) and whole minutes until today's
# STOP_HOUR:00 in TZ_NAME. Both derived from now_epoch() so --check can simulate.
# Epoch subtraction (not HH:MM arithmetic) => correct across the hour and DST.
compute() {
    local now dow ymd target
    now="$(now_epoch)"
    dow="$(TZ="$TZ_NAME" date -d "@$now" +%u)"
    ymd="$(TZ="$TZ_NAME" date -d "@$now" +%Y-%m-%d)"
    target="$(TZ="$TZ_NAME" date -d "$ymd ${STOP_HOUR}:00:00" +%s)"
    echo "$dow $(( (target - now) / 60 ))"
}

# Echo "SKIP <reason>" or "EXTEND <minutes>".
decide() {
    local dow mins dur
    read -r dow mins < <(compute)
    if [ "$WEEKDAYS_ONLY" = "1" ] && [ "$dow" -gt 5 ]; then
        echo "SKIP weekend (dow=$dow)"; return 0
    fi
    if [ "$mins" -le 0 ]; then
        echo "SKIP past ${STOP_HOUR}:00 ${TZ_NAME} (mins=$mins)"; return 0
    fi
    if [ "$mins" -lt "$MIN_FUTURE_MIN" ]; then
        echo "SKIP within ${MIN_FUTURE_MIN}m of ${STOP_HOUR}:00 (mins=$mins); prior tick governs"; return 0
    fi
    dur="$mins"; [ "$dur" -gt "$CAP_MIN" ] && dur="$CAP_MIN"
    echo "EXTEND $dur"
}

# ---- run (cron target) ----------------------------------------------------
do_run() {
    mkdir -p "$STATE_DIR"
    exec 9>"$LOCK" || return 0
    flock -n 9 || { log "run: another instance holds the lock; skipping"; return 0; }
    trim_log

    local decision dur
    decision="$(decide)"
    if [ "${decision%% *}" = "SKIP" ]; then
        log "run: ${decision#SKIP } -> no extend"
        return 0
    fi
    dur="${decision#EXTEND }"

    if [ ! -x "$BIN" ]; then
        log "run: stable coder binary missing at $BIN; run '$SELF install'"
        set_status "keep-alive binary missing at $BIN -- reboot or run: $SELF install"
        return 0
    fi

    local out rc
    out="$(coder_cli schedule extend "$WS" "${dur}m" 2>&1)"; rc=$?
    if [ "$rc" -ne 0 ]; then
        log "run: extend ${dur}m FAILED (rc=$rc): $(printf '%s' "$out" | tr '\n' ' ')"
        if printf '%s' "$out" | grep -qiE 'signed out|session has expired|expired|401|unauthorized|authenticate'; then
            log "run: ACTION NEEDED: run 'coder login ${DEPLOY_URL}'"
            set_status "Coder session expired -- run: coder login ${DEPLOY_URL}"
        else
            set_status "keep-alive extend failed (rc=$rc): $(printf '%s' "$out" | head -1)"
        fi
        return 0
    fi

    # Read the achieved deadline back; detect a template cap (belt-and-suspenders:
    # the soft-TTL viability check passed, but surface a regression passively).
    local stops_next got req skew real_now
    stops_next="$(coder_cli schedule show "$WS" -o json 2>/dev/null \
        | grep -o '"stops_next"[^,]*' | grep -oE '[0-9-]+T[0-9:]+Z' | head -1)"
    if [ -n "$stops_next" ]; then
        real_now="$(date +%s)"                       # real clock: server extends from real now
        got="$(date -d "$stops_next" +%s 2>/dev/null || echo 0)"
        req=$(( real_now + dur * 60 ))
        skew=$(( req - got ))
        if [ "$got" -gt 0 ] && [ "$skew" -gt 600 ]; then
            log "run: extended ${dur}m but deadline is $((skew/60))m short (stops_next=$stops_next) -> CAPPED BY TEMPLATE"
            set_status "keep-alive CAPPED BY TEMPLATE -- cannot hold past $(date -d "$stops_next" '+%H:%M %Z' 2>/dev/null || echo "$stops_next")"
            return 0
        fi
        log "run: extended ${dur}m; stops_next=$stops_next"
    else
        log "run: extended ${dur}m (deadline read-back unavailable)"
    fi
    clear_status
    return 0
}

# ---- install (boot, via personalize) --------------------------------------
provision_binary() {
    local url="${CODER_AGENT_URL:-${DEPLOY_URL:-https://devspaces2.dev.lacework.engineering/}}bin/coder-linux-amd64"
    # Cached binary still runs: only refresh if the server has a newer build
    # (conditional GET via -z; 304 => empty file => keep existing). Avoids a 55MB
    # pull on every boot while still tracking deployment upgrades.
    if [ -x "$BIN" ] && "$BIN" version >/dev/null 2>&1; then
        if curl -fsSL -z "$BIN" -o "$BIN.new" "$url" 2>/dev/null && [ -s "$BIN.new" ]; then
            chmod +x "$BIN.new"
            if "$BIN.new" version >/dev/null 2>&1; then mv "$BIN.new" "$BIN"; log "install: refreshed coder binary"; else rm -f "$BIN.new"; fi
        else
            rm -f "$BIN.new"
        fi
        return 0
    fi
    # No usable cached binary: download fresh; fall back to copying the PATH binary.
    if curl -fsSL -o "$BIN.new" "$url" 2>/dev/null && [ -s "$BIN.new" ] && chmod +x "$BIN.new" && "$BIN.new" version >/dev/null 2>&1; then
        mv "$BIN.new" "$BIN"; log "install: downloaded coder binary"; return 0
    fi
    rm -f "$BIN.new"
    local src; src="$(command -v coder 2>/dev/null || true)"
    if [ -n "$src" ] && [ -x "$src" ] && cp "$src" "$BIN" 2>/dev/null && chmod +x "$BIN" && "$BIN" version >/dev/null 2>&1; then
        log "install: copied coder binary from $src"; return 0
    fi
    log "install: FAILED to provision coder binary (download + cp both failed)"
    set_status "keep-alive could not provision coder binary"
    return 1
}

install_cron() {
    command -v crontab >/dev/null 2>&1 || { log "install: crontab not found; cannot schedule"; return 1; }
    local line="$CRON_SPEC $SELF run >/dev/null 2>&1 $MARKER"
    # Idempotent: drop any prior keep-alive line, re-add ours, preserve others.
    ( crontab -l 2>/dev/null | grep -vF "$MARKER"; echo "$line" ) | crontab -
    log "install: cron installed ($CRON_SPEC)"
}

do_install() {
    mkdir -p "$STATE_DIR"
    # Capture machine facts from the agent env (present at boot, absent under cron).
    {
        echo "# written by coder-keepalive.sh install ($(date -u +%Y-%m-%dT%H:%M:%SZ))"
        echo "KEEPALIVE_WS=\"${CODER_WORKSPACE_NAME:-solomon-dev}\""
        echo "KEEPALIVE_ID=\"${CODER_WORKSPACE_ID:-}\""
        echo "KEEPALIVE_URL=\"${CODER_AGENT_URL:-https://devspaces2.dev.lacework.engineering/}\""
    } >"$ENV_FILE"
    load_env
    provision_binary || true
    install_cron || true
    # Push the deadline now rather than waiting up to a full cron interval. Subshell
    # so do_run's flock/return can't short-circuit the completion log.
    ( do_run ) || true
    log "install: complete (ws=$WS)"
}

# ---- check (dry-run) ------------------------------------------------------
do_check() {
    load_env
    local dow mins decision now
    read -r dow mins < <(compute)
    now="$(now_epoch)"
    decision="$(decide)"
    echo "now (${TZ_NAME}): $(TZ="$TZ_NAME" date -d "@$now" '+%Y-%m-%d %H:%M:%S %Z')  (dow=$dow, mins_to_${STOP_HOUR}:00=$mins)"
    echo "workspace:       $WS"
    echo "stable binary:   $([ -x "$BIN" ] && echo "$BIN" || echo 'MISSING')"
    echo "decision:        $decision"
    [ "${decision%% *}" = "EXTEND" ] && echo "would run:       coder schedule extend $WS ${decision#EXTEND }m"
    return 0
}

# ---- dispatch -------------------------------------------------------------
mkdir -p "$STATE_DIR" 2>/dev/null || true
case "${1:-}" in
    install)      do_install ;;
    run)          load_env; do_run ;;
    --check|check) do_check ;;
    *) echo "usage: ${0##*/} {install|run|--check}" >&2; exit 2 ;;
esac
exit 0
