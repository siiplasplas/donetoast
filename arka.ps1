# Uzun bir işi Claude uygulamasından bağımsız başlatır (uygulama kapansa da sürer), bitince bildirim gösterir.
# Kullanım:
#   arka.ps1 -Ad "Mega taşıması" -Komut "& rclone.exe move ..."     → iş + bitiş bildirimi
#   arka.ps1 -Ad "Render bitti" -Metin "kare_12.png hazır" -SadeceBildir → hemen bildirim (beklemeden)
#   -Uygulama Codex → kartta Codex adı ve logosu (varsayılan Claude). -Hata → kırmızı "yarım kaldı" kartı.
# Sandbox kapalı çağrılmalı; aksi halde yazılan iş dosyasını dışarıdaki süreç göremez.
param(
  [Parameter(Mandatory)][string]$Ad,
  [string]$Komut,
  [string]$Metin = '',
  [switch]$SadeceBildir,
  [switch]$Hata,
  [string]$Uygulama = 'Claude'
)

$kok = $PSScriptRoot
$ps = 'powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass'

if ($SadeceBildir) {
  $h = if ($Hata) { ' -Hata' } else { '' }
  $b64 = { param($s) [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($s)) }
  $ic = "& '$kok\bildir.ps1' -Baslik ([Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('$(& $b64 $Ad)'))) -Metin ([Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('$(& $b64 $Metin)'))) -Uygulama '$Uygulama'$h"
  $cl = "$ps -EncodedCommand $(& $b64 $ic)"
} else {
  if (-not $Komut) { throw '-Komut gerekli (ya da -SadeceBildir kullan)' }
  New-Item -ItemType Directory -Force "$kok\isler" | Out-Null
  $dosya = "$kok\isler\$(Get-Date -Format 'yyyyMMdd-HHmmss').ps1"
  [IO.File]::WriteAllText($dosya, $Komut, (New-Object Text.UTF8Encoding $true))
  $adB64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Ad))
  $ic = "& '$kok\calistir.ps1' -IsDosyasi '$dosya' -Ad ([Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('$adB64'))) -Uygulama '$Uygulama'"
  $cl = "$ps -EncodedCommand $([Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($ic)))"
}

# ShowWindow=0: konsol penceresi hiç açılmaz (-WindowStyle Hidden tek başına kısa bir mavi/siyah pencere yakıp söndürüyordu)
$gizli = New-CimInstance -ClassName Win32_ProcessStartup -ClientOnly -Property @{ ShowWindow = [uint16]0 }
$r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cl; ProcessStartupInformation = $gizli }
if ($r.ReturnValue -ne 0) { throw "Başlatılamadı (WMI kodu $($r.ReturnValue))" }
"başladı pid=$($r.ProcessId)" + $(if ($dosya) { " iş=$dosya log=$([IO.Path]::ChangeExtension($dosya,'.log'))" } else { '' })
