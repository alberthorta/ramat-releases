# Shepherd releases

Compiled builds of Shepherd. Shepherd shows the state of Claude Code sessions from several
machines in one place. The source code is private; this repo only has the builds.

## Components

| Component | What it is | Builds |
|:--|:--|:--|
| `agent` | `shepherd`: runs on each machine with Claude Code (local service, hook CLI, login) | macOS arm64/amd64, Linux amd64/arm64, Windows amd64 |
| `server` | `shepherd-server`: collects the sessions of all machines | Linux amd64/arm64, with a Dockerfile |
| `viewer` | Shepherd.app: macOS viewer | macOS arm64 |

The files are in [Releases](https://github.com/alberthorta/shepherd-releases/releases).
Linux and Windows builds of the agent are not tested yet.

## Claude Code plugin

This repo is also a Claude Code plugin marketplace. The plugin sends session events to the
local `shepherd` service, so the `shepherd` binary must be in the `PATH`.

```sh
claude plugin marketplace add alberthorta/shepherd-releases
claude plugin install shepherd@shepherd
```

## Manifest and signature

`manifest.json` lists the latest version of each component, with the URL and SHA-256 of each
file. `manifest.json.sig` is an ed25519 signature of the exact bytes of `manifest.json`
(base64). The public key is:

```
R6PflNkrrju0+CgHLzFm59q6J2c61zVa+W/3ArpM6pM=
```

Updates only trust a manifest signed with this key.

## License

No license is granted. All rights reserved.
