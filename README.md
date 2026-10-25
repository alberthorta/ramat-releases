# Ramat releases

Ramat shows the state of your Claude Code sessions, from several machines, in one place:
which session is working, which one waits for you, which one needs a permission. This repo has
the compiled builds. The source code is private.

There are two parts to install:

- **Agent** (`ramat`): runs on each machine where you use Claude Code (macOS, Linux, and
  Windows as an experiment). It
  gets the session events from a Claude Code plugin and sends them to the Ramat server.
- **Viewer** (Ramat.app): a macOS app that shows the sessions of all your machines, live.

Both need an account on the Ramat server, `https://ramat.app`. Accounts are by invitation
only: you get an invite link, open it and create your account.

Requirements: Claude Code on a Mac (Apple silicon or Intel) or on Linux (x86-64 or ARM64, with
systemd) for the agent, and macOS 15 or later for the viewer. Windows 10 or later works only as
an experiment: see [Windows (experimental)](#windows-experimental).

## Install the agent

Run this in a terminal on each machine with Claude Code:

```sh
curl -fsSL https://raw.githubusercontent.com/alberthorta/ramat-releases/main/install.sh | sh -s agent
```

It downloads the build for your machine, checks its SHA-256 against the manifest, copies
`ramat` to `~/.local/bin` and starts it as a background service: a launchd agent on macOS
(it also starts at login), a systemd user service on Linux (`systemctl --user status ramat`).
`~/.local/bin` must be in your `PATH`, because the Claude Code hooks call `ramat`.

On a Linux server, turn on linger so the service keeps running when you log out:
`loginctl enable-linger`. The install script tells you when it is off.

Then install the Claude Code plugin:

```sh
claude plugin marketplace add alberthorta/ramat-releases
claude plugin install ramat@ramat
```

Then link the machine to your account:

```sh
ramat login
```

A browser page opens: log in and press **Authorize**. Check that the page shows the same code
as the terminal. On a machine with no browser (a server over SSH), use
`ramat login --no-browser`: it prints the address and the code,
and you approve it from the browser of any other computer.

Sessions you start from now on appear in Ramat. Sessions that were already open before the
plugin was installed show as "untracked" until you start them again.

To check that it works: `ramat status` lists the sessions of this machine.

## Windows (experimental)

The Windows agent has run only in automated tests so far, never on a real machine with Claude
Code. Expect problems. To try it, run this in PowerShell (as yourself, not as administrator):

```powershell
irm https://raw.githubusercontent.com/alberthorta/ramat-releases/main/install.ps1 | iex
```

It checks the SHA-256 of the download, copies `ramat.exe` to `%USERPROFILE%\.local\bin` (the
folder where Claude Code installs itself), adds that folder to your `PATH` if needed, and starts
the agent as a scheduled task of your user ("Ramat agent"): at login, and again within a minute
if it stops. Then install the plugin and log in as on the other systems.

Not there yet on Windows: the project folder of "untracked" sessions, and closing a session
from the viewer ends the process at once, with no clean exit. Claude Code installed with npm is
not detected as a running session; the native installer is.

## Install the viewer

Download it from [ramat.app/download/mac](https://ramat.app/download/mac) (the
`Ramat_<version>_darwin_arm64.dmg` of the latest `viewer` release), open the disk image and
drag Ramat to Applications. A Mac with Apple silicon and macOS 15 or later.

A browser download is marked as coming from the internet and the app is not notarized, so the
first time macOS stops it: open System Settings › Privacy & Security and choose
**Open Anyway**. After that it updates itself.

Or from the terminal, with no Gatekeeper step (curl downloads are not marked):

```sh
curl -fsSL https://raw.githubusercontent.com/alberthorta/ramat-releases/main/install.sh | sh -s viewer
```

Both put Ramat.app in `/Applications`. Open it and press
**Log In with the Browser**: a browser page opens, log in and authorize the viewer, like for a
machine. The key of the viewer is kept in the Secure Enclave of your Mac.

### Answer from the viewer

When a session asks for a permission or asks you a question, the viewer shows it at the top of
the session's details, with **Allow** / **Deny** or the question's options. The terminal shows
the same prompt at the same time: the first answer wins. It works for families at the `full`
data level (or encrypted, with your key unlocked in the viewer), with agent 0.15.0 or later,
in sessions started after the agent's plugin updated.

### Send messages from the viewer

The viewer can send a message to a session, as if you typed it in its terminal. Claude Code
only takes messages from other apps through a *channel*, still a research preview, so start the
session with Ramat's channel and accept the warning Claude Code shows:

```sh
claude --dangerously-load-development-channels plugin:ramat@ramat
```

An alias makes it the default: `alias claude='claude --dangerously-load-development-channels plugin:ramat@ramat'`.
Such sessions show a message box in the viewer. It needs agent 0.16.0 or later.

## Updates

Both parts update by themselves. The Ramat server checks this repo every 15 minutes and tells
the connected agents and viewers when there is a new version; they also check when they start.
Before installing anything, they download `manifest.json`, check its signature with the key
below and check the SHA-256 of the file. They never install an older version.

- **Agent**: installs the new version, updates the Claude Code plugin and restarts the service.
  The previous binary stays as `~/.local/bin/ramat.old` (`ramat.exe.old` on Windows). To only be told (a line in
  `~/.ramat/daemon.log`), set `auto_update = false` in `config.toml`. `ramat update`
  installs the latest version now; `ramat update --check` only says whether there is one.
- **Viewer**: when it starts, it installs a new version before you use it and opens again. When a
  new version comes out while it is open, an **Update to …** button appears in the toolbar. The
  Farms view shows the agent version of each machine and marks the ones that are behind.

Older agents (before 0.10.0) do not update by themselves: run the install command once more.

## Uninstall

```sh
ramat service uninstall
rm ~/.local/bin/ramat
claude plugin uninstall ramat@ramat
rm -rf /Applications/Ramat.app
```

On Windows, in PowerShell: `ramat service uninstall`, then delete
`%USERPROFILE%\.local\bin\ramat.exe` and uninstall the plugin the same way.

Your local data stays in `~/.ramat` (and the viewer's login in
`~/Library/Application Support/Ramat Viewer`): delete those folders too to remove everything.

## Configuration

The agent reads `~/.ramat/config.toml`. It is created with comments the first time the
service starts. Changes apply a few seconds after you save the file, with no restart. While the
service runs, a file with an error is ignored and the last good configuration stays; the reason
is in `~/.ramat/daemon.log`. With an error at start, the service does not start, so a typo can
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

# The animal of each family on the farm (not drawn by the viewer yet).
default_species = "sheep"
[species]
work = "cow"
```

| Option | Default | What it does |
|:--|:--|:--|
| `default_family` | `default` | Family of the sessions started outside every `[[family]]` folder. |
| `default_data` | `full` | Data level of the default family. |
| `auto_update` | `true` | Install new versions of the agent by itself. `false`: only write in the log that one is available. |
| `idle_after` | `15m` | A session waiting for you longer than this shows as **idle** instead of **waiting for you**: same meaning (your turn), it only goes lower in the list. A duration of at least `1m`, like `45m` or `2h`. |
| `queue_max_days` | `7` | Events wait in a local queue while the server is not reachable. Older events are dropped. |
| `queue_max_mb` | `200` | Size limit of that queue. When it is bigger, the oldest events are dropped. |
| `[[family]]` `folder` | | Sessions started in this folder or below it belong to the family. `~` is your home folder. The most specific folder wins. |
| `[[family]]` `family` | | Name of the family: a label to group and filter sessions in the viewer. |
| `[[family]]` `data` | `full` | Data level of the family. When several rules of one family set it, the stricter level wins. |
| `[[family]]` `encrypt` | `false` | Encrypt the family's content end to end: transcript and hook payloads (prompts, tool input and output, answers). Only your viewer can read it; the server cannot search it. |
| `[[family]]` `encrypt_titles` | `false` | Encrypt the session names and the subagent tasks too. Without it they stay readable on the server. |
| `default_encrypt`, `default_encrypt_titles` | `false` | The same, for the default family. |
| `[[family]]` `control` | `true` | Let your viewer act on these sessions: close one, allow or deny a permission, answer a question. Commands are signed with your key; the server cannot make them. |
| `default_control` | `true` | The same, for the default family. |
| `default_species` | `sheep` | The animal of the families with none in `[species]`. A lowercase word. |
| `[species]` | | One line per family, `family = "animal"`, like `work = "cow"`. Sent with each session. The viewer and the web draw sheep, cow, horse, pig, chicken, goat, turkey and rabbit; any other word is a sheep. |

A family groups sessions by folder: personal, work, a client. Agents 0.14 to 0.17 also took
the word **field** (`default_field`, `[[field]]`, `field = "..."`); since 0.18.0 the agent
refuses it and says what to rename, so check your file if you used it.

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
| `none` | Nothing. The sessions stay on your machine: `ramat status` still shows them. |

Environment variables are never sent, at any level: only a few that Claude Code sets itself
(its version, the process id, CLI or desktop app).

### End-to-end encryption

A family with `encrypt = true` sends its content sealed with your key: only your viewer can
read it, the server stores it but cannot read or search it. State, tools, times, model and
token counts are never encrypted, so the session list works the same.

1. In the viewer, open **Encryption** in the toolbar and create your key with a passphrase.
   Save the **recovery key** it shows in your password manager: without the passphrase and the
   recovery key, encrypted data cannot be read by anyone.
2. Each agent pins your key the next time it connects. Check that `ramat key` shows the same
   fingerprint as the viewer.
3. Turn on `encrypt` (and, if you want, `encrypt_titles`) for the families you choose.

Until an agent has your key, an encrypted family sends no content at all, and that content is
not sent later: create the key before turning `encrypt` on. On another Mac, the viewer unlocks
the key with your passphrase (or the recovery key).

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
