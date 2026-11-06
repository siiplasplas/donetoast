<div align="center">

# donetoast

**Steam-style notification cards for Windows.**<br>
Know when a long job or a Claude Code / Codex task finishes, watch it live, and get pinged when the agent needs you.

[![Windows 10/11](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?logo=windows&logoColor=white)](#install)
[![PowerShell 5.1](https://img.shields.io/badge/PowerShell-5.1-5391FE?logo=powershell&logoColor=white)](#install)
[![Claude Code hooks](https://img.shields.io/badge/Claude%20Code-hooks-D97757)](#using-it-with-claude-code-or-codex)
[![Release](https://img.shields.io/github/v/release/siiplasplas/donetoast?color=2ea043)](https://github.com/siiplasplas/donetoast/releases)
[![MIT](https://img.shields.io/github/license/siiplasplas/donetoast?color=8b949e)](LICENSE)

<img src="docs/demo.gif" width="760" alt="A 'needs you' card appears, clears when you answer, then a progress card fills up and turns into a done card">

</div>

```powershell
irm https://raw.githubusercontent.com/siiplasplas/donetoast/main/install.ps1 | iex
```

One line in PowerShell sets up the Claude Code hooks and shows a test card. Nothing else to install. [More about the installer](#install).

## Why

- **Works even when Windows notifications are off.** It draws its own window and does not depend on Focus Assist or the Action Center.
- **Looks right.** The size (283×70), radial background, colours, 44 px avatar and the 300 ms `cubic-bezier(0, .73, .48, 1)` slide-in were all measured from Steam's own client stylesheet.
- **Stacks with no gaps.** Several cards sit directly on top of each other, flush against the taskbar and the right edge of the screen.
- **No console flash.** Jobs are started with `ShowWindow = 0`, so no blue or black PowerShell window blinks on screen.
- **Easy on the PC.** About 1 s of CPU when a card opens, then essentially zero. An open card uses about 10 MB of RAM (working set), a live progress card about 11 MB, and nothing once you click it away. Memory is trimmed right after the slide-in, and a live card trims again every 30 s.
- **A soft sound instead of the Windows ding.** The chimes are synthesized locally and kept quiet, at about −12 dBFS, with no harsh overtones.
- **Nothing to install.** It uses the PowerShell 5.1 and WPF that ship with Windows 10 and 11.

| Done | Failed |
|---|---|
| ![Done card](docs/card-done.png) | ![Failed card](docs/card-failed.png) |
| **Running** (live progress) | **Needs you** |
| ![Progress card](docs/card-progress.png) | ![Needs-you card](docs/card-waiting.png) |

## Install

Run this in PowerShell, then restart Claude Code:

```powershell
irm https://raw.githubusercontent.com/siiplasplas/donetoast/main/install.ps1 | iex
```

`install.ps1` does the following:
- Downloads donetoast to `$HOME\donetoast`.
- Adds the [Claude Code hooks](#using-it-with-claude-code-or-codex) to `~/.claude/settings.json`. Your own hooks stay as they are, and a backup is saved next to the file.
- Adds one line to `~/.claude/CLAUDE.md`, and to `~/.codex/AGENTS.md` if you use Codex, so the agent notifies you when a long task ends.
- Shows a test card.

Running it again is safe. `install.ps1 -Uninstall` removes the hooks and the lines again.

**Let your agent do it.** You can also paste this to Claude Code or Codex:

> Install https://github.com/siiplasplas/donetoast for me: clone it to `$HOME\donetoast` and run its `install.ps1` (outside the sandbox).

**By hand.** Clone the repository anywhere and add the hooks yourself (see below). The scripts find their files relative to themselves.

```powershell
git clone https://github.com/siiplasplas/donetoast "$HOME\donetoast"
```

## Usage

Show a notification right away:

```powershell
& "$HOME\donetoast\donetoast.ps1" -Title 'Render finished' -Message '120 frames ready'
```

Show a red "failed" card:

```powershell
& "$HOME\donetoast\donetoast.ps1" -Title 'Build failed' -Message 'Exit code 1' -Failed
```

Run a long job in the background and get notified when it ends. The job keeps running even if the window that started it is closed:

```powershell
& "$HOME\donetoast\donetoast.ps1" -Title 'Backup' -Command 'robocopy D:\Photos E:\Backup /MIR'
```

When the job ends, a card reports how long it took and the free space on C:. If it fails, a red card shows the exit code and the path to the log. Each job's output goes to `jobs\<timestamp>.log`.

### Live progress

Give a job a name with `-Id` and call again with each new percentage. The first call opens a blue "running" card. Later calls only update a small state file, so they are instant and start no new process. The card works out the time left from how fast the percentage moves.

```powershell
$dt = "$HOME\donetoast\donetoast.ps1"
& $dt -Id upload -Title 'Uploading photos' -Percent 0
& $dt -Id upload -Percent 42 -Message '1.3 of 3 GB'   # -> "42% · 8 min left · 1.3 of 3 GB"
& $dt -Id upload -Done -Title 'Upload finished'       # or -Failed; the same card turns green or red
```

Without `-Percent`, the card shows the time elapsed instead. Clicking a running card hides it, and you still get a card when the job ends.

With `-Command`, add `-Progress` to get a running card from the start that turns into the result card at the end. The job can move the bar itself:

```powershell
& $dt -Title 'Convert videos' -Progress -Command @'
$files = Get-ChildItem D:\Videos\*.mov; $i = 0
foreach ($f in $files) {
  ffmpeg -i $f.FullName ($f.FullName -replace '\.mov$', '.mp4')
  $i++; & $env:DONETOAST -Id $env:DONETOAST_ID -Percent (100 * $i / $files.Count) -Message $f.Name
}
'@
```

### "Needs you" cards

`-Waiting` shows an amber card with a light double-tap sound, for when something is waiting on you:

```powershell
& "$HOME\donetoast\donetoast.ps1" -Title 'Permission needed' -Message 'my-game · Bash' -Waiting
```

| Parameter | What it does |
|---|---|
| `-Title` | Card title (with `-Command`, the job's name) |
| `-Message` | Second line |
| `-Command` | PowerShell command to run in the background; without it the card shows right away |
| `-Failed` | Red "failed" card and the lower chime |
| `-Waiting` | Amber "needs you" card |
| `-Id` | Name of a live card; later calls with the same name update it |
| `-Percent` | With `-Id`: progress from 0 to 100 |
| `-Done` | With `-Id`: turn the live card into a green "done" card |
| `-Progress` | With `-Command`: show a live card while the job runs |
| `-App` | Source name in the header, for example `Claude` or `Codex`; `icons\<name>.png` is used as the avatar |

Click a card to dismiss it. To make cards close on their own, call `toast.ps1` directly with `-Seconds 20`.

### Using it with Claude Code or Codex

**Know when Claude is waiting for you.** Add these hooks to `~/.claude/settings.json`, merged into any `hooks` you already have. A "needs you" card appears when Claude asks for permission or has been waiting for your reply. You don't have to dismiss it: the `clear` hooks remove it when you send your next message or when Claude's turn ends. When no card is open, `claude-clear.cmd` returns in about 0.1 s, so it adds no noticeable delay.

```json
{
  "hooks": {
    "Notification": [
      { "matcher": "permission_prompt|idle_prompt|elicitation_dialog",
        "hooks": [{ "type": "command", "timeout": 15,
          "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:/Users/YOU/donetoast/claude-hook.ps1\" notify" }] }
    ],
    "UserPromptSubmit": [ { "hooks": [{ "type": "command", "timeout": 10, "command": "C:/Users/YOU/donetoast/claude-clear.cmd" }] } ],
    "Stop":             [ { "hooks": [{ "type": "command", "timeout": 10, "command": "C:/Users/YOU/donetoast/claude-clear.cmd" }] } ]
  }
}
```

**Know when a task is done.** Add a line like this to your `CLAUDE.md` or `AGENTS.md`:

> When a long task I'm waiting for finishes (build, render, download, long test) or fails, notify me with
> `& "$HOME\donetoast\donetoast.ps1" -Title '<what>' -Message '<short result>'` (add `-Failed` on failure, `-App Codex` when you are Codex).

If the agent runs in a sandbox, it has to run this command with the sandbox turned off; otherwise the card can't open on your desktop.

## FAQ

**Does it work on macOS or Linux?** No. It is built on WPF, which only exists on Windows.

**Do I need admin rights?** No. Everything runs as your user, and the installer only writes inside your home folder.

**Will Focus Assist / Do Not Disturb hide it?** No. The cards are their own small windows, not Windows notifications, so they show up either way.

**Does it send anything over the network?** No. Only `install.ps1` talks to GitHub, to download the files.

**How do I remove it?** Run `install.ps1 -Uninstall` from the donetoast folder, then delete the folder.

## Customising

- **Icon.** Drop a 256 px PNG into `icons\` named after the `-App` value, for example `icons\myapp.png`. Apps with no icon fall back to `icon.png`.
- **Sound.** Run `make-sounds.ps1` to regenerate the chimes. Alternatives are in `sounds\`: `soft-duo` (default), `bubble`, `calm-arpeggio`, `soft-fall` (default for failures), `soft-tap` (default for "needs you"). To switch, run for example `make-sounds.ps1 -Done bubble -Wait calm-arpeggio`. Running cards make no sound.
- **README images.** Run `tools\make-previews.ps1` to rebuild `docs\` (the demo GIF included). It renders the cards off-screen onto a fake desktop and never takes a real screenshot, so nothing from your screen ends up in the images.

## Files

| File | Role |
|---|---|
| `donetoast.ps1` | Entry point: starts a hidden process for an instant card or a background job |
| `toast.ps1` | The card itself (WPF window, animation, sound) |
| `job-runner.ps1` | Runs a job and calls `toast.ps1` when it ends |
| `claude-hook.ps1`, `claude-clear.cmd` | Claude Code hooks for the "needs you" card |
| `install.ps1` | Sets up the hooks and the agent instructions; `-Uninstall` undoes it |
| `make-sounds.ps1` | Sound synthesizer |
| `tools\` | Icon and README image generators |

Claude and Codex logos belong to Anthropic and OpenAI. They are used here only to show which app a notification came from.

## License

MIT
