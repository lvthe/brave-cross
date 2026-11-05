# _vong_trace.ps1 - thu boot -> chay _trace_vitri.ps1, lap lai toi 3 lan.
#
# Vi sao can vong: may ao ARM nay chi boot qua duoc ~50% so lan, va kieu hong rat deu
# (system_server dung o MDnsSdListener). Moi lan boot ~8-12 phut, nen phai de may tu
# thu lai thay vi ngoi bam tay.
#
#   powershell -ExecutionPolicy Bypass -File _vong_trace.ps1

$ErrorActionPreference = 'Continue'
$sdk = 'D:\PROJECT\ProjectOut\android-sdk'
$adb = "$sdk\platform-tools\adb.exe"
$avd = 'C:\Users\lvthe\.android\avd\buata.avd'
$off = 'D:\PROJECT\ProjectOut\game\brave-cross\work\offline'
$log = "$off\_vong_trace.txt"

function Ghi($s) { $s | Out-File -FilePath $log -Append -Encoding utf8; Write-Output $s }
'' | Out-File -FilePath $log -Encoding utf8

function sh([string]$cmd, [int]$timeout = 20) {
    $j = Start-Job -ScriptBlock { param($a, $c) & $a -s emulator-5554 shell $c 2>&1 } -ArgumentList $adb, $cmd
    Wait-Job $j -Timeout $timeout | Out-Null
    $o = Receive-Job $j -ErrorAction SilentlyContinue
    Remove-Job $j -Force
    return (($o | Out-String).Trim())
}

for ($lan = 1; $lan -le 3; $lan++) {
    Ghi "== LAN $lan $(Get-Date -Format 'HH:mm:ss') =="
    Get-Process qemu-system-armel-headless,qemu-system-armel,emulator -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 4
    foreach ($p in @('hardware-qemu.ini.lock','multiinstance.lock','snapshot.lock.lock','snapshots\default_boot','read-snapshot.txt')) {
        $f = Join-Path $avd $p
        if (Test-Path $f) { Remove-Item $f -Recurse -Force -ErrorAction SilentlyContinue }
    }
    & $adb kill-server 2>&1 | Out-Null
    Start-Process -FilePath "$sdk\emulator\emulator.exe" -ArgumentList '-avd','buata','-no-window','-no-boot-anim','-gpu','host','-no-snapshot' -WorkingDirectory "$sdk\emulator" -RedirectStandardOutput "$off\_emu_v$lan.log" -RedirectStandardError "$off\_emu_v$lan.err" | Out-Null

    $boot = ''
    for ($i = 0; $i -lt 70; $i++) {
        $boot = sh "getprop sys.boot_completed" 12
        if ($boot -eq '1') { break }
        Start-Sleep -Seconds 10
    }
    Ghi "boot='$boot' sau ~$([int]($i*10))s"

    $pm = ''
    if ($boot -eq '1') {
        for ($i = 0; $i -lt 24; $i++) {
            $pm = sh "pm path android" 30
            if ($pm -match '^package:') { break }
            Start-Sleep -Seconds 10
        }
    }
    Ghi "pm='$($pm -replace "`n",' ')'"

    if ($boot -eq '1' -and $pm -match '^package:') {
        Ghi "LAN $lan BOOT+PM OK -> chay trace"
        & powershell -ExecutionPolicy Bypass -File "$off\_trace_vitri.ps1" -Cho 300
        Ghi "== LAN $lan xong $(Get-Date -Format 'HH:mm:ss') =="
        break
    }
    Ghi "LAN $lan HONG (boot=$boot pm=$pm) -> thu lai"
}
Ghi "== KET THUC $(Get-Date -Format 'HH:mm:ss') =="
