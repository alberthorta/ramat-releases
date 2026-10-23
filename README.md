# Shepherd releases

Shepherd shows the state of your Claude Code sessions, from several machines, in one place:
which session is working, which one waits for you, which one needs a permission. This repo has
the compiled builds. The source code is private.

There are two parts to install:

- **Agent** (`shepherd`): runs on each machine where you use Claude Code (macOS or Linux). It
  gets the session events from a Claude Code plugin and sends them to your Shepherd server.
- **Viewer** (Shepherd.app): a macOS app that shows the sessions of all your machines, live.

Both need a Shepherd server and an account on it. Ask the person who runs the server for its
address (for example `https://shepherd.example.com`) and for your account.

Requirements: Claude Code on a Mac (Apple silicon or Intel) or on Linux (x86-64 or ARM64, with
systemd) for the agent, and macOS 15 or later for the viewer. Windows is not supported yet.

## Install the agent

Run this in a terminal on each machine with Claude Code:

```sh
curl -fsSL https://raw.githubusercontent.com/alberthorta/shepherd-releases/main/install.sh | sh -s agent
```

It downloads the build for your machine, checks its SHA-256 against the manifest, copies
`shepherd` to `~/.local/bin` and starts it as a background service: a launchd agent on macOS
(it also starts at login), a systemd user service on Linux (`systemctl --user status shepherd`).
`~/.local/bin` must be in your `PATH`, because the Claude Code hooks call `shepherd`.

On a Linux server, turn on linger so the service keeps running when you log out:
`loginctl enable-linger`. The install script tells you when it is off.

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
as the terminal. On a machine with no browser (a server over SSH), use
`shepherd login --no-browser https://shepherd.example.com`: it prints the address and the code,
and you approve it from the browser of any other computer.

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

## Configuration

The agent reads `~/.shepherd/config.toml`. It is created with comments the first time the
service starts. Changes apply a few seconds after you save the file, with no restart. While the
service runs, a file with an error is ignored and the last good configuration stays; the reason
is in `~/.shepherd/daemon.log`. With an error at start, the service does not start, so a typo can
never send more than you chose.

```toml
# Family of the sessions that match no folder rule.
default_family = "personal"

# Data level of that family: full, titles, metadata or none.
default_data = "full"

# A session that waits for you longer than this shows as idle.
idle_after = "15m"

# Local queue while the server cannot be reached.
queue_max_days = 7
queue_max_mb = 200

# One block per folder rule.
[[family]]
folder = "~/work"
family = "work"
data = "metadata"
```

| Option | Default | What it does |
|:--|:--|:--|
| `default_family` | `default` | Family of the sessions started outside every `[[family]]` folder. |
| `default_data` | `full` | Data level of the default family. |
| `idle_after` | `15m` | A session waiting for you longer than this shows as **idle** instead of **waiting for you**: same meaning (your turn), it only goes lower in the list. A duration of at least `1m`, like `45m` or `2h`. |
| `queue_max_days` | `7` | Events wait in a local queue while the server is not reachable. Older events are dropped. |
| `queue_max_mb` | `200` | Size limit of that queue. When it is bigger, the oldest events are dropped. |
| `[[family]]` `folder` | | Sessions started in this folder or below it belong to the family. `~` is your home folder. The most specific folder wins. |
| `[[family]]` `family` | | Name of the family: a label to group and filter sessions in the viewer. |
| `[[family]]` `data` | `full` | Data level of the family. When several rules of one family set it, the stricter level wins. |

A session keeps the family it had when it started, even if you change the rules later. A new
data level applies at once, also to events that were not sent yet.

Built-in rule: sessions in `~/.claude-mem` (helper sessions of the claude-mem plugin) belong to
the family `claude-mem` with data level `none`, so nothing of them leaves your machine. A rule
for the same folder in the file replaces it, data level included.

### Data levels: what leaves your machine

| Level | What is sent to the server |
|:--|:--|
| `full` | Everything below, plus prompts, tool input and output, Claude's answers and the transcript of the conversation (long texts are cut at 64 KB). |
| `titles` | Everything below, plus the session name and the task of each subagent. |
| `metadata` | Session state, tool names, times, folder, model and token counts. |
| `none` | Nothing. The sessions stay on your machine: `shepherd status` still shows them. |

Environment variables are never sent, at any level: only a few that Claude Code sets itself
(its version, the process id, CLI or desktop app).

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
