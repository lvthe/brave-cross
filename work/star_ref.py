# -*- coding: utf-8 -*-
"""Rut bang HIEU UNG SAO theo cap sao ra JSON.

Vi sao can: `_Lua_addStarLevelEffect` la API Cocos ma ban dung CHUA LAM (no nam
dau bang "API Cocos CHUA LAM" cua `tools/quet_show.gd`, 4 cho goi), va no KHONG
bao loi khi thieu: moi cho goi deu gac bang

    if spHeroSprite._Lua_addStarLevelEffect then      -- luon dung (lop gia lap
        spHeroSprite:_Lua_addStarLevelEffect(nStarLevel)  tra ham cho moi ten)

nen hieu ung sao cua tuong don gian la KHONG HIEN, khong mot dong loi.

BON CHO GOI trong ma goc (dem bang grep tren `sc/`):
    sc/user/Logical/ClientPaperDoll.lua:271,288   (ham dung chung)
      -> tu day ra CUIHeroInfoMainUI.lua:801, CUICharacterDress.lua:202,
         CUICavern.lua:350, CUIArenaHeroInfoDialog.lua:226,
         CUIInfiniteLevelMain.lua:545
    sc/user/Battle/CUIGame.lua:953   g_BattleField:setShowStarEffect(PaperDoll_ShowStarEffect)

CAU TRA LOI NAM TRONG HAI FILE, khong phai suy doan
--------------------------------------------------
1. Doc ma may. Ten ham `_Lua_addStarLevelEffect` co DUNG MOT lan trong
   `libgame.so` (`.rodata 0x7b50d9`) va duoc hai bang bind tro toi
   (`.data 0x9377a0` va `0x938378`), ca hai ghi CUNG mot dia chi ham: `0x41ba6d`
   (Thumb, tuc `0x41ba6c`). Ham bao quanh (`0x41ba6c`) chi doc mot so nguyen roi
   goi `0x41b998(L, n, 1)`; ben trong ham ay:

       0x41b9e2  movs r1, #0 ; movs r2, #0x40 ; add r0, sp, #0x1c
       0x41b9e8  blx  0x201fec                 -- memset(buf, 0, 0x40)
       0x41b9ec  ldr  r2, [pc]  -> "lsStarLevelEffect_%d"
       0x41b9f0  movs r1, #0x3f
       0x41b9f6  blx  0x20261c                 -- snprintf(buf, 63, ten, n)
       0x41b9fe  blx  0x73668c                 -- std::string(buf)
       0x41ba06  mov  r0, r4                   -- r4 = 0x38c7f0()->[0x198]
       0x41ba0a  bl   0x38d2e8                 -- tao node THEO KHOA cau hinh
       0x41ba22  (vong lap)                    -- tung node: [+0x120] = "StarLevelEffect_"

   Tuc: **KHOA CAU HINH** `lsStarLevelEffect_<n>` duoc dua thang vao ham tao,
   chu khong phai ten mot tai nguyen. Ten ham duoc dat o `+0x120` — va truoc do,
   khi co co, ham goi `0x418628(L, "StarLevelEffect_")`, tuc XOA hieu ung cu
   truoc khi tao cai moi.

2. Doc du lieu. `map/global_config.xml`, khoi `<star>` (chu thich 星级), dinh
   nghia dung khoa ay:

        <lsStarLevelEffect_2><item>StarLevelEffect_2Up</item></lsStarLevelEffect_2>
        <lsStarLevelEffect_3><item>StarLevelEffect_3Up</item>
                             <item>StarLevelEffect_3Down</item></lsStarLevelEffect_3>
        ... den _7

   Va `map/StarLevelEffect.xml` co DUNG mot BIEN THE cho tung `<item>` ay, moi
   bien the mot dong tac ten `PluginPlay`. Nen phep doc nay tu kiem duoc: moi
   ten trong cau hinh phai la mot bien the co that trong file armature.

   **File armature co 23 bien the, khong phai 11** — do la cho de doc nham. 11
   bien the cua cau hinh (ten `StarLevelEffect_<cap>Up/_cap>Down`) co dong tac
   `PluginPlay`; 12 bien the con lai ten `StarLevelEffect_mc_*` la RIG LONG NHAU
   (xuong `Layer*` cua cac bien the kia tro toi chung), dong tac cua chung ten
   `Play`. Bang JSON ghi ro tung loai o truong `loai`.

   **Cap 1 KHONG co hieu ung** — cau hinh bat dau tu `_2`. Do cung la ly do
   `NumberUtils.Range(HeroGrowthFactor or 1, 1, 7)` tra 1 thi khong thay gi.

Khong khoi phuc duoc (ghi ra, khong bia):
  * Node nao la CHA cua hai armature hieu ung (ma may cho thay chung duoc tao
    theo khoa cau hinh roi dat ten `+0x120`, nhung khong doc ra cho gan).
    Ban dung gan vao chinh node tuong — dung nhu `spHeroSprite:_Lua_...`, va do
    la cho duy nhat lam hieu ung DI THEO tuong.
  * Thu tu ve cua `_Up` so voi `_Down`. Ban dung giu dung thu tu trong cau hinh
    (them sau thi ve tren), ghi ro la CHUA DO.

    python star_ref.py --json ../../bravecross-game/data_ref/star_ref.json
    python star_ref.py --ke                  # ke ra tung cap sao
"""
import argparse
import io
import json
import os
import re
import sys

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

