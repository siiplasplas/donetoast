# Builds the README images: docs\screenshot.png (three stacked cards), docs\animation.gif (slide-in), docs\card-*.png
# Takes no real screenshot; the cards are drawn with toast.ps1 -Preview and placed on a fake desktop.
param([string]$Out = "$PSScriptRoot\..\docs")
$ErrorActionPreference = 'Stop'
$root = Resolve-Path "$PSScriptRoot\.."; New-Item -ItemType Directory -Force $Out | Out-Null; $Out = Resolve-Path $Out
$tmp = Join-Path $env:TEMP "donetoast-preview"; Remove-Item -Recurse -Force $tmp -EA 0; New-Item -ItemType Directory $tmp | Out-Null

# Steam curve cubic-bezier(0,.73,.48,1), 300 ms, 50 fps -> the card's Y offset (70 -> 0)
function Ease([double]$x) { $lo = 0.0; $hi = 1.0
  for ($i = 0; $i -lt 40; $i++) { $u = ($lo + $hi) / 2; $bx = 3*(1-$u)*(1-$u)*$u*0 + 3*(1-$u)*$u*$u*0.48 + $u*$u*$u; if ($bx -lt $x) { $lo = $u } else { $hi = $u } }
  $u = ($lo + $hi) / 2; 3*(1-$u)*(1-$u)*$u*0.73 + 3*(1-$u)*$u*$u*1 + $u*$u*$u }
$ys = @(for ($f = 0; $f -le 15; $f++) { [Math]::Round(70 * (1 - (Ease ($f / 15))), 2) })

$cards = @(
  @{ id = 'c1'; Title = 'Render finished';    Message = '120 frames ready · took 4 min 12 s'; Time = '21:34'; Failed = $false; App = 'Claude' },
  @{ id = 'c2'; Title = 'Build failed';       Message = 'Exit code 1 · log: build.log';       Time = '21:36'; Failed = $true;  App = 'Codex' },
  @{ id = 'c3'; Title = 'File move finished'; Message = 'Took 18 min · C: 212.4 GB free';     Time = '21:41'; Failed = $false; App = 'Claude' }
)
$inv = [Globalization.CultureInfo]::InvariantCulture
foreach ($c in $cards) {
  $f = if ($c.Failed) { ' -Failed' } else { '' }
  $b64 = { param($s) "([Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('$([Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($s)))')))" }
  $inner = "& '$root\toast.ps1' -Title $(& $b64 $c.Title) -Message $(& $b64 $c.Message) -Time '$($c.Time)' -App '$($c.App)' -Preview '$tmp\$($c.id)' -PreviewY $(($ys | % { $_.ToString($inv) }) -join ',')$f"
  powershell -NoProfile -STA -ExecutionPolicy Bypass -EncodedCommand ([Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($inner)))
  if (-not (Test-Path "$tmp\$($c.id)\frame015.png")) { throw "could not render $($c.id)" }
}

Add-Type -AssemblyName System.Drawing
$S = 2; $W = 560 * $S; $H = 300 * $S; $bar = 48 * $S
function Rgba($a, $r, $g, $b) { [Drawing.Color]::FromArgb($a, $r, $g, $b) }
# Fake desktop background (drawn once)
$desk = New-Object Drawing.Bitmap $W, $H; $g = [Drawing.Graphics]::FromImage($desk); $g.SmoothingMode = 'AntiAlias'
$lg = New-Object Drawing.Drawing2D.LinearGradientBrush ([Drawing.Point]::new(-2,-2)), ([Drawing.Point]::new($W+2,$H+2)), (Rgba 255 18 26 48), (Rgba 255 40 30 70); $lg.WrapMode = 'TileFlipXY'; $g.FillRectangle($lg, 0, 0, $W, $H)
foreach ($l in @(@(0.15,0.25,520,(Rgba 120 60 120 255)), @(0.55,0.05,600,(Rgba 90 200 80 255)), @(0.35,0.8,500,(Rgba 70 40 200 220)))) {
  $path = New-Object Drawing.Drawing2D.GraphicsPath; $r = $l[2]; $path.AddEllipse($W*$l[0]-$r/2, $H*$l[1]-$r/2, $r, $r)
  $pb = New-Object Drawing.Drawing2D.PathGradientBrush $path; $pb.CenterColor = $l[3]; $pb.SurroundColors = @([Drawing.Color]::Transparent); $g.FillPath($pb, $path) }
# taskbar
$g.FillRectangle((New-Object Drawing.SolidBrush (Rgba 235 28 28 30)), 0, $H - $bar, $W, $bar)
$g.FillRectangle((New-Object Drawing.SolidBrush (Rgba 30 255 255 255)), 0, $H - $bar, $W, 1)

$font = New-Object Drawing.Font 'Segoe UI', (9 * $S), ([Drawing.FontStyle]::Regular), ([Drawing.GraphicsUnit]::Pixel)
$g.TextRenderingHint = 'AntiAliasGridFit'; $sf = New-Object Drawing.StringFormat; $sf.Alignment = 'Far'
$g.DrawString("21:41`n2026-11-06", $font, [Drawing.Brushes]::White, [Drawing.RectangleF]::new($W - 90*$S, $H - $bar + 9*$S, 80*$S, 40*$S), $sf)
$g.Dispose()

$cw = 283 * $S; $ch = 70 * $S
function Compose($slots) {   # $slots: the frame file to draw in each slot, or $null
  $b = New-Object Drawing.Bitmap $desk; $g = [Drawing.Graphics]::FromImage($b)
  for ($i = 0; $i -lt $slots.Count; $i++) { if ($slots[$i]) {
    $img = [Drawing.Image]::FromFile($slots[$i]); $g.DrawImage($img, $W - $cw, $H - $bar - $ch * ($i + 1), $cw, $ch); $img.Dispose() } }
  $g.Dispose(); $b }
$last = { param($id) "$tmp\$id\frame015.png" }

$hero = Compose @((& $last 'c1'), (& $last 'c2'), (& $last 'c3')); $hero.Save("$Out\screenshot.png", [Drawing.Imaging.ImageFormat]::Png); $hero.Dispose()
Copy-Item (& $last 'c1') "$Out\card-done.png" -Force; Copy-Item (& $last 'c2') "$Out\card-failed.png" -Force

# Animation frames (50 fps)
$fd = "$tmp\gif"; New-Item -ItemType Directory $fd | Out-Null; $n = 0
function Emit($slots, $repeat) { for ($t = 0; $t -lt $repeat; $t++) { $b = Compose $slots; $b.Save(("$fd\{0:D4}.png" -f $script:n)); $b.Dispose(); $script:n++ } }
Emit @() 20
$shown = @()
foreach ($id in 'c1', 'c2', 'c3') {
  for ($f = 0; $f -le 15; $f++) { Emit (@($shown) + @("$tmp\$id\frame{0:D3}.png" -f $f)) 1 }
  $shown += (& $last $id); Emit $shown 45
}
Emit $shown 60
$ff = (Get-Command ffmpeg).Source
& $ff -v error -y -framerate 50 -i "$fd\%04d.png" -vf "scale=700:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=256:stats_mode=full[p];[b][p]paletteuse=dither=sierra2_4a" -loop 0 "$Out\animation.gif"
Remove-Item -Recurse -Force $tmp
Get-ChildItem $Out | Select Name, @{n='KB';e={[math]::Round($_.Length/1KB)}}
