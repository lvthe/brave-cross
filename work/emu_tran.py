# -*- coding: utf-8 -*-
"""Do CHO DAT TOAN LINH dau tien cua ban goc — cau hoi cuoi cung con lai cua
ROADMAP muc "Cho dung quan".

    python emu_tran.py --chay            # luot A: khong bam nut binh chung
    python emu_tran.py --chay --bam 1    # luot B: bam nut binh chung so 1

KET QUA (2026-09-17): DUONG NAY KHONG DI DUOC. Tien trinh vao duoc canh tran
(`TRAN|chen duoc, bDirectBattle = true`) nhung roi SIGSEGV **ben trong
`RepaleceScene`**; dia chi loi nam trong `[anon:libwebview reservation]`, tombstone
o `work/_tran/`. Cung loai voi bai hoc FMOD o `emu_dom.py`: thu vien ARM goi qua
ban dich thi chet. Giu file lai lam bang chung "da thu, khong phai chua lam".

CAU TRA LOI (lay tu duong khac): cho dat = **moc cua TOAN**, tuc
`Sprite.Troop.PosX` — do trong tran that duoc 7 o = 700 px (ai L_N_01_01). Doc
`.so` thi `dispatch()` (`0x45eda4` -> `0x466220`) KHONG tinh toa do nao, no chi
ghi danh quan vao danh sach cua san, nen cho dung cua quan dua ra chinh la cho
dung cua toan. Xem `ROADMAP.md` §5 "Cho dung quan".

VI SAO PHAI DO TREN MAY AO
--------------------------
Client KHONG quyet dinh cho dat toan linh: `CUIGame:TouchArrmy` (dong 4055 cua
`sc/user/Battle/CUIGame.lua`) chi goi

    self.tArmyIcons[nArmyID]:dispatch()

ma `dispatch` va `setDispatchID` KHONG file Lua nao trong 973 file dinh nghia
(grep ca cay `sc/`), tuc lop C++ cua engine lam het. Che do thu cua chinh engine
thi TU SINH du lieu quan (`g_BattleField:setSendTroops("", self.test)`,
`CUIGame.lua:877-881`). Nen khong co duong doc nao tu `.so` ra cho dat.

DUONG DO
--------
`sc/game.lua:483` co san mot cong: `local bDirectBattle = false` — bat len thi
`g_CUIGame:Test()` (dong 156) dung 10 toan thu `ArmyTypeID = 1..10` voi
`ChapterKey = "L_N_01_01"` roi `g_CSceneManager:RepaleceScene("Battle", ...)`.
Do la duong NGAN NHAT vao duoc mot tran that: khong can mang, khong can dang
nhap, khong phai bam tay qua menu.

Hai luot, hieu bang PHEP TRU ANH: luot A khong bam nut, luot B bam nut 1 ngay
sau khi canh tran dung xong. Cho dat = cho xuat hien them trong B so voi A.
Khong doc duoc toa do tu Lua (engine C++ giu danh sach don vi, khong API nao tra
ve — da doi chieu 30 ham `g_BattleField:*` ma client goi), nen phai do bang anh.

`RepaleceScene` chay DONG BO (`g_bSngSceneLoadAsync = false`, game.lua:476), nen
sau loi goi do thi `g_CUIGame.tArmyIcons` da co — va `TouchArrmy` goi ngay duoc.

CANH BAO: luot do nay chay tren MAY AO THU, khong phai ban that. No chi tra loi
"cho dat nam o dau so voi g_MapZero", va chi khi anh chup ra canh tran that.
"""
import argparse
import pathlib
import re
import time

import emu_tags as E  # noqa: E402

HERE = pathlib.Path(__file__).resolve().parent
SC = HERE / 'vn' / 'decrypted' / 'assets' / 'sc'
ANH = HERE / '_tran'

## Neo vao loi goi, khong phai cho dinh nghia (bai hoc cua emu_tags: neo nham
## thi game.lua hong cu phap va KHONG mot dong log nao ra).
NEO = 'if bDirectBattle then\n\tg_CUIGame:Test()'

## Mo ta MOT node ra logcat: vi tri cuc bo, vi tri the gioi, co.
MO_TA = '''
	local function mo_ta(n)
		if n == nil then return "nil" end
		local ok, x, y = pcall(function() return n:getPosition() end)
		if not ok then return "khong-co-getPosition" end
		local wx, wy = 0, 0
		local ok2 = pcall(function()
			local p = n:getParent()
			if p then wx, wy = p:convertToWorldSpace(x, y) end
		end)
		local w, h = 0, 0
		local ok3, a, b = pcall(function() return n:getContentSize() end)
		if ok3 and a then w, h = a, (b or 0) end
		return string.format("loc %g,%g | world %g,%g | co %gx%g", x, y, wx, wy, w, h)
	end
'''

