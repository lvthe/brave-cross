# _sau_boot.ps1 — chờ emulator ARM boot xong rồi dựng lại môi trường bản gốc:
#   OBB 208 MB + lớp offline + bật cờ gỡ lỗi + mở game.
# (Lượt trước kill emulator giữa boot làm mất /sdcard ⇒ phải đẩy lại.)
$ErrorActionPreference = 'Continue'
$sdk  = 'D:\PROJECT\ProjectOut\android-sdk'
$adb  = "$sdk\platform-tools\adb.exe"
$env:PATH = "$sdk\platform-tools;$env:PATH"
$env:ANDROID_SDK_ROOT = $sdk
$env:ANDROID_HOME = $sdk
$dev = 'emulator-5554'
$offline = 'D:\PROJECT\ProjectOut\game\brave-cross\work\offline'
$obb = "$offline\apk-vn\main.81485.com.cmn.buatanew.obb"

function sh([string]$cmd, [int]$timeout = 120) {
  $j = Start-Job -ScriptBlock { param($a, $d, $c) & $a -s $d shell $c 2>&1 } -ArgumentList $adb, $dev, $cmd
  Wait-Job $j -Timeout $timeout | Out-Null
  $o = Receive-Job $j
  Remove-Job $j -Force
  return ($o | Out-String)
}

Write-Output "== cho boot =="
$boot = ''
for ($i = 0; $i -lt 120; $i++) {
  $boot = (sh "getprop sys.boot_completed" 40).Trim()
  if ($boot -eq '1') { Write-Output "BOOT OK sau ~$($i*15)s"; break }
  Start-Sleep -Seconds 15
}
if ($boot -ne '1') { Write-Output "HET GIO cho boot (boot='$boot')"; exit 1 }

Write-Output "== day OBB =="
sh "mkdir -p /sdcard/Android/obb/com.cmn.buatanew" 60 | Out-Null
$r = & $adb -s $dev push $obb /sdcard/Android/obb/com.cmn.buatanew/ 2>&1
Write-Output ($r | Out-String)
Write-Output (sh "ls -l /sdcard/Android/obb/com.cmn.buatanew" 60)

Write-Output "== day lop offline =="
Push-Location $offline
$p = & python -I deploy.py --push 2>&1
Write-Output ($p | Out-String)
Pop-Location

Write-Output "== mo game =="
Write-Output (sh "am start -n com.cmn.buatanew/org.kingsoft.com.R1_OLChina" 180)

Write-Output "== doi 60s roi doc log offline =="
Start-Sleep -Seconds 60
Write-Output (sh "cat /sdcard/Android/data/com.cmn.buatanew/files/offline.log 2>/dev/null | tail -40" 90)
Write-Output (sh "ps | grep com.cmn" 60)
