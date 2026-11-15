# originalbyteme-unraid-apps

Unofficial Unraid templates and Docker images I maintain for running
coding-agent apps on an Unraid server. Each app has its own folder with its
image, icon and setup guide, and all the Community Apps templates sit together
in `templates/`.

| App | What it runs | Image | Setup guide |
| --- | --- | --- | --- |
| Orca | `orca serve`, the headless runtime of [Orca](https://www.onorca.dev), which runs coding agents side by side in their own git worktrees | `ghcr.io/originalbyteme/unraid-orca` | [orca/README.md](orca/README.md) |
| OpenBot | The official server image of [OpenBot](https://openbot.run), a workspace where a team of AI agents (Claude Code, Codex, OpenCode, Pi, Hermes Agent or your own Ollama model) works on your server, reached from its desktop, web and phone apps | `originalbyteme/unraid-openbot` | [openbot/README.md](openbot/README.md) |
| T3 Code | `t3 serve`, the headless server of [T3 Code](https://t3.codes), a control surface for Claude Code, Codex, Cursor, OpenCode and Pi | `originalbyteme/unraid-t3code` | [t3code/README.md](t3code/README.md) |

## Layout

```
ca_profile.xml           the maintainer profile Community Apps shows
templates/<app>.xml      one Community Apps template per app
<app>/                   the app's Dockerfile, entrypoint, icon and README
.github/workflows/       <app>-build.yml tests and publishes each image,
                         <app>-bump.yml opens a pull request per upstream release
```

## Support

This repository is not affiliated with Stably (Orca), T3 Tools (T3 Code) or
Nightly Labs (OpenBot). Report problems with a container in this repository's
[issues](https://github.com/OriginalByteMe/originalbyteme-unraid-apps/issues),
and problems with the apps themselves at
[stablyai/orca](https://github.com/stablyai/orca),
[pingdotgg/t3code](https://github.com/pingdotgg/t3code) or
[nightly-labs/openbot](https://github.com/nightly-labs/openbot).

This repository is MIT licensed. Each app's README credits the upstream icon and
screenshots it uses.
