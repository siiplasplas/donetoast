# Generates the notification sounds (run once).
# Goal: a short, warm sound that never hurts the ears, so:
#   - mid-low pitch (around C5), no bright overtones, no reverb
#   - 10 ms soft (half-sine) attack -> no click
#   - low level (peak ~ -12 dBFS), the tail fades smoothly into silence
# Options are written to sounds\; the chosen defaults are copied to done.wav / failed.wav.
param([string]$Dir = $PSScriptRoot, [string]$Done = 'soft-duo', [string]$Fail = 'soft-fall')

$code = @'
using System;
public static class Synth {
  // notes: [freq, start_s, decay_s, gain, pitch_slide_ratio, slide_s]
  public static double[] Render(double[][] notes, double length, double peak, double attackSec, double harmonic) {
    int hz = 44100, n = (int)(hz * length); var s = new double[n];
    foreach (var nt in notes) {
      double f = nt[0], g = nt[3], decay = nt[2], slide = nt[4], slideSec = nt[5];
      int start = (int)(nt[1] * hz); double ph = 0, ph2 = 0;
      for (int i = start; i < n; i++) {
        double t = (double)(i - start) / hz;
        double attack = t < attackSec ? Math.Sin(Math.PI / 2 * t / attackSec) : 1.0;
        double env = attack * Math.Exp(-t / decay);
        // slight pitch slide (bubble feel): f*(1+slide) -> f
        double fNow = f * (1 + slide * Math.Exp(-t / Math.Max(slideSec, 1e-4)));
        ph += 2 * Math.PI * fNow / hz; ph2 += 2 * Math.PI * 2 * fNow / hz;
        // fundamental + a very short-lived soft 2nd harmonic (like a felt hammer), nothing above it
        double v = Math.Sin(ph) + harmonic * Math.Sin(ph2) * Math.Exp(-t / (decay * 0.18));
        s[i] += v * env * g;
      }
    }
    // very gentle one-pole low-pass (~5 kHz) takes off any remaining edge
    double a = Math.Exp(-2 * Math.PI * 5000.0 / hz), y = 0;
    for (int i = 0; i < n; i++) { y = (1 - a) * s[i] + a * y; s[i] = y; }
    double m = 1e-9; foreach (var v in s) m = Math.Max(m, Math.Abs(v));
    for (int i = 0; i < n; i++) s[i] = s[i] / m * peak;
    int k = (int)(0.08 * hz); for (int i = 0; i < k; i++) s[n - 1 - i] *= Math.Pow((double)i / k, 2);
    return s;
  }
  public static void Save(string path, double[] s) {
    int hz = 44100; var b = new System.IO.BinaryWriter(System.IO.File.Create(path));
    b.Write("RIFF".ToCharArray()); b.Write(36 + s.Length * 2); b.Write("WAVEfmt ".ToCharArray());
    b.Write(16); b.Write((short)1); b.Write((short)1); b.Write(hz); b.Write(hz * 2); b.Write((short)2); b.Write((short)16);
    b.Write("data".ToCharArray()); b.Write(s.Length * 2);
    var r = new Random(1);
    foreach (var v in s) { double d = (r.NextDouble() - r.NextDouble()) / 32768.0; b.Write((short)Math.Round(Math.Max(-1, Math.Min(1, v + d)) * 32767)); }
    b.Close();
  }
}
'@
if (-not ('Synth' -as [type])) { Add-Type -TypeDefinition $code }

$peak = [Math]::Pow(10, -12 / 20)   # -12 dBFS
$out = "$Dir\sounds"; New-Item -ItemType Directory -Force $out | Out-Null
# note: freq, start s, decay s, gain, pitch slide ratio, slide s
$options = [ordered]@{
  # two warm notes, like a felt piano: C5 -> G5, rising (done)
  'soft-duo'      = [Synth]::Render([double[][]]@(@(523.25,0,0.22,0.75,0,0), @(783.99,0.09,0.38,0.9,0,0)), 0.9, $peak, 0.010, 0.10)
  # a single round "blop": E5 with a slight downward pitch slide
  'bubble'        = [Synth]::Render([double[][]]@(,@(659.25,0,0.16,1.0,0.18,0.025)), 0.55, $peak, 0.006, 0.05)
  # a very light three-note arpeggio: G4 C5 E5, calmer
  'calm-arpeggio' = [Synth]::Render([double[][]]@(@(392.0,0,0.30,0.7,0,0), @(523.25,0.07,0.32,0.75,0,0), @(659.25,0.14,0.45,0.85,0,0)), 1.1, $peak, 0.012, 0.08)
  # failed: falling and soft: G5 -> D5
  'soft-fall'     = [Synth]::Render([double[][]]@(@(783.99,0,0.20,0.8,0,0), @(587.33,0.11,0.40,0.9,0,0)), 0.95, $peak, 0.010, 0.08)
}
foreach ($name in $options.Keys) { [Synth]::Save("$out\$name.wav", $options[$name]) }
Copy-Item "$out\$Done.wav" "$Dir\done.wav" -Force
Copy-Item "$out\$Fail.wav" "$Dir\failed.wav" -Force
"sounds ready: $($options.Keys -join ', ')  (done=$Done, failed=$Fail)"
