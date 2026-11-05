# _ldplayer_trace.ps1 - chay game GOC tren LDPlayer (x86 + ARM translation) roi trace
# CHO DUNG / DUONG DI. Dung sau khi da tat Hyper-V va reboot.
#
#   powershell -ExecutionPolicy Bypass -File _ldplayer_trace.ps1 [-Cho 300]
#
# Vi sao LDPlayer: may ao ARM cua Android SDK chi boot qua ~50% va system_server chet
# sau ~5-9 phut (xem GHI-CHU-TRACE-2026-10-26.md). LDPlayer 9 chay x86_64 + dich ARM,
# co ROOT san nen frida-server chay duoc.
#
# TEP NAY CHI ASCII (PS 5.1 doc .ps1 khong BOM theo ANSI).

param([int]$Cho = 300)

$ErrorActionPreference = 'Continue'
$ld   = 'C:\LDPlayer\LDPlayer9'
$adb  = "$ld\adb.exe"
$off  = 'D:\PROJECT\ProjectOut\game\brave-cross\work\offline'
$log  = "$off\_ld_trace.txt"
$PKG  = 'com.cmn.buatanew'
$env:ADB = $adb

function Ghi($s) { $s | Out-File -FilePath $log -Append -Encoding utf8; Write-Output $s }
'' | Out-File -FilePath $log -Encoding utf8
Ghi "== LDPlayer trace $(Get-Date -Format 'HH:mm:ss') =="

function sh([string]$cmd, [int]$timeout = 30) {
    $j = Start-Job -ScriptBlock { param($a, $c) & $a shell $c 2>&1 } -ArgumentList $adb, $cmd
    Wait-Job $j -Timeout $timeout | Out-Null
    $o = Receive-Job $j -ErrorAction SilentlyContinue
    Remove-Job $j -Force
    return (($o | Out-String).Trim())
}

# --- bat may ao + root ---
Ghi '== bat LDPlayer (root=1) =='
& "$ld\ldconsole.exe" modify --index 0 --root 1 2>&1 | Out-Null
& "$ld\ldconsole.exe" launch --index 0 2>&1 | Out-Null

$dev = ''
for ($i = 0; $i -lt 60; $i++) {
    $o = & $adb devices 2>&1 | Out-String
    $m = [regex]::Match($o, '(emulator-\d+|127\.0\.0\.1:\d+)\s+device')
    if ($m.Success) { $dev = $m.Groups[1].Value; break }
    Start-Sleep -Seconds 5
}
if ($dev -eq '') { Ghi 'KHONG THAY DEVICE cua LDPlayer - dung'; exit 1 }
Ghi "device=$dev"

$boot = ''
for ($i = 0; $i -lt 60; $i++) {
    $boot = sh "getprop sys.boot_completed" 20
    if ($boot -eq '1') { break }
    Start-Sleep -Seconds 5
}
Ghi "boot='$boot'"
if ($boot -ne '1') { Ghi 'CHUA BOOT XONG - dung'; exit 1 }

Ghi '== ABI (can co armeabi-v7a de chay game) =='
Ghi (sh "getprop ro.product.cpu.abilist; getprop ro.product.cpu.abi; getprop ro.build.version.release; getprop ro.build.version.sdk" 25)

Ghi '== root =='
Ghi (sh "id" 20)
& $adb root 2>&1 | Out-Null
Start-Sleep -Seconds 2
Ghi (sh "id" 20)

# --- cai APK + OBB neu thieu ---
$co = sh "pm list packages 2>&1 | grep $PKG" 40
if ($co -notmatch $PKG) {
    Ghi '== cai APK =='
    $o = & $adb install -r -g "$off\apk-vn\com.cmn.buatanew.apk" 2>&1
    Ghi (($o | Out-String).Trim())
    Ghi '== push OBB =='
    sh "mkdir -p /sdcard/Android/obb/$PKG" 30 | Out-Null
    $o = & $adb push "$off\apk-vn\main.81485.com.cmn.buatanew.obb" "/sdcard/Android/obb/$PKG/main.81485.com.cmn.buatanew.obb" 2>&1
    Ghi (($o | Out-String).Trim())
}
Ghi '== kiem OBB =='
Ghi (sh "ls -l /sdcard/Android/obb/$PKG/ 2>&1" 30)

