# _boot_va_chay.ps1 — boot emulator (đã dọn khoá snapshot) rồi CHẠY NGAY một lượt:
#   game -> hook SDK -> trace_danh -> chờ tự đăng nhập + tự vào trận -> in log.
#
# Vì sao gộp: system_server của máy ảo này sống rất ngắn sau khi boot; mỗi vòng
# tay qua Claude là một dịp nó chết. Xem GHI-CHU-TRACE-2026-10-23.md mục 4/4.1.
#
#   powershell -ExecutionPolicy Bypass -File _boot_va_chay.ps1 [-Cho 150]

param([int]$Cho = 150)

$ErrorActionPreference = 'Continue'
$sdk  = 'D:\PROJECT\ProjectOut\android-sdk'
$adb  = "$sdk\platform-tools\adb.exe"
$avd  = 'C:\Users\lvthe\.android\avd\buata.avd'
$off  = 'D:\PROJECT\ProjectOut\game\brave-cross\work\offline'
$log  = "$off\_boot_va_chay.txt"
$PKG  = 'com.cmn.buatanew'

function Ghi($s) { $s | Out-File -FilePath $log -Append -Encoding utf8; Write-Output $s }

'' | Out-File -FilePath $log -Encoding utf8
Ghi "== bat dau $(Get-Date -Format 'HH:mm:ss') =="

# --- dọn tàn dư ---
Get-Process qemu-system-armel-headless,qemu-system-armv7,emulator -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3
foreach ($p in @('hardware-qemu.ini.lock','multiinstance.lock','snapshot.lock.lock','snapshots\default_boot','read-snapshot.txt')) {
    $f = Join-Path $avd $p
    if (Test-Path $f) { Remove-Item $f -Recurse -Force -ErrorAction SilentlyContinue }
}

function sh([string]$cmd, [int]$timeout = 30) {
    $j = Start-Job -ScriptBlock { param($a, $c) & $a -s emulator-5554 shell $c 2>&1 } -ArgumentList $adb, $cmd
    Wait-Job $j -Timeout $timeout | Out-Null
    $o = Receive-Job $j -ErrorAction SilentlyContinue
    Remove-Job $j -Force
    return (($o | Out-String).Trim())
}

# --- boot ---
& $adb kill-server 2>&1 | Out-Null
# -cores 1: TCG nhiều nhân trên guest ARMv7 hay deadlock (system_server futex_wait).
# -prop ro.hw_timeout_multiplier=10: Watchdog Android 6 nhân hệ số — chống bị giết
#   vì boot chậm trên máy ảo.
$p = Start-Process -FilePath "$sdk\emulator\emulator.exe" -ArgumentList '-avd','buata','-no-window','-no-boot-anim','-gpu','host','-no-snapshot','-cores','1','-memory','2048','-prop','ro.hw_timeout_multiplier=10' -WorkingDirectory "$sdk\emulator" -RedirectStandardOutput "$off\_emu_boot_lan.log" -RedirectStandardError "$off\_emu_boot_lan.err" -PassThru
Ghi "emulator pid=$($p.Id)"

$boot = ''
for ($i = 0; $i -lt 120; $i++) {
    $boot = sh "getprop sys.boot_completed" 15
    if ($boot -eq '1') { Ghi "BOOT OK sau ~$([int]($i*15))s"; break }
    Start-Sleep -Seconds 10
}
if ($boot -ne '1') { Ghi "HET GIO boot='$boot'"; exit 1 }

# --- frida-server ---
Ghi '== bat frida-server =='
$fs = Start-Process -FilePath $adb -ArgumentList '-s','emulator-5554','shell','/data/local/tmp/frida-server' -RedirectStandardOutput "$off\_frida_server3.out.txt" -RedirectStandardError "$off\_frida_server3.err.txt" -PassThru
Start-Sleep -Seconds 4
Ghi (sh "ps | grep frida-server | grep -v grep" 20)

# --- mo game (system_server có thể chưa sẵn sàng ngay sau boot -> thử lại) ---
Ghi '== mo game =='
$mo = ''
for ($i = 0; $i -lt 20; $i++) {
    $mo = sh "am start -n $PKG/org.kingsoft.com.R1_OLChina" 90
    if ($mo -notmatch "Can't connect") { break }
    Ghi "  am chua san sang (lan $($i+1))"
    Start-Sleep -Seconds 8
}
Ghi $mo

$pid = ''
for ($i = 0; $i -lt 20; $i++) {
    $line = sh "ps | grep $PKG | grep -v grep" 20
    if ($line -match '^\s*\S+\s+(\d+)') { $pid = $Matches[1]; break }
    Start-Sleep -Seconds 2
}
if ($pid -eq '') { Ghi 'KHONG THAY PID — dung'; exit 1 }
Ghi "pid=$pid"

# --- hook SDK (Java) ---
Ghi '== hook SDK =='
Start-Process -FilePath 'python' -ArgumentList '-I','chay_trace.py','--pid',$pid,'--tep','be_sdk_spawn_bundle.js','--giay','900' -WorkingDirectory "$off\frida" -RedirectStandardOutput "$off\_frida_sdk.out.txt" -RedirectStandardError "$off\_frida_sdk.err.txt" | Out-Null
Start-Sleep -Seconds 10
Ghi ((Get-Content "$off\_frida_sdk.out.txt" -ErrorAction SilentlyContinue) -join "`n")

# --- hook trace (native) ---
Ghi '== hook trace =='
Start-Process -FilePath 'python' -ArgumentList '-I','chay_trace.py','--pid',$pid,'--tep','trace_danh.js','--giay',"$($Cho+300)" -WorkingDirectory "$off\frida" -RedirectStandardOutput "$off\_frida_trace.out.txt" -RedirectStandardError "$off\_frida_trace.err.txt" | Out-Null
Start-Sleep -Seconds 5
Ghi ((Get-Content "$off\_frida_trace.out.txt" -ErrorAction SilentlyContinue) -join "`n")

Ghi "== cho $Cho s =="
Start-Sleep -Seconds $Cho

Ghi '== offline.log =='
Ghi (sh "tail -40 /sdcard/Android/data/$PKG/files/offline.log 2>/dev/null" 45)
Ghi '== trace =='
$tr = "$off\frida\trace_danh.out.jsonl"
if (Test-Path $tr) {
    Ghi ("trace: " + (Get-Content $tr | Measure-Object -Line).Lines + " dong")
    Ghi ((Get-Content $tr | Select-Object -Last 6) -join "`n")
} else { Ghi 'chua co trace_danh.out.jsonl' }
Ghi '== stderr =='
Ghi ((Get-Content "$off\_frida_trace.err.txt" -ErrorAction SilentlyContinue) -join "`n")
Ghi ((Get-Content "$off\_frida_sdk.err.txt" -ErrorAction SilentlyContinue) -join "`n")
Ghi "== xong $(Get-Date -Format 'HH:mm:ss') =="
