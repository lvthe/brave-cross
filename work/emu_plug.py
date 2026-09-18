# -*- coding: utf-8 -*-
"""Điểm gắn armature có mang tỉ lệ 1,02 của đối tượng bắt được không? — máy ảo (bản vn).

    python emu_plug.py [--han 240] [--cai]

Vì sao: `emu_ti_le.py` chốt được "chủ sở hữu 1,02 là CHÍNH ĐỐI TƯỢNG BẮT ĐƯỢC"
(`CDFSpriteRole`), suy ra từ hai hàm xương `_lua_getBonePosInNode` /
`_lua_getBoneRectInNode`. Bản dựng Godot vì thế mang sẵn tỉ lệ ấy ở hộp rig
(`TI_LE_BAT` trong `game/lua_runtime.gd`).

Nhưng khi cài vào, bộ kiểm `diem gan armature` (`tools/verify_plug.gd`) TỤT:
**12 đạt / 0 hỏng -> 8 đạt / 4 hỏng**, và cả bốn lỗi đều đúng hệ số 1,02:

    HONG plug 4 so voi plug 6: doc ra (-1.54, -116.39), file noi (-1.51, -114.11)
    HONG con toan cuc ..., lech 1.020 px

Bộ kiểm ấy gọi `spA:_lua_getPlugInPositionInNode(n, cha)` với `spA` = đối tượng bắt
được và `cha` = node THƯỜNG — **đúng cặp** mà `emu_ti_le.py` kết luận "nguồn bị nhân
1,02". Nên rất có thể bản dựng đúng và KỲ VỌNG trong bộ kiểm mới là phần lỗi thời.

Nhưng đó là **hàm khác** (`_lua_getPlugInPositionInNode`, 48 chỗ gọi trong mã gốc),
không phải hàm đã đo. Suy từ một công thức chung ra một hàm khác là đoán, nên lượt
này đo thẳng.

PHÉP ĐO — tự kiểm chứng, KHÔNG cần tin số trong file:

  Lấy HIỆU hai điểm gắn (điểm gắn là xương, đứng yên, nên hiệu là hằng số). Công
  thức là `inv(dich) * nguon:to_global(v)`:

    * đích là node THƯỜNG (tỉ lệ 1):  hiệu = file x tỉ lệ NGUỒN
    * đích là ARMATURE (tỉ lệ 1,02):  hiệu = file x tỉ lệ NGUỒN / 1,02 -> TRIỆT TIÊU

  Nên **tỉ số giữa hai phép = 1,02**, và CHIỀU của tỉ số ấy nói hệ số thuộc NGUỒN
  hay thuộc ĐÍCH — nếu 1,02 thuộc đích thì tỉ số phải NGƯỢC LẠI. Phép đo không
  dựa vào việc tôi đọc đúng số trong file (số file chỉ dùng để đối chiếu thêm).

  Phép đo này cũng chính là phép đo mà `tools/verify_plug.gd` khẳng định: chỗ gọi
  thật (`CUISoulBox.lua:955`, `CUIGainHeroAnimation.lua:502`) lấy giá trị trả về
  rồi `pParent:addChild(x)` + `x:setPosition(AtX, AtY)` — tức giá trị PHẢI ở hệ
  của cha, gồm cả tỉ lệ giữa armature và cha, không thì node đặt vào lệch chỗ.

Vì sao không tự dựng node cha bằng `create()`: bản dịch ARM của máy ảo GIẾT CA TIẾN
TRÌNH ở mọi lời gọi `create()` trên lớp engine (`emu_dom.py:52`). Nên lấy một node
CÓ SẴN của bố cục Main làm cha — `emu_ti_le.py` đã đo `spMainUITheme_halloween_4`
tỉ lệ 1,00.

Kết quả đo được (2026-09-18, bản vn, xong sau 9s; log đầy đủ của lượt đo):

    PLUG|xong|bone-coll|true|-132,196
    PLUG|HIEU|self|7|1,37
    PLUG|HIEU|thuong|7|1.02001953125,37.739998966455
    PLUG|HIEU|self|4|-1,1
    PLUG|HIEU|thuong|4|-1.02001953125,1.0200000107288

  đích là CHÍNH NGUỒN (`spA`)  : hiệu (1, 37)          <- số NỀN, hệ số nguồn triệt tiêu
  đích là node THƯỜNG (`cha`)   : hiệu (1,02002, 37,74) <- số NỀN x 1,02
  TỈ SỐ                        : 1,02                  <- TỈ LỆ CỦA NGUỒN

  **Kết luận: bản gốc CÓ nhân 1,02 của đối tượng bắt được khi trả điểm gắn vào một
  node thường** — tức `_lua_getPlugInPositionInNode` theo đúng luật đã đo cho hai
  hàm xương, và bản dựng Godot (mang `TI_LE_BAT`) là ĐÚNG. Bộ kiểm
  `tools/verify_plug.gd` mới là phần lỗi thời: kỳ vọng của nó viết từ lúc bản dựng
  còn thiếu hệ số. Nay bộ kiểm ấy KHẲNG ĐỊNH hệ số thay vì so thẳng với file.

HAI LƯỢT ĐỌC SAI, ghi lại để khỏi lặp:

  * Lượt đầu lấy đích là `Hoplite` — cũng là một đối tượng bắt được, tỉ lệ 1,02 —
    nên tỉ số ra 1,02 chỉ là tỉ lệ của ĐÍCH, KHÔNG nói gì về nguồn. Muốn đo tỉ lệ
    NGUỒN thì đích phải là CHÍNH NGUỒN (hệ số triệt tiêu) đối chiếu với một node
    tỉ lệ 1. Đổi đích giữa hai loại armature là phép đo vô nghĩa cho câu hỏi này.
  * `adb push` cần `adb root` trước. Máy ảo khởi động lại thì adbd về lại uid
    shell và MỌI lần đẩy đều "Permission denied" — mà `chay()` không kiểm kết quả
    đẩy, nên triệu chứng là KHÔNG một dòng nào hiện ra, y hệt probe hỏng cú pháp.
    Bản `game.lua` cũ còn nằm trên máy nên rất dễ tưởng là đã đẩy đúng.

MỘT ĐIỀU CHƯA GIẢI QUYẾT, ghi rõ chứ không đoán: **động tác KHÔNG được áp trong
harness này**, nên bốn số tuyệt đối ở trên là TƯ THẾ NGHỈ chứ không phải của
`Star1` — chúng không khớp khoá trong file (đo ra `(0,0)`, `(0,0)`, `(1,-1)`,
`(2,36)`, file ghi `(0;115,54)`, `(51,48;253,23)`, `(1,51;1,43)`, `(5,01;-171,39)`).
Đối chứng: `PlugIn_4_Hero` là xương DUY NHẤT của Gashapon đổi giữa `Star1`
(y = 115,54) và `Star5` (y = 112,74), mà đọc sau hai động tác ra y hệt nhau; thử
cả hai cách (có và không `addChild` vào cây) đều vậy. Nên phép đo TUYỆT ĐỐI là vô
nghĩa ở đây. Phép đo TỈ SỐ thì không phụ thuộc tư thế nên vẫn đứng vững — và đó là
phép trả lời câu hỏi. Ai cần số tuyệt đối thì phải làm cho động tác áp được trước.
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
-- === CHEN DE DO: diem gan armature co mang ti le 1,02 khong (emu_plug.py sinh ra) ===
do
	local function goi(ten, f)
		print("PLUG|goi|" .. ten)
		local ok, a, b = pcall(f)
		print("PLUG|xong|" .. ten .. "|" .. tostring(ok) .. "|"
			.. tostring(a) .. "," .. tostring(b))
		return a, b
	end

	local function hinh(ten)
		local ok, a = pcall(getSpriteFromSpriteCatch, ten)
		print("PLUG|tao|" .. ten .. "|" .. tostring(ok) .. "|" .. tostring(a))
		if ok then return a end
		return nil
	end

	print("PLUG|bat-dau")
	pcall(function() loadLevelFile("conf/UI_Main_960_640.xgg") end)

	-- Node cha THUONG: node CO SAN cua bo cuc Main (khong tao moi — create() giet
	-- ca tien trinh tren ban dich ARM). Thu lan luot, in ra node nao dung duoc.
	local ung_vien = {"spMainUITheme_halloween_4", "ndMain", "ndTop", "ndBottom"}
	local cha = nil
	for _, nm in ipairs(ung_vien) do
		local n = rawget(_G, nm)
		print("PLUG|ung-vien|" .. nm .. "|" .. tostring(n))
		if n ~= nil and cha == nil then cha = n end
	end
	print("PLUG|cha|" .. tostring(cha))

	local spA = hinh("Gashapon")
	if spA == nil or cha == nil then
		print("PLUG|het")
		return
	end

	-- Phai nam TRONG CAY thi dong tac moi ap track (xem chu thich cua
	-- tools/verify_plug.gd); khong thi moi xuong o (0, 0) va phep do vo nghia.
	-- KHONG hoi so con: tra khoa do tren userdata lam ban dich ARM chet ngay
	-- (rang buoc ghi o docstring `emu_tags.py`).
	--
	-- LUOT 2: KHONG them vao cay nua. Luot 1 co them (`cha:addChild(spA)`) va do
	-- duoc dong tac KHONG ap: Star1 va Star5 ra y het nhau, trong khi
	-- `PlugIn_4_Hero` phai lech 2,8 theo y. `emu_cham.py` (muc D) do duoc dong tac
	-- CO ap va no khong them vao cay — nen thu bo buoc them.
	if rawget(_G, 'PLUG_TREO') then
		goi("gan-cha", function() cha:addChild(spA) return true end)
		goi("dat-0", function() spA:setPosition(0, 0) return spA:getPosition() end)
	else
		print("PLUG|khong-treo|de nguyen, khong addChild")
	end
	goi("play", function() return spA:_Lua_playAnimation("Star1") end)
	goi("ten-armature", function() return spA:_Lua_getArmatureName() end)

	-- Doi chung cho "dong tac da ap chua": xương Collision phai khac (0,0).
	goi("coll", function() return spA:_lua_CollisionSize() end)
	-- Doi chung 1: TOA DO XUONG Collision doc ra phai TRUNG voi ban dung Godot
	-- (tools/verify_plug.gd do duoc (-132, 196)). Khong trung thi hai ben dang
	-- o HAI TU THE khac nhau va moi so sanh tuyet doi la vo nghia.
	goi("bone-coll", function() return spA:_lua_getBonePosInNode("Collision", spA) end)

	local PLUG = {4, 5, 6, 7}

	local function doc(dich, nhan)
		if dich == nil then
			print("PLUG|BO-QUA|" .. nhan .. "|dich nil")
			return
		end
		local ra = {}
		for _, n in ipairs(PLUG) do
			local x, y = goi("pos|" .. nhan .. "|" .. n, function()
				return spA:_lua_getPlugInPositionInNode(n, dich) end)
			ra[n] = {x, y}
		end
		-- Tuyet doi (phu thuoc goc/vi tri cua cha nen chi de tham khao).
		for _, n in ipairs(PLUG) do
			if ra[n] ~= nil and ra[n][1] ~= nil then
				print("PLUG|ABS|" .. nhan .. "|" .. n .. "|" .. ra[n][1] .. "," .. ra[n][2])
			end
		end
		-- HIEU so voi diem gan 6 — day moi la phep do sach: hieu khong dinh gi
		-- toi goc, diem neo, hay chieu cao cua cha, chi con ti le.
		if ra[6] ~= nil and ra[6][1] ~= nil then
			for _, n in ipairs(PLUG) do
				if n ~= 6 and ra[n] ~= nil and ra[n][1] ~= nil then
					print("PLUG|HIEU|" .. nhan .. "|" .. n .. "|"
						.. (ra[n][1] - ra[6][1]) .. "," .. (ra[n][2] - ra[6][2]))
				end
			end
		else
			print("PLUG|BO-QUA|" .. nhan .. "|khong doc duoc diem gan 6")
		end
	end

	-- HAI phep, chi khac nhau o TINH CHAT cua dich. Ti so giua chung la ti le cua
	-- NGUON — xem chu thich dau file: dich la CHINH NGUON thi he so cua nguon
	-- triet tieu (`inv(nguon) * nguon:to_global(v)`), nen hieu ra dung so NEN;
	-- dich la node THUONG thi hieu ra `so NEN x ti le NGUON`. Ti so = ti le NGUON.
	--
	-- Day moi la phep tra loi cau hoi. Luot truoc lay dich la `Hoplite` (cung la
	-- doi tuong bat duoc, ti le 1,02) nen ti so ra 1,02 chi la ti le cua DICH —
	-- khong noi gi ve nguon. Phai lay dich la CHINH `spA`.
	doc(spA, "self")
	doc(cha, "thuong")

	-- Doi chieu QUYET DINH: chinh bon xuong ay doc qua duong XUONG
	-- (`_lua_getBonePosInNode`), cung dich, cung tu the. Hai duong ra HAI so khac
	-- nhau thi `_lua_getPlugInPositionInNode` KHONG phai la "vi tri cua xuong
	-- PlugIn_n" — va moi so sanh no voi khoa trong file la so sanh sai doi tuong.
	local TEN = {[4] = "PlugIn_4_Hero", [5] = "PlugIn_5_Word",
		[6] = "PlugIn_6_Light", [7] = "PlugIn_7_HeroName"}
	for _, n in ipairs(PLUG) do
		local x, y = goi("bone|" .. n, function()
			return spA:_lua_getBonePosInNode(TEN[n], cha) end)
		if x ~= nil then
			print("PLUG|BONE|" .. n .. "|" .. x .. "," .. y)
		end
	end

	doc(hinh("Hoplite"), "armature")

	-- Doi chung 2 (QUYET DINH): `PlugIn_4_Hero` la xuong DUY NHAT trong Gashapon
	-- doi giua Star1 (y = 115,54) va Star5 (y = 112,74). Doc no sau CA HAI dong
	-- tac: doi thi dong tac CO ap; khong doi thi bon so tuyet doi o tren la TU THE
	-- NGHI chu khong phai cua Star1, va phep do tuyet doi KHONG noi len gi (con
	-- phep ti so thi khong phu thuoc tu the nen van dung).
	goi("play-Star5", function() return spA:_Lua_playAnimation("Star5") end)
	goi("bone-plug4-sau-Star5", function()
		return spA:_lua_getBonePosInNode("PlugIn_4_Hero", cha) end)
	doc(cha, "Star5")

	print("PLUG|het")
end
'''


def doc():
    txt = E.adb('logcat', '-d').stdout
    return [l for l in re.findall(r'PLUG\|[^\n\r]*', txt)]


def chay(han=240, cai=False):
    if not E.thiet_bi():
        raise SystemExit('khong thay may ao nao — bat emulator truoc')
    if cai:
        print('cai APK %s' % APK_VN)
        r = E.adb('install', '-r', '-d', str(APK_VN))
        print(r.stdout.strip()[-400:], r.stderr.strip()[-400:])
    sc_dir = E.build_overrides([('UI_Main_960_640.xgg', [])], HERE / '_emu',
                               PROBE, token='plug')
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
        if len(lines) >= 2 and lines[-1].startswith('PLUG|het'):
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
