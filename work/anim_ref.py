# -*- coding: utf-8 -*-
"""Rut bang doi ten SPRITE -> ARMATURE cua ham `toAnimationName` ra JSON.

Vi sao can: `CPublic:toArmatureName` (sc/user/Public/CPublic.lua:2033) goi
`toAnimationName(strName)` cho TUNG tuong, TUNG linh va tung nhom dich de lap
danh sach armature nap truoc cua tran (`CPublic:SetBattleArmatureName`, :1890 —
duoc 15 cho goi tu CUIBattleDeploy/CUIArenaRecord/...). Ten do CO trong
libgame.so, nen lop gia lap khong duoc phep de no thanh BONG: doc ra bong thi
`KDebug.ProcessNotString` o :2041 that bai, ham thoat som va danh sach rong.

HAM C++ CHUA DO DUOC. `toAnimationName` la mot binding toan cuc cua engine,
dang ky o 0x20c0ba trong libgame.so — ngay giua `giveBackToSpriteCatch` va
`updateSettingFile` trong bang 111 ten (cung loat voi `createSprite`,
`getUIAnimFromSpriteCatch`, `updateArmatureLanguageSuffix`). Con tro ham nam
trong bang nap luc chay, khong co trong file .so, nen khong doc ra than duoc.
Cho duoc ghi o day la DU LIEU ma ham do phai doc: sau file cau hinh sprite cua
ban goc.

    map/hero_config.xml      map/player_config.xml   map/boss_config.xml
    map/heroex_config.xml    map/sprite_config.xml   map/evil_config.xml

DO DUOC (1968 muc co <sName> tren ca sau file):

  * `<sAnimation>` chi co o **13 muc**, TAT CA trong evil_config.xml, va moi
    gia tri deu la mot armature CO THAT trong map/. Do la cac muc GOC bien the:
    `<sName>Archer_VampirE</sName>` + `<sBaseItem>Archer</sBaseItem>` +
    `<sAnimation>Archer</sAnimation>`.
  * Cac muc cung ho (`Archer_Evil`, `Archer_Dong`, `Archer_Shi`,
    `Archer_Skeleton`, `Archer_DongBoss`, ...) KHONG co <sAnimation>, chung tro
    `<sBaseItem>` ve muc goc do.
  * `<sBaseItem>` dung o **860 muc**, nhung phan lon la toc/ao/vu khi
    (`ZhangJiao_Hair` -> `Silk_Short`, `MaDai_Cloak` -> `Silk_Cloak`). Cac chuoi
    nay ket thuc o ten KHONG phai armature — `Silk`, `weapon_throw`, `Player03`,
    `pause_HeroWake` (do: 0 trong so chung la thu muc armature). Nen luat "di
    theo <sBaseItem> den goc roi lay ten goc" bi chinh du lieu BAC BO, khong
    phai luat cua ham.

Vi vay bang tra o day ghi dung phan do duoc: **13 muc ghi de**, con lai tra ve
nguyen ten. Phan "con lai" khong phai suy dien suong: lop nap armature cua ban
goc (`_tao_rig`, game/lua_runtime.gd) tu phan giai ten bien the ra armature bang
TIEN TO DAI NHAT co du lieu (`Archer_WeaponNormal` -> Archer, `Player004M03F` ->
Player004) — do tren 3142 armature cua assets_ref, do bang 'rig nhan vat'. Va ca
13 gia tri ghi de deu DUNG BANG ket qua cua phep phan giai do, nen du ham C++
lam gi them thi armature duoc nap cung khong doi.

    python anim_ref.py                          # xem thong ke
    python anim_ref.py --json <duong dan>       # ghi JSON
"""
import argparse
import glob
import io
import json
import os
import sys
import xml.etree.ElementTree as ET

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

HERE = os.path.dirname(os.path.abspath(__file__))
MAP = os.path.join(HERE, 'vn/decrypted/assets/map')
HO = ('hero', 'heroex', 'player', 'sprite', 'boss', 'evil')

