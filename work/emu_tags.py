"""Đo TAG THẬT của từng node, bằng cách hỏi chính engine bản gốc.

    python emu_tags.py --list            # xem các màn sẽ đo
    python emu_tags.py --screens 5       # đo 5 màn đầu
    python emu_tags.py --all             # đo hết

Vì sao phải làm thế này
-----------------------
Mã Lua bản gốc trỏ tới node gần như chỉ bằng `getChildByTag` (9.529 lần).
Tag đó KHÔNG nằm trong file .xgg — đã chứng minh bằng ba lối độc lập, và
cuối cùng bằng chính đối chiếu này: không trường nào trong bản ghi node
khớp với tag thật (xem mục "Dịch ngược libgame.so" trong README).

Engine tự sinh tag lúc nạp. Thay vì đoán quy luật, ta hỏi thẳng nó: chạy
bản gốc trong máy ảo, nạp từng bố cục, rồi gọi `getChildByTag` cho từng số
và ghi lại node nào trả về.

Cách chèn mã
------------
Game đặt package.path theo thứ tự: thư mục ngoài trước, assets trong APK
sau. Nên chỉ cần thả file Lua vào /storage/emulated/0/assets/sc/ là đè được
bản trong APK — không phải đóng gói lại, không phải ký lại.

Ba chỗ phải vá để game chạy tới được chỗ nạp bố cục, vì bản dịch ARM của
máy ảo (libndk_translation) gục ở mỗi biên thư viện gốc:
  * UMEvent:Init()            — thống kê Umeng
  * loadBackgroundBank/...    — FMOD
  * dừng trước sngHttMgr      — HTTP
Không cái nào cần cho việc đo.

Ràng buộc đã biết
-----------------
  * KHÔNG gọi getChildrenCount: tra khoá đó trên userdata làm bản dịch ARM
    chết ngay. Chỉ dùng getContentSize / getPosition / getChildByTag.
  * Máy ảo phải là ảnh x86_64 API 30 (chỉ ảnh đó có phiên dịch ARM 32-bit;
    máy ảo đời mới đã bỏ hẳn ảnh ARM, còn ảnh API 33 không có phiên dịch).
"""
import argparse
import atexit
import json
import os
import pathlib
import random
import re
import subprocess
import sys
import tempfile
import time

HERE = pathlib.Path(__file__).resolve().parent
PKG = 'com.cmn.buatanew'
# Dat ban de o thu muc NOI BO cua app, khong phai the nho ao.
#   * the nho ao chay tren FUSE nen chmod khong an; day bang quyen root
#     thi file thuoc UID root/UID cu voi quyen 600, va app doc khong duoc.
#     Trieu chung: game chay nhung KHONG mot moc nao hien ra, vi chinh
#     ban de KDebug cung khong doc duoc. Va UID doi moi lan cai lai APK.
#   * 'files/download' la duong tim THU HAI cua game, truoc ca assets da
#     giai nen — de o day thi khong dung toi ban goc.
REMOTE = '/data/data/com.cmn.buatanew/files/download'
SC = HERE.parent.parent / 'bravecross-game' / 'sc'
LAYOUT = HERE.parent.parent / 'bravecross-game' / 'layout_ref'
DEPTH_MAX = 8
# Tran so luot cho MOT man khi `--cay`. Ban dich ARM chi chet o MOT node moi
# luot, nen moi luot bo qua dung nhanh vua lam no chet va di them duoc. Do duoc:
# 6 luot khong du — UI_ArmyGroup_Campsite_Info 61 -> 235 node roi van thieu,
# UI_Destiny 12 -> 81 van thieu. `lua_list` cung lay so nay lam so buoc trai deu.
LUOT_MAX = 16


def adb_path():
    for p in (os.environ.get('ADB'),
              os.path.expandvars(r'%LOCALAPPDATA%\Microsoft\WinGet\Packages'
                                 r'\Google.PlatformTools_Microsoft.Winget.Source_8wekyb3d8bbwe'
                                 r'\platform-tools\adb.exe')):
        if p and pathlib.Path(p).exists():
            return p
    from shutil import which
    return which('adb')


ADB = adb_path()


def adb(*args, **kw):
    return subprocess.run([ADB] + list(args), capture_output=True, text=True,
                          encoding='utf-8', errors='replace', **kw)


def thiet_bi():
    """Serial cac may ao dang san sang, da sap."""
    ra = []
    for dong in adb('devices').stdout.splitlines()[1:]:
        phan = dong.split()
        if len(phan) >= 2 and phan[1] == 'device':
            ra.append(phan[0])
    return sorted(ra)


def con_song(pid):
    """Tien trinh con song khong.

    Do duoc, khong phai suy tu tai lieu:
      * pid do `os.getpid()` cua Python thi `os.kill(pid, 0)` chay duoc va
        KHONG giet tien trinh dich (no van `poll() == None` sau loi goi);
      * nhung pid lay tu Git Bash (`/proc/$$/winpid`) thi Python KHONG hoi
        duoc — nem `OSError: [WinError 87] The parameter is incorrect`.

    Nen phep thu nay CHI dung cho khoa do chinh Python ghi (moi lan ghi deu
    dung `os.getpid()`), va khoa do script shell ghi thi khong dung.
    """
    if pid <= 0:
        return False
    try:
        os.kill(pid, 0)
    except OSError:
        return False
    return True


