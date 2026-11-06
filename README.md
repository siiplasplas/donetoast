# donetoast

**A lightweight "job finished" notification for Windows, styled after Steam's friend toasts.**
When a long job finishes (a build, a render, a file move, a Claude Code or Codex task), a small card slides up from the bottom-right corner, right above the taskbar, with a soft chime.

![Three stacked notifications above the taskbar](docs/screenshot.png)

![Cards sliding in one after another](docs/animation.gif)

## Why

- **Works even when Windows notifications are off.** It draws its own window and does not depend on Focus Assist or the Action Center.
- **Looks right.** The size (283×70), radial background, colours, 44 px avatar and the 300 ms `cubic-bezier(0, .73, .48, 1)` slide-in were all measured from Steam's own client stylesheet.
- **Stacks with no gaps.** Several cards sit directly on top of each other, flush against the taskbar and the right edge of the screen.
- **No console flash.** Jobs are started with `ShowWindow = 0`, so no blue or black PowerShell window blinks on screen.
- **Easy on the PC.** About 1 s of CPU when a card opens, then essentially zero (≈30 ms per 15 s). Memory is trimmed after the slide-in: about 40 MB instead of 140 MB while the card is open, and everything is freed when you click it away.
- **A soft sound instead of the Windows ding.** The chimes are synthesized locally and kept quiet, at about −12 dBFS, with no harsh overtones.
- **Nothing to install.** It uses the PowerShell 5.1 and WPF that ship with Windows 10 and 11.

| Done | Failed |
|---|---|
| ![Done card](docs/card-done.png) | ![Failed card](docs/card-failed.png) |

## Install

```powershell
git clone https://github.com/siiplasplas/donetoast "$HOME\donetoast"
```

Any folder works; the scripts find their files relative to themselves.

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

| Parameter | What it does |
|---|---|
| `-Title` | Card title (with `-Command`, the job's name) |
| `-Message` | Second line |
| `-Command` | PowerShell command to run in the background; without it the card shows right away |
| `-Failed` | Red "failed" card and the lower chime |
| `-App` | Source name in the header, for example `Claude` or `Codex`; `icons\<name>.png` is used as the avatar |

Click a card to dismiss it. To make cards close on their own, call `toast.ps1` directly with `-Seconds 20`.

### Using it with Claude Code or Codex

Add a line like this to your `CLAUDE.md` or `AGENTS.md`:

> When a long task I'm waiting for finishes (build, render, download, long test) or fails, notify me with
> `& "$HOME\donetoast\donetoast.ps1" -Title '<what>' -Message '<short result>'` (add `-Failed` on failure, `-App Codex` when you are Codex).

If the agent runs in a sandbox, it has to run this command with the sandbox turned off; otherwise the card can't open on your desktop.

## Customising

- **Icon.** Drop a 256 px PNG into `icons\` named after the `-App` value, for example `icons\myapp.png`. Apps with no icon fall back to `icon.png`.
- **Sound.** Run `make-sounds.ps1` to regenerate the chimes. Alternatives are in `sounds\`: `soft-duo` (default), `bubble`, `calm-arpeggio`, `soft-fall` (default for failures). To switch, run for example `make-sounds.ps1 -Done bubble`.
- **README images.** Run `tools\make-previews.ps1` to rebuild `docs\`. It renders the cards off-screen onto a fake desktop and never takes a real screenshot, so nothing from your screen ends up in the images.

## Files

| File | Role |
|---|---|
| `donetoast.ps1` | Entry point: starts a hidden process for an instant card or a background job |
| `toast.ps1` | The card itself (WPF window, animation, sound) |
| `job-runner.ps1` | Runs a job and calls `toast.ps1` when it ends |
| `make-sounds.ps1` | Sound synthesizer |
| `tools\` | Icon and README image generators |

Claude and Codex logos belong to Anthropic and OpenAI. They are used here only to show which app a notification came from.

## License

MIT
