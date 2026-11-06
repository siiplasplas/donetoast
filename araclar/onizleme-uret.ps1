# README görsellerini üretir: docs\ekran.png (üç kart üst üste), docs\animasyon.gif (kayarak gelme), docs\kart-*.png
# Gerçek ekran görüntüsü almaz; kartları bildir.ps1 -Onizleme ile çizip sahte bir masaüstüne yerleştirir.
param([string]$Cikis = "$PSScriptRoot\..\docs")
$ErrorActionPreference = 'Stop'
$kok = Resolve-Path "$PSScriptRoot\.."; New-Item -ItemType Directory -Force $Cikis | Out-Null; $Cikis = Resolve-Path $Cikis
$gecici = Join-Path $env:TEMP "bildirim-onizleme"; Remove-Item -Recurse -Force $gecici -EA 0; New-Item -ItemType Directory $gecici | Out-Null

# Steam eğrisi cubic-bezier(0,.73,.48,1), 300 ms, 50 fps -> kartın Y kayması (70 -> 0)
function Egri([double]$x) { $lo = 0.0; $hi = 1.0
  for ($i = 0; $i -lt 40; $i++) { $u = ($lo + $hi) / 2; $bx = 3*(1-$u)*(1-$u)*$u*0 + 3*(1-$u)*$u*$u*0.48 + $u*$u*$u; if ($bx -lt $x) { $lo = $u } else { $hi = $u } }
  $u = ($lo + $hi) / 2; 3*(1-$u)*(1-$u)*$u*0.73 + 3*(1-$u)*$u*$u*1 + $u*$u*$u }
$ys = @(for ($f = 0; $f -le 15; $f++) { [Math]::Round(70 * (1 - (Egri ($f / 15))), 2) })

$kartlar = @(
  @{ ad = 'k1'; Baslik = 'Render bitti';        Metin = '120 kare hazır · 4 dk 12 sn';       Saat = '21:34'; Hata = $false; App = 'Claude' },
  @{ ad = 'k2'; Baslik = 'Build yarım kaldı';   Metin = 'Çıkış kodu 1 · log: build.log';     Saat = '21:36'; Hata = $true;  App = 'Codex' },
  @{ ad = 'k3'; Baslik = 'Dosya taşıma bitti';  Metin = 'Süre 18 dk. C: boş 212,4 GB.';      Saat = '21:41'; Hata = $false; App = 'Claude' }
)
foreach ($c in $kartlar) {
  $h = if ($c.Hata) { ' -Hata' } else { '' }
  $b64 = { param($s) "([Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('$([Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($s)))')))" }
  $ic = "& '$kok\bildir.ps1' -Baslik $(& $b64 $c.Baslik) -Metin $(& $b64 $c.Metin) -Saat '$($c.Saat)' -Uygulama '$($c.App)' -Onizleme '$gecici\$($c.ad)' -OnizlemeY $(($ys | % { $_.ToString([Globalization.CultureInfo]::InvariantCulture) }) -join ',')$h"
  powershell -NoProfile -STA -ExecutionPolicy Bypass -EncodedCommand ([Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($ic)))
  if (-not (Test-Path "$gecici\$($c.ad)\kare015.png")) { throw "$($c.ad) çizilemedi" }
}