def giu_khoa(bo_khoa, mo_ta):
    """Giu cho doc quyen may ao trong suot luot do. Tu nha khi thoat.

    Da mat 25 phut may ao mot lan vi chay hai ban cung luc: hai tien trinh cung
    day game.lua len cung mot may ao va cung ghi mot file ket qua, nen so do
    duoc la tron lan cua hai luot chu khong kiem chung duoc. Chan han o day.

    Khoa tinh theo SERIAL may ao chu khong theo ten file ket qua: hai luot ghi
    ra hai file khac nhau van dung chung mot may ao, nen khoa theo file thi
    khong chan duoc gi.

    Khoa nay KHONG thay doi_chung.lock cua doi_chung.sh — cai do chan hai ban
    A/B chay chong nhau, con cai nay chan hai luot cham vao may ao. Chay tuan
    tu thi moi luot tu lay roi tu nha, nen khong co chuyen khoa cha/con.
    """
    khoa = pathlib.Path(tempfile.gettempdir()) / (
        'emu_tags.%s.khoa' % (','.join(thiet_bi()) or 'khong-ro'))
    if khoa.exists():
        d = dict(l.split('=', 1) for l in khoa.read_text('utf-8').splitlines()
                 if '=' in l)
        if not bo_khoa:
            if con_song(int(d.get('pid') or 0)):
                raise SystemExit(
                    'DANG CO LUOT KHAC CHAY tren may ao nay.\n'
                    '  khoa  : %s\n  pid   : %s\n  bat   : %s\n'
                    '  mo ta : %s\n'
                    'Cho no xong, hoac chay lai voi --bo-khoa neu chac chan '
                    'khong con gi dang chay.'
                    % (khoa, d.get('pid'), d.get('bat'), d.get('mo_ta')))
            print('khoa cu cua tien trinh da chet (pid %s, bat %s) — lay lai'
                  % (d.get('pid'), d.get('bat')))
        else:
            print('--bo-khoa: pha khoa %s' % khoa)
    khoa.write_text('pid=%d\nbat=%s\nmo_ta=%s\n'
                    % (os.getpid(), time.strftime('%Y-%m-%d %H:%M:%S'), mo_ta),
                    encoding='utf-8')
    # atexit chu khong try/finally: `main()` con nhieu cho raise SystemExit
    # (ten man go sai, ...) va khong dang boc lai ca than ham chi vi cai nay.
    atexit.register(lambda: khoa.unlink(missing_ok=True))


def screens():
    """[(ten file .xgg, [ten node toan cuc])] lay tu layout_ref."""
    out = []
    for f in sorted(LAYOUT.glob('*.json')):
        doc = json.loads(f.read_text('utf-8'))
        names = []

        def walk(n):
            nm = n.get('name') or ''
            if nm and re.match(r'^[A-Za-z_]\w*$', nm):
                names.append(nm)
            for c in n.get('children', []):
                walk(c)

        for r in doc.get('roots', []):
            walk(r)
        if names:
            out.append((doc.get('file') or (f.stem + '.xgg'), names))
    return out


PROBE_HEAD = '''
-- === CHEN DE DO: do tag that (emu_tags.py sinh ra) ===
do
	local function mota(n)
		local w, h = 0, 0
		local ok, a, b = pcall(function() return n:getContentSize() end)
		if ok and a then w, h = a, (b or 0) end
		local x, y = 0, 0
		local ok2, c, d = pcall(function() return n:getPosition() end)
		if ok2 and c then x, y = c, (d or 0) end
		return string.format("%%g|%%g|%%g|%%g", w, h, x, y)
	end
	-- Chi hoi DUNG nhung tag ma ma goc that su dung, khong quet dai. Ban goc
	-- co 135 gia tri tag khac nhau, phu 100%% so luot getChildByTag — trong
	-- khi quet dai 0..60 chi phu 92%% ma van ton 61 luot hoi moi node.
	local TAGS = %(tags)s
	local function quet(man, duong, node, sau)
		if node == nil or sau > %(depth)d then return end
		for _, tg in ipairs(TAGS) do
			local ok, c = pcall(function() return node:getChildByTag(tg) end)
			if ok and c ~= nil then
				local d = duong .. "/" .. tg
				print("DOTAG|" .. man .. "|" .. d .. "|" .. mota(c))
				quet(man, d, c, sau + 1)
			end
		end
	end
	local DS = %(list)s
	for _, m in ipairs(DS) do
		local ok = pcall(function() loadLevelFile("conf/" .. m[1]) end)
		print("DOMAN|" .. m[1] .. "|" .. tostring(ok) .. "|%(token)s")
		if ok then
			for _, nm in ipairs(m[2]) do
				local n = rawget(_G, nm)
				if n ~= nil then
					print("DOTAG|" .. m[1] .. "|" .. nm .. "|" .. mota(n))
					quet(m[1], nm, n, 0)
				else
					-- Ten co trong bo cuc ma _G khong co: ca cay con duoi no
					-- KHONG duoc do, va truoc day khong co dong nao bao. Do
					-- duoc: UI_COG_CityInfo di "tron" ma chi 34/159 node.
					print("DOTREO|" .. m[1] .. "|" .. nm)
				end
			end
		end
	end
	print("DOXONG|%(token)s")
end
'''


