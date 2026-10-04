# -*- coding: utf-8 -*-
"""Rut so do BONG (shadow) cua tung sprite ra JSON, va xuat anh bong ra PNG.

Vi sao can: engine tu dung bong chu khong de Lua dung. Ham `_ShowShadow` cua
libgame.so (`0x419f74`, Thumb) ban ra hai nhanh do duoc:

    0x419f74  movs r1, #1 ; bl 0x23c17c   -- toboolean(co, mac dinh 1)
              -> co that : bl 0x419de6(self, 1)
              -> co gian : bl 0x417e14(self)

`0x419de6` goi TRUOC TIEN `0x419668` (tao bong neu chua co), roi dong bo cho
dung cho va `setVisible(true)`; `0x417e14` goi `removeFromParentAndCleanup(true)`
+ `release()` + tra con tro ve 0. Nghia la bong chi TON TAI khi co ai do goi
`_ShowShadow(true)` — khong he duoc dung san luc nap sprite.

`0x419668` (tao bong) co hai cua chan va mot ten anh:

    str.w r5, [r4, #0x308] ; bl 0x37241c   -- co/khong co cau hinh -> bo qua
    bl 0x3949cc ; cmp r0, #8 ; beq        -- gia tri 8 = khong co bong
    ldr r1, [pc] -> 0x7beccd "Shadow.png"
    bl 0x3ca9a8(self, "Shadow.png", self[0x338])

`0x3ca9a8` dung mot CCSprite 0x1c0 byte: dat neo (0.5, 0.5) — hai hang so
`0x3f000000` — va giu tham chieu toi armature o +0x17c.

Cho nguon so: cau hinh GOC, khong phai suy doan.
    map/global_config.xml   khoi chu thich 阴影: fShadowScaleRate 0.9
                            (ngay tren no la chu thich "mac dinh 0.9"),
                            fSmallShadowScale 0.6, fBigShadowScale 1.5
    map/{hero,heroex,player,sprite,boss,evil}_config.xml
                            tung muc: nShadowSize, fShadowScaleRate,
                            fShadowOffsetRate, fShadowOpacity, sShadow

CAY CUA FILE NAY KHONG PHAI "mot <item> boc het". Do lai bang cach boc theo do
sau: `<sprites>` cua hero_config.xml co **801** khoi cap 1 cho 119 `item` —
`fight` 224, `weapon` 109, `silk` 72, `adapt` 67, `pause` 65, `limbs` 51,
`prop` 34, `move` 35… Tuc the <item> cua mot tuong CHI chua cac so cua tuong,
roi cac khoi kia la ANH EM. Nen `sShadow` nam trong `<limbs>` (ten
`limbs_<Tuong>`, gia tri `<Tuong>Shadow`) chu khong phai trong `<item>`. Mot
regex `<item>(.*?)</item>` se dung o `</item>` cua `<lsAdapt>` ben trong, tuc
cat cut; con gop `<item>` voi `<limbs>` lai thi gan sai chu. Bo doc o day dung
cay that: khoi = phan tu CO `<sName>` va CO it nhat mot khoa bong; ten khoi lay
tu chinh `<sName>`.

Cac khoa so, do lai theo tung khoi (khop dung so lan xuat hien trong file):
    nShadowSize       7   — ca 7 deu la 2
    fShadowScaleRate  7   — 0.7 x3, 0.8 x2, 0.76, 1.0
    fShadowOffsetRate 8   — 0.017…0.235
    fShadowOpacity    2   — 0.8, chi o evil_config (DragonFlight, BatFlight)

KHONG khoi phuc duoc (ghi ra, khong bia):
  * `nShadowSize` anh xa sang ti le nao. Ca 7 cho dat no trong du lieu deu la
    `2`. Bo doc cau hinh cua engine doc khoa bang CHI SO TEN chu khong bang dia
    chi chuoi (quet ca file khong co cho nao tro toi dia chi cua chuoi
    'nShadowSize'), nen khong lan ra duoc bang tinh.
  * `fShadowOffsetRate` nhan voi cai gi (don vi cua no).
  * `sShadow` tro toi tai nguyen NAO. No luon la `<Tuong>Shadow` (120 khoi
    `limbs` trong hero/heroex/player_config.xml), nhung khong file .xml nao ten
    do va khong plist nao chua no — tai nguyen ay KHONG duoc ship. Duong tao
    bong cua engine cung chi dung mot anh dung chung: "Shadow.png".

    python bong_ref.py --json <file> --anh <thu_muc>
    python bong_ref.py                 # chi in ra tom tat
"""
import argparse
import io
import json
import os
import re
import sys

import cay

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from sprites import read_pkm, write_png

ASSETS = cay.ASSETS
MAP = os.path.join(ASSETS, 'map')
BONG_PKM = os.path.join(ASSETS, 'png', 'ribbon', 'Shadow.pkm')

