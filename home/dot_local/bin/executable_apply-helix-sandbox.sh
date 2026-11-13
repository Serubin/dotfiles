#!/usr/bin/env bash
# Install bubblewrap/socat and grant /usr/bin/bwrap (only) unprivileged userns under AppArmor,
# for Claude Code's sandbox as used by Helix. Root-owned state, re-applied by ~/personalize.
set -uo pipefail

log() { echo "[apply-helix-sandbox] $*"; }
err() { echo "[apply-helix-sandbox] $*" >&2; }

missing=()
[ -x /usr/bin/bwrap ] || missing+=(bubblewrap)
command -v socat >/dev/null 2>&1 || missing+=(socat)
if [ "${#missing[@]}" -gt 0 ]; then
    log "installing ${missing[*]}"
    sudo DEBIAN_FRONTEND=noninteractive timeout 180 \
        apt-get install -y -qq -o DPkg::Lock::Timeout=60 "${missing[@]}" >/dev/null \
        || err "apt-get install ${missing[*]} failed"
fi

profile=/etc/apparmor.d/bwrap-userns
sudo tee "$profile" >/dev/null <<'BWRAP_USERNS'
abi <abi/4.0>,
include <tunables/global>

profile bwrap /usr/bin/bwrap flags=(unconfined) {
  userns,

  include if exists <local/bwrap>
}
BWRAP_USERNS
if sudo apparmor_parser -r "$profile"; then
    log "AppArmor userns profile for /usr/bin/bwrap loaded"
else
    err "apparmor_parser rejected $profile; removing"
    sudo rm -f "$profile"
fi

if /usr/bin/bwrap --unshare-user --ro-bind / / true 2>/dev/null; then
    log "bwrap userns self-check OK"
else
    err "bwrap userns self-check FAILED"
fi

# The profile attaches by path, so any other bwrap earlier on PATH is still denied userns.
resolved=$(command -v bwrap 2>/dev/null || true)
if [ -n "$resolved" ] && [ "$resolved" != /usr/bin/bwrap ]; then
    err "WARNING: PATH resolves bwrap to $resolved, which the profile does not cover"
fi