HERE = os.path.dirname(os.path.abspath(__file__))
MAP = os.path.join(HERE, 'vn', 'decrypted', 'assets', 'map')
GLOBAL = os.path.join(MAP, 'global_config.xml')

## File armature xuat ra cua BAN DUNG (do `work/export.py` ghi). Dung de doi
## chieu ten: moi `<item>` phai la mot BIEN THE co that.
VAI_MAC_DINH = os.path.join(HERE, '..', '..', 'bravecross-game', 'assets_ref',
                            'StarLevelEffect', 'StarLevelEffect.json')

CHU_THICH = re.compile(r'<!--.*?-->', re.S)
KHOI_SAO = re.compile(r'<star>(.*?)</star>', re.S)
MUC = re.compile(r'<(lsStarLevelEffect_\d+)>(.*?)</\1>', re.S)
ITEM = re.compile(r'<item>([^<]+)</item>')


def doc_cau_hinh():
    """Tra ve {cap: [ten bien the, ...]} doc tu khoi <star> cua global_config."""
    t = CHU_THICH.sub('', io.open(GLOBAL, encoding='utf-8', errors='replace').read())
    k = KHOI_SAO.search(t)
    if k is None:
        raise SystemExit('khong tim thay khoi <star> trong %s' % GLOBAL)
    ra = {}
    for ten, than in MUC.findall(k.group(1)):
        cap = int(ten.rsplit('_', 1)[1])
        ra[cap] = [s.strip() for s in ITEM.findall(than)]
    return ra


def doc_bien_the(duong):
    """{ten bien the: (so dong tac, [ten dong tac], so xuong)} tu file xuat."""
    if not os.path.exists(duong):
        return None
    d = json.load(io.open(duong, encoding='utf-8'))
    ra = {}
    for v in d['groups']:
        ten_dt = [a['name'] for a in v['animations']]
        xuong = {b['name'] for a in v['animations'] for b in a['bones']}
        ra[v['variant']] = (len(v['animations']), ten_dt, len(xuong))
    return ra


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--json', help='ghi bang ra file JSON')
    ap.add_argument('--ke', action='store_true', help='ke ra tung cap sao')
    ap.add_argument('--vai', default=VAI_MAC_DINH,
                    help='file armature xuat ra cua ban dung, de doi chieu ten')
    a = ap.parse_args()

    bang = doc_cau_hinh()
    print('khoi <star> cua map/global_config.xml: %d cap' % len(bang))
    for cap in sorted(bang):
        print('  cap %d: %s' % (cap, ', '.join(bang[cap])))

    # Doi chieu doc lap: moi ten trong cau hinh phai la mot BIEN THE co that
    # trong file armature, va bien the ay phai co dung mot dong tac.
    vai = doc_bien_the(a.vai)
    lech = 0
    if vai is None:
        print('\nkhong thay %s — BO QUA phep doi chieu ten' % a.vai)
    else:
        print('\ndoi chieu voi %s (%d bien the):' % (os.path.basename(a.vai), len(vai)))
        for cap in sorted(bang):
            for ten in bang[cap]:
                v = vai.get(ten)
                if v is None:
                    print('  %-24s KHONG co bien the nay   <<< LECH' % ten)
                    lech += 1
                else:
                    print('  %-24s %d dong tac %s, %d xuong' % (ten, v[0], v[1], v[2]))
                    if v[0] != 1:
                        print('     <<< LECH: phai dung 1 dong tac')
                        lech += 1
    print('\nlech: %d' % lech)

    if a.json:
        # `loai`: "hieu_ung" = duoc khoi <star> cua cau hinh goi ten (dong tac
        # PluginPlay); "long_nhau" = chi duoc cac xuong `Layer*` kia tro toi
        # (dong tac Play). Phan biet de bo kiem khoi doi mot dong tac cho ca 23.
        ten_hieu_ung = {t for c in bang for t in bang[c]}
        ra = {
            'nguon': {'cau_hinh': 'map/global_config.xml khoi <star>',
                      'armature': 'map/StarLevelEffect.xml (+ .plist/.pkm)',
                      'khoa': '_Lua_addStarLevelEffect = 0x41ba6c trong libgame.so'},
            'dongtac': {str(k): bang[k] for k in sorted(bang)},
            'bien_the': {} if vai is None else
                        {t: {'dong_tac': v[1], 'so_xuong': v[2],
                             'loai': 'hieu_ung' if t in ten_hieu_ung else 'long_nhau'}
                         for t, v in vai.items() if t.startswith('StarLevelEffect_')},
        }
        os.makedirs(os.path.dirname(os.path.abspath(a.json)), exist_ok=True)
        with io.open(a.json, 'w', encoding='utf-8', newline='\n') as f:
            json.dump(ra, f, ensure_ascii=False, indent=1, sort_keys=True)
        print('da ghi', a.json)
    return 1 if lech else 0


if __name__ == '__main__':
    sys.exit(main())
