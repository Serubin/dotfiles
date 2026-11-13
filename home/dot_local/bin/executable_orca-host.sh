#!/usr/bin/env bash
# Run the Orca desktop app headless on this devbox so the phone reaches orcad over Orca Relay.
# usage: orca-host.sh install|sync [--restart]|claim-machine|trust-localhost|reclaim-lock|revive|watchdog|reap|xauth|wait-display|vnc [stop]|status
set -euo pipefail

OPT="$HOME/.local/opt/orca"
STATE="$HOME/.local/state/orca-host"
ACTIVE_JSON="$HOME/.orca-remote/orcad-active.json"
KEY="$HOME/.ssh/orca_localhost_ed25519"
XAUTH="$STATE/Xauthority"
DISPLAY_NUM=98
RELEASES="https://github.com/stablyai/orca/releases/download"
WATCHDOG_GRACE_SEC=360

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
umask 077
mkdir -p "$STATE" "$OPT"

log() { printf '[orca-host] %s\n' "$*" >&2; }
die() { log "$*"; exit 1; }
uctl() { systemctl --user "$@"; }

valid_version() { [[ "$1" =~ ^[0-9]{1,4}\.[0-9]{1,4}\.[0-9]{1,5}$ ]]; }

current_version() {
    local v
    v="$(readlink "$OPT/current" 2>/dev/null || true)"
    valid_version "$v" && [ -x "$OPT/$v/squashfs-root/orca-ide" ] && printf '%s\n' "$v"
}

# The laptop's Orca version, as recorded by whichever client last activated orcad.
wanted_version() {
    [ -r "$ACTIVE_JSON" ] || return 0
    python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1])).get("activeAppVersion") or "")' \
        "$ACTIVE_JSON" 2>/dev/null || true
}

# Prints "<sha512-base64> <size>" for the AppImage entry of an electron-builder manifest.
manifest_entry() {
    python3 -I - "$1" "$2" <<'PY'
import re, sys
text, want = open(sys.argv[1]).read(), sys.argv[2]
if not re.search(r"^version:\s*%s\s*$" % re.escape(want), text, re.M):
    sys.exit("manifest version does not match %s" % want)
m = re.search(r"-\s+url:\s*orca-linux\.AppImage\s*\n\s+sha512:\s*(\S+)\s*\n\s+size:\s*(\d+)", text)
if not m:
    sys.exit("manifest has no orca-linux.AppImage entry")
print(m.group(1), m.group(2))
PY
}

fetch_version() {
    local v="$1" tmp sha size got
    tmp="$(mktemp -d "$OPT/.fetch.XXXXXX")"
    curl -fsSL --retry 3 -o "$tmp/latest-linux.yml" "$RELEASES/v$v/latest-linux.yml"
    read -r sha size < <(manifest_entry "$tmp/latest-linux.yml" "$v") || die "bad manifest for $v"
    curl -fsSL --retry 3 --max-filesize "$size" -o "$tmp/orca-linux.AppImage" "$RELEASES/v$v/orca-linux.AppImage"
    [ "$(stat -c %s "$tmp/orca-linux.AppImage")" = "$size" ] || die "size mismatch for $v"
    got="$(python3 -I -c 'import base64,hashlib,sys; print(base64.b64encode(hashlib.file_digest(open(sys.argv[1],"rb"),"sha512").digest()).decode())' "$tmp/orca-linux.AppImage")"
    [ "$got" = "$sha" ] || die "sha512 mismatch for $v; refusing it"
    chmod 700 "$tmp/orca-linux.AppImage"
    mkdir "$tmp/x"
    (cd "$tmp/x" && "$tmp/orca-linux.AppImage" --appimage-extract >/dev/null)
    [ -x "$tmp/x/squashfs-root/orca-ide" ] || die "extracted $v has no orca-ide"
    rm -rf "${OPT:?}/$v"
    mkdir "$OPT/$v"
    mv "$tmp/x/squashfs-root" "$OPT/$v/squashfs-root"
    rm -rf "$tmp"
    log "installed Orca $v"
}

# Versions a live process still runs from (the local PTY daemon outlives app restarts).
in_use_versions() {
    local exe
    for exe in /proc/[0-9]*/exe; do
        readlink "$exe" 2>/dev/null || true
    done | sed -n "s|^$OPT/\([^/]*\)/squashfs-root/.*|\1|p" | sort -u
}

