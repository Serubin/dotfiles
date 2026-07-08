#!/usr/bin/env bash
# Re-apply the SSH keepalive drop-in so a tmux -CC client whose ssh link died
# ungracefully (lid close, Wi-Fi/VPN switch) releases its session attachment after
# ~60s (15s x 4) instead of lingering until TCP timeout (~2h).
#
# This is root-owned config under /etc, which is wiped on a host restart, so it is
# re-applied at startup by ~/personalize (chezmoi only manages $HOME). /run/sshd is
# created first: this host is socket-activated, so the privsep dir may not exist yet
# at startup and `sshd -t` validation needs it.
set -uo pipefail

sudo mkdir -p /run/sshd
sudo tee /etc/ssh/sshd_config.d/50-client-keepalive.conf >/dev/null <<'SSHD_KEEPALIVE'
ClientAliveInterval 15
ClientAliveCountMax 4
SSHD_KEEPALIVE
sudo sshd -t \
  && echo "[apply-sshd-keepalive] sshd keepalive config OK" \
  || { echo "[apply-sshd-keepalive] sshd config invalid; reverting" >&2; sudo rm -f /etc/ssh/sshd_config.d/50-client-keepalive.conf; }
