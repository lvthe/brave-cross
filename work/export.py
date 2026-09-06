# -*- coding: utf-8 -*-
"""Xuat tron goi mot nhan vat: PNG roi + JSON hoat anh, dung duoc ngay.

Gop ba manh da giai:

    sngxml.py   toa do sprite trong atlas
    sprites.py  pixel — giai ETC1, tach alpha, cat ra PNG
    anim.py     bo xuong, dong tac, keyframe

Mot nhan vat gom ba file cung ten trong assets:

    Cavalry.xml     bo xuong + hoat anh
    Cavalry.plist   toa do sprite trong atlas
    Cavalry.pkm     texture ETC1

Ban VN co 397 nhan vat du ca ba, 21 nhan vat thieu texture.

Cay ket qua:

    <out>/<Ten>/
        sprites/*.png      tung sprite mot file, nen trong suot
        <Ten>.json         bo xuong, dong tac, keyframe, danh sach sprite

JSON dung ten file PNG that (da lam sach ky tu), nen doc JSON ra la nap duoc
anh ngay, khong phai doan ten.

    python export.py --all --out <thu_muc>
    python export.py Cavalry ZhangLiaoGod --out <thu_muc>
    python export.py --list
"""
import os, sys, json, glob, argparse, collections

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from anim import Anim, AnimError
from sprites import Atlas, SpriteError, write_png, safe

DEFAULT_ASSETS = os.path.join('vn', 'decrypted', 'assets')


def index(assets):
    """{ten: (xml, plist, pkm)} — chi nhung nhan vat du ca ba file."""
    def by_name(pattern, check=None):
        out = {}
        for p in glob.glob(os.path.join(assets, '**', pattern), recursive=True):
            if check and not check(p):
                continue
            out[os.path.splitext(os.path.basename(p))[0]] = p
        return out

    xml = by_name('*.xml', lambda p: open(p, 'rb').read(7) == b'sngXml\x00')
    pl = by_name('*.plist')
    tex = by_name('*.pkm')
    out = collections.OrderedDict()
    for n in sorted(xml):
        if n in pl and n in tex:
            out[n] = (xml[n], pl[n], tex[n])
    return out, sorted(set(xml) - set(out))


def export_one(name, paths, outdir):
    xml_p, plist_p, _ = paths
    sub = os.path.join(outdir, name)
    spr_dir = os.path.join(sub, 'sprites')
    os.makedirs(spr_dir, exist_ok=True)

    # --- pixel
    atlas = Atlas(plist_p)
    files = {}
    empty = oob = 0
    for fr in atlas.frames():
        rgba, w, h = atlas.cut(fr)
        if rgba is None:
            # Phan biet ro: muc danh dau kich thuoc 0 (binh thuong, moi nhan
            # vat co mot cai) khac han voi khung nam ngoai bien atlas (bat
            # thuong, dang nghi bo cuc doc sai).
            if atlas.why_skip(fr):
                empty += 1
            else:
                oob += 1
            continue
        fn = safe(fr['name']) + '.png'
        write_png(os.path.join(spr_dir, fn), w, h, rgba)
        files[fr['name']] = collections.OrderedDict([
            ('png', 'sprites/' + fn), ('w', w), ('h', h)])

    # --- bo xuong + hoat anh
    a = Anim(open(xml_p, 'rb').read(), os.path.basename(xml_p))
    doc = a.to_dict()

    # noi ten sprite trong hoat anh voi file PNG that
    def resolve(n):
        for key in (n, n + '.png'):
            if key in files:
                return files[key]
        return None

    doc['spriteFiles'] = collections.OrderedDict(
        (n, resolve(n)) for n in doc['sprites'])
    doc['exported'] = collections.OrderedDict([
        ('pngCount', len(files)), ('placeholders', empty), ('outOfBounds', oob),
        ('spritesMatched', sum(1 for v in doc['spriteFiles'].values() if v)),
    ])

    with open(os.path.join(sub, name + '.json'), 'w', encoding='utf-8') as fp:
        json.dump(doc, fp, ensure_ascii=False, indent=1)

    nanim = sum(len(g['animations']) for g in doc['groups'])
    nkey = sum(len(b['keys']) for g in doc['groups']
               for an in g['animations'] for b in an['bones'])
    return len(files), empty, oob, nanim, nkey, doc['exported']['spritesMatched'], len(doc['sprites'])


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('names', nargs='*', help='ten nhan vat, vd Cavalry')
    ap.add_argument('--assets', default=DEFAULT_ASSETS, help='mac dinh: %(default)s')
    ap.add_argument('--out', help='thu muc ket qua')
    ap.add_argument('--all', action='store_true', help='xuat tat ca')
    ap.add_argument('--list', action='store_true', help='liet ke nhan vat xuat duoc')
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')

    idx, missing = index(a.assets)
    if a.list:
        print('%d nhan vat du ca ba file:' % len(idx))
        for i, n in enumerate(idx):
            print('   %-28s' % n, end='\n' if i % 3 == 2 else '')
        print()
        if missing:
            print('\n%d thieu texture, khong xuat duoc: %s'
                  % (len(missing), ', '.join(missing[:8])))
        return 0

    if not a.out:
        sys.exit('thieu --out')
    todo = list(idx) if a.all else a.names
    if not todo:
        sys.exit('cho ten nhan vat, hoac dung --all / --list')

    tp = te = to = ta = tk = 0
    fail = []
    for i, n in enumerate(todo, 1):
        if n not in idx:
            fail.append((n, 'khong co, hoac thieu file'))
            continue
        try:
            np_, em, ob, na, nk, matched, nspr = export_one(n, idx[n], a.out)
            tp += np_; te += em; to += ob; ta += na; tk += nk
            print('  [%3d/%3d] %-26s %4d PNG, %2d dong tac, %6d keyframe, sprite khop %d/%d'
                  % (i, len(todo), n[:26], np_, na, nk, matched, nspr))
        except (SpriteError, AnimError, OSError) as e:
            fail.append((n, str(e)))
            print('  [%3d/%3d] %-26s LOI: %s' % (i, len(todo), n[:26], e))

    print()
    print('xong: %d nhan vat, %d PNG, %d dong tac, %d keyframe'
          % (len(todo) - len(fail), tp, ta, tk))
    if te:
        print('  muc danh dau kich thuoc 0 (binh thuong): %d' % te)
    if to:
        print('  *** khung ngoai bien atlas (bat thuong): %d ***' % to)
    if fail:
        print('  that bai: %d' % len(fail))
        for n, e in fail[:6]:
            print('     %-24s %s' % (n, e))
    return 0 if not fail else 1


if __name__ == '__main__':
    sys.exit(main())
