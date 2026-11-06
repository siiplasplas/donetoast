# Bildirim seslerini üretir (bir kez çalıştırılır).
# Hedef: kulağı yormayan, sıcak, kısa ses. Bu yüzden:
#   - orta-alçak perde (C5 civarı), parlak üst harmonik yok, yankı yok
#   - 10 ms yumuşak (yarım-sinüs) atak → "tık" yok
#   - düşük ses seviyesi (tepe ~ -12 dBFS), sonu sessizliğe pürüzsüz iner
# Seçenekler ses\ klasörüne yazılır; varsayılanlar bitti.wav / hata.wav olarak kopyalanır.
param([string]$Klasor = $PSScriptRoot, [string]$Bitti = 'yumusak-ikili', [string]$HataSes = 'yumusak-inis')

$kod = @'
using System;
public static class Sentez {
  // notalar: [frekans, baslangic_sn, sonum_sn, kazanc, perde_kaymasi_oran, kayma_sn]
  public static double[] Uret(double[][] notalar, double uzunluk, double tepe, double atakSn, double harmonik) {
    int hz = 44100, n = (int)(hz * uzunluk); var s = new double[n];
    foreach (var nt in notalar) {
      double f = nt[0], g = nt[3], sonum = nt[2], kay = nt[4], kaySn = nt[5];
      int bas = (int)(nt[1] * hz); double faz = 0, faz2 = 0;
      for (int i = bas; i < n; i++) {
        double t = (double)(i - bas) / hz;
        double atak = t < atakSn ? Math.Sin(Math.PI / 2 * t / atakSn) : 1.0;
        double zarf = atak * Math.Exp(-t / sonum);
        // hafif perde kayması (kabarcık hissi): f*(1+kay) -> f
        double fAn = f * (1 + kay * Math.Exp(-t / Math.Max(kaySn, 1e-4)));
        faz += 2 * Math.PI * fAn / hz; faz2 += 2 * Math.PI * 2 * fAn / hz;
        // temel + çok kısa ömürlü yumuşak 2. harmonik (keçe çekiç gibi), 3. ve üstü yok
        double v = Math.Sin(faz) + harmonik * Math.Sin(faz2) * Math.Exp(-t / (sonum * 0.18));
        s[i] += v * zarf * g;
      }
    }
    // çok hafif alçak geçiren (tek kutuplu, ~5 kHz) — kalan sertliği alır
    double a = Math.Exp(-2 * Math.PI * 5000.0 / hz), y = 0;
    for (int i = 0; i < n; i++) { y = (1 - a) * s[i] + a * y; s[i] = y; }
    double m = 1e-9; foreach (var v in s) m = Math.Max(m, Math.Abs(v));
    for (int i = 0; i < n; i++) s[i] = s[i] / m * tepe;
    int k = (int)(0.08 * hz); for (int i = 0; i < k; i++) s[n - 1 - i] *= Math.Pow((double)i / k, 2);
    return s;
  }
  public static void Yaz(string yol, double[] s) {
    int hz = 44100; var b = new System.IO.BinaryWriter(System.IO.File.Create(yol));
    b.Write("RIFF".ToCharArray()); b.Write(36 + s.Length * 2); b.Write("WAVEfmt ".ToCharArray());
    b.Write(16); b.Write((short)1); b.Write((short)1); b.Write(hz); b.Write(hz * 2); b.Write((short)2); b.Write((short)16);
    b.Write("data".ToCharArray()); b.Write(s.Length * 2);
    var r = new Random(1);
    foreach (var v in s) { double d = (r.NextDouble() - r.NextDouble()) / 32768.0; b.Write((short)Math.Round(Math.Max(-1, Math.Min(1, v + d)) * 32767)); }
    b.Close();
  }
}
'@
if (-not ('Sentez' -as [type])) { Add-Type -TypeDefinition $kod }

$tepe = [Math]::Pow(10, -12 / 20)   # -12 dBFS
$c = "$Klasor\ses"; New-Item -ItemType Directory -Force $c | Out-Null
# nota: frekans, başlangıç sn, sönüm sn, kazanç, perde kayması oranı, kayma sn
$secenek = [ordered]@{
  # iki notalı sıcak, keçe piyano gibi: C5 -> G5, yükselen (bitti)
  'yumusak-ikili' = [Sentez]::Uret([double[][]]@(@(523.25,0,0.22,0.75,0,0), @(783.99,0.09,0.38,0.9,0,0)), 0.9, $tepe, 0.010, 0.10)
  # tek, yuvarlak "blop": E5, hafif aşağı kayan perde
  'kabarcik'      = [Sentez]::Uret([double[][]]@(,@(659.25,0,0.16,1.0,0.18,0.025)), 0.55, $tepe, 0.006, 0.05)
  # üç notalı çok hafif arpej: G4 C5 E5, daha sakin
  'sakin-arpej'   = [Sentez]::Uret([double[][]]@(@(392.0,0,0.30,0.7,0,0), @(523.25,0.07,0.32,0.75,0,0), @(659.25,0.14,0.45,0.85,0,0)), 1.1, $tepe, 0.012, 0.08)
  # yarım kaldı: inen, yumuşak: G5 -> D5
  'yumusak-inis'  = [Sentez]::Uret([double[][]]@(@(783.99,0,0.20,0.8,0,0), @(587.33,0.11,0.40,0.9,0,0)), 0.95, $tepe, 0.010, 0.08)
}
foreach ($ad in $secenek.Keys) { [Sentez]::Yaz("$c\$ad.wav", $secenek[$ad]) }
Copy-Item "$c\$Bitti.wav" "$Klasor\bitti.wav" -Force
Copy-Item "$c\$HataSes.wav" "$Klasor\hata.wav" -Force
"sesler hazır: $($secenek.Keys -join ', ')  (bitti=$Bitti, hata=$HataSes)"
