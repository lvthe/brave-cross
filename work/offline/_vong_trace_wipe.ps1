# _vong_trace_wipe.ps1 - nhu _vong_trace.ps1 nhung boot bang -wipe-data (userdata sach).
#
# Dung khi may ao roi vao VONG boot: init dung zygote -> system_server chet -> init
# khoi dong lai, `sys.boot_completed` khong bao gio bang 1. /data ban sau nhieu lan
# kill cung la gia thiet hop ly nhat.
#
#   powershell -ExecutionPolicy Bypass -File _vong_trace_wipe.ps1

$ErrorActionPreference = 'Continue'
$sdk = 'D:\PROJECT\ProjectOut\android-sdk'
$adb = "$sdk\platform-tools\adb.exe"
$avd = 'C:\Users\lvthe\.android\avd\buata.avd'
$off = 'D:\PROJECT\ProjectOut\game\brave-cross\work\offline'
$log = "$off\_vong_trace_wipe.txt"

function Ghi($s) { $s | Out-File -FilePath $log -Append -Encoding utf8; Write-Output $s }
'' | Out-File -FilePath $log -Encoding utf8

function sh([string]$cmd, [int]$timeout = 20) {
    $j = Start-Job -ScriptBlock { param($a, $c) & $a -s emulator-5554 shell $c 2>&1 } -ArgumentList $adb, $cmd
    Wait-Job $j -Timeout $timeout | Out-Null
    $o = Receive-Job $j -ErrorAction SilentlyContinue
    Remove-Job $j -Force
    return (($o | Out-String).Trim())
}

Ghi "== WIPE $(Get-Date -Format 'HH:mm:ss') =="
Get-Process qemu-system-armel-headless,qemu-system-armel,emulator -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 4
foreach ($p in @('hardware-qemu.ini.lock','multiinstance.lock','snapshot.lock.lock','snapshots\default_boot','read-snapshot.txt')) {
    $f = Join-Path $avd $p
    if (Test-Path $f) { Remove-Item $f -Recurse -Force -ErrorAction SilentlyContinue }
}
& $adb kill-server 2>&1 | Out-Null
Start-Process -FilePath "$sdk\emulator\emulator.exe" -ArgumentList '-avd','buata','-no-window','-no-boot-anim','-gpu','host','-no-snapshot','-wipe-data' -WorkingDirectory "$sdk\emulator" -RedirectStandardOutput "$off\_emu_wipe.log" -RedirectStandardError "$off\_emu_wipe.err" | Out-Null

$boot = ''
for ($i = 0; $i -lt 90; $i++) {
    $boot = sh "getprop sys.boot_completed" 12
    if ($boot -eq '1') { break }
    Start-Sleep -Seconds 10
}
Ghi "boot='$boot' sau ~$([int]($i*10))s"

$pm = ''
if ($boot -eq '1') {
    for ($i = 0; $i -lt 30; $i++) {
        $pm = sh "pm path android" 30
        if ($pm -match '^package:') { break }
        Start-Sleep -Seconds 10
    }
}
Ghi "pm='$($pm -replace "`n",' ')'"

if ($boot -eq '1' -and $pm -match '^package:') {
    Ghi 'BOOT+PM OK sau WIPE -> chay trace'
    & powershell -ExecutionPolicy Bypass -File "$off\_trace_vitri.ps1" -Cho 300
} else {
    Ghi 'WIPE VAN HONG - dung'
}
Ghi "== KET THUC $(Get-Date -Format 'HH:mm:ss') =="
