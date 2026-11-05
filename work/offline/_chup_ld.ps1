# _chup_ld.ps1 - chup cua so LDPlayer ra PNG de xem guest dang o dau
#   powershell -ExecutionPolicy Bypass -File _chup_ld.ps1
$ErrorActionPreference = 'Continue'
$out = 'D:\PROJECT\ProjectOut\game\brave-cross\work\offline\_ld_screen.png'

Add-Type -AssemblyName System.Drawing, System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class W {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
}
"@

$p = Get-Process dnplayer -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $p) { Write-Output 'khong thay cua so dnplayer'; exit 1 }
$h = $p.MainWindowHandle
Write-Output ("cua so: " + $p.MainWindowTitle + "  pid=" + $p.Id)

[W]::ShowWindow($h, 9) | Out-Null          # SW_RESTORE
[W]::SetForegroundWindow($h) | Out-Null
Start-Sleep -Milliseconds 800

$r = New-Object W+RECT
[W]::GetWindowRect($h, [ref]$r) | Out-Null
$w = $r.R - $r.L; $hh = $r.B - $r.T
Write-Output ("rect=" + $r.L + "," + $r.T + " " + $w + "x" + $hh)

$bmp = New-Object System.Drawing.Bitmap $w, $hh
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size)
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Output ("da luu " + $out)
