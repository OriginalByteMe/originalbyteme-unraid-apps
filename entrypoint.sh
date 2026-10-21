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
# Docker creates a missing Projects folder as root; an existing share that the
# agents can already write keeps its owner.
as_orca test -w /projects || chown orca /projects

# Mapped Docker or libvirt sockets: join whatever group owns them.
for sock in /var/run/docker.sock /var/run/libvirt/libvirt-sock; do
  [ -S "$sock" ] || continue
  gid=$(stat -c %g "$sock")
  getent group "$gid" >/dev/null || groupadd -g "$gid" "sock$gid"
  usermod -aG "$gid" orca
  if as_orca test -w "$sock"; then
    log "agents can use $sock (root-equivalent on this server)"
  else
    log "WARNING: $sock is mapped but not writable for its group; agents cannot use it"
  fi
done

# SHELL: bash, zsh or fish, for Orca's terminals and the console.
shell=$(command -v "${SHELL:-bash}" || true)
if ! grep -qxF -- "$shell" /etc/shells; then
  log "WARNING: SHELL=${SHELL:-} is not an installed shell; using bash"
  shell=/bin/bash
fi
usermod -s "$shell" orca >/dev/null # prints "no changes" on every restart
export SHELL=$shell

# OH_MY_ZSH=true: Oh My Zsh in the Data folder, installed once the way its own
# installer does it, keeping any existing ~/.zshrc as ~/.zshrc.pre-oh-my-zsh.
if [ "${OH_MY_ZSH:-false}" = true ] && [ ! -d "$HOME/.oh-my-zsh" ]; then
  if as_orca git clone --quiet --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"; then
    [ ! -s "$HOME/.zshrc" ] || as_orca mv "$HOME/.zshrc" "$HOME/.zshrc.pre-oh-my-zsh"
    as_orca cp "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" "$HOME/.zshrc"
    log "installed Oh My Zsh"
  else
    log "WARNING: could not install Oh My Zsh"
  fi
fi
# Without a ~/.zshrc, zsh opens its first-run questionnaire in every terminal.
case $shell in */zsh) [ -e "$HOME/.zshrc" ] || as_orca touch "$HOME/.zshrc" ;; esac

if [ -n "${GH_TOKEN:-}" ]; then
  as_orca gh auth setup-git || log "WARNING: gh auth setup-git failed; git will not use GH_TOKEN"
fi
[ -z "${GIT_USER_NAME:-}" ] || as_orca git config --global user.name "$GIT_USER_NAME"
[ -z "${GIT_USER_EMAIL:-}" ] || as_orca git config --global user.email "$GIT_USER_EMAIL"

# GIT_REPOS: owner/name (GitHub) or full clone URLs, cloned once into /projects.
repo_dirs=()
for repo in ${GIT_REPOS:-}; do
  case "$repo" in
    *://* | git@*) url=$repo ;;
    *) url="https://github.com/$repo.git" ;;
  esac
  dir="/projects/$(basename "$repo" .git)"
  if [ -d "$dir/.git" ] || as_orca git clone --quiet "$url" "$dir"; then
    repo_dirs+=("$dir")
  else
    log "WARNING: could not clone $repo"
  fi
done

# AGENTS: agent CLIs, installed once into ~/.local so they persist and update
# themselves. The names map the agents in Orca's supported list that publish an
# official npm package; any other word is taken as an npm package name.
declare -A npm_name=(
  [amp]=@ampcode/cli [auggie]=@augmentcode/auggie [autohand]=autohand-cli
  [claude]=@anthropic-ai/claude-code [codebuddy]=@tencent-ai/codebuddy-code
  [codex]=@openai/codex [continue]=@continuedev/cli [copilot]=@github/copilot
  [crush]=@charmland/crush [gemini]=@google/gemini-cli [kilo]=@kilocode/cli
  [kimi]=@moonshot-ai/kimi-code [minimax]=@minimax-ai/code
  [omp]=@oh-my-pi/pi-coding-agent [opencode]=opencode-ai
  [pi]=@earendil-works/pi-coding-agent [qwen]=@qwen-code/qwen-code
)
agents=${AGENTS:-}
for name in ${agents//,/ }; do
  name=${name,,}
  pkg=${npm_name[$name]:-$name}
  [ -d "$HOME/.local/lib/node_modules/$pkg" ] || as_orca npm install --global --silent "$pkg" \
    || log "WARNING: could not install $name ($pkg)"
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

# Add the cloned repos to Orca's project list, retrying until the runtime answers
# (`orca-ide status` succeeds before it does, so it cannot be the signal).
register_repos() {
  local dir known err
  for dir in "${repo_dirs[@]}"; do
    for _ in $(seq 90); do
      if known=$(as_orca orca-ide repo list --json 2>/dev/null) && grep -qF "\"$dir\"" <<<"$known"; then
        continue 2
      fi
      if err=$(as_orca orca-ide repo add --path "$dir" --json 2>&1 >/dev/null); then
        log "added $dir to Orca"
        continue 2
      fi
      sleep 2
    done
    log "WARNING: could not add $dir to Orca: $err"
  done
}
[ ${#repo_dirs[@]} -eq 0 ] || register_repos &

log "starting orca serve; clients dial $addr:6768"
# shellcheck disable=SC2086 # ORCA_EXTRA_ARGS is a list of flags
exec "${drop[@]}" \
  orca-ide serve --port 6768 --pairing-address "$addr" ${ORCA_EXTRA_ARGS:-}