Add-Type -AssemblyName System.Drawing
$O = 2; $W = 560 * $O; $H = 300 * $O; $gorev = 48 * $O
function Renk($a, $r, $g, $b) { [Drawing.Color]::FromArgb($a, $r, $g, $b) }
# Sahte masaüstü arka planı (bir kez çizilir)
$zemin = New-Object Drawing.Bitmap $W, $H; $g = [Drawing.Graphics]::FromImage($zemin); $g.SmoothingMode = 'AntiAlias'
$lg = New-Object Drawing.Drawing2D.LinearGradientBrush ([Drawing.Point]::new(-2,-2)), ([Drawing.Point]::new($W+2,$H+2)), (Renk 255 18 26 48), (Renk 255 40 30 70); $lg.WrapMode = 'TileFlipXY'; $g.FillRectangle($lg, 0, 0, $W, $H)
foreach ($l in @(@(0.15,0.25,520,(Renk 120 60 120 255)), @(0.55,0.05,600,(Renk 90 200 80 255)), @(0.35,0.8,500,(Renk 70 40 200 220)))) {
  $yol = New-Object Drawing.Drawing2D.GraphicsPath; $r = $l[2]; $yol.AddEllipse($W*$l[0]-$r/2, $H*$l[1]-$r/2, $r, $r)
  $pf = New-Object Drawing.Drawing2D.PathGradientBrush $yol; $pf.CenterColor = $l[3]; $pf.SurroundColors = @([Drawing.Color]::Transparent); $g.FillPath($pf, $yol) }
# görev çubuğu
$g.FillRectangle((New-Object Drawing.SolidBrush (Renk 235 28 28 30)), 0, $H - $gorev, $W, $gorev)
$g.FillRectangle((New-Object Drawing.SolidBrush (Renk 30 255 255 255)), 0, $H - $gorev, $W, 1)

$yazi = New-Object Drawing.Font 'Segoe UI', (9 * $O), ([Drawing.FontStyle]::Regular), ([Drawing.GraphicsUnit]::Pixel)
$g.TextRenderingHint = 'AntiAliasGridFit'; $sf = New-Object Drawing.StringFormat; $sf.Alignment = 'Far'
$g.DrawString("21:41`n6.11.2026", $yazi, [Drawing.Brushes]::White, [Drawing.RectangleF]::new($W - 90*$O, $H - $gorev + 9*$O, 80*$O, 40*$O), $sf)
$g.Dispose()

$kw = 283 * $O; $kh = 70 * $O
function Kare($yuk) {   # $yuk: her yuva için çizilecek kare dosyası ya da $null
  $b = New-Object Drawing.Bitmap $zemin; $g = [Drawing.Graphics]::FromImage($b)
  for ($i = 0; $i -lt $yuk.Count; $i++) { if ($yuk[$i]) {
    $img = [Drawing.Image]::FromFile($yuk[$i]); $g.DrawImage($img, $W - $kw, $H - $gorev - $kh * ($i + 1), $kw, $kh); $img.Dispose() } }
  $g.Dispose(); $b }
$son = { param($ad) "$gecici\$ad\kare015.png" }

$hero = Kare @((& $son 'k1'), (& $son 'k2'), (& $son 'k3')); $hero.Save("$Cikis\ekran.png", [Drawing.Imaging.ImageFormat]::Png); $hero.Dispose()
Copy-Item (& $son 'k1') "$Cikis\kart-bitti.png" -Force; Copy-Item (& $son 'k2') "$Cikis\kart-hata.png" -Force

# Animasyon kareleri (50 fps)
$kd = "$gecici\gif"; New-Item -ItemType Directory $kd | Out-Null; $n = 0
function Yaz($yuk, $tekrar) { for ($t = 0; $t -lt $tekrar; $t++) { $b = Kare $yuk; $b.Save(("$kd\{0:D4}.png" -f $script:n)); $b.Dispose(); $script:n++ } }
Yaz @() 20
$sira = @('k1', 'k2', 'k3'); $hazir = @()
foreach ($ad in $sira) {
  for ($f = 0; $f -le 15; $f++) { Yaz (@($hazir) + @("$gecici\$ad\kare{0:D3}.png" -f $f)) 1 }
  $hazir += (& $son $ad); Yaz $hazir 45
}
Yaz $hazir 60
$ff = (Get-Command ffmpeg).Source
& $ff -v error -y -framerate 50 -i "$kd\%04d.png" -vf "scale=700:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=256:stats_mode=full[p];[b][p]paletteuse=dither=sierra2_4a" -loop 0 "$Cikis\animasyon.gif"
Remove-Item -Recurse -Force $gecici
Get-ChildItem $Cikis | Select Name, @{n='KB';e={[math]::Round($_.Length/1KB)}}