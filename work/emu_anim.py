# -*- coding: utf-8 -*-
"""Do TRUC TIEP ham `toAnimationName` cua engine ban goc, trong may ao.

    python emu_anim.py            # do va in bang ket qua
    python emu_anim.py --json <f> # ghi ket qua ra JSON

Vi sao phai do o may ao
-----------------------
`CPublic:toArmatureName` (sc/user/Public/CPublic.lua:2033) goi `toAnimationName`
cho tung tuong/linh/nhom dich de lap danh sach armature nap truoc cua tran. Ten
do CO trong libgame.so, nhung THAN HAM khong doc ra duoc: con tro ham nam trong
bang dang ky luc chay (bang 111 ten, `toAnimationName` o 0x20c0ba — ngay giua
`giveBackToSpriteCatch` va `updateSettingFile`), khong co trong file .so.

Bang tra trong cong (`data_ref/anim_ref.json`, sinh bang `anim_ref.py`) rut tu
DU LIEU: `<sAnimation>` co dung 13 muc trong `evil_config.xml`, cong them 90 muc
chi co `<sBaseItem>` tro toi mot trong 13 muc do. Hai cau hoi du lieu khong tu
tra loi duoc, va day la hai cau hoi phep do nay tra loi:

  1. Ham co dung `<sAnimation>` lam ten armature khong, hay tra ve nguyen ten?
  2. `<sBaseItem>` co PHAI la ke thua khong? `Archer_Evil` KHONG co
     `<sAnimation>` rieng, no tro `<sBaseItem>` ve `Archer_VampirE`. Neu ke thua
     thi `Archer_Evil -> Archer`; neu khong thi `Archer_Evil -> Archer_Evil`.

Ket qua luot dau (33 ten, 2026-09-18) tra loi CA HAI: ham doi ten that, va
`<sBaseItem>` la ke thua that (`Archer_Evil -> Archer`). Luot hai mo rong danh
sach len 50 ten de phep ke thua khong chi dung o mot vai ca: them 11 ten con
rai tren muoi goc linh, va 6 ten co chuoi `<sBaseItem>` dai 2-3 buoc ma KHONG
toi mot `<sAnimation>` nao (chieu nguoc lai — phai tra nguyen ten).

Cach lam: y nhu `emu_tags.py` — thay the file Lua cua game trong may ao (game
dat `package.path` de thu muc ngoai thang truoc assets trong APK, xem
`emu_tags.py`), chen mot dau do vao `sc/game.lua` ngay truoc
`sngHttMgr:createInstance()`, roi doc logcat. Ba cho phai va de game chay toi
duoc cho do (Umeng, FMOD, HTTP) cung lay tu `emu_tags.py`.

Mot luot chiem may ao, nen van dung khoa theo serial nhu `emu_tags.py`.
"""
import argparse
import json
import pathlib
import random
import re
import sys
import time

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import emu_tags as E  # noqa: E402

# Ten dem ra do. Bon nhom, moi nhom tra loi mot cau hoi khac nhau:
#   * 13 ten GOC co <sAnimation>        -> ham co doi ten khong
#   * con cua chung (chi co <sBaseItem>) -> co ke thua qua <sBaseItem> khong
#   * ten KHONG co gi                    -> tra nguyen ten (bang tra cua cong
#                                           dua vao gia thiet nay)
#   * ten bien the trong mot file khac   -> moi quan he voi lop nap armature
TEN = (
    # 13 goc
    'Archer_VampirE', 'ArmorCavalry_Boss', 'Artillery_VampirE', 'Assasin_Boss',
    'Berserker_Boss', 'Catapult_VampirE', 'Cavalry_VampirE', 'Defender_VampirE',
    'ElephantSoldier_VampirE', 'Hoplite_VampirE', 'Priest_VampirE',
    'Spearmen_VampirE', 'Witch_VampirE',
    # con cua chung — luot dau do 7 ten, luot hai do them 11 ten nua rai deu
    # tren muoi goc linh, de phep ke thua khong chi dung o mot vai ca
    'Archer_Evil', 'Archer_Dong', 'Archer_Shi', 'Archer_Skeleton',
    'Archer_DongBoss', 'Cavalry_VampirEBoss', 'Witch_Evil',
    'Archer_EvilBoss', 'Archer_ShiBoss', 'Archer_SkeletonBoss',
    'Archer_VampirEBoss', 'Artillery_Dong', 'Artillery_VampirEBoss',
    'Catapult_Skeleton', 'Hoplite_EvilBoss', 'Priest_Shi',
    'Spearmen_SkeletonBoss', 'Witch_DongBoss',
    # khong co gi
    'Archer', 'ArcherN', 'ZhangJiao', 'Player000M03F', 'Archer_WeaponNormal',
    'Archer_Weapon_Wake', 'ZhangJiao_Hair', 'Silk_Short', 'weapon_throw',
    'KhongCoTenNay_12345',
    # bien the nam trong file armature khac ten
    'UITongYong_ItemLight', 'CustomsWin_Star1', 'ItemLight_Level2',
    # chuoi <sBaseItem> dai (2-3 buoc) ma KHONG toi mot <sAnimation> nao —
    # phai tra nguyen ten, do la chieu nguoc lai cua phep ke thua
    'ADou01', 'ArcherN_Weapon_Normal', 'ArcherN_Weapon_Normal2',
    'ArcherN_Weapon_Wake', 'BaiHuZi', 'BuLianShiExclus',
)