prune() {
    local keep="$1" d v used
    used="$(in_use_versions)"
    for d in "$OPT"/*/; do
        v="$(basename "$d")"
        valid_version "$v" || continue
        [ "$v" = "$keep" ] && continue
        grep -qxF "$v" <<<"$used" && continue
        rm -rf "${OPT:?}/$v"
        log "pruned Orca $v"
    done
}

do_sync() {
    local restart="${1:-}" want have
    exec 9>"$STATE/sync.lock"
    flock 9
    rm -rf "$OPT"/.fetch.*
    want="$(wanted_version)"
    have="$(current_version || true)"
    if ! valid_version "$want"; then
        [ -n "$want" ] && log "ignoring unrecognized activeAppVersion '$want'"
        [ -n "$have" ] && return 0
        die "no usable activeAppVersion in $ACTIVE_JSON and nothing installed"
    fi
    [ "$want" = "$have" ] && return 0
    [ -x "$OPT/$want/squashfs-root/orca-ide" ] || fetch_version "$want"
    ln -sfn "$want" "$OPT/.current.tmp"
    mv -T "$OPT/.current.tmp" "$OPT/current"
    log "current: ${have:-none} -> $want"
    prune "$want"
    # A desktop restart pulls in orca-sync, which takes this lock; release it and don't wait on the job.
    flock -u 9
    exec 9>&-
    if [ "$restart" = --restart ] && uctl -q is-active orca-desktop.service; then
        uctl --no-block restart orca-desktop.service
    fi
}

# Each workspace start can be a fresh EC2 instance with new sshd host keys; trust them for loopback only.
do_trust_localhost() {
    python3 -I - "$HOME/.ssh/known_hosts" /etc/ssh/ssh_host_*_key.pub <<'PY'
import base64, hashlib, hmac, os, sys, tempfile
path, pubs, host = sys.argv[1], sys.argv[2:], "127.0.0.1"
want = {tuple(open(p).read().split()[:2]) for p in pubs}

def names_host(field):
    if not field.startswith("|1|"):
        return host in field.split(",")
    try:
        salt, digest = (base64.b64decode(x) for x in field[3:].split("|", 1))
    except ValueError:
        return False
    return hmac.compare_digest(hmac.new(salt, host.encode(), hashlib.sha1).digest(), digest)

try:
    lines = open(path).read().splitlines()
except FileNotFoundError:
    lines = []
have, kept = set(), []
for line in lines:
    parts = line.split()
    if len(parts) < 3 or parts[0].startswith(("#", "@")) or not names_host(parts[0]):
        kept.append(line)
        continue
    have.add((parts[1], parts[2]))
    others = [] if parts[0].startswith("|1|") else [n for n in parts[0].split(",") if n != host]
    if others:
        kept.append(" ".join([",".join(others)] + parts[1:]))
if have == want:
    sys.exit(0)
kept += ["%s %s %s" % (host, kind, key) for kind, key in sorted(want)]
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".known_hosts.")
with os.fdopen(fd, "w") as f:
    f.write("\n".join(kept) + "\n")
if os.path.exists(path):
    os.chmod(tmp, os.stat(path).st_mode & 0o777)
os.replace(tmp, path)
print("[orca-host] refreshed 127.0.0.1 host keys in known_hosts", file=sys.stderr)
PY
}

# A lock from an earlier boot of this host can't have a live owner; Orca treats it as another machine's.
do_reclaim_lock() {
    python3 -I - "$HOME/.config/orca/orcad.lock" <<'PY'
import json, os, socket, sys
path = sys.argv[1]
try:
    lock = json.load(open(path))
except FileNotFoundError:
    sys.exit(0)
except ValueError:
    print("[orca-host] %s is not JSON; leaving it" % path, file=sys.stderr)
    sys.exit(0)
boot = open("/proc/sys/kernel/random/boot_id").read().strip()
if not isinstance(lock, dict) or lock.get("host") != socket.gethostname() or not lock.get("bootId"):
    sys.exit(0)
if lock["bootId"] != boot:
    os.remove(path)
    print("[orca-host] removed orcad.lock from earlier boot %s (pid %s)" % (lock["bootId"], lock.get("pid")),
          file=sys.stderr)
PY
}

# Run from cron: nothing restarts a lingering user manager that earlyoom SIGKILLed.
do_revive() {
    local uid
    uid="$(id -u)"
    [ -e "/var/lib/systemd/linger/$(id -un)" ] || return 0
    systemctl -q is-active "user@$uid.service" && return 0
    log "user@$uid.service is $(systemctl is-active "user@$uid.service" || true); starting it"
    sudo -n systemctl start "user@$uid.service"
}

# Orca picks orcad's data dir by a hash of /etc/machine-id, which a rebuild regenerates; only one machine uses this home.
do_claim_machine() {
    local claim="$HOME/.orca-remote/orcad-machine.json" id key
    id="$(cat /etc/machine-id 2>/dev/null || true)"
    [[ "$id" =~ ^[a-f0-9]{32}$ ]] || die "unusable /etc/machine-id"
    key="$(printf 'linux:%s' "$id" | sha256sum | cut -c1-16)"
    grep -qF "\"machineKey\":\"$key\"" "$claim" 2>/dev/null && return 0
    mkdir -p "$HOME/.orca-remote"
    [ -f "$claim" ] && cp -p "$claim" "$claim.bak"
    printf '{"schemaVersion":1,"machineKey":"%s"}' "$key" > "$claim.tmp"
    mv "$claim.tmp" "$claim"
    log "claimed ~/.orca for machine key $key"
}

ensure_ssh_key() {
    local ak="$HOME/.ssh/authorized_keys" pub
    [ -f "$KEY" ] || ssh-keygen -q -t ed25519 -N '' -C orca-host-localhost -f "$KEY"
    pub="$(awk '{print $1" "$2}' "$KEY.pub")"
    grep -qF "$pub" "$ak" 2>/dev/null || printf 'from="127.0.0.1,::1" %s orca-host-localhost\n' "$pub" >> "$ak"
}

ssh_link_up() {
    ss -Htnp state established '( dst 127.0.0.1 and dport = :22 )' 2>/dev/null | grep -q '"orca-ide"'
}

# Orca stops retrying SSH after ~2 min and only re-arms on resume/unlock, which never fire under Xvfb.
do_watchdog() {
    local f="$STATE/watchdog.down-since" now since
    if ! uctl -q is-active orca-desktop.service; then
        rm -f "$f"
        # A dependency failure (e.g. Xvfb) skips Restart=; only `disable` should keep it down.
        uctl -q is-enabled orca-desktop.service && uctl --no-block start orca-desktop.service
        return 0
    fi
    if ssh_link_up; then
        rm -f "$f"
        return 0
    fi
    now="$(date +%s)"
    [ -s "$f" ] || echo "$now" > "$f"
    since="$(cat "$f")"
    if [ $((now - since)) -ge "$WATCHDOG_GRACE_SEC" ]; then
        log "SSH link down for $((now - since))s; restarting orca-desktop"
        rm -f "$f"
        uctl --no-block restart orca-desktop.service
    fi
}

# Chromium moves its browser process into its own app-orca-<pid>.scope, outside the service cgroup.
do_reap() {
    local unit
    for unit in $(uctl list-units --plain --no-legend --state=active 'app-orca-*.scope' | awk '{print $1}'); do
        uctl stop "$unit" || true
    done
}

do_xauth() {
    : > "$XAUTH"
    python3 -I -c 'import secrets, sys; print("add :%s . %s" % (sys.argv[1], secrets.token_hex(16)))' "$DISPLAY_NUM" \
        | xauth -q -f "$XAUTH" source -
}

# A SIGKILLed Xvfb leaves its socket behind, so probe for a listener rather than the file.
do_wait_display() {
    python3 -I - "$DISPLAY_NUM" <<'PY'
import socket, sys, time
path = "/tmp/.X11-unix/X%s" % sys.argv[1]
for _ in range(150):
    s = socket.socket(socket.AF_UNIX)
    try:
        s.connect(path)
        sys.exit(0)
    except OSError:
        time.sleep(0.1)
    finally:
        s.close()
sys.exit("display :%s did not come up" % sys.argv[1])
PY
}

do_install() {
    local pkgs=()
    do_claim_machine
    command -v Xvfb >/dev/null || pkgs+=(xvfb)
    command -v xauth >/dev/null || pkgs+=(xauth)
    if [ "${#pkgs[@]}" -gt 0 ]; then
        sudo DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=300 install -y -q "${pkgs[@]}" \
            || { sudo apt-get -o DPkg::Lock::Timeout=300 update -q \
                 && sudo DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=300 install -y -q "${pkgs[@]}"; }
    fi
    # Same shape as Ubuntu's chrome profile: lets Chromium's namespace sandbox run under userns restriction.
    sudo tee /etc/apparmor.d/orca-host >/dev/null <<'AA'
abi <abi/4.0>,
include <tunables/global>

profile orca-host @{HOME}/.local/opt/orca/*/squashfs-root/orca-ide flags=(unconfined) {
  userns,

  include if exists <local/orca-host>
}
AA
    sudo apparmor_parser -r /etc/apparmor.d/orca-host
    if [ -f /usr/lib/systemd/system/earlyoom.service ]; then
        sudo mkdir -p /etc/systemd/system/earlyoom.service.d
        sudo tee /etc/systemd/system/earlyoom.service.d/orca-host.conf >/dev/null <<'EOF'
[Service]
ExecStart=
ExecStart=/usr/bin/earlyoom $EARLYOOM_ARGS --avoid "^(systemd|Xvfb|orca-ide|dbus-daemon)$$"
EOF
        sudo systemctl daemon-reload
        sudo systemctl try-restart earlyoom.service
    fi
    if command -v crontab >/dev/null; then
        ( { crontab -l 2>/dev/null || true; } | grep -vF '# orca-host-revive' || true
          echo "*/5 * * * * $HOME/.local/bin/orca-host.sh revive >>$STATE/revive.log 2>&1 # orca-host-revive" ) | crontab -
    fi
    sudo loginctl enable-linger "$(id -un)"
    # Enabling linger starts the user manager asynchronously; its bus must exist before systemctl --user.
    for _ in $(seq 1 60); do
        [ -S "$XDG_RUNTIME_DIR/systemd/private" ] && break
        sleep 0.5
    done
    ensure_ssh_key
    uctl daemon-reload
    uctl reset-failed 'orca-*' 2>/dev/null || true
    uctl enable --now orca-xvfb.service orca-desktop.service orca-version.path orca-watchdog.timer
    log "installed; $(uctl is-active orca-desktop.service)"
}