PROBE = '''
do
	%(mo_ta)s
	print("TRAN|chen duoc, bDirectBattle = true")

	-- 1. Canh tran. `RepaleceScene` chay DONG BO nen sau dong nay moi thu da co.
	local ok, err = pcall(function() g_CUIGame:Test() end)
	print("TRAN|Test " .. tostring(ok) .. " | " .. tostring(err))
	if not ok then
		print("TRAN|KHONG VAO DUOC TRAN")
		print("TRAN|XONG")
		do return end
	end

	-- 2. Man tran da dung: doc cac moc can de doi chieu anh.
	print("TRAN|ManHinh|" .. tostring(g_CPublic:GetWinSize()))
	print("TRAN|MapZero|" .. mo_ta(rawget(_G, "g_MapZero")))
	local c = rawget(_G, "g_CUIGame")
	if c then
		print("TRAN|nArmyIconsCount|" .. tostring(c.nArmyIconsCount))
		print("TRAN|co tArmyIcons|" .. tostring(c.tArmyIcons ~= nil))
	end

	-- 3. BAM NUT BINH CHUNG — dung ham ma man hinh goi khi nguoi choi bam.
	local n = %(bam)d
	if n > 0 then
		local ok2, e2 = pcall(function() g_CUIGame:TouchArrmy(n) end)
		print("TRAN|TouchArrmy(" .. n .. ") " .. tostring(ok2) .. " | " .. tostring(e2))
	else
		print("TRAN|khong bam nut nao (luot doi chung)")
	end

	print("TRAN|XONG")
	-- Phan sau moc nay can mang, ma mang lam ban dich ARM chet. Vong ve cua
	-- engine nam ben C++, nen canh van duoc ve — do la canh ta chup.
	do return end
end
'''


def dung_de(bam, out_dir):
    """Cay file de: bat bDirectBattle, chen dau do, va TAT am thanh (FMOD la
    thu vien ARM, goi qua ban dich la SIGSEGV — bai hoc cua emu_dom)."""
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
    # Dong ngay TRUOC nhanh bDirectBattle cung lam ban dich ARM chet
    # (emu_dom do duoc: `eip 00000000`). Phai tat han, khong thi khong bao gio
    # toi duoc `if bDirectBattle`.
    xg = '\nXGAnalytics:logEventByID(XGAnalytics.EVENT_ID.LOADCONFIG)'
    if g.count(xg) != 1:
        raise SystemExit('khong tim duoc dung mot XGAnalytics LOADCONFIG')
    g = g.replace(xg, '\nprint("CHEN|bo qua XGAnalytics LOADCONFIG")\n', 1)
    if g.count(NEO) != 1:
        raise SystemExit('khong tim duoc dung mot nhanh bDirectBattle')
    g = g.replace(NEO,
                  'if bDirectBattle then\n' + PROBE % {'mo_ta': MO_TA, 'bam': bam}
                  + '\n\tg_CUIGame:Test()\n\tdo return end', 1)
    g = g.replace('\nlocal bDirectBattle = false', '\nlocal bDirectBattle = true', 1)
    (out / 'sc/game.lua').write_text(g, encoding='utf-8')
    return out / 'sc'


def chup(ten):
    xa = '/sdcard/' + ten
    E.adb('shell', 'screencap', '-p', xa)
    ANH.mkdir(parents=True, exist_ok=True)
    dich = ANH / ten
    E.adb('pull', xa, str(dich))
    E.adb('shell', 'rm', '-f', xa)
    return dich if dich.exists() else None


def chay(bam, moc):
    """Day ban de, khoi dong game, chup tai tung moc giay."""
    sc_dir = dung_de(bam, HERE / '_tran')
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
    truoc = 0
    for m in moc:
        time.sleep(max(0, m - truoc))
        truoc = m
        chup('bam%d_%02ds.png' % (bam, m))
        print('  chup tai %ds' % m)
    txt = E.adb('logcat', '-d').stdout
    return re.findall(r'(?:TRAN|CHEN)\|[^\n\r]*', txt)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--bam', type=int, default=0, help='so thu tu nut binh chung')
    ap.add_argument('--moc', default='6,10,16', help='cac moc giay de chup')
    ap.add_argument('--chay', action='store_true')
    ap.add_argument('--bo-khoa', action='store_true')
    a = ap.parse_args()
    moc = [int(x) for x in a.moc.split(',') if x.strip()]
    if not a.chay:
        print('chua chay. Them --chay. (--bam 0 = luot doi chung)')
        return
    E.giu_khoa(a.bo_khoa, 'do cho dat toan linh (bam=%d)' % a.bam)
    dong = chay(a.bam, moc)
    for l in dong:
        print('  ' + l)
    print('%d dong log' % len(dong))
    print('anh: %s' % ANH)


if __name__ == '__main__':
    main()
