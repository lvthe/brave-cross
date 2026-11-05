@echo off
rem ===========================================================================
rem  mo_game.cmd - MO GAME TREN LDPLAYER QUA CAU FRIDA
rem
rem  VI SAO CAN CAU NAY: panel dang nhap cua Kull SDK (Facebook) da chet
rem  (apisdk.kul.vn khong con). Bam icon game se DUNG o panel do, khong bam
rem  duoc gi. Cau nay gia lap Userxsdk.login de bo qua panel; sau do lop
rem  offline tu dang nhap bang tai khoan o duoi.
rem
rem  DIEU KIEN: LDPlayer dang chay; Docker Desktop + Postgres dang chay.
rem  Script tu bat server :8787 neu no chua chay.
rem
rem  DOI TAI KHOAN: sua hai dong TAIKHOAN / MATKHAU ben duoi.
rem  (Mat khau nam trong tep nay - chi dung tren may dev.)
rem ===========================================================================
setlocal
set "ADB=C:\LDPlayer\LDPlayer9\adb.exe"
set "GAME=com.cmn.buatanew"
set "OFF=%~dp0"
set "SERVER=%~dp0..\..\..\bravecross-server"
set "FILES=/data/user/0/%GAME%/files"

if not defined TAIKHOAN  set "TAIKHOAN=tk_ui_1793715945@example.com"
if not defined MATKHAU   set "MATKHAU=123456"
if not defined BX_GIAY    set "BX_GIAY=86400"

echo [1/5] Kiem LDPlayer...
"%ADB%" devices | findstr /C:"device" >nul
if errorlevel 1 (
  echo    KHONG thay may ao. Bat LDPlayer roi chay lai.
  pause
  exit /b 1
)

echo [2/5] Kiem server :8787...
curl -s -m 2 http://127.0.0.1:8787/api/health | findstr /C:"ok" >nul
if errorlevel 1 (
  echo    server chua chay - mo cua so server...
  start "BC server" /d "%SERVER%" cmd /k "npx tsx src/index.ts"
  timeout /t 6 /nobreak >nul
) else (
  echo    server dang chay.
)

echo [3/5] adb root + frida-server...
"%ADB%" root >nul 2>&1
"%ADB%" wait-for-device
timeout /t 2 /nobreak >nul
"%ADB%" shell "pkill -f frida-server" >nul 2>&1
"%ADB%" shell "nohup /data/local/tmp/frida-server >/dev/null 2>&1 &"
rem CHO frida-server THAT SU LEN (sau reboot 2 giay la chua du -> driver mat ket noi)
set /a DEM=0
:cho_frida
"%ADB%" shell "ps -A | grep -q frida-server" >nul 2>&1
if not errorlevel 1 goto frida_ok
set /a DEM+=1
if %DEM% GEQ 20 goto frida_hong
timeout /t 1 /nobreak >nul
goto cho_frida
:frida_hong
echo    KHONG khoi dong duoc frida-server (/data/local/tmp/frida-server).
pause
exit /b 1
:frida_ok
timeout /t 2 /nobreak >nul
echo    frida-server da chay.

echo [4/5] Dong game cu + dien san tai khoan...
"%ADB%" shell am force-stop %GAME%
"%ADB%" shell "printf '%TAIKHOAN%\n%MATKHAU%\n' > %FILES%/dangnhap_cu.txt"
"%ADB%" shell "echo -n '' > %FILES%/dangnhap_cu_test.flag"
"%ADB%" shell "chmod 644 %FILES%/dangnhap_cu.txt %FILES%/dangnhap_cu_test.flag"
rem CHE DO NGUOI CHOI: khong de tu_dong dong huong dan tan thu
"%ADB%" shell "echo -n '' > %FILES%/nguoi_choi.flag"
"%ADB%" shell "chmod 644 %FILES%/nguoi_choi.flag"

echo [5/5] Mo game + hook SDK de bo qua panel Facebook...
echo        (giu cua so nay mo trong khi choi; dong cua so KHONG tat game)
pushd "%OFF%"
python -I -u "frida\chay_trace.py" --spawn --tep be_sdk_spawn_bundle.js --giay %BX_GIAY%
popd
rem Xoa co che do nguoi choi (de bo test sau khong bi anh huong)
"%ADB%" shell "rm -f %FILES%/nguoi_choi.flag" >nul 2>&1

echo.
echo Driver da thoat. Game van chay - co the thu nho cua so nay.
pause
