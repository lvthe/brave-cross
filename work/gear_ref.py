# -*- coding: utf-8 -*-
"""Rut bang DO (trang bi) ra JSON.

Vi sao can: ban goc gan do bang ham TOAN CUC `setGear(pRole, value)`, goi tu
`ClientPaperDoll:ChangePaperDollHelper`:

    for key,value in pairs(tSkinMap) do setGear(pRole, value) end

Ban dung CHUA LAM ham ay (xem `lua/cocos.lua:2306`, `rig/sng_rig.gd:709`), va no
KHONG bao loi khi thieu: `setGear` la ham toan cuc, ma `__index` cua lop gia lap
tra ham cho MOI ten — nen moi loi goi di vao hu khong, va khong mot dong loi.
Hau qua do duoc: xương `Weapon` cua nhan vat chinh con nguyen anh MAC DINH cua
armature (`Player000_Eff-EquipQin_5`, cap 5) trong khi du lieu noi cap 0.

CAU TRA LOI NAM TRONG `map/gear_config.xml` — KHONG phai suy doan
----------------------------------------------------------------
File 57.777 byte, **201 muc `<Gear>`**. Chinh file ay ghi nghia cac truong
(dong 5..20):

    sGearType   Sabre Wand Spear Zither LongBow Sword Fan Lance Harp ShortBow
                Cannon / Helmet Shield Armour Scapula Glove Legguard boots /
                Wing Mount
    nShowType   1 doi texture · 2 doi ARM cua khop · 3 doi hat ·
                4 doi NODE CON · 5 doi vu khi nem

Va ghi luon LUAT DU PHONG khi ten khong co trong bang:

    Neu <sGear>DefenderN_Sword_lv1</sGear> khong tim thay cau hinh tuong ung thi
    mac dinh tach ten ra va dung cach doi TEXTURE. Vi du DefenderN_Sword_lv1 se
    dung texture DefenderN_res-Sword_lv1 de thay texture cua khop Sword. Chi co
    hai tham so thi chi ghep hai tham so.

Tuc: `setGear(pRole, "<ten>")` = tra bang, roi lam MOT trong nam viec. Bon muc
do duoc trong bang:

    equip_3_0     Weapon  2  sBone Weapon  sArmtureName EquipQin_1
    equip_3_5     Weapon  2  sBone Weapon  sArmtureName EquipQin_5
    equip_3_7..10 Weapon  2  sBone Weapon  sArmtureName EquipQin_6   (chan tren)
    equip_3_999   Weapon  2  sBone Weapon  sArmtureName EquipQin_0   <- O TRONG
    wing_1_5      Wing    4                sPropertyName EquipWing_05

BANG CO **NAM LOAI MUC** trong 201 `<Gear>` (do theo TRUONG, khong theo ten):

  * **LA** — 115 muc co `nShowType`: 88 kieu 2 (87 Weapon + 1 Effect) va 27 kieu
    4 (17 Wing + 10 Mount). **Khong muc nao kieu 1, 3 hay 5** — nen kieu 1 va
    kieu 2 chi con la hai nhanh cua duong DU PHONG, khong phai muc trong bang.
  * **BUNDLE** — 70 muc co `lsGear`, tuc mot danh sach ten do khac.
    `DefenderN_lv1` -> `DefenderN_Sword_lv1`, `_Shield_lv1`, `_Hat_lv1`,
    `_Belt_lv1`. Ten bundle la ten DON VI + cap (`ArcherN_lv7`), khong phai ten
    do — nen no thuoc duong `setLevelGear` (ham anh em dang ky ngay canh
    `setGear` trong `libgame.so`, **0 cho goi trong `sc/`**: engine C++ goi khi
    sinh linh), KHONG thuoc 11 cho goi `setGear`.
  * **PARTS** — 7 muc co `lsParts`: `SpearmenN_Spear_lvN` -> hai muc `<Parts>`.
  * **BASEITEM** — 3 muc, chuyen tiep sang do khac (`Witch_lv7` -> `Witch_lv6`).
  * **LIST** — 6 muc, chon theo cap (`equip_Exclusive_10_List` ->
    `sGear_lv5plus = equip_Exclusive_10_5`).

`<Parts>` la bang RIENG (14 muc nam LAN trong `<Gears>`, xen giua cac `<Gear>`),
khong phai truong cua `<Gear>`:

    SpearmenN_Spear_lv1_Texture  nPartsType 1  sBone Spear
                                 sTextureName SpearmenN_res-Spear_lv1
    SpearmenN_Spear_lv1_Throw    nPartsType 5  sWeaponFight SpearmenN_Weapon_Lv1

`nPartsType` dung LAI dung bo ma cua `nShowType` (1 = texture, 5 = vu khi nem).

70 bundle sinh 375 ten la (201 ten khac nhau); **7** trong so do co muc rieng
trong bang, **201** di duong du phong. Do ca 201:

    179  -> texture THAT, theo dung cong thuc cua file bang
     21  -> `_Hide`: AN xuong `<doan 2>` (moi xuong ay deu CO THAT trong
            armature — do ca 21, khong suy)
      1  -> khong ra: `CavalryAlpaca_ABody_lv1_lv4` (hau to cap lap `lv1_lv4`,
            va `CavalryAlpaca` KHONG co xuong `ABody`) — loi du lieu goc, ghi lai

Nen luat du phong that ra la HAI nhanh, khong phai mot:

    <arm>_<xuong>_lv<N>   -> texture `<arm>_res-<xuong>_lv<N>`
    <arm>_<xuong>_Hide    -> AN xuong `<xuong>`

**Cong thuc nay duoc CHINH FILE xac nhan, khong phai suy doan.** Bang `<Parts>`
khai ket qua cua cung phep doi ay mot cach tuong minh: 7/7 muc `<Parts>`
`nPartsType 1` co `(sBone, sTextureName)` TRUNG KHIT cong thuc du phong tinh tu
ten cua chung. Hai cho doc lap trong cung mot file, cung mot dap so.

BA DIEU DE DOC NHAM, do duoc:

  * **`equip_3_999` moi la "khong co do", khong phai cap 0.** Armature
    `EquipQin_0` la o TRONG: phan tu `EquipQin_0` cua `EquipQin.xml` mang anh
    `EquipQin_res-44` (1x1). Cap 0 la do THAT (`EquipQin_1`).
  * **Cap bi CHAN TREN**: 7..10 deu tro ve `EquipQin_6`; art chi co 1..6. Nen
    dung theo bang, dung tu suy "cap N -> ten co hau to N".
  * **Khong suy duoc ten armature tu ten do.** `equip_4_5` -> `EquipZhang_5`
    (QUAT), trong khi anh `Zither_res-equip_4_5_client` nam trong atlas
    `EquipQin`; con `equip_3_5` -> `EquipQin_5` (DAN). Tien to so trong ten do
    la `EquipmentType` cua `Protocol.lua`, con atlas chua anh la chuyen khac.
    Phai doc bang.

Phep tu kiem (chay khong can tham so): moi `sArmtureName`/`sPropertyName` phai
la mot PHAN TU GOC co that trong file armature da xuat cua ban dung, va moi
`sBone` phai la mot xuong co that trong armature cua no — truy nguoc bang
`getSpriteFromSpriteCatch(<sArmtureName>)` (tuc `assets_ref/<File>/<File>.json`).

    python gear_ref.py --json ../../bravecross-game/data_ref/gear_ref.json
    python gear_ref.py --ke          # ke 201 muc
"""
import argparse
import io
import json
import os
import re
import sys
import xml.etree.ElementTree as ET

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