# Cach do THU HAI: khong hoi tung tag, ma DI CA CAY bang getChildren() roi doc
# thang getTag() cua tung node. Cach hoi-tung-tag chi thay duoc node nao noi
# duoc tu mot node co ten toan cuc bang mot DAY CANH CO TAG; node nam sau mot
# canh khong tag thi khong bao gio toi. Cach di cay thi thay het.
#
# getChildren() va getTag() deu la API THAT: ma goc dung chung 26 va 225 lan
# (`CUIAssist.findNodeByName` di ca cay dung hai ham nay). getStringTag() tra
# ve TEN node — chinh `findNodeByName` so ten bang no.
#
# DUONG DAN la chi so con tung tang (1-based), dung cach ma goc duyet. Do tren
# hai man da do tron: chi so con cua engine TRUNG KHIT thu tu con trong file
# .xgg — UI_FriendsChatting 65/65 duong, UI_ArmyGroup_Campsite_ControlPanel
# 172/172, khong truot duong nao. Nho vay ghep duoc THANG, khong phai do
# vi-tri/kich thuoc nhu `emu_join.py` dang lam.
#
# NHUNG duong di nay KHONG phai luc nao cung chay het: ban dich ARM
# (libndk_translation) SIGSEGV khi hoi `getChildren()` vao mot so node hieu
# ung. Do duoc tren UI_ArmyGroup_Campsite_Info: di het 61/122 node roi chet
# (`Fatal signal`, `libndk`, khong co DOXONG), va cho chet doi theo so lenh da
# chay — bo bot mot loi goi thi di them duoc mot node. Nen phai DI LAI NHIEU
# LUOT: luot sau bo qua chinh nhanh da lam chet luot truoc (`BO`, xem `run`).
PROBE_CAY = '''
-- === CHEN DE DO: di ca cay, doc thang tag (emu_tags.py sinh ra) ===
do
	local function mota(n)
		local w, h = 0, 0
		local ok, a, b = pcall(function() return n:getContentSize() end)
		if ok and a then w, h = a, (b or 0) end
		local x, y = 0, 0
		local ok2, c, d = pcall(function() return n:getPosition() end)
		if ok2 and c then x, y = c, (d or 0) end
		return string.format("%%g|%%g|%%g|%%g", w, h, x, y)
	end
	local function chuoi(n, ten)
		local ok, v = pcall(function() return n[ten](n) end)
		if ok and v ~= nil then return tostring(v):gsub("|", "/") end
		return ""
	end
	-- BO phai khai TRUOC `di`: khai sau thi trong than `di` no la bien toan
	-- cuc (nil) va `BO[duong]` no ngay, ca phep do khong chay.
	local BO = %(bo)s
	local function di(man, duong, node, sau)
		if node == nil then return end
		if BO[duong] then return end
		print("DOCAY|" .. man .. "|" .. duong .. "|" .. chuoi(node, "getTag")
				.. "|" .. chuoi(node, "getStringTag") .. "|" .. mota(node))
		if sau >= %(depth)d then return end
		-- getChildren() tra nil (hoac loi) thi CA NHANH duoi bi bo, va truoc
		-- day khong co dong nao bao: man van duoc dong dau "tron", `bo` rong,
		-- nhin khong khac gi mot nhanh la. Do duoc: UI_COG_CityInfo "tron",
		-- bo rong, ma chi 34/159 node. Phai in ra thi moi dem duoc.
		local ok, ch = pcall(function() return node:getChildren() end)
		if not ok or ch == nil then
			print("DOCUT|" .. man .. "|" .. duong .. "|" .. tostring(ok))
			return
		end
		local okn, n = pcall(function() return #ch end)
		if not okn or type(n) ~= "number" then
			print("DOCUT|" .. man .. "|" .. duong .. "|dem")
			return
		end
		for i = 1, n do
			local ok2, c = pcall(function() return ch[i] end)
			if ok2 and c ~= nil then
				di(man, duong .. "/" .. i, c, sau + 1)
			end
		end
	end
	local DS = %(list)s
	for _, m in ipairs(DS) do
		local ok = pcall(function() loadLevelFile("conf/" .. m[1]) end)
		print("DOMAN|" .. m[1] .. "|" .. tostring(ok) .. "|%(token)s")
		if ok then
			for _, nm in ipairs(m[2]) do
				local n = rawget(_G, nm)
				if n ~= nil then
					di(m[1], nm, n, 0)
				else
					-- Ten co trong bo cuc ma _G khong co: ca cay con duoi no
					-- KHONG duoc do, va truoc day khong co dong nao bao — man
					-- van duoc dong dau "tron". Do duoc: UI_COG_CityInfo di
					-- "tron" trong khi chi 34/159 node.
					print("DOTREO|" .. m[1] .. "|" .. nm)
				end
			end
		end
	end
	print("DOXONG|%(token)s")
end
'''


