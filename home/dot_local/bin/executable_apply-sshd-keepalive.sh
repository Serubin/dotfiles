#!/usr/bin/env bash
# Re-apply the SSH keepalive drop-in so a tmux -CC client whose ssh link died
# ungracefully (lid close, Wi-Fi/VPN switch) releases its session attachment after
# ~60s (15s x 4) instead of lingering until TCP timeout (~2h).
#
# Root-owned /etc config, wiped on a host restart, so ~/personalize re-applies it at
# startup (chezmoi only manages $HOME). /run/sshd is created first: this host is
# socket-activated, so the privsep dir `sshd -t` needs may not exist yet.
set -uo pipefail

sudo mkdir -p /run/sshd
sudo tee /etc/ssh/sshd_config.d/50-client-keepalive.conf >/dev/null <<'SSHD_KEEPALIVE'
ClientAliveInterval 15
ClientAliveCountMax 4
SSHD_KEEPALIVE
sudo sshd -t \
  && echo "[apply-sshd-keepalive] sshd keepalive config OK" \
  || { echo "[apply-sshd-keepalive] sshd config invalid; reverting" >&2; sudo rm -f /etc/ssh/sshd_config.d/50-client-keepalive.conf; }
