# Installs donetoast for Claude Code (and Codex, if it is installed). Safe to run more than once.
#   irm https://raw.githubusercontent.com/siiplasplas/donetoast/main/install.ps1 | iex
#   .\install.ps1 -Uninstall      removes the hooks and the instruction lines (the files stay)
# What it does:
#   1. Downloads donetoast to $HOME\donetoast, unless it already runs from a donetoast folder.
#   2. Adds the "needs you" hooks to ~/.claude/settings.json, keeping your hooks (a backup is saved next to it).
#   3. Adds one line to ~/.claude/CLAUDE.md (and ~/.codex/AGENTS.md) so the agent notifies you when a long task ends.
#   4. Shows a test card.
param(
  [string]$Path,
  [switch]$Uninstall,
  [switch]$NoHooks,
  [switch]$NoInstructions,
  [string]$SettingsPath = "$HOME\.claude\settings.json",
  [string]$ClaudeMd = "$HOME\.claude\CLAUDE.md",
  [string]$AgentsMd = "$HOME\.codex\AGENTS.md"
)
$ErrorActionPreference = 'Stop'
$repo = 'siiplasplas/donetoast'
$marker = '<!-- donetoast -->'
function Say($t) { Write-Host "  $t" }

# --- 1. files ---------------------------------------------------------------
if (-not $Path) {
  $Path = if ($PSScriptRoot -and (Test-Path "$PSScriptRoot\toast.ps1")) { $PSScriptRoot } else { "$HOME\donetoast" }
}
if (-not $Uninstall -and -not (Test-Path "$Path\toast.ps1")) {
  Say "Downloading donetoast to $Path"
  $zip = Join-Path $env:TEMP "donetoast-$([guid]::NewGuid().ToString('n')).zip"
  $ex = "$zip.d"
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Invoke-WebRequest "https://github.com/$repo/archive/refs/heads/main.zip" -OutFile $zip -UseBasicParsing
  Expand-Archive $zip $ex -Force
  New-Item -ItemType Directory -Force $Path | Out-Null
  Copy-Item "$ex\donetoast-main\*" $Path -Recurse -Force
  Remove-Item $zip, $ex -Recurse -Force
}
if (-not $Uninstall) { Get-ChildItem $Path -Recurse -File | Unblock-File }
$fwd = (Resolve-Path $Path -ErrorAction SilentlyContinue).Path
if (-not $fwd) { $fwd = $Path }
$fwd = $fwd -replace '\\', '/'

