# Draws the fallback icon (icon.png, 256 px): a rounded blue square with a white terminal prompt ">_".
param([string]$Path = "$PSScriptRoot\..\icon.png")
Add-Type -AssemblyName System.Drawing
$n = 256; $bmp = New-Object Drawing.Bitmap $n, $n; $g = [Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'; $g.Clear([Drawing.Color]::Transparent)
$r = 56; $p = New-Object Drawing.Drawing2D.GraphicsPath
$p.AddArc(0, 0, $r, $r, 180, 90); $p.AddArc($n - $r - 1, 0, $r, $r, 270, 90)
$p.AddArc($n - $r - 1, $n - $r - 1, $r, $r, 0, 90); $p.AddArc(0, $n - $r - 1, $r, $r, 90, 90); $p.CloseFigure()
$fill = New-Object Drawing.Drawing2D.LinearGradientBrush ([Drawing.Point]::new(0, 0)), ([Drawing.Point]::new($n, $n)), ([Drawing.Color]::FromArgb(255, 0x3A, 0xB4, 0xFF)), ([Drawing.Color]::FromArgb(255, 0x1E, 0x5B, 0xD6))
$g.FillPath($fill, $p)
$pen = New-Object Drawing.Pen ([Drawing.Color]::White), 26
$pen.StartCap = 'Round'; $pen.EndCap = 'Round'; $pen.LineJoin = 'Round'
$g.DrawLines($pen, [Drawing.PointF[]]@([Drawing.PointF]::new(70, 82), [Drawing.PointF]::new(118, 128), [Drawing.PointF]::new(70, 174)))
$g.DrawLine($pen, 140, 174, 188, 174)
$bmp.Save($Path, [Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()
"icon: $Path"
