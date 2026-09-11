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
REMOTE = '/storage/emulated/0/assets'
SC = HERE.parent.parent / 'bravecross-game' / 'sc'
LAYOUT = HERE.parent.parent / 'bravecross-game' / 'layout_ref'
TAG_MAX = 30
DEPTH_MAX = 4


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
	local function quet(man, duong, node, sau)
		if node == nil or sau > %(depth)d then return end
		for tg = -1, %(tagmax)d do
			local ok, c = pcall(function() return node:getChildByTag(tg) end)
			if ok and c ~= nil then
				local d = duong .. "/" .. tg
				KDebug.PrintDebug("DOTAG|" .. man .. "|" .. d .. "|" .. mota(c))
				quet(man, d, c, sau + 1)
			end
		end
	end
	local DS = %(list)s
	for _, m in ipairs(DS) do
		local ok = pcall(function() loadLevelFile("conf/" .. m[1]) end)
		KDebug.PrintDebug("DOMAN|" .. m[1] .. "|" .. tostring(ok))
		if ok then
			for _, nm in ipairs(m[2]) do
				local n = rawget(_G, nm)
				if n ~= nil then
					KDebug.PrintDebug("DOTAG|" .. m[1] .. "|" .. nm .. "|" .. mota(n))
					quet(m[1], nm, n, 0)
				end
			end
		end
	end
	KDebug.PrintDebug("DOXONG")
end
'''


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

    t = (SC / 'share/KDebug.lua').read_text('utf-8')
    t += ('\n\n-- CHEN: ban phat hanh dat muc log cao nen PrintDebug im lang.\n'
          'KDebug.OnlineLevel = KDebug.enumLevel.DEBUG\n'
          'function KDebug.writeToFile() end\n')
    (out / 'sc/share/KDebug.lua').write_text(t, encoding='utf-8')

    t = (SC / 'user/Globals/um_event.lua').read_text('utf-8')
    t += ('\n\n-- CHEN: thong ke Umeng lam ban dich ARM cua may ao chet.\n'
          'function UMEvent:Init() end\nfunction UMEvent:StartGame() end\n')
    (out / 'sc/user/Globals/um_event.lua').write_text(t, encoding='utf-8')

    g = (SC / 'game.lua').read_text('utf-8')
    anchor = 'KDebug.PrintDebug("game.lua 6")'
    if anchor not in g:
        raise SystemExit('game.lua khong co moc "game.lua 6"')
    g = g.replace(anchor, anchor + (
        '\n-- CHEN: FMOD la thu vien ARM, goi qua ban dich la SIGSEGV.\n'
        'local function _bo() end\n'
        'loadBackgroundBank = _bo\nloadEffectBank = _bo\npushBankStack = _bo\n'
        'KDebug.PrintDebug("CHEN|da tat am thanh")\n'), 1)
    # Cam moc sau tung buoc lon con lai, de con biet chet o dau.
    for tim in ('g_CUIOptions:InitGameInfo()', 'g_CUILoad:InitUI()',
                'sngHttMgr = ', 'XGAnalytics:logEventByID(XGAnalytics.EVENT_ID.LOADCONFIG)'):
        if '\n' + tim in g:
            g = g.replace('\n' + tim,
                          '\nKDebug.PrintDebug("CHEN|truoc %s")\n' % tim[:34] + tim, 1)
    probe = PROBE_HEAD % {'list': lua_list(items), 'depth': DEPTH_MAX,
                          'tagmax': TAG_MAX}
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


def run(items, out_json):
    work = HERE / '_emu'
    sc_dir = build_overrides(items, work)
    adb('shell', 'am', 'force-stop', PKG)
    adb('push', str(sc_dir), REMOTE + '/')
    adb('shell', 'chmod', '-R', '777', REMOTE)
    adb('logcat', '-c')
    adb('shell', 'monkey', '-p', PKG, '-c', 'android.intent.category.LAUNCHER', '1')

    lines, waited = [], 0
    while waited < 900:
        time.sleep(10)
        waited += 10
        txt = adb('logcat', '-d').stdout
        lines = [m.group(0) for m in re.finditer(r'DO(?:TAG|MAN|XONG)\|?[^\n\r]*', txt)]
        if any(l.startswith('DOXONG') for l in lines):
            break
    print('doc duoc %d dong sau %ds' % (len(lines), waited))

    data, loaded = {}, {}
    for l in lines:
        p = l.split('|')
        if p[0] == 'DOMAN' and len(p) >= 3:
            loaded[p[1]] = p[2]
        elif p[0] == 'DOTAG' and len(p) >= 7:
            man, duong = p[1], p[2]
            w, h, x, y = (float(v) for v in p[3:7])
            data.setdefault(man, {})[duong] = {'w': w, 'h': h, 'x': x, 'y': y}
    pathlib.Path(out_json).write_text(json.dumps(
        {'loaded': loaded, 'nodes': data}, ensure_ascii=False, indent=1),
        encoding='utf-8')
    print('%d man co du lieu -> %s' % (len(data), out_json))
    return data


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--screens', type=int, default=3)
    ap.add_argument('--all', action='store_true')
    ap.add_argument('--list', action='store_true')
    ap.add_argument('--out', default=str(HERE / 'tags_that.json'))
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')

    if not ADB:
        raise SystemExit('khong thay adb')
    items = screens()
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
