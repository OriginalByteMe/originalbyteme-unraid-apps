#!/bin/bash
# Starts as root, so Unraid's "Use Tailscale" hook can run before it, then
# drops to the orca account for everything else.
set -euo pipefail

export USER=orca LOGNAME=orca
log() { echo "[unraid-orca] $*"; }
# Numeric ids: setpriv resolves --regid names as group names, and orca's group
# is "users" or whatever PGID points at.
drop=(setpriv --reuid="$PUID" --regid="$PGID" --init-groups)
as_orca() { "${drop[@]}" "$@"; }

# Files in appdata get the owner Unraid expects (99:100 unless PUID/PGID say otherwise).
if [ "$(id -u orca):$(id -g orca)" != "$PUID:$PGID" ]; then
  getent group "$PGID" >/dev/null || groupadd -g "$PGID" orca
  usermod -o -u "$PUID" -g "$PGID" orca
fi
chown orca "$HOME"

# Mapped Docker or libvirt sockets: join whatever group owns them.
for sock in /var/run/docker.sock /var/run/libvirt/libvirt-sock; do
  [ -S "$sock" ] || continue
  gid=$(stat -c %g "$sock")
  getent group "$gid" >/dev/null || groupadd -g "$gid" "sock$gid"
  usermod -aG "$(getent group "$gid" | cut -d: -f1)" orca
  if as_orca test -w "$sock"; then
    log "agents can use $sock (root-equivalent on this server)"
  else
    log "WARNING: $sock is mapped but not writable for its group; agents cannot use it"
  fi
done

if [ -n "${GH_TOKEN:-}" ]; then
  as_orca gh auth setup-git || log "WARNING: gh auth setup-git failed; git will not use GH_TOKEN"
fi
[ -z "${GIT_USER_NAME:-}" ] || as_orca git config --global user.name "$GIT_USER_NAME"
[ -z "${GIT_USER_EMAIL:-}" ] || as_orca git config --global user.email "$GIT_USER_EMAIL"

# GIT_REPOS: owner/name (GitHub) or full clone URLs, cloned once into ~/projects.
repo_dirs=()
for repo in ${GIT_REPOS:-}; do
  case "$repo" in
    *://* | git@*) url=$repo ;;
    *) url="https://github.com/$repo.git" ;;
  esac
  dir="$HOME/projects/$(basename "$repo" .git)"
  if [ -d "$dir/.git" ] || as_orca git clone --quiet "$url" "$dir"; then
    repo_dirs+=("$dir")
  else
    log "WARNING: could not clone $repo"
  fi
done

# NPM_PACKAGES: agent CLIs, installed once into ~/.local so they persist and self-update.
for pkg in ${NPM_PACKAGES:-}; do
  [ -d "$HOME/.local/lib/node_modules/$pkg" ] || as_orca npm install --global --silent "$pkg" \
    || log "WARNING: could not install $pkg"
done

# `docker run <image> <command>` runs that command as orca instead of the server.
[ $# -eq 0 ] || exec "${drop[@]}" "$@"

addr=${ORCA_PAIRING_ADDRESS:-}
if [ -z "$addr" ] && tailscale ip -4 >/dev/null 2>&1; then
  addr=$(tailscale ip -4 | head -n 1)
fi
if [ -z "$addr" ]; then
  log "ERROR: set ORCA_PAIRING_ADDRESS to the address clients dial (this server's LAN or Tailscale IP), or turn on Use Tailscale"
  exit 1
fi

# Once the runtime answers, add the cloned repos to Orca's project list.
register_repos() {
  for _ in $(seq 90); do
    as_orca orca-ide status --json >/dev/null 2>&1 && break
    sleep 2
  done
  known=$(as_orca orca-ide repo list --json 2>/dev/null || true)
  for dir in "${repo_dirs[@]}"; do
    grep -qF "\"$dir\"" <<<"$known" && continue
    if as_orca orca-ide repo add --path "$dir" --json >/dev/null; then
      log "added $dir to Orca"
    else
      log "WARNING: could not add $dir to Orca"
    fi
  done
}
[ ${#repo_dirs[@]} -eq 0 ] || register_repos &

log "starting orca serve; clients dial $addr:6768"
# shellcheck disable=SC2086 # ORCA_EXTRA_ARGS is a list of flags
exec "${drop[@]}" \
  orca-ide serve --port 6768 --pairing-address "$addr" ${ORCA_EXTRA_ARGS:-}
