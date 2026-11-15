#!/bin/bash
# Starts as root, so Unraid's "Use Tailscale" hook can run before it, then runs
# the official image's start script as the openbot account.
set -euo pipefail

log() { echo "[unraid-openbot] $*"; }
# Numeric ids: setpriv resolves --regid names as group names.
drop=(setpriv --reuid="$PUID" --regid="$PGID" --init-groups)

# Files in appdata get the owner Unraid expects (99:100 unless PUID/PGID say otherwise).
if [ "$(id -u openbot):$(id -g openbot)" != "$PUID:$PGID" ]; then
  getent group "$PGID" >/dev/null || groupmod -g "$PGID" openbot
  usermod -o -u "$PUID" -g "$PGID" openbot
fi
# Docker creates a missing Data folder as root. /run/openbot holds OpenBot's
# control socket, which `openbot` in the Console talks to.
chown openbot:"$PGID" "$HOME" /run/openbot

# `docker run <image> <command>` runs that command as openbot instead of the server.
[ $# -eq 0 ] || exec "${drop[@]}" "$@"

# TAILSCALE: OpenBot's Private network, which the desktop app sets in Settings ›
# Mobile Connect and a server has no screen for. OpenBot reads this file when
# it starts, so the template stays the one place that sets it.
route=openbot how="through OpenBot's network"
if [ "${TAILSCALE:-false}" = true ]; then
  route=private how="over your tailnet only (Private network)"
  # The prefix OpenBot takes as Tailscale (src/main/private-network-detection.ts).
  grep -q '^fd7a115ca1e0' /proc/net/if_inet6 ||
    log "WARNING: TAILSCALE is true, but this container has no Tailscale address, so no device can connect to it. Turn on Use Tailscale with userspace networking off, or use the Host network on a server that runs Tailscale."
fi
"${drop[@]}" mkdir -p "$HOME/.config/OpenBot"
printf '{"version":1,"route":"%s"}\n' "$route" |
  "${drop[@]}" tee "$HOME/.config/OpenBot/openbot-remote-network-route-v1.json" >/dev/null
log "devices connect $how"

exec "${drop[@]}" /opt/OpenBot/app/resources/hosting/openbot-container