import cay

HERE = os.path.dirname(os.path.abspath(__file__))
MAP = os.path.join(cay.ASSETS, 'map')
BANG = os.path.join(MAP, 'gear_config.xml')

## Thu muc armature xuat ra cua BAN DUNG (`work/export.py` ghi). Dung de doi
## chieu: moi ten armature trong bang phai la mot BIEN THE co that.
DICH_ANH = cay.dich_anh()

CHU_THICH = re.compile(r'<!--.*?-->', re.S)

## Nam kieu cua `nShowType`, nguyen van tu chu thich trong chinh file bang.
KIEU = {
    1: 'texture',
    2: 'armature',     # doi ARM cua khop   — vu khi
    3: 'hat',          # doi he hat
    4: 'node_con',     # doi NODE CON       — canh / mount
    5: 'nem',          # doi vu khi nem
}


def _muc(g):
    d = {}
    for c in g:
        if len(c):
            d[c.tag] = [x.text.strip() for x in c if (x.text or '').strip()]
        else:
            d[c.tag] = (c.text or '').strip()
    return d


def doc_bang():
    """Tra ve (danh sach muc <Gear>, danh sach muc <Parts>), giu nguyen thu tu.

    `<Parts>` la mot bang RIENG nam LAN trong `<Gears>` (14 muc, xen giua cac
    `<Gear>`), khong phai mot truong cua `<Gear>`. Bo qua no thi 7 muc
    `SpearmenN_Spear_lvN` khong tra duoc gi.

    Trong `<Gears>` con 4 the `<sGear>` lac TRUC TIEP (rong, du lieu goc loi) —
    `findall('Gear')` bo qua chung, dung y muon.
    """
    t = io.open(BANG, encoding='utf-8-sig', errors='replace').read()
    goc = ET.fromstring(CHU_THICH.sub('', t))
    ge = goc.find('Gears')
    return ([_muc(g) for g in ge.findall('Gear')],
            [_muc(p) for p in ge.findall('Parts')])


