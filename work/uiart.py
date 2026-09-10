# -*- coding: utf-8 -*-
"""Giai anh giao dien tu .pkm ra PNG, danh chi muc theo TEN FRAME.

Hoa ra anh UI khong nam trong atlas: moi anh la mot file .pkm rieng trong
sngSplitData/. Ten file trung khit ten trong section C cua .xgg — vi du
'item_55.png' trong bo cuc <-> sngSplitData/item_55.pkm. Kiem tren HUD man
tran: 93/94 anh tim thay.

ETC1 khong co kenh alpha nen game dung thu thuat quen thuoc: anh cao GAP DOI,
nua tren la mau, nua duoi la alpha dang xam. Chieu cao con duoc dem cho chia
het 4 (yeu cau cua ETC1), nen kich thuoc that lay tu bo cuc chu khong tu file.

Chi muc sinh ra cho Godot tra cuu y het S_CCSpriteFrameCache:spriteFrameByName
cua ban goc — do la cach ban goc gan anh, xem CUIGame.lua.

    python uiart.py --out <thu_muc>                # giai het
    python uiart.py --out <thu_muc> --only item_55 ui_background204
    python uiart.py --list                         # chi dem, khong ghi
"""
import os
import sys
import json
import glob
import struct
import argparse
import collections

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from sprites import read_pkm, write_png, SpriteError

DEFAULT_ASSETS = os.path.join(HERE, 'vn', 'decrypted', 'assets')


def find_pkm(assets):
    """{ten khong duoi: duong dan}. Trung ten thi giu cai gap dau tien."""
    out = collections.OrderedDict()
    for p in sorted(glob.glob(os.path.join(assets, '**', '*.pkm'), recursive=True)):
        out.setdefault(os.path.basename(p)[:-4], p)
    return out


PNG_MAGIC = b'\x89PNG\r\n\x1a\n'


def is_png(path):
    """Vai file .pkm that ra la PNG thuong (png/game_logo.pkm, png/logo.pkm).

    Chung khong qua ETC1 nen khong co tro nua-mau-nua-alpha; chep thang.
    """
    with open(path, 'rb') as fp:
        return fp.read(8) == PNG_MAGIC


def png_size(path):
    """(w, h) doc tu header PNG, hoac None neu khong doc duoc."""
    try:
        with open(path, 'rb') as fp:
            head = fp.read(24)
        if len(head) < 24 or head[:8] != PNG_MAGIC or head[12:16] != b'IHDR':
            return None
        return struct.unpack('>2I', head[16:24])
    except OSError:
        return None


def convert(path):
    """.pkm -> (rgba, w, h) voi alpha lay tu nua duoi.

    read_pkm tra ve RGB (3 byte/diem) o kich thuoc DA DEM (ew x eh, boi so 4
    cua ETC1), kem kich thuoc goc (ow x oh). Phai doc theo hang cua anh dem
    nhung chi lay ow cot va oh hang, neu khong la lech xeo.
    """
    rgb, ew, eh, ow, oh = read_pkm(path)
    if oh < 2:
        raise SpriteError('anh cao %d, khong tach duoc alpha' % oh)
    half = oh // 2
    out = bytearray(ow * half * 4)
    for y in range(half):
        src = y * ew * 3
        asrc = (y + half) * ew * 3
        dst = y * ow * 4
        for x in range(ow):
            out[dst + x * 4 + 0] = rgb[src + x * 3 + 0]
            out[dst + x * 4 + 1] = rgb[src + x * 3 + 1]
            out[dst + x * 4 + 2] = rgb[src + x * 3 + 2]
            out[dst + x * 4 + 3] = rgb[asrc + x * 3 + 0]   # do xam -> alpha
    return bytes(out), ow, half


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--assets', default=DEFAULT_ASSETS, help='mac dinh: %(default)s')
    ap.add_argument('--out', help='thu muc ghi PNG + index.json')
    ap.add_argument('--only', nargs='*', help='chi giai vai ten')
    ap.add_argument('--list', action='store_true', help='chi dem')
    ap.add_argument('--force', action='store_true',
                    help='giai lai ca nhung anh da co')
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')

    # Duong dan mac dinh la TUONG DOI: chay tu thu muc khac thi khong thay gi
    # ma van chay tiep, ghi ra mot index.json rong. Chan ngay o day.
    if not os.path.isdir(a.assets):
        raise SystemExit('khong co thu muc %s\n'
                         'chay tu brave-cross/work, hoac dua --assets tro toi '
                         '<giai nen>/assets' % os.path.abspath(a.assets))
    pkm = find_pkm(a.assets)
    if not pkm:
        raise SystemExit('khong thay file .pkm nao trong %s'
                         % os.path.abspath(a.assets))
    if a.only:
        pkm = collections.OrderedDict((k, v) for k, v in pkm.items() if k in set(a.only))
    print('file .pkm: %d' % len(pkm))
    if a.list:
        return 0
    if not a.out:
        raise SystemExit('thieu --out')

    os.makedirs(a.out, exist_ok=True)
    index = collections.OrderedDict()
    ok = fail = copied = reused = 0
    fails = []
    for i, (name, path) in enumerate(pkm.items(), 1):
        fn = name.replace('/', '_') + '.png'
        dst = os.path.join(a.out, fn)
        # Chay lai duoc nhieu lan: anh da giai va moi hon nguon thi dung lai,
        # chi doc kich thuoc tu header PNG. Nho vay --only khong lam mat chi
        # muc cua nhung anh da co, va giai dut quang van tiep duoc.
        if not a.force and os.path.isfile(dst) \
                and os.path.getmtime(dst) >= os.path.getmtime(path):
            wh = png_size(dst)
            if wh:
                index[name] = collections.OrderedDict(
                    [('png', fn), ('w', wh[0]), ('h', wh[1])])
                ok += 1
                reused += 1
                continue
        try:
            if is_png(path):
                with open(path, 'rb') as src, open(dst, 'wb') as out:
                    out.write(src.read())
                w = h = 0                      # kich thuoc doc tu chinh PNG khi dung
                copied += 1
            else:
                rgba, w, h = convert(path)
                write_png(dst, w, h, rgba)
        except (SpriteError, OSError, ValueError) as e:
            fail += 1
            fails.append((name, str(e)))
            continue
        index[name] = collections.OrderedDict([('png', fn), ('w', w), ('h', h)])
        ok += 1
        if i % 400 == 0:
            print('  ... %d/%d' % (i, len(pkm)), flush=True)

    with open(os.path.join(a.out, 'index.json'), 'w', encoding='utf-8') as fp:
        json.dump(collections.OrderedDict([
            ('note', 'ten -> PNG. Tra cuu y het spriteFrameByName cua ban goc.'),
            ('count', len(index)),
            ('frames', index),
        ]), fp, ensure_ascii=False, indent=1)

    print('xong: %d anh -> %s' % (ok, a.out))
    if reused:
        print('trong do %d anh da co san, dung lai' % reused)
    if copied:
        print('%d file von da la PNG, chep thang' % copied)
    if fail:
        print('that bai: %d' % fail)
        for n, e in fails[:8]:
            print('   %-30s %s' % (n, e))
    return 0


if __name__ == '__main__':
    sys.exit(main())