# --- JSON helpers (PowerShell 5.1's ConvertTo-Json output is hard to read) --
function Format-Json([string]$json) {
  $json = $json -replace '\\u0027', "'" -replace '\\u003c', '<' -replace '\\u003e', '>' -replace '\\u0026', '&'
  $sb = New-Object Text.StringBuilder; $ind = 0; $inStr = $false; $esc = $false
  foreach ($c in $json.ToCharArray()) {
    if ($inStr) { [void]$sb.Append($c); if ($esc) { $esc = $false } elseif ($c -eq '\') { $esc = $true } elseif ($c -eq '"') { $inStr = $false }; continue }
    switch ($c) {
      '"' { $inStr = $true; [void]$sb.Append($c) }
      { $_ -eq '{' -or $_ -eq '[' } { $ind++; [void]$sb.Append($c).Append("`n").Append('  ' * $ind) }
      { $_ -eq '}' -or $_ -eq ']' } { $ind--; [void]$sb.Append("`n").Append('  ' * $ind).Append($c) }
      ',' { [void]$sb.Append(",`n").Append('  ' * $ind) }
      ':' { [void]$sb.Append(': ') }
      default { if (-not [char]::IsWhiteSpace($c)) { [void]$sb.Append($c) } }
    }
  }
  # empty {} and [] on one line
  ($sb.ToString() -replace '\{\s+\}', '{}' -replace '\[\s+\]', '[]') + "`n"
}
function Is-Ours($h) { "$($h.command)" -match 'claude-hook\.ps1|claude-clear\.cmd' }
# Removes donetoast's hooks from a group; returns $null when nothing else is left in it
function Without-Ours($group) {
  $rest = @($group.hooks | Where-Object { -not (Is-Ours $_) })
  if ($rest.Count -eq @($group.hooks).Count) { return $group }
  if (-not $rest.Count) { return $null }
  $group.hooks = [object[]]$rest; $group
}

# --- 2. hooks ---------------------------------------------------------------
if (-not $NoHooks) {
  $cfg = if (Test-Path $SettingsPath) {
    $raw = [IO.File]::ReadAllText($SettingsPath)
    if ($raw.Trim()) { $raw | ConvertFrom-Json } else { New-Object psobject }
  } else { New-Item -ItemType Directory -Force (Split-Path $SettingsPath) | Out-Null; New-Object psobject }
  if (Test-Path $SettingsPath) { Copy-Item $SettingsPath "$SettingsPath.bak-donetoast" -Force }
  if (-not $cfg.hooks) { $cfg | Add-Member hooks (New-Object psobject) -Force }
  $hk = $cfg.hooks
  $notify = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$fwd/claude-hook.ps1`" notify"
  $clear = "`"$fwd/claude-clear.cmd`""
  $want = [ordered]@{
    Notification     = [pscustomobject]@{ matcher = 'permission_prompt|idle_prompt|elicitation_dialog'; hooks = @([pscustomobject]@{ type = 'command'; command = $notify; timeout = 15 }) }
    UserPromptSubmit = [pscustomobject]@{ hooks = @([pscustomobject]@{ type = 'command'; command = $clear; timeout = 10 }) }
    Stop             = [pscustomobject]@{ hooks = @([pscustomobject]@{ type = 'command'; command = $clear; timeout = 10 }) }
  }
  foreach ($ev in $want.Keys) {
    $groups = @(@(foreach ($g in @($hk.$ev)) { if ($g) { Without-Ours $g } }) | Where-Object { $_ })   # drop older donetoast hooks, keep everything else
    if (-not $Uninstall) { $groups += $want[$ev] }
    if ($groups.Count) { $hk | Add-Member $ev ([object[]]$groups) -Force }
    elseif ($hk.PSObject.Properties[$ev]) { $hk.PSObject.Properties.Remove($ev) }
  }
  $json = Format-Json ($cfg | ConvertTo-Json -Depth 50 -Compress)
  $null = $json | ConvertFrom-Json   # never write a file that does not parse
  [IO.File]::WriteAllText($SettingsPath, $json, (New-Object Text.UTF8Encoding $false))
  Say ($(if ($Uninstall) { "Removed the hooks from $SettingsPath" } else { "Added the hooks to $SettingsPath" }))
}

# --- 3. instructions for the agent -------------------------------------------
if (-not $NoInstructions) {
  $line = "$marker When a long task I am waiting for (build, render, download, long test) finishes or fails, notify me with ``& `"$($fwd -replace '/', '\')\donetoast.ps1`" -Title '<what>' -Message '<short result>'`` (add ``-Failed`` on failure). Run it outside the sandbox. Do not use it for tasks that take a few seconds."
  foreach ($f in @(@($ClaudeMd, 'Claude'), @($AgentsMd, 'Codex'))) {
    $file = $f[0]; $dir = Split-Path $file
    if (-not (Test-Path $dir)) { continue }   # that agent is not installed
    $text = if (Test-Path $file) { [IO.File]::ReadAllText($file) } else { '' }
    $kept = ($text -split "`r?`n" | Where-Object { $_ -notlike "$marker*" }) -join "`n"
    if (-not $Uninstall) {
      $app = if ($f[1] -eq 'Codex') { " -App Codex" } else { '' }
      $l = $line -replace "-Message '<short result>'", "-Message '<short result>'$app"
      $kept = $kept.TrimEnd() + $(if ($kept.Trim()) { "`n`n" } else { '' }) + $l
    }
    [IO.File]::WriteAllText($file, $kept.TrimEnd() + "`n", (New-Object Text.UTF8Encoding $false))
    Say ($(if ($Uninstall) { "Removed the instruction from $file" } else { "Added an instruction to $file" }))
  }
}

# --- 4. done ------------------------------------------------------------------
if ($Uninstall) {
  Say "Uninstalled. You can delete $Path now."
} else {
  & "$Path\donetoast.ps1" -Title 'donetoast is ready' -Message 'Claude will ping you here when it needs you' -App Claude | Out-Null
  Say "Installed. A test card should be in the bottom-right corner."
  Say "Restart Claude Code (or open a new session) so it picks up the hooks."
}
