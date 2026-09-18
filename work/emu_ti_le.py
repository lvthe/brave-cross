# -*- coding: utf-8 -*-
"""Đo hệ số 1,02 thuộc NODE NÀO trong bản gốc — chạy trong máy ảo (bản vn).

    python emu_ti_le.py [--han 240] [--cai]

Vì sao: `_lua_getBonePosInNode` / `_lua_getBoneRectInNode` khi tham số 2 là một
đối tượng do `getSpriteFromSpriteCatch` trả về thì lệch hệ số **1,02** so với khi
tham số 2 là node Cocos THƯỜNG (`emu_xuong.py` mục C/G đã đo: hiệu hai lần đặt
node đích là `-(137,26, 42,16)` so với `-(140, 43)`). Chưa biết 1,02 nằm ở đâu, và
`getScale`/`setScale` đều GIẾT CẢ TIẾN TRÌNH (pcall không đo được lỗi native), nên
không đọc thẳng ra được.

PHÉP ĐO NÀY TÁCH ĐƯỢC, không cần đọc tỉ lệ:

  * Dời node đích đi cùng một quãng `dP` rồi lấy hiệu hai kết quả. Công thức là
    `inv(dich) * nguon:to_global(v)`, và độ dời nằm BÊN TRONG phép đổi của chính
    node đích (`T(p) . R . S`), nên **hiệu = `dP / tỉ lệ CỦA CHÍNH node đích`** —
    tỉ lệ của các node CHA KHÔNG đi vào hiệu (chúng là một hệ số chung cho cả hai
    lần đặt, nên triệt tiêu; đó là chỗ dễ đọc sai nhất, và đã đọc sai một lần: xem
    `tools/verify_xuong.gd`, phép đo trên rig CON ra đúng `-(140, 43)` vì rig con
    tỉ lệ 1,00, dù cha nó tỉ lệ 1,02).
  * Đối tượng bắt được (wrapper) và CON của nó (rig) là HAI node lồng nhau, mỗi
    node có tỉ lệ RIÊNG của nó — nên phép đo trên từng node nói ra tỉ lệ của chính
    node ấy. Đối tượng bắt được thì có 0 con (đo được), nên nhánh này không dùng
    được; thay bằng một node Cocos THƯỜNG làm đối chiếu.
  * `rect` là một KÍCH THƯỚC, đi qua phép đổi theo chiều NGƯỢC lại: nó NHÂN tỉ lệ
    của cả CHUỖI NGUỒN rồi CHIA tỉ lệ của chính node đích — nên nó là phép đo thứ
    hai độc lập, và là phép duy nhất đọc được tỉ lệ của NGUỒN.

Thêm một node Cocos THƯỜNG (`spMainUITheme_halloween_4` của bố cục Main) làm đối
chiếu: nó đã đo ra tỉ lệ 1,00.

Kết quả đo được (2026-09-18, bản vn, xong sau 18s; log đầy đủ của lượt đo):

    TILE|xong|dich|so-con|true|0,nil
    TILE|xong|dich|cs|true|163.55999755859,163.20001220703
    TILE|xong|dich|coll|true|163.55999755859,163.20001220703
    TILE|HIEU|wrapper|-137.25499343872,-42.156997680664
    TILE|RECT|wrapper|175,227.5|175,227.5
    TILE|HIEU|thuong|-140,-43
    TILE|RECT|thuong|178.5,232.04899597168|178.5,232.04899597168
    TILE|HIEU|bat-Gashapon|-137.25499343872,-42.156997680664
    TILE|RECT|bat-Gashapon|175,227.5|175,227.5
    TILE|HIEU|bat-YuJin|-137.25499343872,-42.156997680664
    TILE|RECT|bat-YuJin|175,227.5|175,227.5
    TILE|HIEU|bat-BaiHuZi|-137.25499343872,-42.156997680664
    TILE|RECT|bat-BaiHuZi|175,227.5|175,227.5

và `#dich:getChildren()` = **0** — đối tượng bắt được KHÔNG có node con nào (xương
của armature không phải con `CCNode`), nên phép tách "wrapper với con" dự định ban
đầu KHÔNG dùng được: dòng `con` không bao giờ in ra. Phép đo thay thế là `thuong`
(một `CCSprite` của bố cục Main, tỉ lệ 1) — và máy ảo trả lời rõ ràng:

    điểm vào một armature  : 140/1,02 = 137,25499 (ta: 140)   -> ĐÍCH tỉ lệ 1,02
    điểm vào node thường   : -(140, 43), đúng 1               -> ĐÍCH tỉ lệ 1
    hộp đo vào armature    : 175 x 227,5  (= _lua_CollisionSize của nguồn)
    hộp đo vào node thường : 178,5 x 232,04899597168 = 175 x 227,5 x 1,02
                               -> NGUỒN tỉ lệ 1,02

Bốn đối tượng bắt được KHÁC NHAU (Hoplite, Gashapon, YuJin, BaiHuZi) ra y nguyên
từng chữ số, nên 1,02 là **chung cho mọi đối tượng bắt được**, không phải dữ liệu
riêng của một rig.

**Kết luận: chủ sở hữu 1,02 là CHÍNH ĐỐI TƯỢNG BẮT ĐƯỢC** — lớp `CDFSpriteRole`,
tức cây armature mà `getSpriteFromSpriteCatch` trả về; node Cocos THƯỜNG thì tỉ lệ
1. Đọc ra tỉ lệ: điểm bị CHIA cho tỉ lệ CỦA CHÍNH node đích (ở đây node đích là
một đối tượng bắt được khác, tỉ lệ 1,02), còn hộp là một KÍCH THƯỚC nên bị NHÂN tỉ
lệ của NGUỒN rồi chia tỉ lệ của ĐÍCH — nguồn là armature (1,02), đích là node
thường (1,0) thì ra 178,5; đích cũng là armature thì hai hệ số triệt tiêu, ra lại
đúng 175 x 227,5.

Nghi ngờ cũ "hai chiều ngược nhau nên 1,02 không thể nằm trên node đích" (chú
thích đầu `lua/cocos.lua` và `ROADMAP.md`) là do đọc lệch PHÉP ĐO: con số
`178,5 x 232,04899597168` là phép đo với node đích THƯỜNG (mục G của
`emu_xuong.py`), không phải với node đích armature — xem dòng `thuong` ở trên.
Với cùng một kiểu đích thì chiều nhất quán: bản dựng thiếu 1,02 trên đối tượng bắt
được, nên điểm hỏi vào một armature thì LỚN hơn 1,02 lần, còn hộp đo vào một node
thường thì NHỎ hơn 1,02 lần.

Đối chiếu tĩnh: `libgame.so` bản vn có đúng **năm** chỗ nhớ hằng số 1.02f trong
`.text`, trong đó **hai** chỗ giống nhau (`0x3970d4`, `0x3d547c`) gọi
`vcall(+0x6c)(1.02f)` rồi `bl 0x2aa3ea`; `0x2aa3ea` (đặt `[r0+0x234] = 1.0f` rồi
gọi hai hàm ảo) chỉ có **đúng hai** chỗ gọi ấy — một đường nhân bản/khởi tạo
sprite, khớp với "đối tượng bắt được mang sẵn 1,02".
"""
import argparse
import pathlib
import re
import sys
import time

