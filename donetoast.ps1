# donetoast entry point. Starts a hidden, detached process so nothing flashes on screen and
# the job keeps running even if the terminal or app that started it is closed.
# Usage:
#   donetoast.ps1 -Title "Render finished" -Message "120 frames ready"          -> show a card now
#   donetoast.ps1 -Title "Build" -Message "Exit code 1" -Failed                 -> red "failed" card
#   donetoast.ps1 -Title "Claude needs you" -Message "Approve Bash?" -Waiting   -> amber "needs you" card
#   donetoast.ps1 -Title "Backup" -Command "robocopy D:\Photos E:\Backup /MIR"  -> run in background, notify when done
#     add -Progress for a live "running" card from the start; the job can report with $env:DONETOAST_ID (see below)
#   Live card (progress bar + time left), one name per job:
#     donetoast.ps1 -Id upload -Title "Uploading photos" -Percent 0     -> opens the card
#     donetoast.ps1 -Id upload -Percent 42 [-Message "1.2 GB of 3 GB"]  -> updates it (no new process)
#     donetoast.ps1 -Id upload -Done | -Failed [-Message "..."]          -> turns it into a done / failed card
#   -App Codex -> show Codex's name and icon in the header (default: Claude).
# When called from a sandboxed agent, run it with the sandbox off, or the card can't reach your desktop.
param(
  [string]$Title,
  [string]$Message,
  [string]$Command,
  [switch]$Failed,
  [switch]$Waiting,
  [string]$Id,
  [double]$Percent = -1,
  [switch]$Done,
  [switch]$Progress,
  [string]$App = 'Claude'
)

$root = $PSScriptRoot
$ps = 'powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass'
$b64 = { param($s) [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($s)) }
$dec = { param($s) "([Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('$(& $b64 $s)')))" }
function Launch($inner) {
  # ShowWindow=0: the console window never appears (-WindowStyle Hidden alone still flashes it briefly)
  $hidden = New-CimInstance -ClassName Win32_ProcessStartup -ClientOnly -Property @{ ShowWindow = [uint16]0 }
  $r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = "$ps -EncodedCommand $(& $b64 $inner)"; ProcessStartupInformation = $hidden }
  if ($r.ReturnValue -ne 0) { throw "Could not start (WMI code $($r.ReturnValue))" }
  $r.ProcessId
}

if ($Command) {
  if (-not $Title) { $Title = 'Job' }
  New-Item -ItemType Directory -Force "$root\jobs" | Out-Null
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $job = "$root\jobs\$stamp.ps1"
  [IO.File]::WriteAllText($job, $Command, (New-Object Text.UTF8Encoding $true))
  $live = ''
  if ($Progress) { $jid = "job-$stamp"; & $PSCommandPath -Id $jid -Title $Title -App $App | Out-Null; $live = " -Id '$jid'" }
  $p = Launch "& '$root\job-runner.ps1' -JobFile '$job' -Name $(& $dec $Title) -App $(& $dec $App)$live"
  # (-Progress: the job can call  & `$env:DONETOAST -Id `$env:DONETOAST_ID -Percent 42  to move the bar)
  return "started pid=$p job=$job log=$([IO.Path]::ChangeExtension($job, '.log'))" + $(if ($live) { " id=$jid" } else { '' })
}

if (-not $Id) {
  if (-not $Title) { throw '-Title is required' }
  $f = if ($Failed) { ' -Failed' } elseif ($Waiting) { ' -Waiting' } else { '' }
  return "started pid=$(Launch "& '$root\toast.ps1' -Title $(& $dec $Title) -Message $(& $dec "$Message") -App $(& $dec $App)$f")"
}

# Live card: write the state file; open a card only if none is showing for this id yet
if ($Id -notmatch '^[\w.-]{1,64}$') { throw '-Id may only use letters, digits, . _ -' }
$dir = "$root\progress"; New-Item -ItemType Directory -Force $dir | Out-Null
$file = "$dir\$Id.json"; $pidFile = "$dir\$Id.pid"; $muted = "$dir\$Id.muted"
$old = $null; if (Test-Path -LiteralPath $file) { try { $old = Get-Content -Raw -Encoding UTF8 -LiteralPath $file | ConvertFrom-Json } catch {} }
$state = if ($Failed) { 'failed' } elseif ($Done) { 'done' } elseif ($Waiting) { 'waiting' } else { 'running' }
$o = [ordered]@{
  title   = if ($PSBoundParameters.ContainsKey('Title')) { $Title } elseif ($old) { $old.title } else { 'Job' }
  # the message carries over only while the state stays the same ("copying..." must not end up on the done card)
  message = if ($PSBoundParameters.ContainsKey('Message')) { $Message } elseif ($old -and $old.state -eq $state) { $old.message } else { '' }
  percent = if ($PSBoundParameters.ContainsKey('Percent')) { $Percent } elseif ($old) { $old.percent } else { -1 }
  state   = $state
  app     = if ($PSBoundParameters.ContainsKey('App') -or -not $old) { $App } else { $old.app }
}
[IO.File]::WriteAllText($file, ($o | ConvertTo-Json -Compress), (New-Object Text.UTF8Encoding $false))

$alive = $false
if (Test-Path -LiteralPath $pidFile) {
  $cardPid = 0; [int]::TryParse((Get-Content -LiteralPath $pidFile -TotalCount 1), [ref]$cardPid) | Out-Null
  $pr = Get-Process -Id $cardPid -ErrorAction SilentlyContinue
  $alive = $pr -and $pr.ProcessName -eq 'powershell'
}
if ($alive) { return "updated id=$Id" }
if ((Test-Path -LiteralPath $muted) -and $state -eq 'running') { return "updated id=$Id (card hidden)" }
Remove-Item -LiteralPath $muted -Force -ErrorAction SilentlyContinue
$p = Launch "& '$root\toast.ps1' -Id '$Id' -App $(& $dec $o.app)"
Set-Content -LiteralPath $pidFile -Value $p -Encoding ASCII
"started pid=$p id=$Id"