NGUON = ['hero_config.xml', 'heroex_config.xml', 'player_config.xml',
         'sprite_config.xml', 'boss_config.xml', 'evil_config.xml']

KHOA_SO = ['nShadowSize', 'fShadowScaleRate', 'fShadowOffsetRate', 'fShadowOpacity']

## So lan xuat hien phai ra dung bang phep dem tho tren chuoi (xem muc_cua).
SO_LAN = {'nShadowSize': 7, 'fShadowScaleRate': 7, 'fShadowOffsetRate': 8,
          'fShadowOpacity': 2}
SO_VAI = 120

THE = re.compile(r'<(/?)([A-Za-z_][\w.]*)([^>]*?)(/?)>')
CHU_THICH = re.compile(r'<!--.*?-->', re.S)


# ------------------------------------------------------------ cay cua file
def cay(s):
    """Dung cay phan tu cua mot file XML don gian (khong thuoc tinh dang ke).

    Tra ve (goc, so_lan_lech). `lech > 0` nghia la file khong long nhau dung —
    luc do ket qua khong dang tin, phai bao ra chu khong doan bua.
    """
    goc = {'tag': '#goc', 'than': '', 'con': []}
    st = [goc]
    lech = 0
    for m in THE.finditer(s):
        d, tag, _attr, sc = m.group(1), m.group(2), m.group(3), m.group(4)
        if d:
            if len(st) > 1 and st[-1]['tag'] == tag:
                st[-1]['than'] = s[st[-1]['mo']:m.start()]
                st.pop()
            else:
                lech += 1
        elif sc:
            st[-1]['con'].append({'tag': tag, 'than': '', 'con': []})
        else:
            # `mo` la vi tri NGAY SAU the mo: `than` phai la ruot, khong ke ca the.
            nut = {'tag': tag, 'than': '', 'con': [], 'mo': m.end()}
            st[-1]['con'].append(nut)
            st.append(nut)
    return goc, lech


def con_cua(node, tag):
    return [c for c in node['con'] if c['tag'] == tag]


def tim(node, tag, sau=0):
    """Phan tu con dau tien ten `tag`, tim sau toi `sau` tang."""
    for c in node['con']:
        if c['tag'] == tag:
            return c
        if sau:
            r = tim(c, tag, sau - 1)
            if r is not None:
                return r
    return None


def chu(node, tag, mac_dinh=''):
    c = tim(node, tag)
    return c['than'].strip() if c is not None else mac_dinh


def so_cua(node, tag):
    t = chu(node, tag)
    if not t:
        return None
    try:
        return int(t)
    except ValueError:
        try:
            return float(t)
        except ValueError:
            return t


def muc_cua(path):
    """Moi khoi trong file co `<sName>` va it nhat mot khoa bong, kem ten khoi.

    Khong buoc vao ten phan tu chua: hero_config.xml dung `<sprites>`, con
    heroex_config.xml dung `<exclusive>`. Luat "co sName + co khoa bong" doc lap
    voi ten ay, va da kiem: tong so lan xuat hien khop DUNG voi phep dem tho
    tren chuoi (nShadowSize 7, fShadowScaleRate 7, fShadowOffsetRate 8,
    fShadowOpacity 2) — tuc khong bo sot khoi nao, cung khong dem doi.
    """
    s = CHU_THICH.sub('', io.open(path, encoding='utf-8-sig', errors='replace').read())
    g, lech = cay(s)
    if lech:
        print('  !! %s: %d the khong long nhau dung' % (os.path.basename(path), lech))
    ra = []

    def di(n):
        for c in n['con']:
            if chu(c, 'sName') and any(con_cua(c, k) for k in KHOA_SO):
                ra.append(c)
            di(c)

    di(g)
    return ra


def vai_cua(path):
    """{ten_armature: ten_tai_nguyen_bong} tu cac khoi `<limbs>` co `sShadow`.

    Do lai: `sShadow` CHI xuat hien trong khoi `limbs`, ten khoi la
    `limbs_<Tuong>` va gia tri la `<Tuong>Shadow` — vd `limbs_YuJin` →
    `YuJinShadow`, `limbs_DaQiao` → `DaQiaoReplica` (mau le), `limbs_
    XiaoQiaoExclus` → `XiaoQiaoExclusShadow`.
    """
    s = CHU_THICH.sub('', io.open(path, encoding='utf-8-sig', errors='replace').read())
    g, _ = cay(s)
    ra = {}

    def di(n):
        for c in n['con']:
            if c['tag'] == 'limbs':
                ten = chu(c, 'sName')
                b = chu(c, 'sShadow')
                if ten and b:
                    ra[re.sub(r'^limbs_', '', ten)] = b
            di(c)

    di(g)
    return ra


