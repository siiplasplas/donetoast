# Bir iş dosyasını çalıştırır, bitince (ya da hata verince) bildirim gösterir.
# arka.ps1 tarafından başlatılır; elle çağırmaya gerek yok.
param([Parameter(Mandatory)][string]$IsDosyasi, [string]$Ad = 'İş', [string]$Uygulama = 'Claude')

$log = [IO.Path]::ChangeExtension($IsDosyasi, '.log')
$bas = Get-Date
$kod = 0
try {
  & $IsDosyasi *> $log
  if ($LASTEXITCODE) { $kod = $LASTEXITCODE }
  if (-not $?) { $kod = 1 }
} catch {
  $_ | Out-String | Add-Content $log
  $kod = 1
}
$sure = (Get-Date) - $bas
$sureYazi = if ($sure.TotalMinutes -ge 1) { '{0:N0} dk' -f $sure.TotalMinutes } else { '{0:N0} sn' -f $sure.TotalSeconds }
$bos = '{0:N1}' -f ((Get-PSDrive C).Free / 1GB)

if ($kod -eq 0) {
  & "$PSScriptRoot\bildir.ps1" -Baslik "$Ad bitti" -Metin "Süre $sureYazi. C: boş $bos GB." -Uygulama $Uygulama
} else {
  & "$PSScriptRoot\bildir.ps1" -Baslik "$Ad yarım kaldı" -Metin "Çıkış kodu $kod, süre $sureYazi. Log: $log" -Hata -Uygulama $Uygulama
}