def du_phong(ten):
    """LUAT DU PHONG cua chinh file bang, hai nhanh (xem docstring dau file).

    Tra `(kieu, xuong, texture)`:
      * `('texture', <xuong>, <ten texture>)` — `<arm>_<xuong>_lv<N>`
      * `('an', <xuong>, None)`               — `<arm>_<xuong>_Hide`
      * `None`                                — khong tach duoc ten
    """
    p = ten.split('_')
    if len(p) < 2 or not p[0] or not p[1]:
        return None
    if p[-1] == 'Hide':
        return ('an', p[1], None)
    return ('texture', p[1], p[0] + '_res-' + '_'.join(p[1:]))


_KHO = None


def kho_anh():
    """(ten sprite co that, ten xuong co that) tren toan bo `assets_ref`."""
    global _KHO
    if _KHO is not None:
        return _KHO
    anh, xuong = set(), set()
    for g in sorted(os.listdir(DICH_ANH)):
        f = os.path.join(DICH_ANH, g, g + '.json')
        if not os.path.exists(f):
            continue
        try:
            j = json.load(io.open(f, encoding='utf-8'))
        except ValueError:
            continue
        anh.update(j.get('sprites') or [])
        for p in j.get('parts', []):
            xuong.add(p.get('name', ''))
            for ch in p.get('children', []):
                xuong.add(ch.get('name', ''))
    _KHO = (anh, xuong)
    return _KHO


def doc_bien_the(duong):
    """{ten bien the: set(ten xuong)} tu file armature da xuat, hoac None."""
    if not os.path.exists(duong):
        return None
    d = json.load(io.open(duong, encoding='utf-8'))
    ra = {}
    for p in d.get('parts', []):
        ten = set()
        for ch in p.get('children', []):
            ten.add(ch.get('name', ''))
            for s in (ch.get('sprites') or []):
                ten.add(s)
        ra[p.get('name', '')] = ten
    return ra


