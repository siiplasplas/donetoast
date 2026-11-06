# Masaüstü bildirimi — Steam (2023+) bildirim kartı tarzında:
#   283x70, görev çubuğunun hemen üstüne ve ekranın sağ kenarına yapışık, kartlar arasında boşluk yok,
#   alttan 300 ms cubic-bezier(0,.73,.48,1) ile kayarak çıkar (Steam'in kendi eğrisi).
#   Ses: bitti.wav / hata.wav (ses-uret.ps1 üretir). Windows bildirimleri kapalı olsa da çıkar.
# Kullanım: bildir.ps1 -Baslik "Render bitti" -Metin "kare_12.png hazır" [-Hata] [-Saniye 20]
#   Tıklayınca kapanır. -Saniye verilirse o kadar saniye sonra kendiliğinden kapanır (0 = tıklanana kadar kalır).
#   -Uygulama: başlıkta görünen kaynak adı (Claude, Codex...).  -Ikon: 44 px resim (varsayılan: ikonlar\<uygulama>.png, yoksa ikon.png).
#   -Onizleme <klasör>: pencere açmadan kartı PNG kareleri olarak çizer (README görselleri için), -OnizlemeY her karenin dikey kayması.
param(
  [string]$Baslik = 'İş bitti',
  [string]$Metin = '',
  [switch]$Hata,
  [int]$Saniye = 0,
  [string]$Uygulama = 'Claude',
  [string]$Ikon = '',
  [string]$Saat = '',
  [string]$Onizleme = '',
  [double[]]$OnizlemeY = @(0)
)

if (-not $Onizleme) { Add-Content -Encoding UTF8 "$PSScriptRoot\bildirim.log" "$(Get-Date -Format s) $Baslik | $Metin" }

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# Yığılma: boş ilk yuvayı al (yuvalar boşluksuz, alttan yukarı)
$mutex = $null; $yuva = 0
if (-not $Onizleme) {
  for ($i = 0; $i -lt 8; $i++) {
    $m = New-Object Threading.Mutex($false, "Local\MasaustuBildirimYuva$i")
    $aldi = $false
    try { $aldi = $m.WaitOne(0) } catch [Threading.AbandonedMutexException] { $aldi = $true }
    if ($aldi) { $mutex = $m; $yuva = $i; break }
    $m.Dispose()
  }
}

if ($Hata) { $renk = '#E5604F'; $durum = 'yarım kaldı'; $glif = '&#xE7BA;'; $ses = 'hata.wav' }
else       { $renk = '#91C257'; $durum = 'bitti';       $glif = '&#xE73E;'; $ses = 'bitti.wav' }
if (-not $Ikon) { $Ikon = "$PSScriptRoot\ikonlar\$($Uygulama.ToLowerInvariant()).png"; if (-not (Test-Path $Ikon)) { $Ikon = "$PSScriptRoot\ikon.png" } }

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        Topmost="True" ShowInTaskbar="False" ShowActivated="False" ResizeMode="NoResize"
        Width="283" Height="70" Cursor="Hand" UseLayoutRounding="True" SnapsToDevicePixels="True"
        FontFamily="Segoe UI Variable Text, Segoe UI"
        TextOptions.TextFormattingMode="Display" TextOptions.TextRenderingMode="ClearType">
  <Grid ClipToBounds="True" Width="283" Height="70">
    <Grid x:Name="Kart">
      <Grid.RenderTransform><TranslateTransform x:Name="Kay" Y="70"/></Grid.RenderTransform>
      <Grid.Background>
        <RadialGradientBrush GradientOrigin="0,0" Center="0,0" RadiusX="1.5542" RadiusY="1">
          <GradientStop Color="#23262E" Offset="0"/>
          <GradientStop Color="#0E141B" Offset="1"/>
        </RadialGradientBrush>
      </Grid.Background>

      <Border x:Name="Isilti" Opacity="0" IsHitTestVisible="False">
        <Border.Background>
          <RadialGradientBrush GradientOrigin="0,0" Center="0,0" RadiusX="1.5542" RadiusY="1">
            <GradientStop Color="#1F2A39" Offset="0"/>
            <GradientStop Color="#531AA0FF" Offset="1"/>
          </RadialGradientBrush>
        </Border.Background>
      </Border>

      <!-- üstte kartları ayıran 1 px çizgi (boşluk yerine) -->
      <Border Height="1" VerticalAlignment="Top" Background="#14FFFFFF" IsHitTestVisible="False"/>

      <!-- Steam: padding 10, avatar 44, metin avatardan 12 px sonra -->
      <Grid Margin="10,8,10,8">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="44"/><ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        <Image x:Name="Resim" Width="44" Height="44" RenderOptions.BitmapScalingMode="HighQuality"/>
        <Grid Grid.Column="1" Margin="12,0,0,0" VerticalAlignment="Center">
          <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
          <DockPanel>
            <TextBlock x:Name="Saat" DockPanel.Dock="Right" FontSize="11" Foreground="#67707B" Margin="6,0,0,0"/>
            <TextBlock FontSize="11" FontWeight="Medium" Foreground="#8B929A" TextTrimming="CharacterEllipsis">
              <Run Text="$glif" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="10" Foreground="$renk" BaselineAlignment="Center"/>
              <Run x:Name="Ust"/>
            </TextBlock>
          </DockPanel>
          <TextBlock x:Name="BaslikY" Grid.Row="1" FontSize="13" FontWeight="SemiBold" Foreground="#FFFFFF"
                     TextTrimming="CharacterEllipsis" Margin="0,1,0,0"/>
          <TextBlock x:Name="MetinY" Grid.Row="2" FontSize="11.5" Foreground="#8B929A"
                     TextTrimming="CharacterEllipsis" Margin="0,1,0,0"/>
        </Grid>
      </Grid>
    </Grid>
  </Grid>