import emu_tags as E

HERE = pathlib.Path(__file__).resolve().parent
APK_VN = HERE / 'vn' / 'com.cmn.buatanew.apk'

PROBE = '''
-- === CHEN DE DO: he so 1,02 cua doi tuong bat duoc (emu_ti_le.py sinh ra) ===
do
	local function goi(ten, f)
		print("TILE|goi|" .. ten)
		local ok, a, b = pcall(f)
		print("TILE|xong|" .. ten .. "|" .. tostring(ok) .. "|"
			.. tostring(a) .. "," .. tostring(b))
		return a, b
	end

	local function hinh(ten)
		local ok, a = pcall(getSpriteFromSpriteCatch, ten)
		print("TILE|tao|" .. ten .. "|" .. tostring(ok) .. "|" .. tostring(a))
		if ok then return a end
		return nil
	end

	print("TILE|bat-dau")
	pcall(function() loadLevelFile("conf/UI_Main_960_640.xgg") end)

	local nguon = hinh("ZhangLiangBao")
	local dich = hinh("Hoplite")
	if nguon == nil or dich == nil then
		print("TILE|het")
		return
	end

	-- Cau truc cua doi tuong bat duoc: may con, va con thu nhat la gi.
	local so = goi("dich|so-con", function() return #dich:getChildren() end)
	local con = nil
	if so ~= nil and so >= 1 then
		con = goi("dich|con-1|lay", function() return dich:getChildren()[1] end)
	end
	if con ~= nil then
		goi("dich|con-1|ten-lop", function() return tostring(con) end)
		goi("dich|con-1|so-con", function() return #con:getChildren() end)
		goi("dich|con-1|cs", function() return con:getContentSize() end)
	end
	goi("dich|cs", function() return dich:getContentSize() end)
	goi("dich|coll", function() return dich:_lua_CollisionSize() end)

	-- Doi node dich giua hai vi tri (don vi COCOS), roi do hieu vao ba khong gian.
	local A = {-40, 7}
	local B = {100, 50}
	local thuong = rawget(_G, 'spMainUITheme_halloween_4')

	local function do_mot(ten, node)
		if node == nil then return end
		goi("M|dat-a|" .. ten,
			function() node:setPosition(A[1], A[2]) return node:getPosition() end)
		local x1, y1 = goi("M|pos-a|" .. ten,
			function() return nguon:_lua_getBonePosInNode("Collision", node) end)
		local w1, h1 = goi("M|rect-a|" .. ten,
			function() return nguon:_lua_getBoneRectInNode("Collision", node) end)
		goi("M|dat-b|" .. ten,
			function() node:setPosition(B[1], B[2]) return node:getPosition() end)
		local x2, y2 = goi("M|pos-b|" .. ten,
			function() return nguon:_lua_getBonePosInNode("Collision", node) end)
		local w2, h2 = goi("M|rect-b|" .. ten,
			function() return nguon:_lua_getBoneRectInNode("Collision", node) end)
		if x1 ~= nil and x2 ~= nil then
			print("TILE|HIEU|" .. ten .. "|" .. (x2 - x1) .. "," .. (y2 - y1))
		end
		if w1 ~= nil and w2 ~= nil then
			print("TILE|RECT|" .. ten .. "|" .. w1 .. "," .. h1 .. "|" .. w2 .. "," .. h2)
		end
	end

	do_mot("wrapper", dich)
	do_mot("con", con)
	do_mot("thuong", thuong)
	-- Ba doi tuong BAT DUOC khac, de biet 1,02 la chung cho moi doi tuong bat
	-- duoc hay chi cua rieng Hoplite (du lieu armature cua tung rig co the khac).
	for _, t in ipairs({"Gashapon", "YuJin", "BaiHuZi"}) do
		do_mot("bat-" .. t, hinh(t))
	end
	print("TILE|het")
end
'''


