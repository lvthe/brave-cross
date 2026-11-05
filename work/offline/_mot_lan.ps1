# _mot_lan.ps1 — một lượt mở game + gắn hai script Frida + chờ tự đăng nhập/tự vào trận.
#
#   powershell -ExecutionPolicy Bypass -File _mot_lan.ps1 [-Cho 150] [-KhongMo]
#
# Mọi lệnh adb đều bọc Start-Job + timeout (máy ảo ARM này hay treo system_server).
# Không dùng `am force-stop`, không `dumpsys`, không `screencap` (xem
# GHI-CHU-TRACE-2026-10-23.md, mục "Kỷ luật để máy khỏi chết").

param(
    [int]$Cho = 150,        # giây chờ sau khi gắn trace (để tu_dong đăng nhập + vao_tran vào trận)
    [switch]$KhongMo
)

$ErrorActionPreference = 'Continue'
$sdk  = 'D:\PROJECT\ProjectOut\android-sdk'
$adb  = "$sdk\platform-tools\adb.exe"
$dev  = 'emulator-5554'
$off  = 'D:\PROJECT\ProjectOut\game\brave-cross\work\offline'
$PKG  = 'com.cmn.buatanew'

function sh([string]$cmd, [int]$timeout = 30) {
    $j = Start-Job -ScriptBlock { param($a, $c) & $a -s emulator-5554 shell $c 2>&1 } -ArgumentList $adb, $cmd
    Wait-Job $j -Timeout $timeout | Out-Null
    $o = Receive-Job $j -ErrorAction SilentlyContinue
    Remove-Job $j -Force
    return (($o | Out-String).Trim())
}

if (-not $KhongMo) {
    Write-Output '== mo game =='
    Write-Output (sh "am start -n $PKG/org.kingsoft.com.R1_OLChina" 90)
}

# pid: `pidof` trên toybox bản này trả bừa, phải lọc bằng ps
$pid = ''
for ($i = 0; $i -lt 15; $i++) {
    $line = sh "ps | grep $PKG | grep -v grep"
    if ($line -match '^\s*\S+\s+(\d+)') { $pid = $Matches[1]; break }
    Start-Sleep -Seconds 2
}
if ($pid -eq '') { Write-Output 'KHONG THAY PID — dung'; exit 1 }
Write-Output "pid=$pid"

Write-Output '== gan hook SDK =='
$p1 = Start-Process -FilePath 'python' -ArgumentList '-I', 'chay_trace.py', '--pid', $pid, '--tep', 'be_sdk_spawn_bundle.js', '--giay', '600' -WorkingDirectory "$off\frida" -RedirectStandardOutput "$off\_frida_sdk.out.txt" -RedirectStandardError "$off\_frida_sdk.err.txt" -PassThru
Start-Sleep -Seconds 12
Write-Output ((Get-Content "$off\_frida_sdk.out.txt" -ErrorAction SilentlyContinue) -join "`n")

Write-Output '== gan trace danh =='
$p2 = Start-Process -FilePath 'python' -ArgumentList '-I', 'chay_trace.py', '--pid', $pid, '--tep', 'trace_danh.js', '--giay', "$($Cho + 120)" -WorkingDirectory "$off\frida" -RedirectStandardOutput "$off\_frida_trace.out.txt" -RedirectStandardError "$off\_frida_trace.err.txt" -PassThru

Write-Output "== cho $Cho s =="
Start-Sleep -Seconds $Cho

Write-Output '== offline.log (30 dong cuoi) =='
Write-Output (sh "tail -30 /sdcard/Android/data/$PKG/files/offline.log 2>/dev/null" 45)

Write-Output '== trace (dong moi) =='
$tr = "$off\frida\trace_danh.out.jsonl"
if (Test-Path $tr) {
    $n = (Get-Content $tr | Measure-Object -Line).Lines
    Write-Output "trace_danh.out.jsonl: $n dong"
    Get-Content $tr | Select-Object -Last 8
} else { Write-Output 'chua co trace_danh.out.jsonl' }

Write-Output '== frida stderr =='
Write-Output ((Get-Content "$off\_frida_trace.err.txt" -ErrorAction SilentlyContinue) -join "`n")
Write-Output ((Get-Content "$off\_frida_sdk.err.txt" -ErrorAction SilentlyContinue) -join "`n")