do_vnc() {
    if [ "${1:-}" = stop ]; then
        uctl stop orca-vnc.service
        return 0
    fi
    command -v x11vnc >/dev/null || sudo DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=300 install -y -q x11vnc
    [ -s "$STATE/vnc.pass" ] || python3 -I -c 'import secrets; print(secrets.token_urlsafe(6))' > "$STATE/vnc.pass"
    systemd-run --user --unit=orca-vnc --collect \
        x11vnc -display ":$DISPLAY_NUM" -auth "$XAUTH" -localhost -rfbport 5900 \
        -passwdfile "$STATE/vnc.pass" -forever -shared -quiet
    log "VNC on 127.0.0.1:5900; password in $STATE/vnc.pass; stop with: orca-host.sh vnc stop"
}

do_status() {
    local u
    for u in orca-xvfb.service orca-desktop.service orca-version.path orca-watchdog.timer orca-vnc.service; do
        printf '%-22s %s\n' "$u" "$(uctl is-active "$u" 2>/dev/null || true)"
    done
    printf '%-22s %s\n' "version" "current=$(current_version || echo none) laptop=$(wanted_version)"
    printf '%-22s %s\n' "orcad pid" "$(pgrep -u "$(id -u)" -f '/orcad\.js ' | tr '\n' ' ' || true)"
    printf '%-22s %s\n' "ssh link" "$(ssh_link_up && echo up || echo down)"
}

case "${1:-}" in
    install) do_install ;;
    sync) do_sync "${2:-}" ;;
    claim-machine) do_claim_machine ;;
    trust-localhost) do_trust_localhost ;;
    reclaim-lock) do_reclaim_lock ;;
    revive) do_revive ;;
    watchdog) do_watchdog ;;
    reap) do_reap ;;
    xauth) do_xauth ;;
    wait-display) do_wait_display ;;
    vnc) do_vnc "${2:-}" ;;
    status) do_status ;;
    *) sed -n 3p "$0" >&2; exit 2 ;;
esac