def doc():
    txt = E.adb('logcat', '-d').stdout
    return [l for l in re.findall(r'TILE\|[^\n\r]*', txt)]


def chay(han=240, cai=False):
    if not E.thiet_bi():
        raise SystemExit('khong thay may ao nao — bat emulator truoc')
    if cai:
        print('cai APK %s' % APK_VN)
        r = E.adb('install', '-r', '-d', str(APK_VN))
        print(r.stdout.strip()[-400:], r.stderr.strip()[-400:])
    sc_dir = E.build_overrides([('UI_Main_960_640.xgg', [])], HERE / '_emu',
                               PROBE, token='tile')
    E.adb('shell', 'am', 'force-stop', E.PKG)
    for _ in range(20):
        if not E.adb('shell', 'pidof', E.PKG).stdout.strip():
            break
        time.sleep(0.5)
    E.adb('push', str(sc_dir / 'game.lua'), E.REMOTE + '/sc/game.lua')
    E.cap_quyen()
    E.adb('logcat', '-b', 'all', '-c')
    E.adb('shell', 'am', 'start', '-n', '%s/%s' % (E.PKG, E.ACT))
    cho = 0
    while cho < han:
        time.sleep(3)
        cho += 3
        lines = doc()
        if len(lines) >= 2 and lines[-1].startswith('TILE|het'):
            return lines + ['(xong sau %ds)' % cho]
        if not E.adb('shell', 'pidof', E.PKG).stdout.strip() and cho >= 15:
            return doc() + ['(game chet sau %ds)' % cho]
    return doc() + ['(het gio %ds)' % han]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--cai', action='store_true', help='cai lai APK truoc khi chay')
    ap.add_argument('--han', type=int, default=240)
    a = ap.parse_args()
    for l in chay(a.han, a.cai):
        print(l)
    return 0


if __name__ == '__main__':
    sys.exit(main())
