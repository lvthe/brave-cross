"""Đo `_lua_CollisionSize` của armature bằng máy ảo Android — hỏi thẳng engine gốc.

    python emu_cham.py            # chạy một lượt, in ra các dòng CHAM|
    python emu_cham.py --cai      # cài lại APK trước khi chạy

VÌ SAO PHẢI ĐO
--------------
`_lua_CollisionSize` có 6 chỗ gọi trong mã gốc (`CUIBarracksMain.lua:1043,1091`,
`CUICavern.lua:363,408,454`, `CUIInfiniteLevelMain.lua:848`) và chưa từng tồn tại
ở lớp giả lập. Đọc mã máy chỉ trả lời được một nửa:

  * Nửa TRẢ LỜI ĐƯỢC: nó trả về HAI số. Bảng bind của lớp armature nằm ở `.data`
    0x937350 (81 bản ghi, KHÔNG nằm trong 132 lớp của `binder.py` — tìm ra bằng
    cách dò bản ghi 12 byte quanh tên `_lua_CollisionSize`), bản ghi trỏ tới
    `0x2ab932`, và đoạn mã đó đọc hai float ở `[sp+8]` và `[sp+0xc]` rồi
    `lua_pushnumber` hai lần — tức một cặp số, không phải một số.

  * Nửa KHÔNG trả lời được: cặp số ấy NGHĨA LÀ GÌ và ở HỆ NÀO. Hàm gọi
    `0x2ab860`, tra `.symtab` ra đúng tên
    `std::map<int, CDFColliderBoneInfo>::operator[]` (và `0x2ab7e4` là
    `_Rb_tree::_M_insert_unique`) — tức cặp số nằm trong một **bản ghi
    `CDFColliderBoneInfo`** gắn trên chính armature ở `+0x27c`, khoá `0`. Các
    trường của bản ghi ấy chỉ suy ra được từ cách ghi, không có tài liệu, và câu
    hỏi "đơn vị là gì" thì đọc mã không bao giờ trả lời chắc được.

DỰ ĐOÁN ĐEM ĐI KIỂM (đọc từ dữ liệu armature đã xuất, KHÔNG phải từ mã máy)
--------------------------------------------------------------------------
Mỗi armature có một xương tên `Collision` (**224** trong 418 file `.xml`, tính
theo biến thể MANG TÊN FILE — xem `cham_ref.py`), và xương ấy mang đúng một ảnh
`_res-44`. Bản ghi sprite trong `.xml` cho ảnh đó **không phải 1×1**: cỡ hay gặp
nhất là **3×3** (Hoplite, ElephantSoldier, Archer), rồi **2×2** (BaiHuZi), còn
ZhangLiangBao là 1×1. Tức hộp chạm là một ảnh nhỏ phóng to theo `sx`/`sy` của
khoá hoạt hình, và số ra tròn trịa đúng kiểu người đặt tay:

    Hoplite          3×54,52  × 3×54,4   = 163,56  × 163,2
    ElephantSoldier  3×56,84  × 3×39,5   = 170,52  × 118,5
    BaiHuZi          2×160    × 2×152,5  = 320     × 305
    ZhangLiangBao    1×175    × 1×227,5  = 175     × 227,5
    YuJin            1×139,88 × 1×179,84 = 140,005 × 179,986  (rot −0,04/−0,06)

Bốn phép thử phân biệt:

  1. Armature KHÔNG có xương `Collision` (`DaQuZhanShi`, `BaoXiang`) — nếu cặp
     số là (0, 0) thì đó là tra bảng thất bại, chứ không phải mặc định nào khác.
  2. `setScale(2)` rồi đo lại. Số ĐỔI theo thì nó ở hệ của nút CHA (điểm ảnh
     theo tỉ lệ đang vẽ); số KHÔNG ĐỔI thì nó ở hệ NỘI BỘ của armature.
  3. TÍNH hay ĐỘNG. **ZhangLiangBao** là rig DUY NHẤT trong 224 mà khoá 0 của
     `Collision` khác nhau giữa các động tác (`Death`/`Hit`/`Wake` có
     sy = 227,49000549316406; `Fight`/`Fight2`/`Standby`/`Walk` có 227,5). Đổi
     sang `Hit` rồi đo: **227,5 = hộp tính một lần**, còn **227,490005 = hộp
     theo động tác đang chạy**. Kèm một phép ĐỐI CHỨNG bằng
     `_lua_getBonePosInNode("Collision")` — toạ độ xương phải đổi theo, không
     thì `playAnimation` chưa kịp có tác dụng trong cùng một đoạn Lua và phép
     đo trên không nói lên gì.
  4. Cặp trục `rot1`/`rot2`: `MaYuanYi` (rot −0,08 / rot2 −0,03) và
     `GongSunZan` (rot 0,04 / rot2 0,06) — hai góc khác nhau đủ để **đổi vai**
     cho ra số khác hẳn (MaYuanYi: 254,654 × 189,623 so với 254,489 × 189,845).

Cách chèn, cách trả quyền file, cách khởi động — y như `emu_nhan.py` (xem
docstring ở đó). Mỗi bước in TRƯỚC khi gọi, vì bản dịch ARM của máy ảo hay
SIGSEGV ở một lời gọi native nào đó mà `pcall` không đỡ được.
"""
import argparse
import pathlib
import re
import sys
import time