def cac_tag():
    """Moi gia tri tag ma ma goc that su hoi, lay tu chinh ma Lua.

    Do duoc: 135 gia tri khac nhau, phu 100% so luot goi getChildByTag. Hoi
    dung chung thi vua phu kin vua khoi ton luot hoi cho nhung so khong ai
    dung — tag di tu 0 den 63535 nhung phan lon la thua.
    """
    import collections
    pat = re.compile(r'getChildByTag(?:InAllChildren)?\s*\(\s*(\d+)\s*\)')
    c = collections.Counter()
    for f in SC.rglob('*.lua'):
        c.update(int(m) for m in pat.findall(f.read_text('utf-8', 'ignore')))
    # Them 0..16 cho day: day la vung dac, va co node mang tag ma ma goc
    # khong hoi truc tiep (no hoi qua bien cuc bo).
    return sorted(set(c) | set(range(0, 17)))


def lua_list(items, xoay=0):
    """Danh sách màn cho đầu dò. `xoay` quay vòng DANH SÁCH NEO của từng màn.

    Vì sao quay: đầu dò đi lần lượt từng neo, và bản dịch ARM chết giữa đường
    nên các neo SAU chỗ chết không bao giờ được đi trong lượt đó. Lượt sau bỏ
    qua đúng nhánh vừa chết (xem `bo`), nhưng neo chưa tới cũng bị bỏ luôn —
    nên nếu chỗ chết cứ nằm ở đầu danh sách thì các neo cuối không bao giờ tới.
    Quay vòng thì mỗi lượt mở đầu ở một neo khác.

    LÝ DO NÀY LÀ SUY LUẬN CẤU TRÚC, CHƯA ĐO ĐƯỢC LỢI ÍCH. Đừng đọc nó thành
    "quay là bắt buộc". Bản ghi cũ ở đây nói quay là thứ duy nhất tới được
    `ttfCampCountdownTree` của UI_ArmyGroup_Campsite_Info — **câu đó sai, và
    sai vì tôi đọc nhầm khoá**. Tag của nó đã đo được từ trước, nằm dưới khoá
    theo CHỈ SỐ CON `ndArmyGroupCampsiteShot/3/2/31` (tag 0, 40×40; con `/1`=2,
    `/2`=3 — đúng chín tag mà `CUIArmyGroupCampsite.lua:533` hỏi). Tôi đi tìm
    khoá chứa chuỗi "CountdownTree" nên không thấy, rồi dựng lên cả một chẩn
    đoán "16 lượt không đời nào tới được". Thứ thật sự chặn nó là khâu ÁP dữ
    liệu: `emu_join.py --ghi` chưa từng chạy đường chỉ số con.

    Đối chứng sạch (`--khong-xoay`, cùng mã, cùng trần 16 lượt, chỉ khác `xoay`)
    nằm ở mục "Quay neo" trong README — số đo ở đó mới là thứ được phép trích.

    TRẢI ĐỀU, KHÔNG XOAY TỪNG NẤC. Bản đầu làm `k = xoay % len(names)`, mà
    `xoay` chạy 0..15, nên với màn nhiều neo thì vị trí mở đầu **chỉ nhích trong
    16 chỗ đầu** — mọi neo sau vị trí 16 vẫn không bao giờ được mở đầu. Đo được:
    neo đo được LUÔN là một TIỀN TỐ của danh sách, không bao giờ có lỗ:
    `UI_Main_ControlPanel` 21/75 neo (đúng vị trí 1..21), `UI_Hero` 84/168,
    `UI_Friends` 28/33 — cả ba đều liền mạch từ 1. Nay bước nhảy là
    `len(names)/LUOT_MAX`, nên 16 lượt trải khắp danh sách; lượt mở đầu ở neo
    thứ k đi k hết tới cuối rồi vòng về đầu, nên nó vẫn học được cả hai đoạn.
    """
    parts = []
    for fn, names in items:
        ns = names
        if xoay and len(names) > 1:
            k = (xoay * len(names)) // LUOT_MAX % len(names)
            ns = names[k:] + names[:k]
        parts.append('{"%s",{%s}}'
                     % (fn, ','.join('"%s"' % n for n in ns)))
    return '{' + ','.join(parts) + '}'


