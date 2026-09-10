# -*- coding: utf-8 -*-
"""Xuat anh NEN CANH ra PNG.

Khac voi nhan vat: nen canh khong nam trong atlas ma la tung file .pkm roi
trong assets/png/scene/<canh>/.

Cac file Scene_*.plist co trong assets nhung TEXTURE CUA CHUNG KHONG CO —
khong o APK, khong o OBB (da kiem: 9874 muc trong OBB, 16 file Scene_* deu la
.plist). Nhung atlas do duoc tai ve luc chay tu may chu va. Nen phan nen ghep
tu 45 manh nho ma BattleField_*.xgg mo ta thi KHONG dung lai duoc.

Bu lai, cac lop nen DAY MAN thi co du: plain_a01..a04, lava_*, siege*... —
1024x768 hoac 1367x768, ve tay, dung duoc ngay.

ETC1 khong mang kenh alpha nen game xep doi chieu cao: nua tren la mau, nua
duoi la do trong (lay kenh do). Giong het cach lam voi atlas nhan vat.

    python scenes.py --list
    python scenes.py --all --out <thu_muc>
    python scenes.py plain lava --out <thu_muc>
"""
import os, sys, glob, struct, argparse, collections

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from sprites import read_pkm, write_png, safe, SpriteError

DEFAULT_SCENES = os.path.join(HERE, 'vn', 'decrypted', 'assets', 'png', 'scene')
## Nen day man: rong it nhat 960 va cao (sau khi tach alpha) it nhat 600.
MIN_W, MIN_H = 960, 600


def head(path):
    """(rong, cao) ghi trong header PKM, chua tach alpha."""
    d = open(path, 'rb').read(16)
    if len(d) < 16 or d[:4] != b'PKM ':
        return None
    ew, eh, ow, oh = struct.unpack('>4H', d[8:16])
    return ow, oh


def is_backdrop(path):
    wh = head(path)
    return bool(wh) and wh[0] >= MIN_W and wh[1] // 2 >= MIN_H


def decode(path):
    """(rgba, rong, cao) sau khi tach kenh trong suot."""
    rgb, ew, eh, ow, oh = read_pkm(path)
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
    return bytes(out), ow, half


def survey(root):
    """canh -> danh sach file nen day man."""
    out = collections.OrderedDict()
    for d in sorted(glob.glob(os.path.join(root, '*'))):
        if not os.path.isdir(d):
            continue
        files = sorted(p for p in glob.glob(os.path.join(d, '*.pkm'))
                       if is_backdrop(p))
        if files:
            out[os.path.basename(d)] = files
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('names', nargs='*', help='ten canh, vd plain lava')
    ap.add_argument('--scenes', default=DEFAULT_SCENES, help='mac dinh: %(default)s')
    ap.add_argument('--out', help='thu muc ket qua')
    ap.add_argument('--all', action='store_true')
    ap.add_argument('--list', action='store_true')
    ap.add_argument('--raw', metavar='THU_MUC',
                    help='xuat MOI .pkm trong mot thu muc, khong loc theo kich '
                         'thuoc — dung cho assets/png/background (art giao dien)')
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')

    if a.raw:
        if not a.out:
            sys.exit('thieu --out')
        files = sorted(glob.glob(os.path.join(a.raw, '*.pkm')))
        if not files:
            sys.exit('khong co .pkm trong %s' % a.raw)
        os.makedirs(a.out, exist_ok=True)
        n_ok = n_fail = 0
        for p in files:
            name = safe(os.path.splitext(os.path.basename(p))[0]) + '.png'
            try:
                rgba, w, h = decode(p)
                write_png(os.path.join(a.out, name), w, h, rgba)
                n_ok += 1
            except (SpriteError, OSError, ValueError) as e:
                print('  %-34s LOI: %s' % (name, e))
                n_fail += 1
        print('xong: %d anh, %d loi  ->  %s' % (n_ok, n_fail, a.out))
        return 1 if n_fail else 0

    if not os.path.isdir(a.scenes):
        sys.exit('khong thay %s' % a.scenes)
    found = survey(a.scenes)

    if a.list or not (a.all or a.names):
        print('%d canh co nen day man (>= %dx%d):' % (len(found), MIN_W, MIN_H))
        for scene, files in found.items():
            print('  %-14s %d anh' % (scene, len(files)))
            for p in files:
                wh = head(p)
                print('     %-32s %dx%d' % (os.path.basename(p), wh[0], wh[1] // 2))
        return 0

    if not a.out:
        sys.exit('thieu --out')
    todo = list(found) if a.all else a.names
    n_ok = n_fail = 0
    for scene in todo:
        if scene not in found:
            print('  %-14s khong co nen day man' % scene)
            continue
        sub = os.path.join(a.out, scene)
        os.makedirs(sub, exist_ok=True)
        for p in found[scene]:
            name = safe(os.path.splitext(os.path.basename(p))[0]) + '.png'
            try:
                rgba, w, h = decode(p)
                write_png(os.path.join(sub, name), w, h, rgba)
                print('  %-14s %-34s %dx%d' % (scene, name, w, h))
                n_ok += 1
            except (SpriteError, OSError) as e:
                print('  %-14s %-34s LOI: %s' % (scene, name, e))
                n_fail += 1
    print('\nxong: %d anh, %d loi' % (n_ok, n_fail))
    return 1 if n_fail else 0


if __name__ == '__main__':
    sys.exit(main())
