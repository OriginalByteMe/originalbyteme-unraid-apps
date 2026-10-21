# unraid-orca

An Unraid template and Docker image for [Orca](https://www.onorca.dev), the app
for running coding agents side by side in their own git worktrees. The container
runs `orca serve`, Orca's headless runtime, so the agents, worktrees and
terminals live on your server while the Orca desktop app, the browser client or
the Orca phone app connect to it.

The image is rebuilt whenever Orca publishes a release, because Orca clients and
servers need matching versions to talk to each other.

## Install

Until the template is in Community Apps, copy it onto the flash drive from the
Unraid terminal:

```sh
curl -fsSL -o /boot/config/plugins/dockerMan/templates-user/my-Orca.xml \
  https://raw.githubusercontent.com/OriginalByteMe/unraid-orca/main/templates/orca.xml
```

Then on the Docker tab choose **Add Container** and pick **Orca** from the user
templates.

1. Set **Pairing address** to the address your other devices use to reach the
   server (its LAN or Tailscale IP), or turn on **Use Tailscale** and leave it
   empty (see below).
2. Apply, then open the container's log. Orca prints a **Pairing URL** and a
   **Browser URL**.
3. In the Orca desktop app, go to **Settings → Remote Orca Servers → Add Server**
   and paste the pairing URL. Or open the browser URL directly.
4. Open the container's **Console** and log in to each agent once, for example
   `claude` and then `/login`, or `codex login --device-auth`. Logins are kept in
   the Data folder.

For the phone app, add `--mobile-pairing` under **Extra serve arguments**; the
log then prints a mobile pairing link and QR code instead.

## Settings

| Setting | Variable | What it does |
|---|---|---|
| Orca port | 6768 | Port the clients connect to |
| Data | `/home/orca` | State, pairing keys, agent logins, shell settings and worktrees |
| Projects | `/projects` | Your repositories. Open or clone projects here from Orca; point it at any share |
| Pairing address | `ORCA_PAIRING_ADDRESS` | Address clients dial. Empty means the container's Tailscale IP |
| GitHub token | `GH_TOKEN` | Used by git and `gh` for clones, pushes and pull requests |
| Repositories | `GIT_REPOS` | Space-separated `owner/name` or clone URLs, cloned once into `/projects` and added to Orca |
| Agent CLIs | `NPM_PACKAGES` | npm packages installed once into the Data folder; they update themselves from there. Node and Bun are both installed, so Bun-based CLIs such as omp work |
| Shell | `SHELL` | `bash`, `zsh` or `fish` for Orca's terminals and the console. `tmux` is installed too |
| Oh My Zsh | `OH_MY_ZSH` | `true` installs Oh My Zsh into the Data folder on the next start, keeping an existing `.zshrc` as `.zshrc.pre-oh-my-zsh` |
| Git user name / email | `GIT_USER_NAME`, `GIT_USER_EMAIL` | Identity on the agents' commits |
| Docker socket | `/var/run/docker.sock` | Off unless you fill it in. See below |
| libvirt socket | `/var/run/libvirt/libvirt-sock` | Off unless you fill it in. See below |
| Extra serve arguments | `ORCA_EXTRA_ARGS` | Extra flags for `orca serve` |
| PUID / PGID | `PUID`, `PGID` | Account the agents run as, 99:100 by default like other Unraid apps |

The agents run as that unprivileged account. The Console button drops you into
its shell too; use `sh` instead of `bash` if you need root inside the container.

## Docker and VM access

Fill in the **Docker socket** path to let agents run `docker`, for example to
give each agent its own sandbox container through an Orca
[per-workspace environment](https://www.onorca.dev/docs/ways-to-run) recipe.
Fill in the **libvirt socket** path to let them start and manage VMs with
`virsh`, for recipes that need another operating system.

Either socket gives the agents root-level control of the whole server: anything
that can start a container or define a VM can mount your shares, read every
other app's data, or stop other containers and VMs. Only map them when you trust
every agent and prompt that runs in this container. Containers the agents start
are not limited by this container's memory settings, so give them `--memory`
caps yourself.

## Tailscale

The template is set up for Unraid's **Use Tailscale** switch (Unraid 7 or later):
the hostname defaults to `orca` and Tailscale's state lives in the Data folder.
Turn it on, apply, and approve the container from the link in its log. With the
pairing address left empty, Orca advertises the container's Tailscale IP, so any
device on your tailnet can pair.

## Updating

Unraid shows an update on the Docker tab when a new image is out. Update the
Orca desktop and phone apps at about the same time; a client and server too far
apart report an incompatible protocol version.

Updating or restarting the container ends every running terminal and agent in
it; their history and worktrees stay in the Data folder. Do it between tasks.

## Building it yourself

```sh
docker build --build-arg ORCA_VERSION=1.4.237 -t unraid-orca .
```

Every push runs `.github/workflows/build.yml`, which builds the image and checks
that it refuses to start without a pairing address, honours PUID and PGID, can
use a mapped Docker socket, runs omp on the bundled Bun, serves the web client,
clones and registers a repository in `/projects`, and opens Orca terminals in
zsh with Oh My Zsh loaded. Images are published from a manual run with
**publish** ticked, or by the schedule when Orca has a release this repository
has not built yet.

## Credits

Orca is made by [Stably](https://github.com/stablyai/orca) and is MIT licensed;
the icon is Orca's. The Docker approach borrows from
[ivan-cavero/Orca-Headless](https://github.com/ivan-cavero/Orca-Headless). This
repository is MIT licensed.