def build_overrides(items, out_dir, head=PROBE_HEAD, sau=None, bo=(), token='0',
                    xoay=0):
    """Dựng cây file đè: KDebug (bật log), um_event (tắt Umeng), game.lua (vá + đo)."""
    out = pathlib.Path(out_dir)
    (out / 'sc/share').mkdir(parents=True, exist_ok=True)
    (out / 'sc/user/Globals').mkdir(parents=True, exist_ok=True)

    # KHONG de KDebug. Da thu ha KDebug.OnlineLevel de bat lai cac moc
    # "game.lua 1", "game.lua 2"... ma ban phat hanh tat di — lam vay thi game
    # chet ngay, khong mot dong nao ra. `print` tran cua Lua di thang ra
    # logcat qua CCLog, dung no la du va con nhanh gap nam lan.
    t = (SC / 'user/Globals/um_event.lua').read_text('utf-8')
    t += ('\n\n-- CHEN: thong ke Umeng lam ban dich ARM cua may ao chet.\n'
          'function UMEvent:Init() end\nfunction UMEvent:StartGame() end\n')
    (out / 'sc/user/Globals/um_event.lua').write_text(t, encoding='utf-8')

    g = (SC / 'game.lua').read_text('utf-8')
    # Dau nhan biet: print tran, khong phu thuoc ban de KDebug. Neu dong
    # nay khong hien ra thi nghia la game dang chay game.lua GOC.
    g = 'print("CHEN|dang dung ban de game.lua")\n' + g
    # In package.path ngay sau khi game dung xong, de biet require tim o dau.
    g = g.replace('sngSetSearchFileSuffix(".sc");',
                  'sngSetSearchFileSuffix(".sc");\n'
                  'print("CHEN|package.path=" .. tostring(package.path))\n', 1)
    anchor = 'KDebug.PrintDebug("game.lua 6")'
    if anchor not in g:
        raise SystemExit('game.lua khong co moc "game.lua 6"')
    g = g.replace(anchor, anchor + (
        '\n-- CHEN: FMOD la thu vien ARM, goi qua ban dich la SIGSEGV.\n'
        'local function _bo() end\n'
        'loadBackgroundBank = _bo\nloadEffectBank = _bo\npushBankStack = _bo\n'
        'print("CHEN|da tat am thanh")\n'), 1)
    # Cam moc sau tung buoc lon con lai, de con biet chet o dau.
    for tim in ('g_CUIOptions:InitGameInfo()', 'g_CUILoad:InitUI()',
                'sngHttMgr = ', 'XGAnalytics:logEventByID(XGAnalytics.EVENT_ID.LOADCONFIG)'):
        if '\n' + tim in g:
            g = g.replace('\n' + tim,
                          '\nprint("CHEN|truoc %s")\n' % tim[:34] + tim, 1)
    tags = cac_tag()
    probe = head % {'list': lua_list(items, xoay),
                    'depth': DEPTH_MAX if sau is None else sau,
                    'tags': '{' + ','.join(str(t) for t in tags) + '}',
                    'bo': '{' + ','.join('["%s"]=true' % b for b in bo) + '}',
                    'token': token}
    # PHAI neo vao cho GOI, khong phai cho DINH NGHIA: game.lua co ca
    # 'function sngHttMgr:createInstance()' (dong 163) lan loi goi (dong 488).
    # Neo nham thi probe roi vao giua mot dinh nghia ham, game.lua hong cu
    # phap va khong nap duoc — trieu chung la KHONG mot moc nao hien ra.
    stop = '\nsngHttMgr:createInstance()'
    if g.count(stop) != 1:
        raise SystemExit('khong tim duoc dung mot loi goi sngHttMgr:createInstance()')
    # Do XONG thi dung han: phan sau can mang, ma mang lai lam ban dich chet.
    g = g.replace(stop, '\n' + probe + '\ndo return end\n' + stop, 1)
    (out / 'sc/game.lua').write_text(g, encoding='utf-8')
    return out / 'sc'


ACT = 'org.kingsoft.com.R1_OLChina'


def cap_quyen():
    """Tra quyen so huu ve cho app.

    adb push chay bang root nen file ra thuoc root; app doc khong duoc. UID
    cua app con DOI moi lan cai lai APK, nen phai hoi lai chu khong ghi cung.
    """
    uid = adb('shell', 'stat', '-c', '%U:%G',
              '/data/data/' + PKG).stdout.strip()
    if uid:
        adb('shell', 'chown', '-R', uid, REMOTE)
    adb('shell', 'chmod', '-R', '755', REMOTE)


def doc_log():
    txt = adb('logcat', '-d').stdout
    return [m.group(0) for m in
            re.finditer(r'DO(?:TAG|CAY|MAN|XONG)\|?[^\n\r]*', txt)]


def do_mot_man(item, han=45, head=PROBE_HEAD, sau=None, bo=(), token='0', xoay=0):
    """Đo MỘT màn trong một lần khởi động game.

    Phải một màn một lần: nạp nhiều bố cục liên tiếp trong cùng một lần chạy
    thì bản dịch ARM của máy ảo gục (game chết trước cả dòng log đầu). Đã
    loại trừ hai nguyên nhân khác — cú pháp bản game.lua sinh ra đúng (kiểm
    bằng loadstring), và bản đè một màn chạy lại trên máy ảo mới vẫn ra dữ
    liệu, nên không phải máy ảo rệu.

    `bo` là danh sách đường dẫn (theo chỉ số con) KHÔNG đi xuống nữa — dùng
    cho lượt sau của `run`, sau khi lượt trước đã làm bản dịch ARM chết.

    `token` là dấu riêng của LƯỢT NÀY, in kèm vào cả DOMAN lẫn DOXONG. Phải
    có: `logcat -c` không phải lúc nào cũng xoá sạch, nên nếu nhận DOXONG trần
    thì có lúc nhận nhầm DOXONG của lượt trước, kết luận "đi trọn" trong khi
    game vừa chết ở node thứ 12 — và vì đã tin là trọn nên không thử lại lượt
    nữa. Đo được: 17/283 màn bị đóng dấu "tron" mà dữ liệu khuyết (màn nào
    cũng chỉ có tên gốc ĐẦU TIÊN xuất hiện, vd UI_Destiny 12 node, UI_Hero 468
    trên 168 tên gốc). Dấu riêng làm cho lượt sau không thể nhận nhầm nữa.

    `xoay` quay vòng danh sách neo của màn (xem `lua_list`). Lượt `n` truyền
    `n - 1`.
    """
    sc_dir = build_overrides([item], HERE / '_emu', head, sau, bo, token,
                             xoay=xoay)
    adb('shell', 'am', 'force-stop', PKG)
    # PHAI cho tien trinh cu chet han. Neu khong, 'am start' bi bo qua va man
    # do khong ra du lieu — trieu chung la cu mot man duoc thi mot man truot,
    # xen ke deu dan.
    for _ in range(20):
        if not adb('shell', 'pidof', PKG).stdout.strip():
            break
        time.sleep(0.5)
    adb('push', str(sc_dir / 'game.lua'), REMOTE + '/sc/game.lua')
    cap_quyen()
    adb('logcat', '-b', 'all', '-c')
    adb('shell', 'am', 'start', '-n', '%s/%s' % (PKG, ACT))

    # PHAI doi dong DOMAN CUA CHINH man nay, VA doi DOXONG dung dau cua LUOT
    # NAY (`token`). 'logcat -c' khong phai luc nao cung xoa sach: nhan DOXONG
    # tran thi co luc nhan nham DOXONG cua luot truoc — do duoc 17/283 man bi
    # dong dau "tron" trong khi chi di duoc 12 node.
    dau = 'DOMAN|' + item[0] + '|'
    duoi = 'DOXONG|' + token
    cho = 0
    while cho < han:
        time.sleep(3)
        cho += 3
        lines = doc_log()
        if any(l.startswith(dau) for l in lines) and \
                any(l.startswith(duoi) for l in lines):
            return lines, cho
        # Game chet giua chung thi khoi cho het gio.
        if cho >= 21 and not adb('shell', 'pidof', PKG).stdout.strip():
            return doc_log(), cho
        # Con song ma qua lau van chua toi phep do thi cung bo — man chay
        # duoc chi mat 6 giay.
        if cho >= 33 and not any(l.startswith(dau) for l in lines):
            return lines, cho
    return doc_log(), cho


