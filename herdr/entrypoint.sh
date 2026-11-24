#!/bin/bash
# Starts as root, so Unraid's "Use Tailscale" hook and sshd can run, then runs
# Herdr and everything the agents touch as the herdr account.
set -euo pipefail

export USER=herdr LOGNAME=herdr
log() { echo "[unraid-herdr] $*"; }
drop=(setpriv --reuid="$PUID" --regid="$PGID" --init-groups)
as_herdr() { "${drop[@]}" "$@"; }

if [ "$(id -u herdr):$(id -g herdr)" != "$PUID:$PGID" ]; then
  getent group "$PGID" >/dev/null || groupadd -g "$PGID" herdr
  usermod -o -u "$PUID" -g "$PGID" herdr
fi
chown herdr "$HOME"
as_herdr test -w /projects || chown herdr /projects

for sock in /var/run/docker.sock /var/run/libvirt/libvirt-sock; do
  [ -S "$sock" ] || continue
  gid=$(stat -c %g "$sock")
  getent group "$gid" >/dev/null || groupadd -g "$gid" "sock$gid"
  usermod -aG "$gid" herdr
  if as_herdr test -w "$sock"; then
    log "agents can use $sock (root-equivalent on this server)"
  else
    log "WARNING: $sock is mapped but not writable for its group; agents cannot use it"
  fi
done

shell=$(command -v "${SHELL:-bash}" || true)
if ! grep -qxF -- "$shell" /etc/shells; then
  log "WARNING: SHELL=${SHELL:-} is not an installed shell; using bash"
  shell=/bin/bash
fi
usermod -s "$shell" herdr >/dev/null
export SHELL=$shell
case $shell in */zsh) [ -e "$HOME/.zshrc" ] || as_herdr touch "$HOME/.zshrc" ;; esac

if [ -n "${GH_TOKEN:-}" ]; then
  sed -i '/^GH_TOKEN=/d' /etc/environment
  printf 'GH_TOKEN="%s"\n' "$GH_TOKEN" >> /etc/environment
  as_herdr gh auth setup-git || log "WARNING: gh auth setup-git failed; git will not use GH_TOKEN"
fi
[ -z "${GIT_USER_NAME:-}" ] || as_herdr git config --global user.name "$GIT_USER_NAME"
[ -z "${GIT_USER_EMAIL:-}" ] || as_herdr git config --global user.email "$GIT_USER_EMAIL"

as_herdr onboard clone

declare -A npm_name=(
  [claude]=@anthropic-ai/claude-code [codex]=@openai/codex [gemini]=@google/gemini-cli
  [omp]=@oh-my-pi/pi-coding-agent [opencode]=opencode-ai [pi]=@earendil-works/pi-coding-agent
)
agents=${AGENTS:-}
for name in ${agents//,/ }; do
  name=${name,,}
  pkg=${npm_name[$name]:-$name}
  [ -d "$HOME/.local/lib/node_modules/$pkg" ] || as_herdr npm install --global --silent "$pkg" \
    || log "WARNING: could not install $name ($pkg)"
done

# SSH host keys live in the Data folder, so clients keep trusting the server
# across updates. AUTHORIZED_KEYS lines are added to whatever is already there.
as_herdr install -d -m 0700 "$HOME/.ssh" "$HOME/.ssh/host"
for type in ed25519 rsa; do
  key=$HOME/.ssh/host/ssh_host_${type}_key
  [ -f "$key" ] || as_herdr ssh-keygen -q -t "$type" -N '' -C herdr-unraid -f "$key"
done
keys=$HOME/.ssh/authorized_keys
as_herdr touch "$keys"
while IFS= read -r line; do
  [ -z "$line" ] || grep -qxF -- "$line" "$keys" || echo "$line" | as_herdr tee -a "$keys" >/dev/null
done <<<"${AUTHORIZED_KEYS:-}"
[ $# -eq 0 ] || exec "${drop[@]}" "$@"

[ -s "$keys" ] || log "WARNING: no SSH keys; set Authorized keys or add them to $keys"
cd /projects
as_herdr herdr server >/dev/null 2>&1 &
log "herdr server started; attach with herdr --remote using port 2222 and user herdr"
exec /usr/sbin/sshd -D -e
