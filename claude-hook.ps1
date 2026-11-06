# Claude Code hook: shows an amber "needs you" card when Claude waits for you
# (a permission prompt, or no reply for a while) and removes it once you answer.
#   Notification hook          -> claude-hook.ps1 notify
#   UserPromptSubmit / Stop    -> claude-hook.ps1 clear
# One card per Claude session; a new notification updates the open card instead of stacking another.
param([ValidateSet('notify', 'clear')][string]$Mode = 'notify')

[Console]::InputEncoding = [Text.Encoding]::UTF8
try { $j = [Console]::In.ReadToEnd() | ConvertFrom-Json } catch { exit 0 }
$sid = ([string]$j.session_id) -replace '[^\w-]', ''
if (-not $sid) { $sid = 'default' }
$id = "claude-$($sid.Substring(0, [Math]::Min(12, $sid.Length)))"

if ($Mode -eq 'clear') {   # deleting the state file closes the card within a second
  Remove-Item -LiteralPath "$PSScriptRoot\progress\$id.json" -Force -ErrorAction SilentlyContinue
  exit 0
}

$msg = [string]$j.message
$where = if ($j.cwd) { Split-Path -Leaf ([string]$j.cwd) } else { '' }
# Short title by type; the second line says where, and what is being asked
switch ([string]$j.notification_type) {
  'permission_prompt' { $title = 'Permission needed'; $msg = $msg -replace '^Claude needs your permission to use ', '' }
  'idle_prompt'       { $title = 'Waiting for your reply'; $msg = '' }
  default             { $title = if ($msg) { $msg } else { 'Claude needs you' }; $msg = '' }
}
$line = (@($where, $msg) | Where-Object { $_ }) -join ' · '
& "$PSScriptRoot\donetoast.ps1" -Id $id -Waiting -Title $title -Message $line -App Claude | Out-Null
exit 0