def gop(lines, data, loaded, cay=None, treo=None, cut=None):
    for l in lines:
        p = l.split('|')
        if p[0] == 'DOMAN' and len(p) >= 3:
            loaded[p[1]] = p[2]
        elif p[0] == 'DOTREO' and len(p) >= 3 and treo is not None:
            treo.setdefault(p[1], set()).add(p[2])
        elif p[0] == 'DOCUT' and len(p) >= 3 and cut is not None:
            cut.setdefault(p[1], set()).add(p[2])
        elif p[0] == 'DOTAG' and len(p) >= 7:
            try:
                w, h, x, y = (float(v) for v in p[3:7])
            except ValueError:
                continue
            data.setdefault(p[1], {})[p[2]] = {'w': w, 'h': h, 'x': x, 'y': y}
        elif p[0] == 'DOCAY' and len(p) >= 9 and cay is not None:
            try:
                w, h, x, y = (float(v) for v in p[5:9])
            except ValueError:
                continue
            # Duong dan la chi so con tung tang (1-based) — dung cach ma goc
            # duyet: `for i = 1, #children do ... children[i]`.
            cay.setdefault(p[1], {})[p[2]] = {
                'tag': p[3], 'name': p[4], 'w': w, 'h': h, 'x': x, 'y': y}


