@echo off
rem ===========================================================================
rem  tao_tai_khoan.cmd - TAO TAI KHOAN EMAIL/MAT KHAU (thay cho Facebook).
rem
rem  Vi sao khong phai Facebook: SDK Kull cua game goi server rieng cua ho
rem  (apisdk.kul.vn) da chet - khong co backend de xac thuc Facebook. Tai khoan
rem  cua ban dung diem nay nam trong Postgres cua server rieng.
rem
rem  Dung:  tao_tai_khoan.cmd email@example.com matkhau
rem  Sau do mo game bang mo_game.cmd (sua TAIKHOAN / MATKHAU trong tep do).
rem ===========================================================================
setlocal
if "%~1"=="" goto huongdan
if "%~2"=="" goto huongdan
python -I "%~dp0tao_tai_khoan.py" "%~1" "%~2"
goto het

:huongdan
echo Cach dung: tao_tai_khoan.cmd email@example.com matkhau
echo (server phai dang chay o cong 8787)

:het
pause
