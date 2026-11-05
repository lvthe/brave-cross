# _trace_vitri.ps1 - boot (neu chua) roi CHAY MOT LUOT DO CHO DUNG/DUONG DI tren ban goc.
#
# Khac _boot_va_chay.ps1 o hai cho:
#   * gan trace_vitri.js (vi tri + dan tran) thay trace_danh.js (hit-box);
#   * day lop offline len may truoc (deploy.py --push) de tu_dong + vao_tran tu dang
#     nhap va tu vao tran - khong phai cham man hinh.
#
#   powershell -ExecutionPolicy Bypass -File _trace_vitri.ps1 [-Cho 300]
#
# TEP NAY CHI ASCII: PowerShell 5.1 doc tep .ps1 khong BOM theo bang ma ANSI, nen mot
# dau gach dai hay chu co dau se lam vo chuoi va script khong parse duoc.

param([int]$Cho = 300)

$ErrorActionPreference = 'Continue'
$sdk = 'D:\PROJECT\ProjectOut\android-sdk'
$adb = "$sdk\platform-tools\adb.exe"
$off = 'D:\PROJECT\ProjectOut\game\brave-cross\work\offline'
$log = "$off\_trace_vitri.txt"
$PKG = 'com.cmn.buatanew'
$env:ADB = $adb

function Ghi($s) { $s | Out-File -FilePath $log -Append -Encoding utf8; Write-Output $s }

'' | Out-File -FilePath $log -Encoding utf8
Ghi "== bat dau $(Get-Date -Format 'HH:mm:ss') =="

function sh([string]$cmd, [int]$timeout = 30) {
    $j = Start-Job -ScriptBlock { param($a, $c) & $a -s emulator-5554 shell $c 2>&1 } -ArgumentList $adb, $cmd
    Wait-Job $j -Timeout $timeout | Out-Null
    $o = Receive-Job $j -ErrorAction SilentlyContinue
    Remove-Job $j -Force
    return (($o | Out-String).Trim())
}

# --- cho boot ---
$boot = ''
for ($i = 0; $i -lt 90; $i++) {
    $boot = sh "getprop sys.boot_completed" 15
    if ($boot -eq '1') { Ghi "BOOT OK (~$([int]($i*10))s)"; break }
    Start-Sleep -Seconds 10
}
if ($boot -ne '1') { Ghi "HET GIO boot='$boot' - dung"; exit 1 }

# --- Package Manager (co the chet roi init khoi dong lai, rat cham) ---
$pm = ''
for ($i = 0; $i -lt 80; $i++) {
    $pm = sh "pm path android 2>&1" 40
    if ($pm -match '^package:') {
        $inst = sh "pm list packages 2>&1 | grep $PKG" 40
        if ($inst -match $PKG) { $pm = $inst }
        break
    }
    if ($i % 4 -eq 0) { Ghi "  pm chua san sang (lan $($i+1))" }
    Start-Sleep -Seconds 10
}
Ghi "package: $pm"

# --- cai lai neu thieu (APK + OBB) ---
if ($pm -notmatch $PKG) {
    Ghi '== CHUA CAI - cai APK =='
    $o = & $adb -s emulator-5554 install -r -g "$off\apk-vn\com.cmn.buatanew.apk" 2>&1
    Ghi (($o | Out-String).Trim())
    Ghi '== push OBB =='
    sh "mkdir -p /sdcard/Android/obb/$PKG" 30 | Out-Null
    $o = & $adb -s emulator-5554 push "$off\apk-vn\main.81485.com.cmn.buatanew.obb" "/sdcard/Android/obb/$PKG/main.81485.com.cmn.buatanew.obb" 2>&1
    Ghi (($o | Out-String).Trim())
}

# --- day lop offline (tu_dong + vao_tran) ---
Ghi '== deploy --push =='
try {
    $o = & python -I deploy.py --push 2>&1
    Ghi (($o | Out-String).Trim())
} catch { Ghi "deploy loi: $_" }