def run(items, out_json, head=PROBE_HEAD, sau=None, cay=False, xoay=True):
    """Quét lần lượt. Ghi tăng dần, và bỏ qua màn đã có — chạy lại là tiếp tục.

    Với `cay=True` thì mỗi màn có thể phải chạy NHIỀU LƯỢT: bản dịch ARM chết
    giữa đường đi (xem PROBE_CAY). Lượt sau bỏ qua đúng nhánh đã làm chết lượt
    trước, nên đi được xa hơn. Ghi lại `lan` và `bo` để còn biết đã phải bỏ gì.
    """
    out = pathlib.Path(out_json)
    data, loaded, cay_data = {}, {}, {}
    xong, so_lan, bo_man, treo_man, cut_man = {}, {}, {}, {}, {}
    if out.exists():
        cu = json.loads(out.read_text('utf-8'))
        data, loaded = cu.get('nodes', {}), cu.get('loaded', {})
        cay_data = cu.get('cay', {})
        xong, so_lan = cu.get('xong', {}), cu.get('lan', {})
        bo_man = cu.get('bo', {})
        treo_man = {m: set(v) for m, v in cu.get('treo', {}).items()}
        cut_man = {m: set(v) for m, v in cu.get('cut', {}).items()}
        print('da co %d man, chay tiep' % len(loaded))

    # KDebug + um_event khong doi giua cac man, day mot lan; moi vong sau do
    # chi day lai game.lua cho nhanh. Token o day chi de dong goi du file —
    # vong do that su sinh token rieng ngay duoi.
    sc_dir = build_overrides([items[0]], HERE / '_emu', head, sau,
                             token='%08x' % random.getrandbits(32))
    adb('shell', 'mkdir', '-p', REMOTE)
    adb('push', str(sc_dir), REMOTE + '/')
    cap_quyen()
    # Vong dem cua logcat mac dinh chi 2 MiB, ma mot man di ca cay in vai tram
    # dong DOCAY CON xen vao do la rat nhieu vet loi cua game. Noi rong truoc
    # cho chac; may nao khong ho tro -G thi thoi, khong phai loi.
    adb('logcat', '-G', '32M')

    def ghi():
        out.write_text(json.dumps(
            {'loaded': loaded, 'nodes': data, 'cay': cay_data,
             'xong': xong, 'lan': so_lan, 'bo': bo_man,
             'treo': {m: sorted(v) for m, v in treo_man.items()},
             'cut': {m: sorted(v) for m, v in cut_man.items()}},
            ensure_ascii=False, indent=1), encoding='utf-8')

    t0 = time.time()
    for i, item in enumerate(items, 1):
        man = item[0]
        # Bo qua man DA CO du lieu, khong phai man da chay: man truot phai
        # duoc thu lai khi chay tiep.
        if (cay_data if cay else data).get(man) and (not cay or xong.get(man)):
            continue
        bo = set(bo_man.get(man, []))
        cho_tong = 0
        lan = 0
        tok = ''
        khong_tien = 0
        for lan in range(1, LUOT_MAX + 1):
            # Token MOI moi luot: DOXONG cua luot truoc khong dung lai duoc.
            tok = '%08x' % random.getrandbits(32)
            truoc_duong = len((cay_data if cay else data).get(man, {}))
            truoc_bo = len(bo)
            lines, cho = do_mot_man(item, head=head, sau=sau,
                                    bo=sorted(bo), token=tok,
                                    xoay=(lan - 1) if xoay else 0)
            cho_tong += cho
            gop(lines, data, loaded, cay_data,
                treo_man.setdefault(man, set()),
                cut_man.setdefault(man, set()))
            if any(l.startswith('DOXONG|' + tok) for l in lines):
                break
            # Cho chet = duong DOCAY cuoi cung cua CHINH man nay. Bo qua no thi
            # luot sau di tiep duoc qua cho do.
            cuoi = [l.split('|')[2] for l in lines
                    if l.startswith('DOCAY|' + man + '|')]
            if cuoi:
                bo.add(cuoi[-1])
            # Dung theo TIEN BO, khong theo "chet lai dung cho cu". Khi `xoay`
            # quay vong danh sach neo (xem lua_list), mot luot co the mo dau o
            # neo khac va hoc duoc doan khac TRONG KHI van chet o cung mot node
            # — dung lai theo cho chet thi vut mat chinh cai loi ich cua quay.
            # Do duoc: UI_ArmyGroup_Campsite_Info dung o luot 6 vi ly do do,
            # trong khi ban khong quay di het 16 luot (xem muc "Quay neo" trong
            # README — do la phep do DUY NHAT duoc phep trich cho loi ich nay).
            # Luat nay khong bao gio dung som hon ban cu theo kieu "thay cho
            # chet la dung": tien bo la dieu kien DU de di tiep, va tran van 16.
            if (len((cay_data if cay else data).get(man, {})) == truoc_duong
                    and len(bo) == truoc_bo):
                khong_tien += 1
                if khong_tien >= 2:
                    break
            else:
                khong_tien = 0
        loaded.setdefault(man, 'khong-ra-du-lieu')
        xong[man] = any(l.startswith('DOXONG|' + tok) for l in lines)
        so_lan[man] = lan
        bo_man[man] = sorted(bo)
        n = len((cay_data if cay else data).get(man, {}))
        # "Tron" phai co nghia la KHONG bo nhanh nao. `xong` chi noi rang da di
        # het danh sach neo — nhanh nam trong `bo` van bi bo qua lang le, nen
        # mot man co the vua "tron" vua thieu du lieu (do duoc: UI_COG_CityInfo
        # tron ma chi 34/159 node). In ro ra thi khong con lua duoc nhau.
        if not xong[man]:
            trang = 'THIEU'
        elif bo:
            trang = 'tron-bo%d' % len(bo)
        else:
            trang = 'tron'
        con = (len(items) - i) * (time.time() - t0) / max(i, 1)
        print('[%3d/%3d] %-46s %4d node  %3ds  %d luot  %s (con ~%d phut)'
              % (i, len(items), man[:46], n, cho_tong, lan,
                 trang, con / 60), flush=True)
        ghi()
    co = sum(1 for m in loaded if data.get(m) or cay_data.get(m))
    print('xong: %d/%d man co du lieu, %d node -> %s'
          % (co, len(loaded),
             sum(len(v) for v in data.values()) + sum(len(v) for v in cay_data.values()),
             out))
    if cay:
        sach = sum(1 for m in xong if xong[m] and not bo_man.get(m))
        print('man di tron, khong bo nhanh nao: %d/%d' % (sach, len(xong)))
        treo = {m: v for m, v in treo_man.items() if v}
        if treo:
            print('man co ten trong bo cuc ma _G khong co: %d, tong %d ten'
                  % (len(treo), sum(len(v) for v in treo.values())))
        cut = {m: v for m, v in cut_man.items() if v}
        if cut:
            print('man bi getChildren() tra nil giua cay: %d, tong %d nhanh'
                  % (len(cut), sum(len(v) for v in cut.values())))
            for m in sorted(cut, key=lambda m: -len(cut[m]))[:10]:
                print('   %-44s %d nhanh' % (m[:44], len(cut[m])))
    return data