# --- lop offline ---
Ghi '== deploy --push =='
try { Ghi (((& python -I deploy.py --push 2>&1) | Out-String).Trim()) } catch { Ghi "deploy loi: $_" }

# --- frida-server (BAN ARM: tien trinh game la ARM duoc dich) ---
Ghi '== frida-server =='
$fs = sh "ls -l /data/local/tmp/frida-server 2>&1" 20
if ($fs -notmatch 'frida-server') {
    $o = & $adb push "$off\frida\frida-server" "/data/local/tmp/frida-server" 2>&1
    Ghi (($o | Out-String).Trim())
    sh "chmod 755 /data/local/tmp/frida-server" 20 | Out-Null
}
Start-Process -FilePath $adb -ArgumentList 'shell','/data/local/tmp/frida-server' -RedirectStandardOutput "$off\_ld_fs.out.txt" -RedirectStandardError "$off\_ld_fs.err.txt" | Out-Null
Start-Sleep -Seconds 5
Ghi (sh "ps | grep frida-server | grep -v grep" 20)

# --- chay game ---
Ghi '== mo game =='
Ghi (sh "am start -n $PKG/org.kingsoft.com.R1_OLChina" 90)

$pid2 = ''
for ($i = 0; $i -lt 40; $i++) {
    $line = sh "ps | grep $PKG | grep -v grep" 20
    if ($line -match '^\s*\S+\s+(\d+)') { $pid2 = $Matches[1]; break }
    Start-Sleep -Seconds 2
}
if ($pid2 -eq '') { Ghi 'KHONG THAY PID - dung'; exit 1 }
Ghi "pid=$pid2"

Ghi '== hook SDK =='
Start-Process -FilePath 'python' -ArgumentList '-I','chay_trace.py','--pid',$pid2,'--tep','be_sdk_spawn_bundle.js','--giay','1800' -WorkingDirectory "$off\frida" -RedirectStandardOutput "$off\_ld_sdk.out.txt" -RedirectStandardError "$off\_ld_sdk.err.txt" | Out-Null
Start-Sleep -Seconds 12
Ghi ((Get-Content "$off\_ld_sdk.out.txt" -ErrorAction SilentlyContinue) -join "`n")

Ghi '== hook vi tri =='
Start-Process -FilePath 'python' -ArgumentList '-I','chay_trace.py','--pid',$pid2,'--tep','trace_vitri.js','--giay',"$($Cho+600)" -WorkingDirectory "$off\frida" -RedirectStandardOutput "$off\_ld_vitri.out.txt" -RedirectStandardError "$off\_ld_vitri.err.txt" | Out-Null
Start-Sleep -Seconds 10
Ghi ((Get-Content "$off\_ld_vitri.out.txt" -ErrorAction SilentlyContinue) -join "`n")

Ghi "== cho $Cho s =="
Start-Sleep -Seconds $Cho

Ghi '== offline log =='
Ghi (sh "tail -30 /sdcard/Android/data/$PKG/files/sc/offline.log 2>/dev/null" 40)
Ghi (sh "tail -20 /sdcard/Android/data/$PKG/files/offline.log 2>/dev/null" 40)
Ghi '== trace =='
$tr = "$off\frida\trace_danh.out.jsonl"
if (Test-Path $tr) {
    Ghi ("trace: " + (Get-Content $tr | Measure-Object -Line).Lines + " dong")
    Ghi ((Get-Content $tr | Select-Object -Last 8) -join "`n")
} else { Ghi 'chua co trace_danh.out.jsonl' }
Ghi '== stderr =='
Ghi ((Get-Content "$off\_ld_vitri.err.txt" -ErrorAction SilentlyContinue) -join "`n")
Ghi ((Get-Content "$off\_ld_sdk.err.txt" -ErrorAction SilentlyContinue) -join "`n")
Ghi "== xong $(Get-Date -Format 'HH:mm:ss') =="
