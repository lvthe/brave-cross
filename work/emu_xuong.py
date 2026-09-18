"""Đo `_lua_getBonePosInNode` / `_lua_getBoneRectInNode` bằng máy ảo Android.

    python emu_xuong.py            # chạy một lượt, in ra các dòng XUONG|
    python emu_xuong.py --cai      # cài lại APK trước khi chạy

VÌ SAO PHẢI ĐO
--------------
Hai hàm này chưa từng tồn tại ở lớp giả lập, và chỗ gọi chúng **không im lặng
như các API còn thiếu khác**: `CUIHeroInfoFightSoulUI.lua:3098-3115` gác bằng
`if spHero._lua_getBonePosInNode ~= nil then` — mà `__index` của lớp giả lập trả
về một hàm cho MỌI tên, nên phép gác ấy luôn đúng, rồi

    headBoneX, headBoneY = spHero:_lua_getBonePosInNode("Head", spTargetPos)
    headBoneW, headBoneH = spHero:_lua_getBoneRectInNode("Head", spTargetPos)
    facePosX = headBoneX + offsetX

nên `nil + số` là **lỗi Lua thật**, không phải bóng. Màn ấy là màn gắn MẶT lên
ĐẦU nhân vật (đúng nghĩa đen), nên nó phải chạy.

Đọc mã máy chỉ trả lời được nửa:
  * `_lua_getBonePosInNode` (0x2aabfa) và `_lua_getBoneRectInNode` (0x2aab56)
    đều lấy chuỗi ở tham số 1, lấy userdata ở tham số 2, rồi gọi một hàm công
    nhân: `0x2aabb6` (pos) / `0x2aab0c` (rect). Hàm công nhân ấy hỏi armature
    theo TÊN xương (gọi ảo ở `vtable+0x290`), nhận về một đối tượng xương, rồi
    gọi tiếp một hàm ảo của xương (`vtable+0x78`) — với cả hai hàm, cùng một
    offset. Nếu tham số 2 khác nil thì kết quả được đưa qua `0x49d070`, tức một
    phép đổi KHÔNG GIAN giữa hai node; nil thì trả thẳng.
  * Cả hai đều đẩy **HAI** số lên Lua.

Còn lại phải đo: hai số ấy là gì (góc nào của hộp, hay tâm), đơn vị nào, và
`_lua_getBoneRectInNode` có phải chính `_lua_CollisionSize` mở rộng cho xương
bất kỳ hay không. Nghi vấn cuối là thứ đáng đo nhất, vì nếu đúng thì ta đã có
sẵn **592 giá trị đã kiểm** của `_lua_CollisionSize` để đối chiếu.

BÀI TOÁN KHUNG ẢNH — chỗ bảng `ChamRef` đang dựa vào một nguồn chưa chắc đúng
------------------------------------------------------------------------------
`ChamRef` lấy `(w,h)` của xương chạm từ **bản ghi sprite trong `.xml`**. Nhưng
cùng một ảnh còn khai khung ở **bản ghi `.plist`**, và bản ghi ấy có BA cặp số
cỡ (13 float, `sngxml.py` đọc thành `sizeWH`, `sizeWH2`, `sourceSize`):

    f2,f3   = sizeWH      — khung ĐÃ CẮT trong atlas
    f9,f10  = sizeWH2     — LẶP LẠI y hệt sizeWH (đo: 13.634/13.634 khung)
    f11,f12 = sourceSize  — `sourceSize` thật: khung TRƯỚC KHI CẮT

Tức `srcW/srcH` mà `export.py` ghi ra **đã sửa**: trước đây nó lấy f9,f10 (bản
lặp của `w/h`, không phải khung trước khi cắt), nay lấy f11,f12. Với ảnh của
xương chạm (`_res-44`), hai nguồn `.xml` và
`sourceSize` bằng nhau ở **253/256** rig và lệch đúng 1 điểm ảnh ở ba rig
`BatFlight` (2×2 so với 1×1), `DragonFlight` (2×2 so với 1×1), `LvBuZhanShi`
(1×1 so với 0×0) — cả ba chưa từng được đo. Lệch 1 điểm ảnh nhân với `sx` cỡ
50–160 thì đo được thoải mái, nên mục (D) của lượt đo này gọi thẳng
`_lua_CollisionSize` của ba rig ấy.

CÁCH ĐO
-------
Một lượt in ra, cho từng rig: `_lua_CollisionSize()` (mốc đã biết), rồi cặp
pos/rect của xương `Collision`, `Collision_1`, `Head`, và của một tên xương
KHÔNG có. Gọi hai lần cho mỗi cặp: một lần truyền chính armature làm tham số 2,
một lần bỏ trống — để biết tham số 2 có bắt buộc không và phép đổi không gian
làm gì.

Phép đổi không gian đo riêng ở cuối (mục C rồi (F), (G)), bằng những node đặt ở
vị trí biết trước. Nằm CUỐI là cố ý: bản dịch ARM của máy ảo hay SIGSEGV ở một
lời gọi native lạ, mà pcall KHÔNG đỡ được lỗi native, nên thứ gì đáng ngờ thì để
sau cùng. (Lần đo trước mục C truyền `rawget(_G, "ndMain")` và node ấy nil lúc
ấy, nên không thu được gì.)

KẾT QUẢ ĐÃ ĐO (bốn lượt, mỗi lượt một câu hỏi)
----------------------------------------------
**Hai hàm.** `_lua_getBonePosInNode(ten)` trả **đúng cặp đã lưu** trong bản ghi
khung (`v2`, `−v3`): `ZhangLiangBao` → `(−88, 227)`; `ElephantSoldier` →
`(−103, 115)`; `YuJin Head` → `(1, 127)`; `Gashapon` → `(−132, 196)`. Tham số 2
**bỏ trống được** — `pos-self` và `pos-nil` giống nhau ở **mọi** xương đã đo. Tên
xương không có thì trả `(0, 0)` **không báo lỗi** (`DaQuZhanShi`, và tên bịa).
`_lua_getBoneRectInNode(ten)` chính là `hop()` của `cham_ref.py` với `(w, h)` là
**`sourceSize` của plist**, đúng bằng `_lua_CollisionSize` khi xương ấy là
`Collision`: `ElephantSoldier` → `(170,52, 118,5)` và `(52,8, 106,8)` và
`(54, 53)`; `BatFlight Head` → `(66,518943786621, 90,896179199219)`. Một chỗ khớp đáng ghi: `getContentSize()` của armature **bằng đúng**
`_lua_CollisionSize()` ở cả ba rig đo được cả hai (`YuJin` 140,00547790527 ×
179,98643493652, `Gashapon` 266 × 310,80001831055) — tức hộp chạm chính là ô của
node.
Ba phép đo mới của mục (D) chốt nguồn khung: `BatFlight` → **145,00999450684 ×
120**, `DragonFlight` → **175 × 145**, `DragonFlight Head` → **64 × 64** — cả ba
hợp với `sourceSize` và **đều không hợp** với bản ghi `.xml` (290,02 × 240;
350 × 290; 65 × 64). `LvBuZhanShi` → **0 × 0** (hai biến thể `_A2` và `_Weapon1`
**không** tra được bằng `getSpriteFromSpriteCatch` — nó trả `nil`).

**Phép đổi không gian (mục C, G).** Tham số 2 **có** được dùng, và đúng là một
phép đổi không gian kiểu `convertToNodeSpace`: cho node đích đi từ `(−40, 7)` lên
`(100, 50)` thì kết quả đi từ `(−48,785, 220,137)` xuống `(−186,03999, 177,97999)`
— hiệu **đúng bằng** hiệu hai vị trí. Cùng cách đo ấy với một node **Cocos
thường** của bố cục Main (`spMainUITheme_halloween_4`): hiệu **đúng bằng**
`−(140, 43)`, không sai một ly. Nên tỉ lệ của node đích là **1**, còn
`_lua_getBoneRectInNode` ra **178,5 × 232,04899597168** = `175 × 227,5` nhân
**1,02** — tức **armature mang sẵn một hệ số 1,02** mà node Cocos thường không
có, và `rect` **cũng** đi qua phép đổi ấy (khi đích là armature thì hai hệ số
triệt tiêu nhau nên trước đây bốn số đo đều ra `175 × 227,5`).

**Hệ số 1,02 thuộc CHÍNH ĐỐI TƯỢNG BẮT ĐƯỢC — đã đo xong** (`emu_ti_le.py`,
2026-09-18). Nó thuộc đối tượng `getSpriteFromSpriteCatch` trả về (`CDFSpriteRole`,
tức cây armature), nên **nguồn** là armature thì tỉ lệ 1,02, **đích** là armature
thì tỉ lệ 1,02, còn node Cocos **thường** thì tỉ lệ 1 — và bốn đối tượng bắt được
khác nhau (Hoplite, Gashapon, YuJin, BaiHuZi) ra y nguyên từng chữ số. `emu_ti_le`
tách được mà **không cần đọc tỉ lệ**: nó so hộp/dấu của một đối tượng bắt được với
một node thường của bố cục Main.

Nhưng **không đọc được `getScale`**: gọi nó **giết cả tiến trình**, và
`setScale` cũng vậy — đo hai lượt, dòng cuối trước khi tắt lần lượt là
`C|scale-n2` (trên armature) và `G|scale` (trên `CCSprite` thường). pcall không
đỡ được lỗi native. **Cảnh báo cho những lượt đo sau: đừng gọi `getScale` /
`setScale` trong harness này.**
"""
import argparse
import pathlib
import re
import sys
import time

