"""Đo CÁCH TRỘN MÀU của armature (đốm xanh ở Main) bằng máy ảo Android.

    python emu_dom.py --nhanh nen        # dựng cảnh Main, không gắn gì
    python emu_dom.py --nhanh bien-the   # mỗi biến thể một lượt (một lần chạy)
    python emu_dom.py --nhanh tuong      # đối chứng: armature hình tượng
    python emu_dom.py --so               # chỉ đọc ảnh đã chụp
    python emu_dom.py --phan-loai        # bảng phân loại từ ảnh đã chụp

KẾT LUẬN ĐÃ ĐO (2026-09-15) — xem CLAUDE.md mục "Đốm xanh ở Main"
---------------------------------------------------------------
`UITongYong_ItemLight` (đốm xanh) trộn CỘNG; armature HÌNH TƯỢNG (`DaQuZhanShi`)
trộn THƯỜNG. Tức trộn cộng là **theo từng hiệu ứng**, KHÔNG phải luật chung
của armature — nên bản sửa ở phía Godot phải khoanh theo hiệu ứng, đặt đại
additive cho mọi `SngRig` là sai.

Số đo, và vì sao nó dứt khoát
-----------------------------
Trên nền ĐEN thì trộn thường và trộn cộng cho KẾT QUẢ Y HỆT NHAU (cả hai
đều ra `a*src`). Nên nền đen vô dụng. Trên nền SÁNG thì khác hẳn, và đó là
phép thử dùng ở đây. Gọi `src` là màu trung bình của ảnh nguồn (theo alpha),
`a` là alpha trung bình, `dst` là nền:

    trộn cộng  : Δ = a*src          -> số DƯƠNG, không phụ thuộc dst
    trộn thường: Δ = a*(src − dst)  -> ÂM khi src < dst

Nên một chữ ký duy nhất là đủ: **trộn cộng KHÔNG BAO GIỜ làm tối một kênh
nào**. Tối đi ở bất kỳ kênh nào là bằng chứng trộn thường.

Ảnh nguồn `UITongYong_Res-lizi*_instant.png`: 128×128 RGBA, 3204–4052 điểm
hiện mỗi ảnh, trung bình theo alpha trên 110 388 điểm hiện là
`src = (78.7, 125.5, 248.4)`, `a = 0.507` — xanh đậm, không phải trắng.

Số đo trên máy ảo (nền trời sáng):

  * `UITongYong_ItemLight` ở (480,500): nền `(100,245,248)` → có hiệu ứng
    `(164,251,251)`, điểm sáng nhất `(255,255,255)`, khác biệt chỉ trong
    x 399..479, y 179..266 (1165 điểm). Ảnh crop cho ra một VÒNG CUNG TRẮNG,
    không phải khối xanh. Δ đo được `+64` ở kênh r. Trộn thường cần
    `src_r ≥ 164` (thực tế 78.7) — BẤT KHẢ. Trộn cộng cho
    `a_eff = 64/78.7 = 0.81`, dự đoán Δg = 102 và Δb = 201, cả hai đều bão
    hoà 255 (đo 251). **Trộn thường không thể; trộn cộng khớp.**
  * Đối chứng `DaQuZhanShi` (hình tượng, gần đục, tối) ở (640,360): nền
    `(122,213,202)` → `(106,119,118)`, tức r −16, g −94, b −84. Trộn cộng
    không bao giờ làm tối ⇒ **hình tượng vẽ THƯỜNG**.

Không tự đọc bằng mắt — `so_mau_mot()` đọc thẳng điểm ảnh: lấy hiệu ảnh
`<tên>.png` với ảnh nền `nen.png`, rồi so màu trung bình ở đúng những điểm
khác nhau đó.

Vì sao phải để MÃ GỐC dựng cảnh
-------------------------------
Đã đo: bản dịch ARM của máy ảo làm CHẾT CA TIẾN TRÌNH ở mọi lời gọi `create()`
trên lớp engine (`CCScene:create()`, `CCLayerColorRoundRect:create(...)`), ở
`S_CCDirector:getRunningScene()`, `node:getDescription()`, `getChildrenCount`,
`node:setScale(...)`, và ở `g_CSceneManager:RepaleceSceneWithoutLoading("Main")`.
`pcall` KHÔNG bắt được SIGSEGV (tiến trình chết với `eip 00000000` trên
`GLThread`), nên các lời gọi đó chết không in được gì — vì vậy đầu dò in một
dòng trước MỖI bước (`buoc()`), để lần chạy sau biết ngay chết ở đâu. Vì
`setScale` cũng chết nên KHÔNG thu nhỏ được nhiều biến thể vào một màn: mỗi
lượt một biến thể.

Đo được thì vẫn đo tốt: `loadLevelFile`, `getChildByTag`, `getContentSize`,
`getPosition`, `setColor(r,g,b)`, `setOpacity(n)`, `setPosition(x,y)`,
`addChild(child, z, tag)`, `_Lua_playAnimation(name)`,
`S_CCDirector:replaceScene(scene)`, `S_CCSchedule:scheduleOnce(obj, "method")`.

Nên đường duy nhất tới một cảnh CÓ VẼ là gọi chính mã gốc:
`loadLevelFile("conf/UI_Main_960_640.xgg")` cho ra `_G.g_MainUIScene` (một
CCScene) rồi `S_CCDirector:replaceScene(_G.g_MainUIScene)`.

Chuỗi tải cảnh của bản gốc chạy bằng bộ hẹn giờ (`S_CCSchedule:scheduleOnce`)
chứ không phải mạch chạy thẳng, nên sau khi gọi `main` thì cảnh CHƯA tồn tại —
phải gắn hiệu ứng ở khung sau.

Đầu dò chèn trước `XGAnalytics:logEventByID(LOADCONFIG)` trong `game.lua`
chứ không phải trước `sngHttMgr:createInstance()` như `emu_tags`: chính dòng
XGAnalytics đó làm bản dịch ARM nhảy vào địa chỉ 0. Sau đầu dò là
`do return end`, nên phần còn lại của `game.lua` (cần mạng) không chạy;
vòng vẽ của engine vẫn chạy tiếp vì nó nằm bên C++ — đó là cảnh ta chụp.
"""
import argparse
import pathlib
import re
import sys
import time

