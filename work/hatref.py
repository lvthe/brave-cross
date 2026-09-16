# -*- coding: utf-8 -*-
"""Xuat dinh nghia hat cua ban goc (.plist) sang JSON cho ban port.

    python hatref.py --out ../../bravecross-game/hat_ref
    python hatref.py --list

Vi sao xuat JSON chu khong chep thang .plist: Godot khong co bo doc plist, va
tu viet mot bo doc XML plist trong GDScript la viet lai ca mot thu vien —
trong khi du lieu that ra chi la MOT DICT PHANG, 51 khoa (32/33 dinh nghia dung
51, rieng map/yellowTrail 52 — xem chu thich o vong lap), kieu so/chuoi. Doi o
buoc nay giu NGUYEN MOI KHOA cua plist, ke ca khoa ban port chua dung toi, de
sau con tra lai duoc. Bo bot khoa ngay o buoc xuat la tu tay lam mat du lieu
cua ban goc, dung kieu sai ma nguyen tac 1 cua CLAUDE.md cam.

Khoa cua mot dinh nghia = duong dan tuong doi trong assets/ va BO DUOI —
cung loi voi uiart.py, de 'map/beachfiresmall' tra ra dung tep. Bo cuc .xgg
ghi duong dan tuong doi voi THU MUC conf ('../map/beachfiresmall.plist'), nen
phia Godot chi viec bo '../' o dau va '.plist' o duoi. Da kiem: ca 87 node hat
trong ca cay deu ghi dang '../...', khong node nao ghi dang khac.

--out ghi hai thu:
    <flat>.json   mot dinh nghia hat, JSON, giu nguyen khoa cua plist
    index.json    {khoa: {"json": <ten tep>, "texture": <khoa anh>}}

Trong do <khoa anh> = thu muc cua plist + textureFileName bo duoi, vi plist
Cocos ghi TEN TEP tran va anh nam ngay canh no. Do tren 33 dinh nghia: ca 33
deu co textureFileName, va 6/6 anh ma bo cuc dung deu tra ra duoc khoa co
that trong ui_ref (xem --ui).
"""
import os
import sys
import glob
import json
import argparse
import plistlib
import collections

HERE = os.path.dirname(os.path.abspath(__file__))

DEFAULT_ASSETS = os.path.join(HERE, 'vn', 'decrypted', 'assets')
DEFAULT_UI = os.path.join(HERE, '..', '..', 'bravecross-game', 'ui_ref')

CO_KHOA = b'maxParticles'      # dau hieu mot plist la dinh nghia hat


def find_hat(assets):
    """{khoa: duong dan that} cho moi .plist la dinh nghia hat.

    Loc bang CHINH noi dung chu khong bang ten: 534 .plist trong cay, phan lon
    la atlas khung hinh cua anh — chung cung duoi .plist va cung nam lan trong
    assets/. Dau hieu phan biet duy nhat la co khoa maxParticles.
    """
    out = collections.OrderedDict()
    for p in sorted(glob.glob(os.path.join(assets, '**', '*.plist'),
                              recursive=True)):
        try:
            with open(p, 'rb') as f:
                if CO_KHOA not in f.read():
                    continue
        except OSError:
            continue
        rel = os.path.relpath(p, assets).replace('\\', '/')[:-len('.plist')]
        out[rel] = p
    return out


def khoa_anh(khoa, ten_anh):
    """Khoa anh cua mot dinh nghia hat: thu muc plist + ten anh, bo duoi."""
    if not ten_anh:
        return ''
    thu_muc = khoa.rsplit('/', 1)[0] if '/' in khoa else ''
    goc = os.path.splitext(ten_anh)[0]
    return (thu_muc + '/' + goc) if thu_muc else goc


def ten_json(khoa):
    return khoa.replace('/', '_') + '.json'


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--assets', default=DEFAULT_ASSETS, help='mac dinh: %(default)s')
    ap.add_argument('--ui', default=DEFAULT_UI,
                    help='thu muc ui_ref de doi chieu anh co that khong')
    ap.add_argument('--out', help='thu muc ghi JSON + index.json')
    ap.add_argument('--list', action='store_true', help='chi liet ke roi thoat')
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')

    if not os.path.isdir(a.assets):
        raise SystemExit('khong co thu muc %s\n'
                         'chay tu brave-cross/work, hoac dua --assets tro toi '
                         '<giai nen>/assets' % os.path.abspath(a.assets))
    hats = find_hat(a.assets)
    if not hats:
        raise SystemExit('khong thay .plist nao co %s trong %s'
                         % (CO_KHOA.decode(), os.path.abspath(a.assets)))

    # Anh co that khong: doc thang index.json cua ui_ref (do uiart.py ghi).
    anh_co = set()
    idx = os.path.join(a.ui, 'index.json')
    if os.path.isfile(idx):
        with open(idx, encoding='utf-8') as f:
            d = json.load(f)
        anh_co = set((d.get('frames') or {}).keys())
    khong_co_anh = os.path.isdir(a.ui) and not anh_co

    print('dinh nghia hat: %d' % len(hats))
    if a.list:
        for k, p in hats.items():
            print('   %-42s %s' % (k, os.path.relpath(p, a.assets)))
        return 0
    if not a.out:
        raise SystemExit('thieu --out')

    os.makedirs(a.out, exist_ok=True)
    index = collections.OrderedDict()
    thieu = []
    for k, p in hats.items():
        with open(p, 'rb') as f:
            d = plistlib.load(f)
        # Giu NGUYEN gia tri, khong loc. Do tren 33 dinh nghia: 32 cai dung 51
        # khoa, con map/yellowTrail co 52 — khoa them la textureImageData, mot
        # CHUOI base64 (6.708 ky tu, giai nen ra gzip roi ra anh PNG 19.726
        # byte). No la BAN SAO cua chinh anh, khong phai du lieu hat, nhung van
        # giu lai: bo di la tu y cat bot du lieu goc. Nhanh isinstance(bytes)
        # ben duoi la chot chan cho plist dang <data> — do ra thi tren cay nay
        # KHONG cai nao roi vao do.
        sach = collections.OrderedDict()
        for key in d:
            v = d[key]
            if isinstance(v, bytes):
                sach[key] = {'_bytes': len(v)}
            else:
                sach[key] = v
        with open(os.path.join(a.out, ten_json(k)), 'w', encoding='utf-8') as f:
            json.dump(sach, f, ensure_ascii=False, indent=1)
        tex = khoa_anh(k, d.get('textureFileName'))
        muc = collections.OrderedDict([('json', ten_json(k)), ('texture', tex)])
        if anh_co:
            muc['texture_co'] = tex in anh_co
            if tex not in anh_co:
                thieu.append((k, tex))
        index[k] = muc
    with open(os.path.join(a.out, 'index.json'), 'w', encoding='utf-8') as f:
        json.dump(index, f, ensure_ascii=False, indent=1)

    print('xong: %d dinh nghia -> %s' % (len(index), a.out))
    if khong_co_anh:
        print('luu y: %s khong co index.json nen khong doi chieu duoc anh'
              % a.ui)
    if thieu:
        print('anh KHONG co trong ui_ref (%d):' % len(thieu))
        for k, t in thieu:
            print('   %-42s %s' % (k, t))
    return 0


if __name__ == '__main__':
    sys.exit(main())
