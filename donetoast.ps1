# donetoast entry point. Starts a hidden, detached process so nothing flashes on screen and
# the job keeps running even if the terminal or app that started it is closed.
# Usage:
#   donetoast.ps1 -Title "Render finished" -Message "120 frames ready"          -> show a card now
#   donetoast.ps1 -Title "Build" -Message "Exit code 1" -Failed                 -> red "failed" card
#   donetoast.ps1 -Title "Backup" -Command "robocopy D:\Photos E:\Backup /MIR"  -> run in background, notify when done
#   -App Codex -> show Codex's name and icon in the header (default: Claude).
# When called from a sandboxed agent, run it with the sandbox off, or the card can't reach your desktop.
param(
  [Parameter(Mandatory)][string]$Title,
  [string]$Message = '',
  [string]$Command,
  [switch]$Failed,
  [string]$App = 'Claude'
)

$root = $PSScriptRoot
$ps = 'powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass'
$b64 = { param($s) [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($s)) }
$dec = { param($s) "([Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('$(& $b64 $s)')))" }

if (-not $Command) {
  $f = if ($Failed) { ' -Failed' } else { '' }
  $inner = "& '$root\toast.ps1' -Title $(& $dec $Title) -Message $(& $dec $Message) -App $(& $dec $App)$f"
} else {
  New-Item -ItemType Directory -Force "$root\jobs" | Out-Null
  $job = "$root\jobs\$(Get-Date -Format 'yyyyMMdd-HHmmss').ps1"
  [IO.File]::WriteAllText($job, $Command, (New-Object Text.UTF8Encoding $true))
  $inner = "& '$root\job-runner.ps1' -JobFile '$job' -Name $(& $dec $Title) -App $(& $dec $App)"
}
$cl = "$ps -EncodedCommand $(& $b64 $inner)"

# ShowWindow=0: the console window never appears (-WindowStyle Hidden alone still flashes it briefly)
$hidden = New-CimInstance -ClassName Win32_ProcessStartup -ClientOnly -Property @{ ShowWindow = [uint16]0 }
$r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cl; ProcessStartupInformation = $hidden }
if ($r.ReturnValue -ne 0) { throw "Could not start (WMI code $($r.ReturnValue))" }
"started pid=$($r.ProcessId)" + $(if ($job) { " job=$job log=$([IO.Path]::ChangeExtension($job, '.log'))" } else { '' })
