# Herdr's headless server for Unraid, reached over SSH with `herdr --remote`.
# amd64 only: Unraid and its Tailscale hook are x86_64.
FROM ubuntu:24.04

# Pinned; .github/workflows/herdr-bump.yml opens a pull request for each release.
ARG HERDR_VERSION=0.9.5
ENV DEBIAN_FRONTEND=noninteractive

# GitHub CLI and Tailscale come from their vendors' apt repos. Tailscale is
# preinstalled so Unraid's "Use Tailscale" hook skips its own download on every
# start. Docker's CLI lets agents use a mapped Docker socket.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl jq; \
    install -d -m 0755 /etc/apt/keyrings; \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc; \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/github-cli.gpg; \
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg -o /etc/apt/keyrings/tailscale.gpg; \
    echo "deb [signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable" > /etc/apt/sources.list.d/docker.list; \
    echo "deb [signed-by=/etc/apt/keyrings/github-cli.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list; \
    echo "deb [signed-by=/etc/apt/keyrings/tailscale.gpg] https://pkgs.tailscale.com/stable/ubuntu noble main" > /etc/apt/sources.list.d/tailscale.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      docker-ce-cli gh tailscale openssh-server libvirt-clients \
      git openssh-client rsync make tini procps xz-utils unzip zsh fish python3 locales; \
    locale-gen en_US.UTF-8; \
    rm -rf /var/lib/apt/lists/*

# Herdr's Linux binary, checked against the digest GitHub records for the asset.
RUN set -eux; \
    asset=herdr-linux-x86_64; \
    sum=$(curl -fsSL "https://api.github.com/repos/herdrdev/herdr/releases/tags/v${HERDR_VERSION}" \
      | jq -r --arg a "$asset" '.assets[] | select(.name == $a) | .digest | sub("^sha256:"; "")'); \
    curl -fsSL -o /usr/local/bin/herdr "https://github.com/herdrdev/herdr/releases/download/v${HERDR_VERSION}/$asset"; \
    echo "${sum}  /usr/local/bin/herdr" | sha256sum -c -; \
    chmod 0755 /usr/local/bin/herdr; \
    herdr --version

# Node for agent CLIs installed with npm. Latest 24.x at build time, checked
# against nodejs.org's published sums.
RUN set -eux; \
    base=https://nodejs.org/dist/latest-v24.x; \
    line=$(curl -fsSL "$base/SHASUMS256.txt" | grep 'linux-x64.tar.xz$'); \
    curl -fsSL -o /tmp/node.tar.xz "$base/${line##* }"; \
    echo "${line%% *}  /tmp/node.tar.xz" | sha256sum -c -; \
    tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 --exclude='*/CHANGELOG.md'; \
    rm /tmp/node.tar.xz; \
    node --version

# Bun, which omp runs on. The baseline build also runs on CPUs without AVX2.
RUN set -eux; \
    base=https://github.com/oven-sh/bun/releases/latest/download; \
    line=$(curl -fsSL "$base/SHASUMS256.txt" | grep ' bun-linux-x64-baseline.zip$'); \
    curl -fsSL -o /tmp/bun.zip "$base/bun-linux-x64-baseline.zip"; \
    echo "${line%% *}  /tmp/bun.zip" | sha256sum -c -; \
    unzip -j /tmp/bun.zip '*/bun' -d /usr/local/bin; \
    ln -s bun /usr/local/bin/bunx; \
    rm /tmp/bun.zip; \
    bun --version

# The runtime account, already 99:100 (Unraid's nobody:users); the entrypoint
# moves it when PUID/PGID differ. Interactive root bash (Unraid's Console
# button) becomes herdr in its shell; `sh` still gives a root shell.
# SSH sessions get their environment from PAM's /etc/environment, not Docker's.
RUN useradd --no-log-init -u 99 -g users -m -d /home/herdr -s /bin/bash herdr \
 && install -d -o herdr -g users /projects \
 && echo '[ "$(id -u)" = 0 ] && export SHELL="$(getent passwd herdr | cut -d: -f7)" && exec setpriv --reuid="$(id -u herdr)" --regid="$(id -g herdr)" --init-groups "$SHELL"' >> /etc/bash.bashrc \
 && printf '%s\n' 'PATH="/home/herdr/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"' \
      'NPM_CONFIG_PREFIX="/home/herdr/.local"' 'LANG="en_US.UTF-8"' > /etc/environment \
 && rm -f /etc/ssh/ssh_host_* \
 && install -d -m 0755 /run/sshd

COPY sshd_config /etc/ssh/sshd_config.d/herdr.conf

ENV HOME=/home/herdr \
    PATH=/home/herdr/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    NPM_CONFIG_PREFIX=/home/herdr/.local \
    LANG=en_US.UTF-8 \
    PUID=99 \
    PGID=100

COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint
EXPOSE 2222
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint"]
