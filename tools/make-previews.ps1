# Builds the README images: docs\demo.gif (the whole flow, with captions), docs\screenshot.png (three stacked cards),
# docs\animation.gif (slide-in), docs\card-*.png
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
  @{ id = 'c1'; Title = 'Render finished';    Message = '120 frames ready · took 4 min 12 s'; Time = '21:34'; Args = '';                            App = 'Claude' },
  @{ id = 'c2'; Title = 'Permission needed';  Message = 'my-game · Bash';                     Time = '21:36'; Args = ' -Waiting';                   App = 'Claude' },
  @{ id = 'c3'; Title = 'Uploading backup';   Message = '42% · 8 min left · 1.3 of 3 GB';     Time = '21:41'; Args = ' -State running -Percent 42'; App = 'Claude' },
  @{ id = 'c4'; Title = 'Build failed';       Message = 'Exit code 1 · log: build.log';       Time = '21:38'; Args = ' -Failed';                    App = 'Codex' }
)
$inv = [Globalization.CultureInfo]::InvariantCulture
function Render($c, $yList = $ys) {   # draws one card into $tmp\<id>\frameNNN.png, one frame per Y offset
  $b64 = { param($s) "([Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('$([Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($s)))')))" }
  $inner = "& '$root\toast.ps1' -Title $(& $b64 $c.Title) -Message $(& $b64 $c.Message) -Time '$($c.Time)' -App '$($c.App)' -Preview '$tmp\$($c.id)' -PreviewY $(($yList | % { ([double]$_).ToString($inv) }) -join ',')$($c.Args)"
  powershell -NoProfile -STA -ExecutionPolicy Bypass -EncodedCommand ([Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($inner)))
  if (-not (Test-Path ("$tmp\$($c.id)\frame{0:D3}.png" -f ($yList.Count - 1)))) { throw "could not render $($c.id)" }
}
foreach ($c in $cards) { Render $c }

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
$capBig = New-Object Drawing.Font 'Segoe UI Semibold', (17 * $S), ([Drawing.FontStyle]::Regular), ([Drawing.GraphicsUnit]::Pixel)
$capSmall = New-Object Drawing.Font 'Segoe UI', (11 * $S), ([Drawing.FontStyle]::Regular), ([Drawing.GraphicsUnit]::Pixel)
$capDim = New-Object Drawing.SolidBrush (Rgba 255 175 182 200)
function Compose($slots, $caption) {   # $slots: the frame file to draw in each slot, or $null; $caption: @(step, title, line)
  $b = New-Object Drawing.Bitmap $desk; $g = [Drawing.Graphics]::FromImage($b)
  for ($i = 0; $i -lt $slots.Count; $i++) { if ($slots[$i]) {
    $img = [Drawing.Image]::FromFile($slots[$i]); $g.DrawImage($img, $W - $cw, $H - $bar - $ch * ($i + 1), $cw, $ch); $img.Dispose() } }
  if ($caption) {
    $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'
    $x = 26 * $S; $y = 26 * $S; $box = $W - $cw - 46 * $S
    $g.DrawString($caption[0], $capSmall, $capDim, $x, $y)
    $g.DrawString($caption[1], $capBig, [Drawing.Brushes]::White, $x - 1 * $S, $y + 16 * $S)
    $g.DrawString($caption[2], $capSmall, $capDim, [Drawing.RectangleF]::new($x, $y + 44 * $S, $box, 60 * $S))
  }
  $g.Dispose(); $b }
$last = { param($id) "$tmp\$id\frame015.png" }

$hero = Compose @((& $last 'c1'), (& $last 'c2'), (& $last 'c3')); $hero.Save("$Out\screenshot.png", [Drawing.Imaging.ImageFormat]::Png); $hero.Dispose()
Copy-Item (& $last 'c1') "$Out\card-done.png" -Force; Copy-Item (& $last 'c4') "$Out\card-failed.png" -Force
Copy-Item (& $last 'c2') "$Out\card-waiting.png" -Force; Copy-Item (& $last 'c3') "$Out\card-progress.png" -Force

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

# Story demo (docs\demo.gif): needs you -> answered -> live progress -> done, with captions
$prog = { param($p) $left = [Math]::Ceiling((100 - $p) * 0.1)
  @{ id = "p$p"; Title = 'Uploading backup'; Message = ('{0}% · {1} min left · {2} of 3 GB' -f $p, $left, (3 * $p / 100).ToString('0.0', $inv)); Time = '21:44'; Args = " -State running -Percent $p"; App = 'Claude' } }
Render (& $prog 0)
$steps = 5..95 | Where-Object { $_ % 5 -eq 0 }
foreach ($p in $steps) { Render (& $prog $p) @(0) }
Render @{ id = 'pd'; Title = 'Upload finished'; Message = '3 GB uploaded · took 9 min 40 s'; Time = '21:54'; Args = ''; App = 'Claude' } @(0)

$sd = "$tmp\story"; New-Item -ItemType Directory $sd | Out-Null; $script:sn = 0
function Shot($slots, $cap, $repeat) { $b = Compose $slots $cap; for ($t = 0; $t -lt $repeat; $t++) { $b.Save(("$sd\{0:D4}.png" -f $script:sn)); $script:sn++ }; $b.Dispose() }
$capA = @('1 / 3', 'Claude needs you', 'An amber card shows up when Claude asks for permission, even while you are in another window.')
$capB = @('1 / 3', 'You answer, it goes away', 'Reply in Claude Code and the card clears itself. Nothing to dismiss.')
$capC = @('2 / 3', 'Long jobs show live progress', 'A progress bar and the time left, moved by your script with one line.')
$capD = @('3 / 3', 'Done, with a soft chime', 'The same card turns into a done card. Click it away when you have seen it.')
Shot @() $capA 40
for ($f = 0; $f -le 15; $f++) { Shot @("$tmp\c2\frame{0:D3}.png" -f $f) $capA 1 }
Shot @((& $last 'c2')) $capA 110
Shot @((& $last 'c2')) $capB 35
for ($f = 15; $f -ge 0; $f--) { Shot @("$tmp\c2\frame{0:D3}.png" -f $f) $capB 1 }
Shot @() $capB 45
for ($f = 0; $f -le 15; $f++) { Shot @("$tmp\p0\frame{0:D3}.png" -f $f) $capC 1 }
Shot @((& $last 'p0')) $capC 30
foreach ($p in $steps) { Shot @("$tmp\p$p\frame000.png") $capC 8 }
Shot @("$tmp\pd\frame000.png") $capD 170
& $ff -v error -y -framerate 50 -i "$sd\%04d.png" -vf "format=rgb24,mpdecimate=hi=1:lo=1:frac=0:max=0,scale=760:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=256:stats_mode=full[p];[b][p]paletteuse=dither=sierra2_4a:diff_mode=rectangle" -fps_mode vfr -loop 0 "$Out\demo.gif"
if (-not $env:DONETOAST_KEEP) { Remove-Item -Recurse -Force $tmp }
Get-ChildItem $Out | Select Name, @{n='KB';e={[math]::Round($_.Length/1KB)}}