</Window>
"@

$w = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
$el = @{}; foreach ($ad in 'Kart', 'Kay', 'Isilti', 'Ust', 'Saat', 'BaslikY', 'MetinY', 'Resim') { $el[$ad] = $w.FindName($ad) }

# Resmi belleğe tam yükle (dosya kilitlenmesin, önizlemede de hemen hazır olsun)
$bi = New-Object Windows.Media.Imaging.BitmapImage
$bi.BeginInit(); $bi.CacheOption = 'OnLoad'; $bi.DecodePixelWidth = 88; $bi.UriSource = [Uri]$Ikon; $bi.EndInit(); $bi.Freeze()
$el.Resim.Source = $bi

$el.Ust.Text = " $Uygulama  ·  $durum"
$el.Saat.Text = if ($Saat) { $Saat } else { Get-Date -Format 'HH:mm' }
$el.BaslikY.Text = $Baslik
$el.MetinY.Text = $Metin
$w.ToolTip = if ($Metin) { "$Baslik`n$Metin" } else { $Baslik }

# Önizleme: pencere açmadan kareleri 2x çözünürlükte PNG olarak yaz ve çık
if ($Onizleme) {
  New-Item -ItemType Directory -Force $Onizleme | Out-Null
  $kok = $w.Content; $w.Content = $null
  $kok.Measure([Windows.Size]::new(283, 70)); $kok.Arrange([Windows.Rect]::new(0, 0, 283, 70))
  for ($k = 0; $k -lt $OnizlemeY.Count; $k++) {
    $el.Kay.Y = $OnizlemeY[$k]; $kok.UpdateLayout()
    $rtb = New-Object Windows.Media.Imaging.RenderTargetBitmap(566, 140, 192, 192, [Windows.Media.PixelFormats]::Pbgra32)
    $rtb.Render($kok)
    $enc = New-Object Windows.Media.Imaging.PngBitmapEncoder; $enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($rtb))
    $fs = [IO.File]::Create((Join-Path $Onizleme ('kare{0:D3}.png' -f $k))); $enc.Save($fs); $fs.Close()
  }
  return
}

$spline = New-Object Windows.Media.Animation.KeySpline(0, 0.73, 0.48, 1)
function Kaydir($prop, $hedef, $ms, $bitince) {
  $a = New-Object Windows.Media.Animation.DoubleAnimationUsingKeyFrames
  $a.KeyFrames.Add((New-Object Windows.Media.Animation.SplineDoubleKeyFrame($hedef, [Windows.Media.Animation.KeyTime]::FromTimeSpan([TimeSpan]::FromMilliseconds($ms)), $spline))) | Out-Null
  if ($bitince) { $a.add_Completed($bitince) }
  $el.Kay.BeginAnimation($prop, $a)
}

$script:kapaniyor = $false
$kapat = {
  if ($script:kapaniyor) { return }; $script:kapaniyor = $true
  Kaydir ([Windows.Media.TranslateTransform]::XProperty) 283 260 { $w.Close() }
}

$w.add_MouseLeftButtonUp($kapat)
$w.add_MouseEnter({ $el.Isilti.BeginAnimation([Windows.UIElement]::OpacityProperty, (New-Object Windows.Media.Animation.DoubleAnimation(0.5, [Windows.Duration]::new([TimeSpan]::FromMilliseconds(300))))) })
$w.add_MouseLeave({ $el.Isilti.BeginAnimation([Windows.UIElement]::OpacityProperty, (New-Object Windows.Media.Animation.DoubleAnimation(0, [Windows.Duration]::new([TimeSpan]::FromMilliseconds(300))))) })

$w.add_ContentRendered({
  $alan = [Windows.SystemParameters]::WorkArea
  $w.Left = $alan.Right - 283
  $w.Top = $alan.Bottom - 70 * ($yuva + 1)
  Kaydir ([Windows.Media.TranslateTransform]::YProperty) 0 300 $null
  try { (New-Object Media.SoundPlayer "$PSScriptRoot\$ses").Play() } catch {}
  # Giriş bitince belleği bir kez boşalt: kart beklerken RAM'de az yer tutsun (~140 MB -> ~40 MB)
  $b = New-Object Windows.Threading.DispatcherTimer -Property @{ Interval = [TimeSpan]::FromSeconds(2) }
  $b.add_Tick({
    $this.Stop(); [GC]::Collect(); [GC]::WaitForPendingFinalizers(); [GC]::Collect()
    # Tek seferlik kırpma: sınırı kısa süre en alta çekip hemen geri bırak (kalıcı sınır CPU'yu yoruyordu)
    try { $p = [Diagnostics.Process]::GetCurrentProcess(); $eskiMax = $p.MaxWorkingSet
          $p.MaxWorkingSet = [IntPtr]$p.MinWorkingSet; $p.MaxWorkingSet = $eskiMax } catch {}
  }); $b.Start()
  if ($Saniye -gt 0) {
    $t = New-Object Windows.Threading.DispatcherTimer -Property @{ Interval = [TimeSpan]::FromSeconds($Saniye) }
    $t.add_Tick({ $this.Stop(); & $kapat }); $t.Start()
  }
})

$w.Left = -10000; $w.Top = -10000
$w.add_Closed({ $w.Dispatcher.InvokeShutdown() })
$w.Show()
[Windows.Threading.Dispatcher]::Run()

if ($mutex) { try { $mutex.ReleaseMutex() } catch {}; $mutex.Dispose() }