PROBE = '''
-- === CHEN DE DO: toAnimationName (emu_anim.py sinh ra) ===
do
	local DS = %(list)s
	for _, ten in ipairs(DS) do
		local ok, v = pcall(function() return toAnimationName(ten) end)
		print("DOANIM|" .. ten .. "|" .. tostring(ok) .. "|" .. tostring(v))
	end
	print("DOXONG|%(token)s")
end
'''


def lua_ds():
    return '{' + ','.join('"%s"' % t for t in TEN) + '}'


def do(han=60):
    """Mot luot: day ban de, chay game, doc logcat. Tra [(ten, ok, ketqua)]."""
    tok = '%08x' % random.getrandbits(32)
    # build_overrides con doi %(depth)s/%(tags)s/%(bo)s — khong dung toi thi de
    # nguyen, nhung VAN phai co khoa trong dict vi no % ca chuoi.
    head = PROBE % {'list': lua_ds(), 'token': tok}
    head = head.replace('%(depth)s', '0').replace('%(tags)s', '{}') \
               .replace('%(bo)s', '{}')
    sc = E.build_overrides([], HERE / '_emu_anim', head=head, token=tok)

    E.adb('shell', 'am', 'force-stop', E.PKG)
    for _ in range(20):
        if not E.adb('shell', 'pidof', E.PKG).stdout.strip():
            break
        time.sleep(0.5)
    E.adb('shell', 'mkdir', '-p', E.REMOTE)
    E.adb('push', str(sc), E.REMOTE + '/')
    E.cap_quyen()
    E.adb('logcat', '-b', 'all', '-c')
    E.adb('shell', 'am', 'start', '-n', '%s/%s' % (E.PKG, E.ACT))

    ra, cho = [], 0
    while cho < han:
        time.sleep(3)
        cho += 3
        txt = E.adb('logcat', '-d').stdout
        ra = [m.group(0) for m in
              re.finditer(r'DO(?:ANIM|XONG)\|?[^\n\r]*', txt)]
        if any(l.startswith('DOXONG|' + tok) for l in ra):
            break
        if cho >= 21 and not E.adb('shell', 'pidof', E.PKG).stdout.strip():
            break
    out = []
    for l in ra:
        p = l.split('|')
        if p[0] == 'DOANIM' and len(p) >= 4:
            out.append((p[1], p[2], '|'.join(p[3:])))
    return out, cho, any(l.startswith('DOXONG|' + tok) for l in ra)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--json')
    ap.add_argument('--bo-khoa', action='store_true')
    ap.add_argument('--han', type=int, default=60)
    a = ap.parse_args()

    E.giu_khoa(a.bo_khoa, 'do toAnimationName (%d ten)' % len(TEN))
    ra, cho, xong = do(a.han)
    print('cho %ds, %s, %d dong' % (cho, 'DOXONG' if xong else 'KHONG DOXONG',
                                    len(ra)))
    for ten, ok, v in ra:
        print('  %-28s -> %s%s' % (
            ten, v, '' if ok == 'true' else '  (pcall hong: %s)' % ok))
    thieu = [t for t in TEN if t not in {r[0] for r in ra}]
    if thieu:
        print('khong do duoc %d ten: %s' % (len(thieu), ' '.join(thieu)))
    if a.json:
        pathlib.Path(a.json).write_text(json.dumps(
            {'do': {t: v for t, _o, v in ra}, 'ten': list(TEN),
             'xong': xong, 'cho': cho},
            ensure_ascii=False, indent=1), encoding='utf-8')
        print('da ghi', a.json)


if __name__ == '__main__':
    main()