import emu_tags as E

HERE = pathlib.Path(__file__).resolve().parent
SC = E.SC
ANH = HERE / '_dom'

# Dùng chung cho cả hai lượt: nạp bộ cục Main rồi cho engine VẼ nó.
# Đo được (lượt `thu`): `loadLevelFile("conf/UI_Main_960_640.xgg")` cho ra
# `_G.g_MainUIScene` là một CCScene, `S_CCDirector:replaceScene` chạy được,
# và màn hình lên đủ trời/núi/cỏ của bản gốc. KHÔNG đi qua
# `g_CSceneManager:RepaleceSceneWithoutLoading("Main")` — hàm đó chết ở
# `eip 00000000` ngay bên trong nó (đã đo), còn ba thứ ta cần ở đây thì không.
DUNG_CANH = '''
	local function buoc(ten, f)
		print("DOM|" .. ten .. "|bat-dau")
		local ok, a = pcall(f)
		print("DOM|" .. ten .. "|xong|" .. tostring(ok) .. "|" .. tostring(a))
		return ok, a
	end

	buoc("nap-bo-cuc", function()
		return loadLevelFile("conf/UI_Main_960_640.xgg")
	end)
	local sc = rawget(_G, "g_MainUIScene")
	print("DOM|canh|" .. tostring(sc))
	if sc == nil then
		print("DOM|het|khong nap duoc bo cuc Main")
		return
	end
	buoc("replaceScene", function() return S_CCDirector:replaceScene(sc) end)
'''

# Lượt 1: chỉ có cảnh. Ảnh này là "nền" để lượt 2 đối chiếu.
DAU_DO_NEN = ('\n-- === CHEN DE DO: dung canh Main, khong gan gi ===\n'
              'do\n' + DUNG_CANH + '''
	print("DOM|san-sang")
end
''')