import emu_tags as E

HERE = pathlib.Path(__file__).resolve().parent
APK_VN = HERE / 'vn' / 'com.cmn.buatanew.apk'

# `%` trong khuôn này phải viết `%%` (đây là khuôn cho phép `%`-format của
# build_overrides). Đoạn dưới KHÔNG dùng string.format nên không có `%`.
PROBE = '''
-- === CHEN DE DO: _lua_CollisionSize (emu_cham.py sinh ra) ===
do
	-- In TEN buoc TRUOC khi goi: ban dich ARM cua may ao hay SIGSEGV o mot loi
	-- goi native nao do, va pcall KHONG do duoc loi native — nen dong cuoi con
	-- lai chinh la thu pham.
	local function goi(ten, f)
		print("CHAM|goi|" .. ten)
		local ok, a, b = pcall(f)
		print("CHAM|xong|" .. ten .. "|" .. tostring(ok) .. "|"
			.. tostring(a) .. "," .. tostring(b))
		return a, b
	end

	-- Doi chieu bang DUONG CUA BAN GOC: chinh ham ma CUIBarracksMain /
	-- CUICavern / CUIInfiniteLevelMain dung de lay hinh tuong.
	local function hinh(ten)
		print("CHAM|tao|" .. ten)
		local ok, a = pcall(getSpriteFromSpriteCatch, ten)
		print("CHAM|tao-xong|" .. ten .. "|" .. tostring(ok) .. "|" .. tostring(a))
		if ok then return a end
		return nil
	end

	-- Do MOT node: bon so cua cung mot node, dat canh nhau de doc ra ngay
	-- quan he giua chung.
	local function do_node(tien, n)
		if n == nil then return end
		goi(tien .. "-coll", function() return n:_lua_CollisionSize() end)
		goi(tien .. "-cs", function() return n:getContentSize() end)
		goi(tien .. "-cspx", function() return n:getContentSizeInPixels() end)
		goi(tien .. "-scaleX", function() return n:getScaleX() end)
		goi(tien .. "-scaleY", function() return n:getScaleY() end)
	end

	print("CHAM|bat-dau")
	print("CHAM|co-ham|" .. tostring(type(getSpriteFromSpriteCatch)))
	-- Nap bo cuc Main de he thong nao can thiet thi da dung: day cung la cach
	-- emu_tags / emu_nhan dua game toi trang thai do duoc.
	print("CHAM|nap|" .. tostring(pcall(function()
		loadLevelFile("conf/UI_Main_960_640.xgg")
	end)))

	-- (A) DOI CHUNG DON VI. Mot node CUA BO CUC: bo cuc .xgg ghi kich thuoc
	-- theo DON VI THIET KE, nen doc lai no cho biet getContentSize tra ve don vi
	-- thiet ke hay diem anh tren may ao nay. Khong co phep do nay thi khong the
	-- noi con so cua armature la lon hay nho.
	for _, nm in ipairs({"ndMain", "ndTop", "ndBottom", "spMainBg"}) do
		local n = rawget(_G, nm)
		print("CHAM|node|" .. nm .. "|" .. tostring(n))
		do_node("A-" .. nm, n)
	end

	local arm = hinh("Hoplite")
	if arm ~= nil then
		do_node("B-Hoplite", arm)
		goi("B-ten", function() return arm:_Lua_getArmatureName() end)
		goi("B-play", function() return arm:_Lua_playAnimation("Standby") end)
		goi("B-coll-sau-play", function() return arm:_lua_CollisionSize() end)
		-- Doi ti le: dung setScaleX/setScaleY chu KHONG dung setScale (setScale
		-- la bind varargs va ban dich ARM chet ngay o loi goi do — da thay bang
		-- chinh lan chay truoc).
		goi("B-scaleX-2", function() return arm:setScaleX(2.0) end)
		goi("B-coll-sau-scaleX", function() return arm:_lua_CollisionSize() end)
		goi("B-scaleX-1", function() return arm:setScaleX(1.0) end)
		goi("B-scaleY-2", function() return arm:setScaleY(2.0) end)
		goi("B-coll-sau-scaleY", function() return arm:_lua_CollisionSize() end)
		goi("B-scaleY-1", function() return arm:setScaleY(1.0) end)
	end

	-- (B) Bon hinh tuong that, do lon rat khac nhau (xem bang du doan o
	-- docstring). Moi cai in TRUOC khi tao, va tao tung cai mot.
	for _, t in ipairs({"BaiHuZi", "YuJin", "ZhangLiangBao", "ElephantSoldier"}) do
		local a2 = hinh(t)
		do_node("C-" .. t, a2)
	end

	-- (C) Hai ca DOI CHUNG: khong co xuong `Collision` nao trong file .xml.
	for _, t in ipairs({"DaQuZhanShi", "BaoXiang"}) do
		local a3 = hinh(t)
		do_node("D-" .. t, a3)
	end

	-- (D) TINH hay DONG. ZhangLiangBao la rig DUY NHAT trong 224 rig co xuong
	-- `Collision` ma khoa 0 KHAC nhau giua cac dong tac (quet bang cham_ref.py):
	-- Death/Hit/Wake co sy = 227,49000549316406 con Fight/Fight2/Standby/Walk co
	-- 227,5. Do lai sau khi DOI DONG TAC:
	--   * van 227,5         -> hop KHONG theo dong tac (tinh mot lan luc dung)
	--   * thanh 227,490005  -> hop theo dong tac dang chay
	-- Doi chung: toa do xuong Collision phai DOI theo, khong thi `playAnimation`
	-- khong kip co tac dung trong cung mot doan Lua va phep do tren la vo nghia.
	local z = hinh("ZhangLiangBao")
	if z ~= nil then
		goi("D-bone-truoc", function() return z:_lua_getBonePosInNode("Collision", z) end)
		for _, dt in ipairs({"Hit", "Death", "Fight2", "Standby"}) do
			goi("D-play-" .. dt, function() return z:_Lua_playAnimation(dt) end)
			goi("D-bone-" .. dt, function() return z:_lua_getBonePosInNode("Collision", z) end)
			goi("D-coll-" .. dt, function() return z:_lua_CollisionSize() end)
		end
	end

	-- (E) CAP TRUC rot1/rot2: hai rig co CA HAI goc khac 0 va khac nhau du lon
	-- de phan biet vai. Du doan dung vai / doi vai:
	--   MaYuanYi   (1x1, sx 254,39 sy 189,49, rot -0,08 rot2 -0,03)
	--              dung 254,654 x 189,623   |  doi vai 254,489 x 189,845
	--   GongSunZan (1x1, sx 139,89 sy 184,86, rot  0,04 rot2  0,06)
	--              dung 140,019 x 185,006   |  doi vai 140,084 x 184,958
	for _, t in ipairs({"MaYuanYi", "GongSunZan"}) do
		local a4 = hinh(t)
		do_node("E-" .. t, a4)
	end

	print("CHAM|het")
end
'''


