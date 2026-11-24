# unraid-openbot

An unofficial Unraid template and Docker image for
[OpenBot](https://openbot.run) ([source](https://github.com/nightly-labs/openbot)),
Nightly Labs' workspace for a team of AI agents such as Claude Code, Codex,
Gemini, OpenCode, Pi, Hermes Agent or a model on your own Ollama server. The
container runs OpenBot's official server image, so the agents, their
workspaces, chats and files live on your Unraid server, while the OpenBot desktop
app, phone app and [openbot.run/app](https://openbot.run/app) reach it through
your OpenBot account. This project is not affiliated with Nightly Labs.

OpenBot is free for noncommercial use only. Its source and images are under the
[PolyForm Noncommercial License 1.0.0](https://github.com/nightly-labs/openbot/blob/main/LICENSE),
so using it for a business needs a license from Nightly Labs.

## What this image adds to OpenBot

- Runs OpenBot as Unraid's usual 99:100 account, or PUID and PGID, so the Data
  folder in appdata has the owner Unraid expects. The official image runs as
  1000:1000.
- A **Tailscale** setting that switches OpenBot to its Private network. The
  desktop app has this in Settings › Mobile Connect, but a server has no screen
  to choose it on.
- Works with Unraid's **Use Tailscale** switch: the container starts as root so
  Unraid's hook can run, and Tailscale is preinstalled so the hook does not
  download it on every start.
- The Console button opens a shell as OpenBot's account, so `openbot` commands
  and provider sign-ins land in the Data folder. The first time, it walks you
  through signing the server in to OpenBot and GitHub; run `onboard` to go
  through it again.
- The GitHub CLI, so the agents can clone, push and open pull requests once you
  sign in with a one-time code.

Everything else is the official image: the same OpenBot, started by its own
start script, with the Electron sandbox on.

## Getting started

1. **Install the template.** Until it is in Community Apps, copy it onto the
   flash drive from the Unraid terminal:

   ```sh
   curl -fsSL -o /boot/config/plugins/dockerMan/templates-user/my-OpenBot.xml \
     https://raw.githubusercontent.com/OriginalByteMe/originalbyteme-unraid-apps/main/templates/openbot.xml
   ```

   Then on the Docker tab choose **Add Container** and pick **OpenBot** from the
   user templates.
2. **Choose how your devices connect.** Leave **Tailscale** at `false` to use
   OpenBot's network, or see [Tailscale](#tailscale).
3. **Apply, then sign the server in.** Open the container's **Console**. The
   first time, it asks to sign the server in to OpenBot (`openbot login --name
   Unraid`): enter your OpenBot email, then the code that OpenBot sends to it.
   It also offers GitHub, with a one-time code at
   `https://github.com/login/device`. `openbot status` shows the account and
   the server.
4. **Open OpenBot** on your computer, or at openbot.run/app (the container's
   **WebUI** button), signed in with the same email, and pick **Unraid** from the
   server list.
5. **Connect the phone app.** It has no email sign-in: run
   `openbot mobile-connect` in the Console and scan the QR code with the app.
   The code works once and expires after two minutes.
6. **Connect a provider and create an agent.** A new server has none, so the
   app starts with the provider step. Each sign-in finishes on your own device:
   Codex, Grok and Cline show a device code, and Claude shows a page whose code
   you paste back into the app. A provider that is signed in on your laptop is
   not signed in on the server.

## Tailscale

With **Tailscale** at `false`, OpenBot's account and Signal services help your
devices find the server. The connection then goes directly between them when it
can, and otherwise through OpenBot's encrypted relay. On Unraid's default bridge
network the container sees only its internal Docker address, so devices on your
LAN or tailnet often end up on the relay.

Set **Tailscale** to `true` to switch OpenBot to its Private network:

- OpenBot gets no STUN or TURN server, so no chat, file or remote desktop
  traffic goes through an OpenBot relay. Devices connect only to the server's
  addresses on a private network, which here is the container's tailnet address.
- Signing in, and the short Signal messages that set up each connection, still
  go through OpenBot. They carry no chats or files (see "Remote Team API" in
  OpenBot's [privacy notes](https://github.com/nightly-labs/openbot/blob/main/PRIVACY.md)).
- Every device that connects, including teammates' and your phone, needs
  Tailscale and access to the container on your tailnet.

The container needs a tailnet address of its own:

1. Set **Tailscale** to `true` and turn on **Use Tailscale** (Unraid 7 or
   later). The template already sets the hostname to `openbot`, keeps
   Tailscale's state in the Data folder, and turns userspace networking off.
   OpenBot needs it off: in userspace mode the container has no tailnet
   interface for OpenBot to offer.
2. Apply, open the container's log, and approve the container from the
   **To authenticate, visit** link.
3. The log then shows
   `[unraid-openbot] devices connect over your tailnet only (Private network)`.
   If it shows a WARNING instead, the container has no Tailscale address: check
   that Use Tailscale is on and userspace networking is off.

Instead of Use Tailscale, you can set **Network Type** to **Host** on a server
that runs the Tailscale plugin, and OpenBot uses the server's own tailnet
address. OpenBot's Docker guide recommends host networking for devices on the
same network, but it removes the container's network isolation: other programs
on the server can reach OpenBot's local listeners, agents can reach services
that listen only on the server's `127.0.0.1`, and the container does not start
if the server has its own X display on `:0` or `:1`.

Keeping sign-in off OpenBot's servers too needs OpenBot's account service run
by yourself, a separate deployment
([self-hosting.md](https://github.com/nightly-labs/openbot/blob/main/docs/self-hosting.md))
that this template does not cover.

## Local models with Ollama

OpenBot runs a local model through OpenCode, on any OpenAI-compatible server.
It looks for Ollama only at `127.0.0.1:11434`, which inside this container is
the container itself, so add your Ollama server by hand in OpenBot's provider
settings for this server: `http://<Unraid LAN IP>:11434/v1`, or the server's
tailnet address with Tailscale on.

- Pick a model that supports tool calls. Small models and models not trained
  for tools can send tool calls in the wrong format.
- OpenBot's guide asks for at least 64,000 tokens of context, and Ollama's
  default can be 4,000. Raise it in Ollama (`OLLAMA_CONTEXT_LENGTH`, or
  `num_ctx` in a Modelfile) before you start.

Give the agent **backup models**, such as Claude Code, in its settings. OpenBot
moves the agent to the next ready backup when a plan reaches its usage limit,
or when a turn fails with a provider error (unavailable, network, timeout, rate
limit, billing or sign-in) before it wrote text or ran a tool. A weak answer
does not trigger it. Before you sign a Claude subscription in on a server, read
OpenBot's [provider terms](https://github.com/nightly-labs/openbot/blob/main/docs/provider-terms.md#claude).

## Moving from Hermes Agent

Hermes runs in a container of its own, so use OpenBot's ZIP export. Reading the
Hermes folder directly works only for the desktop app on the same computer.

1. In Hermes, install OpenBot's export skill:
   `hermes skills install nightly-labs/openbot/resources/agent-import/hermes-agent`,
   or `/skills install nightly-labs/openbot/resources/agent-import/hermes-agent`
   in a chat.
2. Send `/openbot-export` in a Hermes chat, choose the profiles, and copy the
   ZIP it makes to the computer you use OpenBot on.
3. In OpenBot, with this server selected, open **Server settings › Import ›
   Hermes Agent**, choose **Choose export file** and pick the ZIP.

Each profile becomes an agent with its persona, saved memories, custom skills
and supported scheduled jobs. Chat history, credentials, MCP settings and
messaging connections stay in Hermes. See OpenBot's
[guide](https://openbot.run/guides/import-hermes-agents). OpenBot can also run
Hermes Agent itself as a provider: select **Download** on the Hermes row of this
server's provider settings.

## Settings

| Setting | Variable | What it does |
|---|---|---|
| Tailscale | `TAILSCALE` | `false`: devices connect through OpenBot's network. `true`: OpenBot's Private network, devices connect over your tailnet only. See [Tailscale](#tailscale) |
| Data | `/data` | OpenBot's database, the agents' workspaces, provider sign-ins and the keyring that unlocks them |
| PUID / PGID | `PUID`, `PGID` | Account OpenBot and its agents run as, 99:100 by default like other Unraid apps |

OpenBot reads `OPENBOT_DISPLAY_SIZE` too, the size of the agents' virtual
display (`1280x800` by default); add it with **Add another Path, Port,
Variable, Label or Device** if you need it.

The Console button drops you into OpenBot's account. Use `sh` instead of `bash`
if you need root inside the container.

## Security

OpenBot keeps Chromium's sandbox on, and the sandbox needs user namespaces,
which Docker's default seccomp profile refuses. OpenBot's own Compose file
ships a profile that allows them, but a Community Apps template cannot ship a
file, so this template uses `--security-opt seccomp=unconfined` with
`no-new-privileges`. To use OpenBot's profile instead, save it outside the Data
folder and point Extra Parameters at it:

```sh
curl -fsSL -o /mnt/user/appdata/openbot-seccomp.json \
  https://raw.githubusercontent.com/nightly-labs/openbot/main/docker/seccomp.json
```

Then replace `seccomp=unconfined` with
`seccomp=/mnt/user/appdata/openbot-seccomp.json`.

Agents have full access inside the container and to the Data folder. Map other
shares only when you want agents to work in them.

OpenBot is Electron with Chromium, plus whatever agent CLIs you connect. It
holds new turns while memory is low, and reads the container's limit for that,
so add `--memory=6g` (or what suits your server) to Extra Parameters to cap it.

## Backups

Stop the container and copy the whole Data folder. It holds the keyring and its
password file, which unlock OpenBot's encrypted data, so a copy of the
workspaces alone is not a backup.

## Updating

Unraid shows an update on the Docker tab when a new image is out, which happens
when a pull request bumping OpenBot's version is merged here. **Server settings
› Updates** in the app cannot update this container; update it from the Docker
tab instead.

To stay on one version, change the Repository field to a version tag such as
`originalbyteme/unraid-openbot:0.71.0`. Do not go back to an older version
than you have run: OpenBot migrates its database on upgrade.

Updating or restarting the container stops running agents. OpenBot stops them
and closes its database first, within the 60 seconds the template allows.

## Building it yourself

```sh
docker build -t unraid-openbot openbot
```

Every push that touches OpenBot runs `.github/workflows/openbot-build.yml`,
which builds the image and, with the template's Extra Parameters, checks that
OpenBot starts as 99:100 or PUID and PGID, that the Tailscale setting switches
the route both ways and warns without a tailnet address, and that Unraid's own
Use Tailscale hook starts Tailscale in the container on a tunnel device.

The OpenBot version is pinned in the Dockerfile. Every 6 hours
`.github/workflows/openbot-bump.yml` checks OpenBot's stable releases and, when
there is a newer one with its image published, opens a pull request that bumps
the pin and runs the build against it. Merging that pull request publishes the
image to Docker Hub as `originalbyteme/unraid-openbot`, where Community Apps
reads its Last Update date; closing it skips that version. A manual run of
`openbot-build.yml` with **publish** ticked republishes the pinned version, for
example after a Dockerfile change.

## Credits

OpenBot is made by [Nightly Labs](https://github.com/nightly-labs/openbot) and
licensed under the PolyForm Noncommercial License 1.0.0; the image contains it
under that license, and the template's icon is OpenBot's own, served from openbot.run. This repository is MIT licensed.