# ------------------------------------------------------------------ quet
def quet():
    muc = {}
    vai = {}
    for f in NGUON:
        p = os.path.join(MAP, f)
        if not os.path.exists(p):
            continue
        for m in muc_cua(p):
            ten = chu(m, 'sName')
            co = muc.setdefault(ten, {})
            for k in KHOA_SO:
                v = so_cua(m, k)
                if v is not None:
                    co[k] = v
        vai.update(vai_cua(p))

    g, _ = cay(CHU_THICH.sub('', io.open(os.path.join(MAP, 'global_config.xml'),
                                         encoding='utf-8-sig', errors='replace').read()))
    toan = {}
    # So mac dinh nam trong khoi <stage> cua global_config.xml, ngay duoi chu
    # thich 阴影 (do lai bang cay: config > global > stage > fShadowScaleRate).
    khuc = tim(g, 'stage', sau=2)
    if khuc is not None:
        for k in ('fShadowScaleRate', 'fSmallShadowScale', 'fBigShadowScale'):
            v = so_cua(khuc, k)
            if v is not None:
                toan[k] = v
    return {'toan_cuc': toan, 'muc': muc, 'vai': vai}


def dem(b):
    dem = {}
    for co in b['muc'].values():
        for k, v in co.items():
            dem.setdefault(k, {})
            dem[k][v] = dem[k].get(v, 0) + 1
    return dem


# ------------------------------------------------------------- xuat anh
def xuat_anh(thu_muc):
    """Giai ma png/ribbon/Shadow.pkm ra PNG.

    ETC1 khong mang kenh alpha: nua TREN la mau, nua DUOI la do trong (lay kenh
    do) — dung thu thuat nhu sprites.py va scenes.py.

    Do lai tren chinh file PNG xuat ra (xem tools/verify_bong.gd):
      * 164x22, alpha giua 112/255 = 0,439, bon goc 0.
      * alpha PHANG trong long hinh — ca anh khong diem nao qua 115/255: day la
        mot ELIP DAC vien cung noi tiep trong o, KHONG phai gradient mem. Do dam
        nam o chinh anh, con `fShadowOpacity` cua cau hinh nhan them len tren.
      * be ngang hang giua 164 (cham ca hai mep), hang dau = hang cuoi = 66, hep
        dan deu ra hai dau — doi xung tren-duoi. Mot mat na alpha doc sai se
        khong ra hinh gon gang nhu vay.
    """
    rgb, ew, eh, ow, oh = read_pkm(BONG_PKM)
    half = oh // 2
    out = bytearray(ow * half * 4)
    for y in range(half):
        row = y * ew * 3
        arow = (y + half) * ew * 3
        for x in range(ow):
            d = (y * ow + x) * 4
            s = row + x * 3
            out[d] = rgb[s]
            out[d + 1] = rgb[s + 1]
            out[d + 2] = rgb[s + 2]
            out[d + 3] = rgb[arow + x * 3]
    os.makedirs(thu_muc, exist_ok=True)
    dich = os.path.join(thu_muc, 'Shadow.png')
    write_png(dich, ow, half, out)
    return dich, ow, half


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--json', help='ghi so do bong ra file JSON')
    ap.add_argument('--anh', help='thu muc de ghi Shadow.png')
    ap.add_argument('--ke', action='store_true', help='ke ra tung muc co so do bong')
    a = ap.parse_args()

    b = quet()
    print('toan cuc:', b['toan_cuc'])
    print('so muc co so do bong:', len(b['muc']))
    d = dem(b)
    hong = 0
    for k in KHOA_SO:
        n = sum(d.get(k, {}).values())
        canh = '' if n == SO_LAN[k] else '   <<< LECH, phai la %d' % SO_LAN[k]
        hong += 0 if n == SO_LAN[k] else 1
        print('  %-20s %-40s tong %d%s' % (k, dict(sorted(d.get(k, {}).items(),
                                                           key=lambda x: str(x[0]))), n, canh))
    print('so armature co sShadow:', len(b['vai']),
          '' if len(b['vai']) == SO_VAI else '<<< LECH, phai la %d' % SO_VAI)

    if a.ke:
        for ten, co in sorted(b['muc'].items()):
            print('  %-24s %s' % (ten, co))
        for ten, co in sorted(b['vai'].items()):
            print('  limbs %-22s %s' % (ten, co))

    if a.json:
        b['nguon'] = {'muc': NGUON, 'toan_cuc': 'map/global_config.xml',
                      'anh': 'png/ribbon/Shadow.pkm'}
        with io.open(a.json, 'w', encoding='utf-8', newline='\n') as f:
            json.dump(b, f, ensure_ascii=False, indent=1, sort_keys=True)
        print('da ghi', a.json)

    if a.anh:
        p, w, h = xuat_anh(a.anh)
        print('da ghi %s (%dx%d)' % (p, w, h))


if __name__ == '__main__':
    main()