# So do duoc lan 17/09/2026, de mot lan lech du lieu khong di qua im lang.
SO_MUC = 1968
SO_GHI_DE = 13


def doc_armature():
    """Ten cac armature CO THAT: ten file .xml trong map/ (bo cac file cau hinh)."""
    canh = set()
    for p in glob.glob(os.path.join(MAP, '*.xml')):
        ten = os.path.splitext(os.path.basename(p))[0]
        if ten not in [h + '_config' for h in HO]:
            canh.add(ten)
    return canh


def doc_muc():
    """Moi muc co <sName> trong sau file cau hinh -> ban ghi cac truong con."""
    muc = {}
    for h in HO:
        p = os.path.join(MAP, h + '_config.xml')
        if not os.path.exists(p):
            raise SystemExit('thieu ' + p)
        goc = ET.parse(p).getroot()

        def di(el):
            for c in el:
                nm = c.find('sName')
                if nm is not None and nm.text:
                    # Chi lay truong la (khong co con) — lsAdapt/... la khung.
                    muc[nm.text] = {g.tag: (g.text or '').strip()
                                    for g in c if len(g) == 0}
                di(c)
        di(goc)
    return muc


def di_theo_goc(muc, ten):
    """Ten goc cua chuoi <sBaseItem> (None neu dut / lap). Dung de DO, khong phai
    luat cua ham — xem phan dau file."""
    thay = set()
    while True:
        if ten in thay or ten not in muc:
            return None
        thay.add(ten)
        goc = muc[ten].get('sBaseItem')
        if not goc:
            return ten
        ten = goc


def rut(muc, arm):
    ghi_de = {}
    for ten in sorted(muc):
        an = muc[ten].get('sAnimation')
        if an:
            if an == ten:
                raise SystemExit('%s: <sAnimation> bang chinh <sName>, vo nghia' % ten)
            ghi_de[ten] = an
    # Moi dich phai la armature co that — neu khong thi bang tra nay sai.
    for ten, an in sorted(ghi_de.items()):
        if an not in arm:
            raise SystemExit('%s -> %s: %s khong phai armature trong %s'
                             % (ten, an, an, MAP))
    return ghi_de


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--json', help='ghi bang tra ra file JSON')
    a = ap.parse_args()

    arm = doc_armature()
    muc = doc_muc()
    ghi_de = rut(muc, arm)

    co_goc = [t for t in muc if muc[t].get('sBaseItem')]
    goc_la_arm = [t for t in co_goc if di_theo_goc(muc, t) in arm]
    co_an = [t for t in muc if muc[t].get('sAnimation')]

    print('armature trong %s: %d' % (MAP, len(arm)))
    print('muc co <sName>: %d%s' % (
        len(muc), '' if len(muc) == SO_MUC else '   <<< LECH, phai la %d' % SO_MUC))
    print('muc co <sAnimation>: %d%s' % (
        len(co_an), '' if len(co_an) == SO_GHI_DE else
        '   <<< LECH, phai la %d' % SO_GHI_DE))
    print('muc co <sBaseItem>: %d, trong do chuoi di den mot ARMATURE: %d'
          % (len(co_goc), len(goc_la_arm)))
    print('bang ghi de: %d dong' % len(ghi_de))
    for ten, an in sorted(ghi_de.items()):
        print('  %-28s -> %s' % (ten, an))

    if a.json:
        b = {
            'note': 'ten sprite -> ten armature cua ham toAnimationName. Nguon la '
                    'truong <sAnimation> trong cau hinh sprite ban goc; muc khong '
                    'co <sAnimation> tra ve nguyen ten (xem work/anim_ref.py).',
            'nguon': {'cau_hinh': 'map/%s_config.xml' % '|'.join(HO),
                      'khoa': 'toAnimationName dang ky o 0x20c0ba trong libgame.so'},
            'doi_ten': ghi_de,
        }
        with io.open(a.json, 'w', encoding='utf-8', newline='\n') as f:
            json.dump(b, f, ensure_ascii=False, indent=1, sort_keys=True)
        print('da ghi', a.json)


if __name__ == '__main__':
    main()