def main():
    # Phai doi TRUOC parse_args: `--help` in ca mo ta co dau tieng Viet, ma console
    # cp1252 cua Windows thi nem UnicodeEncodeError ngay giua duong.
    sys.stdout.reconfigure(encoding='utf-8')
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--screens', type=int, default=3)
    ap.add_argument('--all', action='store_true')
    ap.add_argument('--list', action='store_true')
    ap.add_argument('--match', default='', help='chi do man co ten chua chuoi nay')
    # --match khop CHUA chuoi, nen "UI_Friends" keo theo ca UI_FriendsChatting.
    # Khi chay lai dung nhung man con thieu thi phai khop dung ten.
    ap.add_argument('--chi', default=None,
                    help='chi do dung nhung man nay, ngan cach bang dau phay')
    ap.add_argument('--out', default=str(HERE / 'tags_that.json'))
    # Cach do thu hai: di ca cay roi doc thang getTag(), thay vi hoi tung tag.
    ap.add_argument('--cay', action='store_true',
                    help='di ca cay bang getChildren/getTag (do duoc ca node '
                         'sau mot canh khong tag)')
    ap.add_argument('--sau', type=int, default=None, help='do sau toi da')
    # Nhanh DOI CHUNG cho phep quay neo: cung ma, cung so luot, chi khac `xoay`.
    # Khong co no thi moi so sanh "quay" / "khong quay" deu dinh cai bug token cu.
    ap.add_argument('--khong-xoay', action='store_true',
                    help='tat quay neo (nhanh doi chung cua --xoay)')
    # Do DUNG vai neo, theo dung thu tu dua vao. Sinh ra de pha tran do: neo
    # chua toi duoc nam SAU mot cho ma ban dich ARM chet, ma `bo` chi bo duoc
    # MOT duong moi luot nen co man khong bao gio di het phan dau. Bo han phan
    # dau di thi cay con cua neo can do khong con bi cho chet chan nua.
    # Do duoc: UI_Main_ControlPanel khong quay thi chi toi 2/75 neo, va
    # snsMainToolArmySoul (neo 41/75) khong bao gio duoc do.
    ap.add_argument('--neo', default=None,
                    help='chi do dung nhung neo nay, theo thu tu nay, ngan cach '
                         'bang dau phay (vd: --neo "lMainToolbarTop,snsMainUIGold")')
    ap.add_argument('--bo-khoa', action='store_true',
                    help='pha khoa may ao cu — chi khi chac chan khong con luot '
                         'nao dang chay')
    a = ap.parse_args()

    if not ADB:
        raise SystemExit('khong thay adb')
    items = screens()
    if a.match:
        items = [x for x in items if a.match in x[0]]
    if a.chi is not None:
        muon = [t.strip() for t in a.chi.split(',') if t.strip()]
        # rong thi dung han: `--chi ""` (vd do `$(cat …)` hong) ma coi nhu khong
        # loc thi bo do ca 287 man roi cat con 3 — do duoc, va ton 3 luot may ao.
        if not muon:
            raise SystemExit('--chi rong')
        items = [x for x in items if x[0] in muon]
        thieu = [t for t in muon if t not in {x[0] for x in items}]
        if thieu:
            # Go sai ten thi `items` rong va bo do "chay xong" ma khong do gi —
            # dung cai bay vua phai tranh o phan doc log.
            raise SystemExit('khong co man: %s' % ', '.join(thieu))
    if a.neo is not None:
        muon = [t.strip() for t in a.neo.split(',') if t.strip()]
        if not muon:
            raise SystemExit('--neo rong')
        # Giu DUNG thu tu nguoi goi dua vao, khong theo thu tu bo cuc: do neo
        # nao truoc la do NGUOI DO quyet dinh (neo quan trong nhat do truoc,
        # phong khi tien trinh chet giua duong).
        items = [(fn, [n for n in muon if n in set(names)]) for fn, names in items]
        items = [x for x in items if x[1]]
        if not items:
            raise SystemExit('--neo khong khop neo nao: %s' % ', '.join(muon))
        # Ten go sai thi bi lang le bo qua — noi ra de khong do thieu roi tuong
        # la neo do khong ton tai.
        co = {n for _, ns in items for n in ns}
        if len(co) < len(muon):
            print('CANH BAO: %d/%d ten khong khop neo nao: %s'
                  % (len(muon) - len(co), len(muon),
                     ', '.join(n for n in muon if n not in co)))
    if a.list:
        for fn, names in items[:40]:
            print('%-44s %d node co ten' % (fn, len(names)))
        print('... tong %d man' % len(items))
        return
    # `--chi` tu no da la mot danh sach ngan: cat them con 3 man nua thi do
    # duoc dung 3 man dau (theo thu tu ten file) chu khong phai 3 man minh muon
    # — da mac, nen `--chi` mien luon cho `--screens`.
    if not a.all and a.chi is None:
        items = items[:a.screens]
    print('do %d man' % len(items))
    # Lay khoa SAU khi da loc xong va NGAY TRUOC khi cham vao may ao: phan doc
    # bo cuc khong dung chung gi voi ai, con `--list` thi thoat truoc do roi.
    giu_khoa(a.bo_khoa, mo_ta=' '.join(sys.argv[1:])[:200])
    if a.cay:
        run(items, a.out, PROBE_CAY, a.sau, cay=True, xoay=not a.khong_xoay)
    else:
        run(items, a.out)


if __name__ == '__main__':
    main()
