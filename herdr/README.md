# unraid-herdr

An unofficial Unraid template and Docker image for
[Herdr](https://herdr.dev) ([source](https://github.com/herdrdev/herdr)), the
runtime your coding agents live on. Herdr is a terminal workspace that keeps
Claude Code, Codex, OpenCode and other agents running in a background server,
marks each pane working, blocked or idle, and is customised through
`config.toml` and plugins. The container runs Herdr's headless server on your
Unraid box behind an SSH server, so you attach from any machine and the agents
keep working when you disconnect. This project is not affiliated with Herdr.

## What this image adds to Herdr

- Runs `herdr server` as Unraid's usual 99:100 account, started from `/projects`.
- An SSH server on port 2222 for `herdr --remote` and saved machines, key login
  only, with host keys kept in the Data folder so clients keep trusting it
  across updates.
- Installs agent CLIs by name, for example `claude codex`, into the Data folder
  so they survive updates.
- Clones a list of GitHub repositories into a Projects folder.
- Offers bash, zsh or fish for the panes.
- Works with Unraid's **Use Tailscale** switch.
- Can hand the agents the Docker or libvirt socket, so they can run their own
  containers and VMs.

## Getting started

1. **Install the template.** Until it is in Community Apps, copy it onto the
   flash drive from the Unraid terminal:

   ```sh
   curl -fsSL -o /boot/config/plugins/dockerMan/templates-user/my-Herdr.xml \
     https://raw.githubusercontent.com/OriginalByteMe/originalbyteme-unraid-apps/main/templates/herdr.xml
   ```

   Then on the Docker tab choose **Add Container** and pick **Herdr** from the
   user templates.
2. **Paste your public key** into **Authorized keys**, the contents of
   `~/.ssh/id_ed25519.pub` on the machine you attach from. Several keys go on
   separate lines.
3. **Pick your projects, agents and shell**, then **Apply**.
4. **Attach.** On your own machine, with Herdr installed, add the server to
   `~/.ssh/config`:

   ```
   Host unraid-herdr
     HostName <server>
     Port 2222
     User herdr
   ```

   Then run `herdr --remote unraid-herdr`, or `herdr machine add unraid-herdr`
   to keep it in Herdr's sidebar next to your local work. `ctrl+b q` detaches
   and the agents keep running.
5. **Log in to each agent once** from a Herdr pane, for example `claude` and
   then `/login`, or `codex login --device-auth`. Logins are kept in the Data
   folder.

Herdr's config lives at `~/.config/herdr/config.toml` in the Data folder. After
editing it, run `herdr server reload-config` in a pane.

## Updates

The image is rebuilt for each Herdr release. Updating the container restarts
the server: Herdr restores the saved layout and resumes supported agent
sessions, but the running processes do not survive. Keep your local Herdr on a
version close to the image's.

## Credits

The icon is Herdr's logo from
[herdrdev/herdr](https://github.com/herdrdev/herdr), Apache-2.0.
