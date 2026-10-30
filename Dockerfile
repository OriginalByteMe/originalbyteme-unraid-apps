# Headless Orca (`orca serve`) for Unraid. amd64 only: Orca's deb and Unraid's
# Tailscale hook are both x86_64 here.
FROM ubuntu:24.04

# Pinned; .github/workflows/orca-bump.yml opens a pull request for each release.
ARG ORCA_VERSION=1.4.245
ENV DEBIAN_FRONTEND=noninteractive

# Docker CLI, GitHub CLI and Tailscale come from their vendors' apt repos.
# Tailscale is preinstalled so Unraid's "Use Tailscale" hook skips its own
# download on every start; the hook only needs jq and the two binaries.
# The lib* packages are Electron libraries Orca's deb does not declare, taken
# from Orca's headless Linux guide. zsh, fish and tmux back the Shell setting.
RUN set -eux; \
    test -n "${ORCA_VERSION}"; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl jq; \
    install -d -m 0755 /etc/apt/keyrings; \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc; \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/github-cli.gpg; \
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg -o /etc/apt/keyrings/tailscale.gpg; \
    echo "deb [signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable" > /etc/apt/sources.list.d/docker.list; \
    echo "deb [signed-by=/etc/apt/keyrings/github-cli.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list; \
    echo "deb [signed-by=/etc/apt/keyrings/tailscale.gpg] https://pkgs.tailscale.com/stable/ubuntu noble main" > /etc/apt/sources.list.d/tailscale.list; \
    curl -fsSL -o /tmp/orca.deb "https://github.com/stablyai/orca/releases/download/v${ORCA_VERSION}/orca-ide_${ORCA_VERSION}_amd64.deb"; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      /tmp/orca.deb docker-ce-cli gh tailscale libvirt-clients \
      git openssh-client tini xz-utils unzip zsh fish tmux python3 \
      libgtk-3-0t64 libnss3 libatk1.0-0t64 libatk-bridge2.0-0t64 libgbm1 libasound2t64 \
      libxtst6 libcups2t64 libdrm2 libxkbcommon0 libpango-1.0-0 libcairo2 libatspi2.0-0t64 \
      libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libxrender1 libx11-xcb1 \
      libxcb-dri3-0 libxss1; \
    rm -rf /tmp/orca.deb /var/lib/apt/lists/*; \
    orca-ide --version

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

# Bun, which omp and other Bun-based agent CLIs run on. The baseline build also
# runs on CPUs without AVX2, which many NAS boxes have.
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
# moves it when PUID/PGID differ. Xvfb wants a root-owned X socket directory.
# Interactive root bash (Unraid's Console button) becomes orca in orca's shell,
# so agent logins land in orca's home; `sh` still gives a root shell.
RUN useradd --no-log-init -u 99 -g users -m -d /home/orca -s /bin/bash orca \
 && install -d -o orca -g users /projects \
 && install -d -m 1777 /tmp/.X11-unix \
 && echo '[ "$(id -u)" = 0 ] && export SHELL="$(getent passwd orca | cut -d: -f7)" && exec setpriv --reuid="$(id -u orca)" --regid="$(id -g orca)" --init-groups "$SHELL"' >> /etc/bash.bashrc

ENV HOME=/home/orca \
    PATH=/home/orca/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    NPM_CONFIG_PREFIX=/home/orca/.local \
    LIBGL_ALWAYS_SOFTWARE=1 \
    ORCA_ELECTRON_NO_SANDBOX=1 \
    PUID=99 \
    PGID=100

COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint
EXPOSE 6768
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint"]
