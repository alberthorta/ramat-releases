# Shepherd releases

Shepherd shows the state of your Claude Code sessions, from several machines, in one place:
which session is working, which one waits for you, which one needs a permission. This repo has
the compiled builds. The source code is private.

There are two parts to install:

- **Agent** (`shepherd`): runs on each machine where you use Claude Code. It gets the session
  events from a Claude Code plugin and sends them to your Shepherd server.
- **Viewer** (Shepherd.app): a macOS app that shows the sessions of all your machines, live.

Both need a Shepherd server and an account on it. Ask the person who runs the server for its
address (for example `https://shepherd.example.com`) and for your account.

Requirements: a Mac (Apple silicon or Intel) with Claude Code for the agent, and macOS 15 or
later for the viewer. Linux and Windows are not supported yet.

## Install the agent

Run this in a terminal on each machine with Claude Code:

```sh
curl -fsSL https://raw.githubusercontent.com/alberthorta/shepherd-releases/main/install.sh | sh -s agent
```

It downloads the build for your Mac, checks its SHA-256 against the manifest, copies
`shepherd` to `~/.local/bin` and starts it as a background service (it also starts at login).
`~/.local/bin` must be in your `PATH`, because the Claude Code hooks call `shepherd`.

Then install the Claude Code plugin:

```sh
claude plugin marketplace add alberthorta/shepherd-releases
claude plugin install shepherd@shepherd
```

Then link the machine to your account:

```sh
shepherd login https://shepherd.example.com
```

A browser page opens: log in and press **Authorize**. Check that the page shows the same code
as the terminal.

Sessions you start from now on appear in Shepherd. Sessions that were already open before the
plugin was installed show as "untracked" until you start them again.

To check that it works: `shepherd status` lists the sessions of this machine.

## Install the viewer

```sh
curl -fsSL https://raw.githubusercontent.com/alberthorta/shepherd-releases/main/install.sh | sh -s viewer
```

It installs Shepherd.app in `~/Applications`. Open it, enter the server address and press
**Log In with the Browser**: a browser page opens, log in and authorize the viewer, like for a
machine. The key of the viewer is kept in the Secure Enclave of your Mac.

You can also download `Shepherd_<version>_darwin_arm64.zip` from the latest `viewer` release
and unzip it. A browser download is marked as coming from the internet and the app is not
notarized, so the first time macOS blocks it: right click the app, then **Open**.

## Update

Run the same install command again. It installs the latest version and restarts the service.
Then run `claude plugin marketplace update shepherd` to get the latest plugin.

## Uninstall

```sh
shepherd service uninstall
rm ~/.local/bin/shepherd
claude plugin uninstall shepherd@shepherd
rm -rf ~/Applications/Shepherd.app
```

Your local data stays in `~/.shepherd` (and the viewer's login in
`~/Library/Application Support/Shepherd Viewer`): delete those folders too to remove everything.

## What leaves your machine

What the agent sends to the server depends on the data level of each family of sessions, set in
`~/.shepherd/config.toml` (`full`, `titles` or `metadata`). The file explains each level. The
default is `full`: prompts, tool input and output, and transcripts. Environment variables are
never sent.

## Manifest and signature

`manifest.json` lists the latest version of each component, with the URL and SHA-256 of each
file. `manifest.json.sig` is an ed25519 signature of the exact bytes of `manifest.json`
(base64). The public key is:

```
R6PflNkrrju0+CgHLzFm59q6J2c61zVa+W/3ArpM6pM=
```

Automatic updates (coming later) will only trust a manifest signed with this key.

## License

No license is granted. All rights reserved.
