# Claude Code hook: shows an amber "needs you" card when Claude waits for you and removes it once you answer.
#   PermissionRequest                       -> claude-hook.ps1 permission   (instant, names the tool: "my-game · Bash: npm test")
#   Notification                            -> claude-hook.ps1 notify       (waiting for your reply, questions; late permission fallback)
#   PostToolUse / PostToolUseFailure        -> claude-clear.cmd             (clears the card once the approved tool has run)
#   UserPromptSubmit / Stop                 -> claude-clear.cmd             (clears everything else, also a denied prompt)
# One card per Claude session; a new notification updates the open card instead of stacking another.
param([ValidateSet('notify', 'permission', 'clear')][string]$Mode = 'notify')

[Console]::InputEncoding = [Text.Encoding]::UTF8
try { $j = [Console]::In.ReadToEnd() | ConvertFrom-Json } catch { exit 0 }
$sid = ([string]$j.session_id) -replace '[^\w-]', ''
if (-not $sid) { $sid = 'default' }
$id = "claude-$($sid.Substring(0, [Math]::Min(12, $sid.Length)))"
$card = "$PSScriptRoot\progress\$id.json"
$toolFile = "$PSScriptRoot\progress\$id.tool"   # which tool the permission card is about
function ToolKey($o) { "$($o.tool_name)|$($o.tool_input | ConvertTo-Json -Compress -Depth 20)" }

if ($Mode -eq 'clear') {   # deleting the state file closes the card within a second
  if ("$($j.hook_event_name)" -like 'PostToolUse*') {
    # After a tool ran: clear only the permission card for that very tool. Other tools finishing in
    # parallel, or a "waiting for your reply" card, stay.
    if (-not (Test-Path -LiteralPath $toolFile)) { exit 0 }
    if ([IO.File]::ReadAllText($toolFile) -ne (ToolKey $j)) { exit 0 }
  }
  Remove-Item -LiteralPath $card, $toolFile -Force -ErrorAction SilentlyContinue
  exit 0
}

$where = if ($j.cwd) { Split-Path -Leaf ([string]$j.cwd) } else { '' }
if ($Mode -eq 'permission') {
  $tool = ([string]$j.tool_name) -replace '^mcp__[^_]+(_[^_]+)*?__', ''
  $in = $j.tool_input
  $what = switch -Regex ([string]$j.tool_name) {
    '^Bash$'                                    { [string]$in.command }
    '^(Edit|MultiEdit|Write|Read|NotebookEdit)$' { if ($in.file_path) { Split-Path -Leaf ([string]$in.file_path) } elseif ($in.notebook_path) { Split-Path -Leaf ([string]$in.notebook_path) } }
    '^WebFetch$'                                { try { ([Uri][string]$in.url).Host } catch { '' } }
    '^WebSearch$'                               { [string]$in.query }
    default                                     { '' }
  }
  $what = ($what -replace '\s+', ' ').Trim()
  if ($what.Length -gt 48) { $what = $what.Substring(0, 47) + [char]0x2026 }
  $detail = if ($what) { "${tool}: $what" } else { $tool }
  [IO.File]::WriteAllText($toolFile, (ToolKey $j), (New-Object Text.UTF8Encoding $false))
  $line = (@($where, $detail) | Where-Object { $_ }) -join ' · '
  & "$PSScriptRoot\donetoast.ps1" -Id $id -Waiting -Title 'Permission needed' -Message $line -App Claude | Out-Null
  exit 0
}

$msg = [string]$j.message
# Short title by type; the second line says where, and what is being asked
switch ([string]$j.notification_type) {
  'permission_prompt' {
    if (Test-Path -LiteralPath $card) { exit 0 }   # the PermissionRequest hook already shows it, with more detail
    $title = 'Permission needed'; $msg = $msg -replace '^Claude needs your permission to use ', '' }
  'idle_prompt'       { $title = 'Waiting for your reply'; $msg = '' }
  default             { $title = if ($msg) { $msg } else { 'Claude needs you' }; $msg = '' }
}
$line = (@($where, $msg) | Where-Object { $_ }) -join ' · '
& "$PSScriptRoot\donetoast.ps1" -Id $id -Waiting -Title $title -Message $line -App Claude | Out-Null
exit 0