# --- frida-server ---
Ghi '== frida-server =='
$fs = sh "ls /data/local/tmp/frida-server 2>&1" 20
if ($fs -notmatch 'frida-server') {
    Ghi '  chua co frida-server - push'
    $o = & $adb -s emulator-5554 push "$offridarida-server" "/data/local/tmp/frida-server" 2>&1
    Ghi (($o | Out-String).Trim())
    sh "chmod 755 /data/local/tmp/frida-server" 20 | Out-Null
}
Start-Process -FilePath $adb -ArgumentList '-s','emulator-5554','shell','/data/local/tmp/frida-server' -RedirectStandardOutput "$off\_frida_vitri_srv.out.txt" -RedirectStandardError "$off\_frida_vitri_srv.err.txt" | Out-Null
Start-Sleep -Seconds 4
Ghi (sh "ps | grep frida-server | grep -v grep" 20)

# --- mo game ---
Ghi '== am start =='
$mo = ''
for ($i = 0; $i -lt 12; $i++) {
    $mo = sh "am start -n $PKG/org.kingsoft.com.R1_OLChina" 90
    if ($mo -notmatch "Can't connect|Could not access") { break }
    Ghi "  am chua san sang (lan $($i+1))"
    Start-Sleep -Seconds 8
}
Ghi $mo

$pid2 = ''
for ($i = 0; $i -lt 25; $i++) {
    $line = sh "ps | grep $PKG | grep -v grep" 20
    if ($line -match '^\s*\S+\s+(\d+)') { $pid2 = $Matches[1]; break }
    Start-Sleep -Seconds 2
}
if ($pid2 -eq '') { Ghi 'KHONG THAY PID - dung'; exit 1 }
Ghi "pid=$pid2"

# --- hook SDK (Java, bundle) ---
Ghi '== hook SDK =='
Start-Process -FilePath 'python' -ArgumentList '-I','chay_trace.py','--pid',$pid2,'--tep','be_sdk_spawn_bundle.js','--giay','1200' -WorkingDirectory "$off\frida" -RedirectStandardOutput "$off\_frida_vitri_sdk.out.txt" -RedirectStandardError "$off\_frida_vitri_sdk.err.txt" | Out-Null
Start-Sleep -Seconds 12
Ghi ((Get-Content "$off\_frida_vitri_sdk.out.txt" -ErrorAction SilentlyContinue) -join "`n")

# --- hook vi tri (native) ---
Ghi '== hook vi tri =='
Start-Process -FilePath 'python' -ArgumentList '-I','chay_trace.py','--pid',$pid2,'--tep','trace_vitri.js','--giay',"$($Cho+240)" -WorkingDirectory "$off\frida" -RedirectStandardOutput "$off\_frida_vitri.out.txt" -RedirectStandardError "$off\_frida_vitri.err.txt" | Out-Null
Start-Sleep -Seconds 8
Ghi ((Get-Content "$off\_frida_vitri.out.txt" -ErrorAction SilentlyContinue) -join "`n")

Ghi "== cho $Cho s =="
Start-Sleep -Seconds $Cho

Ghi '== offline.log =='
Ghi (sh "tail -30 /sdcard/Android/data/$PKG/files/sc/offline.log 2>/dev/null" 45)
Ghi (sh "tail -20 /sdcard/Android/data/$PKG/files/offline.log 2>/dev/null" 45)
Ghi '== trace =='
$tr = "$off\frida\trace_danh.out.jsonl"
if (Test-Path $tr) {
    Ghi ("trace: " + (Get-Content $tr | Measure-Object -Line).Lines + " dong")
    Ghi ((Get-Content $tr | Select-Object -Last 8) -join "`n")
} else { Ghi 'chua co trace_danh.out.jsonl' }
Ghi '== stderr =='
Ghi ((Get-Content "$off\_frida_vitri.err.txt" -ErrorAction SilentlyContinue) -join "`n")
Ghi ((Get-Content "$off\_frida_vitri_sdk.err.txt" -ErrorAction SilentlyContinue) -join "`n")
Ghi "== xong $(Get-Date -Format 'HH:mm:ss') =="