import emu_tags as E

HERE = pathlib.Path(__file__).resolve().parent
APK_VN = HERE / 'vn' / 'com.cmn.buatanew.apk'

## Rig đem đo. Chọn theo tính chất, không theo cảm giác:
##   ZhangLiangBao    có `Collision` (175 × 227,5) lẫn `Head`, và là rig DUY NHẤT
##                    trong 224 rig có khoá 0 của `Collision` khác nhau giữa các
##                    động tác (227,5 so với 227,49000549316406).
##   ElephantSoldier  có CẢ `Collision` lẫn `Collision_1` là hai xương KHÁC nhau
##                    (170,52 × 118,5 là của `Collision`) — dùng để kiểm phép
##                    tra theo tên có phân biệt được hai xương không.
##   Hoplite          rig của 7 phép đo gốc (163,55999755859375 × 118,5…).
##   BaiHuZi/YuJin    hai cỡ rất khác (320 × 305 và nhỏ).
##   Gashapon         rig của `tools/verify_plug.gd`, có bốn xương PlugIn_*.
##   DaQuZhanShi      KHÔNG có xương `Collision` — ca "tên xương không tồn tại".

PROBE = '''
-- === CHEN DE DO: xuong cua armature (emu_xuong.py sinh ra) ===
do
	local function goi(ten, f)
		print("XUONG|goi|" .. ten)
		local ok, a, b = pcall(f)
		print("XUONG|xong|" .. ten .. "|" .. tostring(ok) .. "|"
			.. tostring(a) .. "," .. tostring(b))
		return a, b
	end

	local function hinh(ten)
		local ok, a = pcall(getSpriteFromSpriteCatch, ten)
		print("XUONG|tao|" .. ten .. "|" .. tostring(ok) .. "|" .. tostring(a))
		if ok then return a end
		return nil
	end

	-- Bon so cho MOT xuong: pos/rect voi tham so 2 la chinh armature, roi pos/rect
	-- bo trong tham so 2. In ten xuong o CA HAI dau de doc ra ngay dong nao ung
	-- voi xuong nao.
	local function do_xuong(tien, n, xuong)
		if n == nil then return end
		goi(tien .. "|pos-self|" .. xuong,
			function() return n:_lua_getBonePosInNode(xuong, n) end)
		goi(tien .. "|pos-nil|" .. xuong,
			function() return n:_lua_getBonePosInNode(xuong) end)
		goi(tien .. "|rect-self|" .. xuong,
			function() return n:_lua_getBoneRectInNode(xuong, n) end)
		goi(tien .. "|rect-nil|" .. xuong,
			function() return n:_lua_getBoneRectInNode(xuong) end)
	end

	print("XUONG|bat-dau")
	print("XUONG|co-ham|" .. tostring(type(getSpriteFromSpriteCatch)))
	pcall(function() loadLevelFile("conf/UI_Main_960_640.xgg") end)

	-- (A) Tung rig: moc `_lua_CollisionSize` truoc, roi bon xuong.
	for _, t in ipairs({"ZhangLiangBao", "ElephantSoldier", "Hoplite",
			"BaiHuZi", "YuJin", "Gashapon"}) do
		local n = hinh(t)
		if n ~= nil then
			goi("A|" .. t .. "|ten", function() return n:_Lua_getArmatureName() end)
			goi("A|" .. t .. "|coll", function() return n:_lua_CollisionSize() end)
			goi("A|" .. t .. "|cs", function() return n:getContentSize() end)
			goi("A|" .. t .. "|pos", function() return n:getPosition() end)
			do_xuong("A|" .. t, n, "Collision")
			do_xuong("A|" .. t, n, "Collision_1")
			do_xuong("A|" .. t, n, "Head")
			do_xuong("A|" .. t, n, "KhongCoXuongNay")
		end
	end

	-- (B) Ca "armature khong co xuong Collision" — DaQuZhanShi.
	local d = hinh("DaQuZhanShi")
	if d ~= nil then
		goi("B|DaQuZhanShi|coll", function() return d:_lua_CollisionSize() end)
		do_xuong("B|DaQuZhanShi", d, "Collision")
		do_xuong("B|DaQuZhanShi", d, "Head")
	end

	-- (D) BA RIG MA HAI NGUON KHUNG KHONG THONG NHAT. Xuong `Collision` cua mot
	-- rig mang anh `_res-44`; khung cua anh ay doc duoc o HAI cho:
	--   * ban ghi sprite trong .xml  (bang ChamRef dang dung)
	--   * `sourceSize` cua ban ghi plist (13 float thu 12,13 — o +0x34/+0x38)
	-- Voi 256 anh `_res-44` thi hai nguon BANG NHAU o 253 muc, lech o DUNG BA:
	--   BatFlight 2x2 | DragonFlight 2x2 | LvBuZhanShi 1x1   (.xml)
	--   BatFlight 1x1 | DragonFlight 1x1 | LvBuZhanShi 0x0   (plist sourceSize)
	-- Kep theo `sx` (co 50-160) thi hai gia tri cach nhau mot khoang thay duoc,
	-- nen `_lua_CollisionSize` cua ba rig nay noi thang ra nguon nao dung.
	-- (Va ca ba rig nay CHUA he duoc do lan nao.)
	-- `LvBuZhanShi_A2` va `LvBuZhanShi_Weapon1` la hai bien the CUNG dung anh ay:
	-- bang cu (theo .xml) ghi 1x1 nen co mat trong bang; theo `sourceSize` thi
	-- anh ay 0x0 nen hop bang khong. Hai dong duoi day noi thang ra so nao.
	for _, t in ipairs({"BatFlight", "DragonFlight", "LvBuZhanShi",
			"LvBuZhanShi_A2", "LvBuZhanShi_Weapon1"}) do
		local n3 = hinh(t)
		if n3 ~= nil then
			goi("D|" .. t .. "|coll", function() return n3:_lua_CollisionSize() end)
			do_xuong("D|" .. t, n3, "Collision")
			do_xuong("D|" .. t, n3, "Head")
		end
	end

	-- (C) PHEP DOI KHONG GIAN. Tham so 2 la mot node KHAC voi chinh armature. Da do
	-- duoc: hai vi tri khac nhau cua node dich cho ra hai ket qua KHAC nhau, va
	-- hieu hai ket qua DUNG bang hieu hai vi tri nhan -0,980393 — tuc phep doi CO
	-- that, va co mot he so ti le 1,02 o dau do. Ba phep do con lai o day:
	--   * node dich o goc toa do (0,0)  -> biet so hang tu do (neo).
	--   * doi node dich di hai lan khac nhau -> chot lai he so.
	--   * `_lua_getBoneRectInNode` co doi theo khong (bon so do truoc deu y nguyen).
	--
	-- CACH DO TI LE — DA THU VA DA BO: `getScale` lan `setScale` tren sprite lay
	-- tu `getSpriteFromSpriteCatch` deu GIET CA TIEN TRINH, va pcall KHONG do duoc
	-- loi native (do hai luot: dong cuoi truoc khi tat la `C|scale-n2`, roi
	-- `C|dat-n4-scale2`). Nen ti le khong doc duoc bang hai ham ay; muc (F) di
	-- duong khac — tim mot node KHONG phai armature de lam node dich.
	local n2 = hinh("ZhangLiangBao")
	local n3 = hinh("Hoplite")
	if n2 ~= nil and n3 ~= nil then
		goi("C|pos-self", function() return n2:_lua_getBonePosInNode("Collision", n2) end)
		goi("C|rect-self", function() return n2:_lua_getBoneRectInNode("Collision", n2) end)
		goi("C|vi-tri-n3-goc", function() return n3:getPosition() end)
		goi("C|pos-n3-goc", function() return n2:_lua_getBonePosInNode("Collision", n3) end)
		goi("C|rect-n3-goc", function() return n2:_lua_getBoneRectInNode("Collision", n3) end)
		goi("C|dat-n3-a", function() n3:setPosition(100, 50) return n3:getPosition() end)
		goi("C|pos-n3-a", function() return n2:_lua_getBonePosInNode("Collision", n3) end)
		goi("C|rect-n3-a", function() return n2:_lua_getBoneRectInNode("Collision", n3) end)
		goi("C|dat-n3-b", function() n3:setPosition(-40, 7) return n3:getPosition() end)
		goi("C|pos-n3-b", function() return n2:_lua_getBonePosInNode("Collision", n3) end)
	end

	-- (F) CO NODE NAO KHONG PHAI ARMATURE LAM NODE DICH DUOC KHONG? Cau hoi con
	-- lai cua muc C: he so 0,980393 thuoc node NGUON hay node DICH. Muon tach
	-- phai co mot node dich TI LE 1 — ma armature thi khong doc/doi duoc ti le
	-- (`getScale` lan `setScale` deu giet tien trinh). Vay truoc het xem trong
	-- `_G` co san node nao khong: bon man goc lay dich tu bien TOAN CUC
	-- (`cnHeroInfoUIAnimPos`, `CUIHeroInfoFightSoulUI.lua:3075`), va class node
	-- thuong thi co the tu tao. Muc nay chi DOC, khong goi native nao.
	local ten = {}
	for k, v in pairs(_G) do
		if type(k) == 'string' and (k:sub(1, 2) == 'cn' or k:find('Main') ~= nil) then
			ten[#ten + 1] = k .. '=' .. tostring(v)
		end
	end
	print("XUONG|F|toan-cuc|" .. table.concat(ten, ' ; '))
	print("XUONG|F|CCNode|" .. tostring(rawget(_G, 'CCNode')))
	print("XUONG|F|CCSprite|" .. tostring(rawget(_G, 'CCSprite')))
	print("XUONG|F|cnHeroInfoUIAnimPos|" .. tostring(rawget(_G, 'cnHeroInfoUIAnimPos')))

	-- (G) NODE DICH TI LE 1. Muc (F) cho thay bo cuc Main co san node COCOS
	-- THUONG (`spMainUITheme_halloween_4` la CCSprite, `btnMainContest` la nut,
	-- `g_MainUIScrollLayer` la CCScrollLayer) — khac han armature, va day moi la
	-- loai node ma bon man goc truyen vao tham so 2 (`cnHeroInfoUIAnimPos`).
	--
	-- KHONG doc duoc ti le: `getScale` GIET CA TIEN TRINH o CA class Cocos thuong
	-- chu khong rieng armature (do duoc: dong cuoi truoc khi tat la `G|scale`,
	-- goi tren mot CCSprite). `setScale` cung vay. Nhung khong can doc: do DICH
	-- CHO hai lan, hieu hai ket qua chia cho hieu hai vi tri ra ngay 1/ti_le cua
	-- node dich. Voi node dich la armature thi so do ra 1/1,02; con day thi:
	--   hieu = -(140, 43)        -> node dich ti le 1, va he so 1,02 thuoc NGUON
	--   hieu = -(137,26, 42,16)  -> ti le 1,02 thuoc chinh node DICH (armature)
	local nguon = hinh("ZhangLiangBao")
	local dich = rawget(_G, 'spMainUITheme_halloween_4')
	if nguon ~= nil and dich ~= nil then
		goi("G|vi-tri", function() return dich:getPosition() end)
		goi("G|pos-goc", function() return nguon:_lua_getBonePosInNode("Collision", dich) end)
		goi("G|rect-goc", function() return nguon:_lua_getBoneRectInNode("Collision", dich) end)
		goi("G|dat-a", function() dich:setPosition(100, 50) return dich:getPosition() end)
		goi("G|pos-a", function() return nguon:_lua_getBonePosInNode("Collision", dich) end)
		goi("G|rect-a", function() return nguon:_lua_getBoneRectInNode("Collision", dich) end)
		goi("G|dat-b", function() dich:setPosition(-40, 7) return dich:getPosition() end)
		goi("G|pos-b", function() return nguon:_lua_getBonePosInNode("Collision", dich) end)
	end

	print("XUONG|het")
end
'''


def doc():
    txt = E.adb('logcat', '-d').stdout
    return [l for l in re.findall(r'XUONG\|[^\n\r]*', txt)]


def chay(han=240, cai=False):
    if not E.thiet_bi():
        raise SystemExit('khong thay may ao nao — bat emulator truoc')
    if cai:
        print('cai APK %s' % APK_VN)
        r = E.adb('install', '-r', '-d', str(APK_VN))
        print(r.stdout.strip()[-400:], r.stderr.strip()[-400:])
    sc_dir = E.build_overrides([('UI_Main_960_640.xgg', [])], HERE / '_emu',
                               PROBE, token='xuong')
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
        if len(lines) >= 2 and lines[-1].startswith('XUONG|het'):
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
