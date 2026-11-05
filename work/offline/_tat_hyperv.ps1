# _tat_hyperv.ps1 - tat Hyper-V + Memory Integrity (can quyen Admin), roi phai reboot.
#
#   powershell -ExecutionPolicy Bypass -File _tat_hyperv.ps1
#
# Bat lai sau nay:
#   bcdedit /set hypervisorlaunchtype auto
#   Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' -Name Enabled -Value 1
#   + reboot

$log = 'D:\PROJECT\ProjectOut\game\brave-cross\work\offline\_tat_hyperv.txt'
'' | Out-File -FilePath $log -Encoding utf8
function Ghi($s) { $s | Out-File -FilePath $log -Append -Encoding utf8 }

Ghi "== tat Hyper-V + VBS $(Get-Date -Format 'HH:mm:ss') =="

$o = bcdedit /set hypervisorlaunchtype off 2>&1
Ghi ("bcdedit hypervisorlaunchtype off -> " + (($o | Out-String).Trim()))

$k = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity'
try {
    Set-ItemProperty -Path $k -Name Enabled -Value 0 -Type DWord -ErrorAction Stop
    Ghi 'Memory Integrity (HVCI) Enabled -> 0'
} catch { Ghi "HVCI loi: $($_.Exception.Message)" }

$dg = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'
try {
    Set-ItemProperty -Path $dg -Name EnableVirtualizationBasedSecurity -Value 0 -Type DWord -ErrorAction Stop
    Ghi 'VBS EnableVirtualizationBasedSecurity -> 0'
} catch { Ghi "VBS loi: $($_.Exception.Message)" }

Ghi '-- kiem lai --'
Ghi ((bcdedit /enum '{current}' 2>&1 | Select-String 'hypervisorlaunchtype' | Out-String).Trim())
Ghi '== xong, hay KHOI DONG LAI MAY =='