# Lượt 2: y hệt lượt 1, thêm HAI armature ở hai chỗ khác nhau trên nền trời:
#
#   - `UITongYong_ItemLight` — HIỆU ỨNG hạt, màu xanh (55,92,240), alpha ~0.5
#   - `DaQuZhanShi`          — ĐỐI CHỨNG: hình tướng (Lữ Bố…), gần đặc
#                              (alpha 217/255) và màu TỐI (66,45,39)
#
# Trên nền trời sáng (100,245,248) thì hai kiểu trộn cho kết quả ngược hẳn
# nhau, nên đối chứng này trả lời câu hỏi "trộn cộng là luật của RIÊNG hạt hay
# của MỌI armature" — câu đó quyết định vá `SngRig` cục bộ hay toàn cục:
#
#                 nền trời (100,245,248)
#   hạt,  trộn cộng  -> (128,255,255)  sáng hơn nền
#   hạt,  trộn thường-> ( 77,167,243)  tối hơn nền ở r,g
#   tướng,trộn cộng  -> (156,255,255)  sáng bệt hẳn lên
#   tướng,trộn thường-> ( 71, 75, 70)  vẫn TỐI như chính nó
DAU_DO_HIEN = ('\n-- === CHEN DE DO: dung canh Main roi gan hieu ung ===\n'
               'do\n' + DUNG_CANH + '''
	local function gan(ten, x, y)
		local okE, e = buoc("dung-" .. ten, function()
			return getSpriteFromSpriteCatch(ten)
		end)
		if not (okE and e ~= nil) then
			print("DOM|het|khong dung duoc " .. ten)
			return nil
		end
		buoc("vt-" .. ten, function() return e:setPosition(x, y) end)
		buoc("chay-" .. ten, function() return e:_Lua_playAnimation("Play") end)
		buoc("gan-" .. ten, function() return sc:addChild(e, 60000, 60000) end)
		return e
	end

	-- Toạ độ cảnh = toạ độ màn hình 1280x720, gốc dưới-trái (đã đo: đặt ở
	-- y=500 thì hiện ở 220 px tính từ mép trên). Cả hai chỗ đều là TRỜI SÁNG.
	gan("UITongYong_ItemLight", 480, 500)
	print("DOM|san-sang")
end
''')

# Lượt 3: ĐỐI CHỨNG. Cùng cảnh, nhưng chỉ gắn armature HÌNH TƯỚNG — gần đặc
# (alpha 217/255) và màu tối. Trộn cộng KHÔNG BAO GIỜ làm một điểm tối hơn
# nền, nên nếu lượt này ra tối hơn nền thì armature nói chung là trộn THƯỜNG,
# và trộn cộng chỉ dành cho hạt — tức là vá `SngRig` phải CỤC BỘ, không phải
# đổi cả cách vẽ armature.
DAU_DO_TUONG = ('\n-- === CHEN DE DO: doi chung armature hinh tuong ===\n'
                'do\n' + DUNG_CANH + '''
	local okE, e = buoc("dung-tuong", function()
		return getSpriteFromSpriteCatch("DaQuZhanShi")
	end)
	if okE and e ~= nil then
		buoc("vt", function() return e:setPosition(640, 360) end)
		buoc("chay", function() return e:_Lua_playAnimation("Play") end)
		buoc("gan", function() return sc:addChild(e, 60000, 60000) end)
	end
	print("DOM|san-sang")
end
''')


# Đo cho hết ranh giới của bản dịch ARM, trong MỘT lần chạy: in một dòng
# trước mỗi bước, bước nào làm chết tiến trình thì lần chạy cho biết ngay.
# Cần cả bốn thứ này mới vẽ được hiệu ứng lên một nền sáng, nên chỉ cần một
# thứ chết là đường "đo bằng máy ảo" đóng — và đóng thì phải nói ra, không
# đặt đại.
DAU_DO_THU = '''
-- === CHEN DE DO: do ranh gioi ban dich ARM ===
do
	local function buoc(ten, f)
		print("DOM|" .. ten .. "|bat-dau")
		local ok, a = pcall(f)
		print("DOM|" .. ten .. "|xong|" .. tostring(ok) .. "|" .. tostring(a))
		return ok, a
	end

	-- 1. Dung doi tuong hieu ung: day la thu KHONG THE thay the.
	local okE, efe = buoc("hieu-ung", function()
		return getSpriteFromSpriteCatch("UITongYong_ItemLight")
	end)

	-- 2. Dieu khien no.
	if okE and efe ~= nil then
		buoc("co", function() return efe:getContentSize() end)
		buoc("vt", function() return efe:setPosition(480, 320) end)
		buoc("chay", function() return efe:_Lua_playAnimation("Play") end)
	end

	-- 3. Nap mot bo cuc co san (emu_tags van lam duoc buoc nay).
	local okL = buoc("nap-bo-cuc", function()
		return loadLevelFile("conf/UI_Main_960_640.xgg")
	end)
	local sc = rawget(_G, "g_MainUIScene")
	print("DOM|g_MainUIScene|" .. tostring(sc))

	-- 4. Gan vao cay: day la cho CUIMainTopTool:_ShowHightLight lam.
	if okL and sc ~= nil and efe ~= nil then
		buoc("addChild", function() return sc:addChild(efe, 60000, 60000) end)
	end

	-- 5. Cho engine VE cay do: khong co buoc nay thi man hinh van den.
	if sc ~= nil then
		buoc("replaceScene", function() return S_CCDirector:replaceScene(sc) end)
	end

	-- 6. Bo hen gio (chuoi tai canh cua ban goc dua vao no).
	_G.DOM_THU = {}
	function DOM_THU:chay() print("DOM|hen-gio|da-chay") end
	buoc("scheduleOnce", function() return S_CCSchedule:scheduleOnce(DOM_THU, "chay") end)

	print("DOM|san-sang")
end
'''