def o_trong(f, ten):
    """Phan tu `ten` cua file armature `f` co phai O TRONG khong.

    "O trong" = moi anh cua phan tu deu 1x1. Do duoc: trong ca 201 muc cua bang,
    dung MOT muc ra trong — `equip_3_999` -> `EquipQin_0`, va anh cua no la
    `EquipQin_res-44` (1x1, do tu `spriteFiles`). 88 muc con lai deu co anh that
    (vd `EquipJian_res-EquipJian_1_client`).

    Nen `equip_3_999` MOI la "khong co do", khong phai cap 0: `equip_3_0` la do
    THAT (-> `EquipQin_1`). Doc nham cho nay thi cap 0 ra hinh trong.
    """
    if f is None or not os.path.exists(f):
        return False
    d = json.load(io.open(f, encoding='utf-8'))
    sf = d.get('spriteFiles') or {}
    for p in d.get('parts', []):
        if p.get('name') != ten:
            continue
        ten_anh = []
        for ch in p.get('children', []):
            ten_anh.extend(ch.get('sprites') or [])
            if not ch.get('sprites') and ch.get('name') in sf:
                ten_anh.append(ch.get('name'))
        # `spriteFiles[x]` co the la `null` (anh khong co o trong atlas) — bo qua,
        # khong coi la trong: thieu du lieu khac voi "o trong".
        co = [sf[x] for x in ten_anh if isinstance(sf.get(x), dict)]
        if not co:
            return False
        return all(int(a.get('w', 9)) <= 1 and int(a.get('h', 9)) <= 1 for a in co)
    return False


_XUONG_ARM = {}

## Hai cap (armature, xuong) ma luat du phong bia ra mot xuong KHONG co trong
## armature ay — loi ten trong du lieu goc, khong phai loi cua bo doc. Gia tri
## la ten xuong THAT (do tu chinh file armature, xem cho dung o `main`).
XUONG_LECH_GOC = {
    # Khien: `DefenderN.json` de o xuong `Logic_Shield`, va anh nen cua xuong
    # ay la `DefenderN_res-Shield_lv1`.
    ('DefenderN', 'Shield'): 'Logic_Shield',
    # Yên/bung cua alpaca: xuong `ABody1` cua bien the `Cavalry`.
    ('Cavalry', 'ABody'): 'ABody1',
}


def xuong_cua_armature(ten):
    """Tap ten xuong cua bien the ma `getSpriteFromSpriteCatch(ten)` se dung.

    Tra None khi khong co file. Theo DUNG luat `SngRig._bien_the_cho`: khop TEN
    truoc; ten thu muc khong phai mot bien the (`PlayerM.xml` chi co `PlayerM03W`
    ...) thi gop het, vi luc ay khong biet chac bien the nao.

    VI SAO CAN RIENG PHEP NAY. `kho_anh()` gop xuong cua MOI armature trong
    `assets_ref` vao mot tap, nen no noi "xuong `<X>` co ton tai o DAU DO",
    khong phai "co trong CHINH armature nay". Do duoc: `DefenderN_Shield_lv3`
    -> du phong nham xuong `Shield`, ma `DefenderN.json` KHONG co xuong `Shield`
    — khien nam o xuong `Logic_Shield` va anh nen cua no CHINH LA
    `DefenderN_res-Shield_lv1`. Anh `DefenderN_res-Shield_lv3` thi CO that
    trong `spriteFiles`, nen phep kiem cu (chi hoi ten anh) xanh, va loi chi lo
    ra luc chay duoi dang `SngRig` ghi mot ten vao `chua_lam`.
    """
    if ten in _XUONG_ARM:
        return _XUONG_ARM[ten]
    f, _ = armature_cua(ten)
    ra = None
    if f is not None:
        bt = doc_bien_the(f)
        if ten in bt:
            ra = bt[ten]
        else:
            gop = set()
            for s in bt.values():
                gop |= s
            ra = gop
    _XUONG_ARM[ten] = ra
    return ra


