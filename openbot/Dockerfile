# OpenBot's official server image (docs/docker.md in nightly-labs/openbot) for
# Unraid. It starts as root so Unraid's "Use Tailscale" hook can run, then the
# entrypoint runs the image's own start script as the openbot account.

# Pinned; .github/workflows/openbot-bump.yml opens a pull request for each release.
ARG OPENBOT_VERSION=0.76.0
FROM ghcr.io/nightly-labs/openbot:${OPENBOT_VERSION}

USER root
# Tailscale is preinstalled so Unraid's "Use Tailscale" hook skips its own
# download on every start; the hook only needs jq and both binaries in /usr/bin.
RUN set -eux; \
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg -o /usr/share/keyrings/tailscale.gpg; \
    echo "deb [signed-by=/usr/share/keyrings/tailscale.gpg] https://pkgs.tailscale.com/stable/ubuntu noble main" > /etc/apt/sources.list.d/tailscale.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends jq tailscale; \
    rm -rf /var/lib/apt/lists/*; \
    test -x /usr/bin/tailscaled || ln -s /usr/sbin/tailscaled /usr/bin/tailscaled

# The openbot account as Unraid's usual 99:100 (nobody:users); the entrypoint
# moves it when PUID/PGID differ. Interactive root bash (Unraid's Console
# button) becomes openbot, so `openbot login` and provider sign-ins land in its
# home, the Data folder; `sh` still gives a root shell.
RUN usermod -u 99 -g 100 openbot \
 && chown 99:100 /data /run/openbot \
 && echo '[ "$(id -u)" = 0 ] && exec setpriv --reuid="$(id -u openbot)" --regid="$(id -g openbot)" --init-groups bash' >> /etc/bash.bashrc

ENV HOME=/data \
    PUID=99 \
    PGID=100

COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint"]