def dung_de(probe, out_dir):
    """Dựng cây file đè: tắt Umeng + FMOD, rồi chèn đầu dò vào game.lua."""
    out = pathlib.Path(out_dir)
    (out / 'sc/share').mkdir(parents=True, exist_ok=True)
    (out / 'sc/user/Globals').mkdir(parents=True, exist_ok=True)

    t = (SC / 'user/Globals/um_event.lua').read_text('utf-8')
    t += ('\n\n-- CHEN: thong ke Umeng lam ban dich ARM cua may ao chet.\n'
          'function UMEvent:Init() end\nfunction UMEvent:StartGame() end\n')
    (out / 'sc/user/Globals/um_event.lua').write_text(t, encoding='utf-8')

    g = (SC / 'game.lua').read_text('utf-8')
    g = 'print("CHEN|dang dung ban de game.lua")\n' + g
    anchor = 'KDebug.PrintDebug("game.lua 6")'
    if anchor not in g:
        raise SystemExit('game.lua khong co moc "game.lua 6"')
    g = g.replace(anchor, anchor + (
        '\n-- CHEN: FMOD la thu vien ARM, goi qua ban dich la SIGSEGV.\n'
        'local function _bo() end\n'
        'loadBackgroundBank = _bo\nloadEffectBank = _bo\npushBankStack = _bo\n'
        'print("CHEN|da tat am thanh")\n'), 1)
    # Chen TRUOC `XGAnalytics:logEventByID(LOADCONFIG)` chu khong phai truoc
    # `sngHttMgr:createInstance()` nhu emu_tags: do duoc o day la CHINH dong
    # XGAnalytics lam ban dich ARM nhay vao dia chi 0 (SIGSEGV, eip 00000000).
    # `g_CUILoad:InitUI()` (dong 452) da chay xong truoc do nen canh da co.
    stop = ('\nXGAnalytics:logEventByID('
            'XGAnalytics.EVENT_ID.LOADCONFIG)')
    if g.count(stop) != 1:
        raise SystemExit('khong tim duoc dung mot loi goi XGAnalytics LOADCONFIG')
    g = g.replace(stop, '\n' + probe + '\ndo return end\n' + stop, 1)
    # Cam moc sau tung buoc lon con lai, de con biet chet o dau — y het
    # emu_tags. Khong co may moc nay thi trieu chung chi la "khong mot dong
    # DOM nao ra", khong biet chet o buoc nao.
    for tim in ('g_CUIOptions:InitGameInfo()', 'g_CUILoad:InitUI()',
                'g_SetGame:GetString("CloseGuide")',
                'g_bShowServerKickedMsg = false',
                'local bDirectBattle = false',
                'sngHttMgr = '):
        if '\n' + tim in g:
            g = g.replace('\n' + tim,
                          '\nprint("CHEN|truoc %s")\n' % tim[:34] + tim, 1)
    # Do XONG thi dung han, GIONG emu_tags: phan sau moc nay can mang, ma
    # mang lam ban dich ARM chet. Vong ve cua engine van chay tiep (no nam
    # ben C++), nen canh cuoi cung van duoc ve — do la canh ta chup.
    (out / 'sc/game.lua').write_text(g, encoding='utf-8')
    return out / 'sc'


