# Ramat releases

Ramat shows the state of your Claude Code sessions, from several machines, in one place:
which session is working, which one waits for you, which one needs a permission. This repo has
the compiled builds. The source code is private.

Ramat has three parts:

- **Agent** (`ramat`): runs on each machine where you use Claude Code (macOS, Linux, and
  Windows as an experiment). It gets the session events from a Claude Code plugin and sends
  them to the Ramat server.
- **Viewer** (Ramat.app): a macOS app, and an experimental Windows one, that shows the sessions
  of all your machines, live. It is also where you read encrypted content and act on sessions.
- **Server and web** (`https://ramat.app`): run for you. On the web you manage your account,
  your machines and the animals of your families. The web does not show sessions.

You need an account on `https://ramat.app`. Accounts are by invitation only: you get an invite
link, open it and create your account.

## Requirements

| Part | Needs |
|:--|:--|
| Agent | Claude Code on a Mac (Apple silicon or Intel), on Linux (x86-64 or ARM64, with systemd), or on Windows 10 or later ([experimental](#windows-experimental)). |
| Viewer | A Mac with Apple silicon and macOS 15 or later, or Windows 10 or later ([experimental](#windows-viewer-experimental)). |

## Getting started

Do these steps in this order. Encryption is on by default, and an agent with no key sends no
content, so create your key before you install the agents.

1. Create your account with the invite link.
2. [Install the viewer](#install-the-viewer) and log in.
3. In the viewer, open **Encryption** in the toolbar and create your key (see
   [End-to-end encryption](#end-to-end-encryption)). Save the recovery key in your password
   manager.
4. [Install the agent](#install-the-agent) on each machine with Claude Code, install the plugin
   and run `ramat login`.
5. On each machine, check that `ramat key` shows the same fingerprint as the viewer.

## Install the viewer

Download it from [ramat.app/download/mac](https://ramat.app/download/mac) (the
`Ramat_<version>_darwin_arm64.dmg` of the latest `viewer` release), open the disk image and
drag Ramat to Applications.

A browser download is marked as coming from the internet and the app is not notarized, so the
first time macOS stops it: open System Settings › Privacy & Security and choose
**Open Anyway**. After that it updates itself.

Or from the terminal, with no Gatekeeper step (curl downloads are not marked):

```sh
curl -fsSL https://raw.githubusercontent.com/alberthorta/ramat-releases/main/install.sh | sh -s viewer
```

Both put Ramat.app in `/Applications`. Open it and press **Log In with the Browser**: a browser
page opens, log in and authorize the viewer, like for a machine. The login key of the viewer is
kept in the Secure Enclave of your Mac.

### Windows viewer (experimental)

The Windows viewer has run only in automated tests so far, never on a real machine. It needs
Windows 10 or 11 with the WebView2 runtime (part of Windows 11 and of an updated Windows 10).
To try it, run this in PowerShell (as yourself, not as administrator):

```powershell
iex "& { $(irm https://raw.githubusercontent.com/alberthorta/ramat-releases/main/install.ps1) } viewer"
```

It checks the SHA-256 of the download, copies `Ramat.exe` to `%LOCALAPPDATA%\Programs\Ramat`,
adds Ramat to the Start menu and opens it. Log in with the browser as on a Mac. The login key
and the unlocked encryption key are kept in files protected by Windows for your user account
(DPAPI): they do not work on another computer or account, but they are not in a hardware chip
like on a Mac. It updates itself.

## Install the agent

Run this in a terminal on each machine with Claude Code:

```sh
curl -fsSL https://raw.githubusercontent.com/alberthorta/ramat-releases/main/install.sh | sh -s agent
```

It downloads the build for your machine, checks its SHA-256 against the manifest, copies
`ramat` to `~/.local/bin` and starts it as a background service: a launchd agent on macOS
(it also starts at login), a systemd user service on Linux (`systemctl --user status ramat`).
`~/.local/bin` must be in your `PATH`, because the Claude Code hooks call `ramat`: if it is
not, the installer adds it to your shell's start file (`~/.zshrc`, `~/.bash_profile` on macOS,
`~/.bashrc` on Linux, fish's `conf.d`, or `~/.profile`). Open a new terminal to use `ramat`.

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
`ramat login --no-browser`: it prints the address and the code, and you approve it from the
browser of any other computer.

Sessions you start from now on appear in Ramat. Sessions that were already open before the
plugin was installed show as "untracked" until you start them again.

To check that it works: `ramat status` lists the sessions of this machine.

### Windows (experimental)

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

### Agent commands

| Command | What it does |
|:--|:--|
| `ramat login [--no-browser]` | Link this machine to your account. |
| `ramat status [-a]` | Show the sessions of this machine. |
| `ramat key [--reset]` | Show the keys this machine pinned for encryption and for commands. `--reset` forgets them, so the agent takes the next key the server sends. |
| `ramat update [--check]` | Install the latest version now, or only say whether there is one. |
| `ramat service install` / `uninstall` | Start or remove the background service. |
| `ramat version` | Print the version. |

The service writes its log to `~/.ramat/daemon.log`.

## Using the viewer

- **Overview**: a summary of your sessions, one card per machine.
- **Herd**: every open session, grouped by what it needs from you (waiting for you, working,
  asleep). Click a session to see its details and its transcript on the right.
- **History**: sessions that ended.
- **Farms**: your machines, with their agent version (machines that are behind are marked).
  You can rename a machine or revoke it. Under it, **Animals**: the animal of each family.

You can also act on sessions from the viewer. This needs your key unlocked in the viewer, and
the family must allow it (`control`, on by default, see [Configuration](#configuration)).
Commands are signed with your key: the server cannot make them.

- **Answer prompts**: when a session asks for a permission or asks you a question, its details
  show **Allow** / **Deny** or the question's options. The terminal shows the same prompt at the
  same time: the first answer wins. It needs the `full` data level and agent 0.15.0 or later,
  in sessions started after the plugin updated.
- **Close a session** (**Close…** in its details): ends the Claude Code process on its machine.
- **Send a message**: types a message into the session, as if you typed it in its terminal.
  Claude Code only takes messages from other apps through a *channel*, still a research
  preview, so start the session with Ramat's channel and accept the warning Claude Code shows:

  ```sh
  claude --dangerously-load-development-channels plugin:ramat@ramat
  ```

  An alias makes it the default:
  `alias claude='claude --dangerously-load-development-channels plugin:ramat@ramat'`. Such
  sessions show a message box in the viewer. It needs agent 0.16.0 or later.

## Configuration

The agent reads `~/.ramat/config.toml`. It is created with comments the first time the
service starts. Changes apply a few seconds after you save the file, with no restart. While the
service runs, a file with an error is ignored and the last good configuration stays; the reason
is in `~/.ramat/daemon.log`. With an error at start, the service does not start, so a typo can
never send more than you chose.

A **family** groups sessions by folder: personal, work, a client. Each `[[family]]` block is a
folder rule. Sessions started in that folder or below it belong to its family; the most
specific folder wins. Sessions that match no rule belong to `default_family`.

Each family has four options: `data`, `encrypt`, `encrypt_titles` and `control`. A rule can set
them. When the rules of a family leave an option out, it comes from the matching `default_*`
option (`default_data`, `default_encrypt`, ...). This is true for every family, the default
family included. When several rules of one family set the same option, the safer value wins:
the stricter data level, encryption on, control off. So a second folder added later cannot open
up the first by mistake.

`default_family` is not one of these: it is only the name of the family for sessions that match
no rule.

```toml
# Family of the sessions that match no folder rule.
default_family = "personal"

# For every family that does not set its own (these are the defaults).
default_data = "full"
default_encrypt = true
default_encrypt_titles = true
default_control = true

# A session that waits for you longer than this shows as idle.
idle_after = "15m"

# One block per folder rule.
[[family]]
folder = "~/work"
family = "work"
data = "metadata"
control = false

[[family]]
folder = "~/notes"
family = "notes"
encrypt = false          # sent in clear, so the server can search it
encrypt_titles = false
```

### Options

| Option | Default | What it does |
|:--|:--|:--|
| `default_family` | `default` | Family of the sessions started outside every `[[family]]` folder. |
| `default_data` | `full` | Data level of every family whose rules do not set `data`. |
| `default_encrypt` | `true` | Encryption of the content of every family whose rules do not set `encrypt`. |
| `default_encrypt_titles` | `true` | Encryption of the names of every family whose rules do not set `encrypt_titles`. |
| `default_control` | `true` | Viewer commands for every family whose rules do not set `control`. |
| `auto_update` | `true` | Install new versions of the agent by itself. `false`: only write in the log that one is available. |
| `idle_after` | `15m` | A session waiting for you longer than this shows as **idle** instead of **waiting for you**: same meaning (your turn), it only goes lower in the list. A duration of at least `1m`, like `45m` or `2h`. |
| `queue_max_days` | `7` | Events wait in a local queue while the server is not reachable. Older events are dropped. |
| `queue_max_mb` | `200` | Size limit of that queue. When it is bigger, the oldest events are dropped. |
| `[[family]]` `folder` | | Sessions started in this folder or below it belong to the family. `~` is your home folder. |
| `[[family]]` `family` | | Name of the family: a label to group and filter sessions in the viewer. |
| `[[family]]` `data` | `default_data` | Data level of the family (see below). |
| `[[family]]` `encrypt` | `default_encrypt` | Encrypt the family's content end to end: transcript and hook payloads (prompts, tool input and output, answers). Only your viewer can read it; the server cannot search it. |
| `[[family]]` `encrypt_titles` | `default_encrypt_titles` | Encrypt the session names and the subagent tasks. When off, they stay readable on the server. |
| `[[family]]` `control` | `default_control` | Let your viewer act on these sessions: answer a prompt, close a session, send a message. |

A session keeps the family it had when it started, even if you change the rules later. A new
data level applies at once, also to events that were not sent yet.

Built-in rule: sessions in `~/.claude-mem` (helper sessions of the claude-mem plugin) belong to
the family `claude-mem` with data level `none`, so nothing of them leaves your machine. A rule
for the same folder in the file replaces it, data level included.

Each family is drawn as an animal (sheep, cow, horse, pig, chicken, goat, turkey or rabbit):
pick it on the **Animals** page of the viewer or of the web, not in this file.

### Old configuration files

- **Before agent 0.20.0**, the `default_*` options only applied to the default family, and
  encryption was off unless you turned it on. Now they apply to every family and encryption is
  on. If a family must stay in clear, add `encrypt = false` to its rule.
- Agents 0.18 took `default_species` and `[species]`. They do nothing now: the agent writes a
  line in the log, and you can delete them.
- Agents 0.14 to 0.17 took the word **field** (`default_field`, `[[field]]`, `field = "..."`).
  Since 0.18.0 the agent refuses it and says what to rename.

### Data levels: what leaves your machine

| Level | What is sent to the server |
|:--|:--|
| `full` | Everything below, plus prompts, tool input and output, Claude's answers and the transcript of the conversation (long texts are cut at 64 KB). |
| `titles` | Everything below, plus the session name and the task of each subagent. |
| `metadata` | Session state, tool names, times, folder, model and token counts. |
| `none` | Nothing. The sessions stay on your machine: `ramat status` still shows them. |

Environment variables are never sent, at any level: only a few that Claude Code sets itself
(its version, the process id, CLI or desktop app).

## End-to-end encryption

Encryption is on by default for every family. An encrypted family sends its content sealed
with your key: only your viewer can read it. The server stores it but cannot read or search it.
With `encrypt_titles` (also on by default), the session names and the subagent tasks are sealed
too. State, tools, times, model and token counts are never encrypted, so the session list works
the same.

Encryption does not send more than the data level allows: a family at `metadata` sends no
content, encrypted or not.

How to set it up:

1. In the viewer, open **Encryption** in the toolbar and create your key with a passphrase.
   Save the **recovery key** it shows in your password manager. Without the passphrase and the
   recovery key, nobody can read the encrypted data, not even you.
2. Each agent pins your key the next time it connects. Check that `ramat key` shows the same
   fingerprint as the viewer.
3. On another Mac, the viewer unlocks the key with your passphrase (or the recovery key). The
   server keeps a copy of your key that only your passphrase opens.

Things to know:

- **Until an agent has your key, an encrypted family sends no content and no names**, and that
  content is not sent later. So create the key before you install the agents.
- **If the server ever sends a different key**, the agent does not use it: encrypted families
  send no content and commands from the viewer are refused, until you run `ramat key --reset`.
  Only do that if you made a new key on purpose.
- **Turning encryption on does not encrypt what was sent before.** Older content stays in clear
  on the server.
- The same key signs the commands of the viewer (answers, close, messages), so they also need
  the key unlocked in the viewer.

## Updates

Both the agent and the viewer update by themselves. The Ramat server checks this repo every
15 minutes and tells the connected agents and viewers when there is a new version; they also
check when they start. Before installing anything, they download `manifest.json`, check its
signature with the key below and check the SHA-256 of the file. They never install an older
version.

- **Agent**: installs the new version, updates the Claude Code plugin and restarts the service.
  The previous binary stays as `~/.local/bin/ramat.old` (`ramat.exe.old` on Windows). To only be
  told (a line in `~/.ramat/daemon.log`), set `auto_update = false` in `config.toml`.
  `ramat update` installs the latest version now; `ramat update --check` only says whether
  there is one.
- **Viewer**: when it starts, it installs a new version before you use it and opens again. When a
  new version comes out while it is open, an **Update to …** button appears in the toolbar.

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
To remove a machine from your account, revoke it in the viewer (Farms) or on the web.

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