def armature_cua(ten):
    """File armature cua ban dung ma `getSpriteFromSpriteCatch(ten)` se doc.

    Phai soi DUNG luat cua `LuaRuntime._tao_rig` (`game/lua_runtime.gd:105-111`):
    ten la BIEN THE nam trong mot file armature KHAC ten — `EquipQin_1` nam
    trong `EquipQin.json`, `EquipWing_11` nam trong `EquipWing.json`,
    `Player004M03F` nam trong `Player004.json`. Khong co thu muc trung ten thi
    cat dan duoi, lay tien to DAI NHAT co thu muc, roi xin dung bien the do.

    Thieu luat nay thi phep doi chieu bao "48 ten khong co file" trong khi ca 48
    deu co — dung loai lech do BO DOC sai chu khong phai do du lieu sai.
    """
    for i in range(len(ten), 3, -1):
        goc = ten[:i].rstrip('_')
        f = os.path.join(DICH_ANH, goc, goc + '.json')
        if os.path.exists(f):
            return f, ten
    return None, None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--json', help='ghi bang ra file JSON')
    ap.add_argument('--ke', action='store_true', help='ke ra tung muc')
    a = ap.parse_args()

    bang, parts = doc_bang()
    theo_kieu = {}
    for d in bang:
        k = d.get('sGearType', '(khong)')
        theo_kieu[k] = theo_kieu.get(k, 0) + 1
    print('map/gear_config.xml: %d muc <Gear>, %d muc <Parts>' % (len(bang), len(parts)))
    for k in sorted(theo_kieu):
        print('  %-10s %3d' % (k, theo_kieu[k]))
    # Ba loai muc cua <Gear>, do theo TRUONG chu khong theo ten.
    theo_loai = {'la(nShowType)': 0, 'bundle(lsGear)': 0, 'parts(lsParts)': 0,
                 'baseItem': 0, 'List(lvNplus)': 0, 'rong': 0}
    for d in bang:
        if d.get('nShowType'):
            theo_loai['la(nShowType)'] += 1
        elif d.get('lsGear'):
            theo_loai['bundle(lsGear)'] += 1
        elif d.get('lsParts'):
            theo_loai['parts(lsParts)'] += 1
        elif d.get('sBaseItem'):
            theo_loai['baseItem'] += 1
        elif d.get('sGear_lv5plus') or d.get('sGear_lv6plus'):
            theo_loai['List(lvNplus)'] += 1
        else:
            theo_loai['rong'] += 1
    print('  loai muc:', ', '.join('%s %d' % (k, v) for k, v in theo_loai.items()))
    nst = {}
    for d in bang:
        n = d.get('nShowType')
        if n:
            nst[n] = nst.get(n, 0) + 1
    print('  nShowType:', ', '.join('%s=%d' % (k, v) for k, v in sorted(nst.items())))

    # Doi chieu doc lap 1: moi ten armature phai la mot PHAN TU GOC co that.
    lech = 0
    khong_co_file = set()
    so_bien_the = 0
    for d in bang:
        for truong in ('sArmtureName', 'sPropertyName'):
            ten = d.get(truong)
            if not ten:
                continue
            f, _ = armature_cua(ten)
            if f is None:
                khong_co_file.add(ten)
                continue
            bien_the = doc_bien_the(f)
            if ten in bien_the:
                so_bien_the += 1
                continue
            # Ten khong phai PHAN TU GOC: phai la ten BIEN THE (nhu
            # `Player004M03F` nam trong `Player004.json`) — luc ay
            # `getSpriteFromSpriteCatch` van dung duoc, vi no cat duoi dan.
            if any(ten.startswith(p) or p.startswith(ten) for p in bien_the):
                so_bien_the += 1
                continue
            print('  LECH: %-20s -> %s khong phai phan tu goc cua %s'
                  % (d.get('sName'), ten, os.path.basename(f)))
            lech += 1
    print('\narmature doi chieu: %d ten khong co file xuat ra, %d ten dung duoc'
          % (len(khong_co_file), so_bien_the))
    if khong_co_file:
        print('  %s' % ', '.join(sorted(khong_co_file)[:12]))
    # O trong: phai dung MOT muc (`equip_3_999`). Nhieu hon thi luat "moi anh
    # 1x1" da bat nham phan tu that, va cap 0 se ra hinh trong oan.
    rong = []
    for d in bang:
        dich = d.get('sArmtureName') or d.get('sPropertyName')
        if not dich:
            continue
        f, _ = armature_cua(dich)
        if o_trong(f, dich):
            rong.append(d.get('sName'))
    print('o trong (moi anh 1x1): %d muc — %s' % (len(rong), ', '.join(rong)))

    # Doi chieu doc lap 2: moi TEN LA do bundle sinh ra phai ra mot trong hai
    # nhanh cua luat du phong, va nhanh ay phai CHAM duoc vao du lieu that.
    # Day moi la phep thu co luc: no chay tren 201 ten ma KHONG muc nao trong
    # bang chua san ket qua.
    anh, xuong = kho_anh()
    bundle = [d for d in bang if d.get('lsGear')]
    la = []
    for d in bundle:
        la.extend(d['lsGear'])
    can = set(x for x in la if x not in set(dd.get('sName') for dd in bang))
    texture_ok = an_ok = 0
    khong_ra = []
    for ten in sorted(can):
        r = du_phong(ten)
        if r is None:
            khong_ra.append((ten, 'khong tach duoc ten'))
            continue
        kieu, xuong_ten, tex = r
        if kieu == 'texture' and tex in anh:
            texture_ok += 1
        elif kieu == 'an' and xuong_ten in xuong:
            an_ok += 1
        else:
            khong_ra.append((ten, tex or ('an ' + xuong_ten)))
    print('du phong: %d bundle sinh %d ten la (%d ten khac nhau), %d muc co san'
          % (len(bundle), len(la), len(can), len(la) - len(can)))
    print('  texture that %d · an xuong that %d · khong ra %d'
          % (texture_ok, an_ok, len(khong_ra)))
    for ten, r in khong_ra:
        # Ngoai le CO TEN: loi du lieu goc (hau to cap lap `lv1_lv4`), khong
        # phai loi cua bo doc. Bat ky ten nao KHAC dang nay van la lech that.
        if re.search(r'_lv\d+_lv\d+$', ten):
            print('     goc (loi du lieu): %-34s -> %s' % (ten, r))
        else:
            print('     LECH: %-34s -> %s' % (ten, r))
            lech += 1
    # Doi chieu doc lap 2b: nhanh TEXTURE phai tro toi mot xuong CO THAT trong
    # CHINH armature cua bundle sinh ra no — khong phai "co that o dau do".
    # `kho_anh()` o tren gop xuong cua ca kho nen no KHONG bat duoc lop loi nay:
    # do la ly do phep kiem nay ton tai.
    #
    # Do duoc DUNG HAI ho, ca hai deu la ten do dat sai trong du lieu goc (xuong
    # co that, chi la TEN KHAC):
    #
    #   `DefenderN_Shield_lv1..lv7` -> xuong `Shield`. `DefenderN.json` khong co
    #   xuong `Shield`: khien nam o `Logic_Shield` (35 xuong cua bien the
    #   `DefenderN`), va anh nen cua chinh xuong ay LA
    #   `DefenderN_res-Shield_lv1`. Anh `DefenderN_res-Shield_lv3` CO that trong
    #   `spriteFiles` — nen phep kiem cu (chi hoi ten anh) xanh.
    #
    #   `CavalryAlpaca_ABody_lv1` (+ ban loi hau to `_lv1_lv4`) -> xuong `ABody`.
    #   Khong armature nao co xuong ten dung `ABody` (quet ca kho: 0). Doi tuong
    #   that nam trong `Cavalry.json`: atlas `Cavalry` co anh
    #   `CavalryAlpaca_res-ABody_lv1`, va xuong VE no ten `ABody1` (bien the
    #   `Cavalry`, cung voi `Cavalry_Dong`, `Cavalry_Evil`...).
    #
    # Hai muc nay ghi ra theo TEN kem xuong that, khong cong vao `lech` — cung
    # loi voi ngoai le `_lv\d+_lv\d+$` ben tren. Bat ky cap (armature, xuong)
    # NAO KHAC dang nay van la lech that.
    x_ok = 0
    x_lech = {}
    for d in bundle:
        arm = re.sub(r'_lv\d+$', '', d.get('sName', ''))
        xuong_arm = xuong_cua_armature(arm)
        if xuong_arm is None:
            continue
        for ten in d.get('lsGear') or []:
            if ten in set(dd.get('sName') for dd in bang):
                continue
            r = du_phong(ten)
            if not r or r[0] != 'texture':
                continue
            if r[1] in xuong_arm:
                x_ok += 1
            else:
                k = (arm, r[1])
                x_lech[k] = x_lech.get(k, 0) + 1
    print('  xuong co that trong CHINH armature: %d dung · %d cap (armature, xuong) KHONG'
          % (x_ok, len(x_lech)))
    for (arm, xu), n in sorted(x_lech.items()):
        that = XUONG_LECH_GOC.get((arm, xu))
        if that:
            print('     goc (loi du lieu): %-14s khong co xuong %-10s (xuong that: %s) ×%d'
                  % (arm, xu, that, n))
        else:
            print('     LECH XUONG: %-14s khong co xuong %-10s ×%d' % (arm, xu, n))
            lech += 1

    # Doi chieu doc lap 3 — phep thu MANH NHAT: chinh file khai ket qua cua
    # luat du phong trong bang <Parts> SONG SONG. `SpearmenN_Spear_lvN` ->
    # <Parts> `..._Texture` voi `nPartsType 1`, `sBone Spear`,
    # `sTextureName SpearmenN_res-Spear_lvN` — dung y cong thuc du phong.
    # Hai cho doc lap trong cung mot file, cung mot dap so: cong thuc khong
    # phai suy doan.
    ten_part = set(p.get('sName') for p in parts)
    doi_part = set()
    for d in bang:
        doi_part.update(d.get('lsParts') or [])
    thieu = sorted(doi_part - ten_part)
    n_khop = 0
    for p in parts:
        tn = p.get('sName', '')
        if p.get('nPartsType') != '1' or not tn.endswith('_Texture'):
            continue
        goc_ten = tn[:-len('_Texture')]
        r = du_phong(goc_ten)
        if r and r[0] == 'texture' and r[1] == p.get('sBone') \
                and r[2] == p.get('sTextureName'):
            n_khop += 1
        else:
            print('  LECH: <Parts> %s khong khop cong thuc du phong: %s vs %s'
                  % (tn, p.get('sTextureName'), r))
            lech += 1
    print('bang <Parts>: %d muc, %d duoc <Gear> tro toi, %d thieu'
          % (len(parts), len(doi_part), len(thieu)))
    if thieu:
        print('  THIEU: %s' % ', '.join(thieu))
        lech += len(thieu)
    print('  khop cong thuc du phong: %d/%d'
          % (n_khop, sum(1 for p in parts if p.get('nPartsType') == '1')))
    print('lech: %d' % lech)

    if a.ke:
        print('\n%-22s %-8s %-4s %-12s %-20s %s'
              % ('sName', 'type', 'show', 'sBone', 'armature', 'khac'))
        for d in bang:
            khac = []
            for k in ('sTextureName', 'sParticlePlist', 'sAgencyBone',
                      'nAgencyBoneDisplayIndex', 'nDisplayIndex', 'sWeaponFight',
                      'sWeaponWake', 'sBaseItem', 'sGear_lv5plus',
                      'sGear_lv6plus', 'nPartsType', 'sParts', 'sShowType',
                      'sType', 'lsGear', 'lsParts', 'lsThrowWeaponType'):
                if k in d:
                    v = d[k]
                    khac.append('%s=%s' % (k, '|'.join(v) if isinstance(v, list) else v))
            print('%-22s %-8s %-4s %-12s %-20s %s'
                  % (d.get('sName', ''), d.get('sGearType', ''),
                     d.get('nShowType', ''), d.get('sBone', ''),
                     d.get('sArmtureName') or d.get('sPropertyName') or '',
                     ' '.join(khac)))

    if a.json:
        ra = {
            'nguon': {
                'bang': 'map/gear_config.xml',
                'armature': 'map/*.xml (+ .plist/.pkm), tra bang ten bien the',
                'khoa': 'setGear(pRole, ten) — ham toan cuc, 10 cho goi THAT trong sc/',
            },
            'kieu': {str(k): v for k, v in KIEU.items()},
            'do': {},
            'parts': {},
        }
        for d in bang:
            ten = d.get('sName')
            if not ten:
                continue
            n = d.get('nShowType')
            muc = {
                'loai': d.get('sGearType', ''),
                'kieu': KIEU.get(int(n), '?') if n and n.isdigit() else '?',
                'nShowType': int(n) if n and n.isdigit() else None,
            }
            for k in ('sBone', 'sArmtureName', 'sPropertyName', 'sTextureName',
                      'sParticlePlist', 'sAgencyBone', 'sBaseItem',
                      # `sGear_lv5plus` / `sGear_lv6plus` la muc dang LIST: chon do
                      # theo CAP (`equip_Exclusive_10_List` -> `equip_Exclusive_10_5`).
                      # Thieu hai truong nay thi `GearRef.chuyen_tiep` khong bao gio
                      # ra duoc nhanh LIST, va 6 muc dang ay roi vao duong du phong.
                      'sGear_lv5plus', 'sGear_lv6plus'):
                if d.get(k):
                    muc[k] = d[k]
            for k in ('nDisplayIndex', 'nAgencyBoneDisplayIndex'):
                if d.get(k) and d[k].lstrip('-').isdigit():
                    muc[k] = int(d[k])
            if d.get('lsGear'):
                muc['lsGear'] = list(d['lsGear'])
            # `lsParts` la muc dang PARTS: tro toi bang RIENG `<Parts>` (14 muc).
            # Thieu no thi `GearRef.ls_parts` luon tra rong va ca nhanh PARTS trong
            # `SngRig._dat_do` la ma chet — 7 muc, trong do co `SpearmenN_Spear_lv1`
            # (giao linh, dung o moi ai co SpearmenN).
            if d.get('lsParts'):
                muc['lsParts'] = list(d['lsParts'])
            # `trong` = do nay KHONG ve gi (o trong 1x1). Chi 1 muc trong bang.
            dich = d.get('sArmtureName') or d.get('sPropertyName')
            if dich:
                f, _ = armature_cua(dich)
                if o_trong(f, dich):
                    muc['trong'] = True
            ra['do'][ten] = muc
        for p in parts:
            ten = p.get('sName')
            if not ten:
                continue
            muc = {'nPartsType': int(p['nPartsType']) if p.get('nPartsType', '').isdigit() else None}
            for k in ('sBone', 'sTextureName', 'sWeaponFight', 'sWeaponWake',
                      'sParticlePlist', 'lsThrowWeaponType'):
                if p.get(k):
                    muc[k] = p[k]
            ra['parts'][ten] = muc
        os.makedirs(os.path.dirname(os.path.abspath(a.json)), exist_ok=True)
        with io.open(a.json, 'w', encoding='utf-8', newline='\n') as f:
            json.dump(ra, f, ensure_ascii=False, indent=1, sort_keys=True)
        print('da ghi %s (%d muc do, %d muc parts)'
              % (a.json, len(ra['do']), len(ra['parts'])))
    return 1 if lech else 0


if __name__ == '__main__':
    sys.exit(main())