def chup(ten):
    xa = '/sdcard/' + ten
    E.adb('shell', 'screencap', '-p', xa)
    dich = ANH / ten
    E.adb('pull', xa, str(dich))
    E.adb('shell', 'rm', '-f', xa)
    return dich if dich.exists() else None


def chay(probe, nhan, cho=14):
    """Đẩy bản đè, khởi động game, chờ rồi chụp."""
    sc_dir = dung_de(probe, HERE / '_dom')
    E.adb('shell', 'am', 'force-stop', E.PKG)
    for _ in range(20):
        if not E.adb('shell', 'pidof', E.PKG).stdout.strip():
            break
        time.sleep(0.5)
    E.adb('shell', 'mkdir', '-p', E.REMOTE)
    E.adb('push', str(sc_dir), E.REMOTE + '/')
    E.cap_quyen()
    E.adb('logcat', '-b', 'all', '-c')
    E.adb('shell', 'am', 'start', '-n', '%s/%s' % (E.PKG, E.ACT))
    time.sleep(cho)
    a = chup(nhan + '.png')
    txt = E.adb('logcat', '-d').stdout
    # Dong logcat co tien to thoi gian/pid nen phai cat tu nhan tro di, khong
    # the doi dong BAT DAU bang "DOM|" — y het cach emu_tags.doc_log lam.
    dong = re.findall(r'(?:DOM|CHEN)\|[^\n\r]*', txt)
    return a, dong


# Phân loại MỘT biến thể mỗi lượt, ở cùng một chỗ trên dải trời (nền sáng,
# đều) — so màu lúc có armature với màu nền (ảnh `nen`):
#
#   sáng HƠN nền ở cả ba kênh  -> chỉ trộn CỘNG mới làm được
#   TỐI hơn nền ở kênh nào đó  -> trộn THƯỜNG (cộng không bao giờ làm tối)
#
# Nhờ vậy câu "trộn cộng là luật của nhóm nào" trở thành số đo, không phải suy
# đoán từ tên. Hai mục đầu đã đo rồi (2026-09-15); các mục sau là để tìm xem
# có quy tắc nào theo TÊN không — `ItemLight`/`Light`/`GuangHuan` là ứng viên.
BIEN_THE = [
    'UITongYong_ItemLight',           # dấu nháy sáng ở Main — đã đo là CỘNG
    'DaQuZhanShi',                    # hình tướng — đã đo là THƯỜNG
    'UIWuDaoHui_HeroLightFront',
    'UIChiBang_GuangHuan',
    'ItemLight_Level2',
    'UIZhuangBeiZhuanShu_HuoHua',
    'UIYunYouShangRenAll_Yun',
    'UIYunYouShangRenAll_ShangRen',
    'Treasure_MoKuLevel1',
]

# Một biến thể mỗi lượt chạy. Không gắn nhiều con cùng lúc được: `setScale`
# là một trong những lời gọi làm bản dịch ARM chết (`eip 00000000`, đo rồi),
# mà không thu nhỏ thì armature hình tướng rộng ~840 px, chồng lên nhau hết.
DAU_DO_MOT = ('\n-- === CHEN DE DO: mot bien the armature ===\n'
              'do\n' + DUNG_CANH + '''
	local ten = "%(ten)s"
	local okE, e = buoc("dung", function()
		return getSpriteFromSpriteCatch(ten)
	end)
	if okE and e ~= nil then
		buoc("vt", function() return e:setPosition(640, 500) end)
		buoc("chay", function() return e:_Lua_playAnimation("Play") end)
		buoc("gan", function() return sc:addChild(e, 60000, 60000) end)
	else
		print("DOM|thieu|" .. ten)
	end
	print("DOM|san-sang")
end
''')


