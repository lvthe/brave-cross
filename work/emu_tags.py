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
import json
import os
import pathlib
import re
import subprocess
import sys
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
		print("DOMAN|" .. m[1] .. "|" .. tostring(ok))
		if ok then
			for _, nm in ipairs(m[2]) do
				local n = rawget(_G, nm)
				if n ~= nil then
					print("DOTAG|" .. m[1] .. "|" .. nm .. "|" .. mota(n))
					quet(m[1], nm, n, 0)
				end
			end
		end
	end
	print("DOXONG")
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


def lua_list(items):
    parts = []
    for fn, names in items:
        ns = ','.join('"%s"' % n for n in names)
        parts.append('{"%s",{%s}}' % (fn, ns))
    return '{' + ','.join(parts) + '}'


def build_overrides(items, out_dir):
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
    probe = PROBE_HEAD % {'list': lua_list(items), 'depth': DEPTH_MAX,
                          'tags': '{' + ','.join(str(t) for t in tags) + '}'}
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
            re.finditer(r'DO(?:TAG|MAN|XONG)\|?[^\n\r]*', txt)]


def do_mot_man(item, han=45):
    """Đo MỘT màn trong một lần khởi động game.

    Phải một màn một lần: nạp nhiều bố cục liên tiếp trong cùng một lần chạy
    thì bản dịch ARM của máy ảo gục (game chết trước cả dòng log đầu). Đã
    loại trừ hai nguyên nhân khác — cú pháp bản game.lua sinh ra đúng (kiểm
    bằng loadstring), và bản đè một màn chạy lại trên máy ảo mới vẫn ra dữ
    liệu, nên không phải máy ảo rệu.
    """
    sc_dir = build_overrides([item], HERE / '_emu')
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

    # PHAI doi dong DOMAN CUA CHINH man nay roi moi tin DOXONG. 'logcat -c'
    # khong phai luc nao cung xoa sach: neu con DOXONG cua vong truoc thi vong
    # sau ket luan ngay sau 3 giay va man do mat trang — trieu chung lai la
    # mot man duoc, mot man truot, xen ke.
    dau = 'DOMAN|' + item[0] + '|'
    cho = 0
    while cho < han:
        time.sleep(3)
        cho += 3
        lines = doc_log()
        if any(l.startswith(dau) for l in lines) and \
                any(l.startswith('DOXONG') for l in lines):
            return lines, cho
        # Game chet giua chung thi khoi cho het gio.
        if cho >= 21 and not adb('shell', 'pidof', PKG).stdout.strip():
            return doc_log(), cho
        # Con song ma qua lau van chua toi phep do thi cung bo — man chay
        # duoc chi mat 6 giay.
        if cho >= 33 and not any(l.startswith(dau) for l in lines):
            return lines, cho
    return doc_log(), cho


def gop(lines, data, loaded):
    for l in lines:
        p = l.split('|')
        if p[0] == 'DOMAN' and len(p) >= 3:
            loaded[p[1]] = p[2]
        elif p[0] == 'DOTAG' and len(p) >= 7:
            try:
                w, h, x, y = (float(v) for v in p[3:7])
            except ValueError:
                continue
            data.setdefault(p[1], {})[p[2]] = {'w': w, 'h': h, 'x': x, 'y': y}


def run(items, out_json):
    """Quét lần lượt. Ghi tăng dần, và bỏ qua màn đã có — chạy lại là tiếp tục."""
    out = pathlib.Path(out_json)
    data, loaded = {}, {}
    if out.exists():
        cu = json.loads(out.read_text('utf-8'))
        data, loaded = cu.get('nodes', {}), cu.get('loaded', {})
        print('da co %d man, chay tiep' % len(loaded))

    # KDebug + um_event khong doi giua cac man, day mot lan; moi vong sau do
    # chi day lai game.lua cho nhanh.
    sc_dir = build_overrides([items[0]], HERE / '_emu')
    adb('shell', 'mkdir', '-p', REMOTE)
    adb('push', str(sc_dir), REMOTE + '/')
    cap_quyen()

    t0 = time.time()
    for i, item in enumerate(items, 1):
        man = item[0]
        # Bo qua man DA CO du lieu, khong phai man da chay: man truot phai
        # duoc thu lai khi chay tiep.
        if data.get(man):
            continue
        lines, cho = do_mot_man(item)
        gop(lines, data, loaded)
        loaded.setdefault(man, 'khong-ra-du-lieu')
        n = len(data.get(man, {}))
        con = (len(items) - i) * (time.time() - t0) / max(i, 1)
        print('[%3d/%3d] %-46s %4d node  %3ds  (con ~%d phut)'
              % (i, len(items), man[:46], n, cho, con / 60), flush=True)
        out.write_text(json.dumps({'loaded': loaded, 'nodes': data},
                                  ensure_ascii=False, indent=1), encoding='utf-8')
    co = sum(1 for m in loaded if data.get(m))
    print('xong: %d/%d man co du lieu, %d node -> %s'
          % (co, len(loaded), sum(len(v) for v in data.values()), out))
    return data


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--screens', type=int, default=3)
    ap.add_argument('--all', action='store_true')
    ap.add_argument('--list', action='store_true')
    ap.add_argument('--match', default='', help='chi do man co ten chua chuoi nay')
    ap.add_argument('--out', default=str(HERE / 'tags_that.json'))
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')

    if not ADB:
        raise SystemExit('khong thay adb')
    items = screens()
    if a.match:
        items = [x for x in items if a.match in x[0]]
    if a.list:
        for fn, names in items[:40]:
            print('%-44s %d node co ten' % (fn, len(names)))
        print('... tong %d man' % len(items))
        return
    if not a.all:
        items = items[:a.screens]
    print('do %d man' % len(items))
    run(items, a.out)


if __name__ == '__main__':
    main()