def doc_cham():
    txt = E.adb('logcat', '-d').stdout
    return [l for l in re.findall(r'CHAM\|[^\n\r]*', txt)]


def chay(han=240, cai=False, density=None):
    if not E.thiet_bi():
        raise SystemExit('khong thay may ao nao — bat emulator truoc')
    if cai:
        print('cai APK %s' % APK_VN)
        r = E.adb('install', '-r', '-d', str(APK_VN))
        print(r.stdout.strip()[-400:], r.stderr.strip()[-400:])
    # Doi mat do diem anh: neu con so cua armature DOI theo mat do thi no o don
    # vi DIEM ANH, con khong doi thi o don vi thiet ke. Tra ve mat do cu.
    cu = None
    if density:
        cu = E.adb('shell', 'wm', 'density').stdout.strip()
        print('mat do cu: %s' % cu)
        E.adb('shell', 'wm', 'density', str(density))
    try:
        sc_dir = E.build_overrides([('UI_Main_960_640.xgg', [])], HERE / '_emu',
                                   PROBE, token='cham')
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
            lines = doc_cham()
            if len(lines) >= 2 and lines[-1].startswith('CHAM|het'):
                return lines + ['(xong sau %ds)' % cho]
            if not E.adb('shell', 'pidof', E.PKG).stdout.strip() and cho >= 15:
                return doc_cham() + ['(game chet sau %ds)' % cho]
        return doc_cham() + ['(het gio %ds)' % han]
    finally:
        if cu:
            E.adb('shell', 'wm', 'density', 'reset')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--cai', action='store_true', help='cai lai APK truoc khi chay')
    ap.add_argument('--han', type=int, default=240)
    ap.add_argument('--density', type=int, default=None,
                    help='dat wm density truoc khi chay (do xem don vi co theo '
                         'mat do diem anh khong)')
    a = ap.parse_args()
    for l in chay(a.han, a.cai, a.density):
        print(l)
    return 0


if __name__ == '__main__':
    sys.exit(main())