def so_mau_mot(ten):
    """Một biến thể duy nhất trên màn hình: sáng hơn nền (CỘNG) hay tối (THƯỜNG)."""
    from PIL import Image
    duong = ANH / (ten + '.png')
    if not duong.exists():
        return ten, 'khong co anh', None
    a = Image.open(ANH / 'nen.png').convert('RGB')
    b = Image.open(duong).convert('RGB')
    w, h = a.size
    pa, pb = a.load(), b.load()
    diem = []
    x0, y0, x1, y1 = w, h, -1, -1
    for y in range(h):
        for x in range(w):
            ca, cb = pa[x, y], pb[x, y]
            if max(abs(ca[k] - cb[k]) for k in range(3)) > 12:
                diem.append((ca, cb))
                x0, y0 = min(x0, x), min(y0, y)
                x1, y1 = max(x1, x), max(y1, y)
    if len(diem) < 50:
        return ten, 'khong ve duoc (thieu anh?)', None
    na = tuple(round(sum(d[0][k] for d in diem) / len(diem)) for k in range(3))
    nb = tuple(round(sum(d[1][k] for d in diem) / len(diem)) for k in range(3))
    d = tuple(nb[k] - na[k] for k in range(3))
    # Bien thien am o BAT KY kenh nao la bang chung tron THUONG: cong khong
    # bao gio lam toi. Nguoc lai, sang len o ca ba kenh thi chi cong moi lam
    # duoc (nen troi da gan 255 o g,b nen chi r con phan biet — van du).
    return ten, (len(diem), (x0, y0, x1, y1), na, nb, d), d


def bang():
    """Bảng phân loại: mỗi biến thể đã chụp một dòng, kèm vùng và màu đo được.

    In cả những biến thể CHƯA có ảnh (ghi ro la thieu) — một dòng `thieu` là
    câu trả lời thật, còn bỏ im lặng thì bảng trông như đã đo hết.
    """
    print('%-32s %7s %-22s %-16s %-16s %s'
          % ('bien the', 'so diem', 'vung', 'nen (tb)', 'co armature (tb)', 'ket luan'))
    for ten in BIEN_THE:
        _, kq, d = so_mau_mot(ten)
        if d is None:
            print('%-32s  -- %s' % (ten, kq))
            continue
        n, vung, na, nb, d = kq
        ket = 'CONG' if min(d) >= 0 and max(d) > 3 else 'THUONG'
        print('%-32s %7d %-22s %-16s %-16s %s  (d r%+d g%+d b%+d)'
              % (ten, n, '%d,%d..%d,%d' % vung, na, nb, ket, d[0], d[1], d[2]))
    print()
    print('nen.png = canh Main khong gan gi; <bien the>.png = canh do + mot armature.')
    print('CONG: khong kenh nao toi di. THUONG: co kenh toi di (cong khong lam duoc the).')


def main():
    # truoc parse_args: --help in mo ta co dau, console cp1252 se vo
    sys.stdout.reconfigure(encoding='utf-8')
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--chi-day', action='store_true')
    ap.add_argument('--nhanh', default='', help='chi chay mot luot: nen | hieu-ung | tuong | thu | bien-the')
    ap.add_argument('--so', action='store_true',
                    help='chi doc anh da chup, khong chay may ao')
    ap.add_argument('--phan-loai', action='store_true',
                    help='phan loai tung bien the trong BIEN_THE bang anh da chup')
    a = ap.parse_args()
    ANH.mkdir(exist_ok=True)

    if a.so or a.phan_loai:
        bang()
        return

    ds = [l for l in E.adb('devices').stdout.splitlines()
          if l.strip().endswith('device')]
    if not ds:
        raise SystemExit('khong thay may ao nao — bat emulator truoc')
    print('may ao:', ', '.join(l.split()[0] for l in ds))

    if a.chi_day:
        dung_de(DAU_DO_HIEN, HERE / '_dom')
        print('da dung ban de o', HERE / '_dom')
        return

    luot = [(DAU_DO_NEN, 'nen', 16),
            (DAU_DO_HIEN, 'hieu-ung', 20),
            (DAU_DO_TUONG, 'tuong', 18),
            (DAU_DO_THU, 'thu', 16)]
    if a.nhanh == 'bien-the':
        luot = [(DAU_DO_MOT % {'ten': t}, t, 18) for t in BIEN_THE]
    elif a.nhanh:
        luot = [x for x in luot if x[1] == a.nhanh]
    for probe, nhan, cho in luot:
        anh, dong = chay(probe, nhan, cho)
        print('--- %s ---' % nhan)
        for l in dong[:70]:
            print(' ', l)
        print('  anh:', anh)

    if not a.nhanh:
        print()
        bang()


if __name__ == '__main__':
    main()
