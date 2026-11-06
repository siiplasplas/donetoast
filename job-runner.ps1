# Runs a job file and shows a card when it finishes or fails.
# Started by donetoast.ps1 -Command; no need to call it directly.
param([Parameter(Mandatory)][string]$JobFile, [string]$Name = 'Job', [string]$App = 'Claude')

$log = [IO.Path]::ChangeExtension($JobFile, '.log')
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

if ($code -eq 0) {
  & "$PSScriptRoot\toast.ps1" -Title "$Name finished" -Message "Took $took · C: $free GB free" -App $App
} else {
  & "$PSScriptRoot\toast.ps1" -Title "$Name failed" -Message "Exit code $code after $took · log: $log" -Failed -App $App
}
