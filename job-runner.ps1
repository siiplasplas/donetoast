# Runs a job file and shows a card when it finishes or fails.
# Started by donetoast.ps1 -Command; no need to call it directly.
# With -Id (donetoast.ps1 -Command ... -Progress) the live card that is already open turns into the result card,
# and the job can report progress itself: & $env:DONETOAST -Id $env:DONETOAST_ID -Percent 42
param([Parameter(Mandatory)][string]$JobFile, [string]$Name = 'Job', [string]$App = 'Claude', [string]$Id = '')

$log = [IO.Path]::ChangeExtension($JobFile, '.log')
$env:DONETOAST = "$PSScriptRoot\donetoast.ps1"; $env:DONETOAST_ID = $Id
$start = Get-Date
$code = 0
try {
  & $JobFile *> $log
  if ($LASTEXITCODE) { $code = $LASTEXITCODE }
  if (-not $?) { $code = 1 }
} catch {
  $_ | Out-String | Add-Content $log
  $code = 1
}
$span = (Get-Date) - $start
$took = if ($span.TotalMinutes -ge 1) { '{0:N0} min' -f $span.TotalMinutes } else { '{0:N0} s' -f $span.TotalSeconds }
$inv = [Globalization.CultureInfo]::InvariantCulture
$free = ((Get-PSDrive C).Free / 1GB).ToString('N1', $inv)

if ($code -eq 0) { $t = "$Name finished"; $m = "Took $took · C: $free GB free" }
else             { $t = "$Name failed";   $m = "Exit code $code after $took · log: $log" }
if ($Id) {   # the live card turns into the result card
  if ($code -eq 0) { & "$PSScriptRoot\donetoast.ps1" -Id $Id -Title $t -Message $m -Done -App $App | Out-Null }
  else             { & "$PSScriptRoot\donetoast.ps1" -Id $Id -Title $t -Message $m -Failed -App $App | Out-Null }
} elseif ($code -eq 0) {
  & "$PSScriptRoot\toast.ps1" -Title $t -Message $m -App $App
} else {
  & "$PSScriptRoot\toast.ps1" -Title $t -Message $m -Failed -App $App
}
