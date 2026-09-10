# -*- coding: utf-8 -*-
"""Xuat tron goi mot atlas hoat anh: PNG roi + JSON hoat anh, dung duoc ngay.

Gop ba manh da giai:

    sngxml.py   toa do sprite trong atlas
    sprites.py  pixel — giai ETC1, tach alpha, cat ra PNG
    anim.py     bo xuong, dong tac, keyframe

Mot atlas hoat anh gom ba file cung ten trong assets:

    Cavalry.xml     bo xuong + hoat anh
    Cavalry.plist   toa do sprite trong atlas
    Cavalry.pkm     texture ETC1

Ban VN co 397 atlas du ca ba file. KHONG phai 397 "nhan vat": trong so do co
97 atlas UI* + 8 XS* (hieu ung) + 3 Button/Cartoon, con lai ~289 moi la nhan
vat / quan chung / trang phuc.

21 atlas nua co .xml + .plist nhung khong xuat duoc. Kiem lai bang cach doc ten
texture tu header cua plist: ca 21 deu tro toi <ten>.png — mot file KHONG ton
tai trong ca ban CN lan ban VN, tuc texture khong duoc dong goi trong build.
Day khong phai loi tim duong dan. Va khong co nhan vat nao trong so 21 nay:
16 la UI*/XS*, 3 la *Multi (atlas gop), con ZhaoYunWake / ZhaoYunExclusWake la
lop chu phu de canh thuc tinh (cac khung ten _vi/_en/_kr/_zh_Hant).
=> Moi nhan vat choi duoc deu xuat duoc; khong thieu nhan vat nao.

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

DEFAULT_ASSETS = os.path.join(HERE, 'vn', 'decrypted', 'assets')


def index(assets):
    """{ten: (xml, plist, pkm)} — chi nhung atlas du ca ba file."""
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


def _entry(fr, png, w, h):
    """Mot muc spriteFiles.

    offX/offY la DO LECH XEN VIEN: atlas cat bo vien trong suot de tiet kiem
    cho, nen tam cua anh da cat khong con trung tam cua khung goc. Thieu so
    nay thi rap xuong lai se lech tung manh. srcW/srcH la kich thuoc khung
    truoc khi cat."""
    ox, oy = fr.get('offsetXY', [0.0, 0.0])
    sw, sh = fr.get('sourceWH', [w, h])
    return collections.OrderedDict([
        ('png', png), ('w', w), ('h', h),
        ('offX', round(ox, 4)), ('offY', round(oy, 4)),
        ('srcW', round(sw, 4)), ('srcH', round(sh, 4)),
    ])


def _rewrite_json(name, xml_p, plist_p, sub):
    """Dung lai <Ten>.json tu .xml + .plist, giu nguyen PNG cua lan xuat truoc."""
    jp = os.path.join(sub, name + '.json')
    if not os.path.isfile(jp):
        raise OSError('chua xuat lan nao, khong dung duoc --json-only')
    with open(jp, encoding='utf-8') as fp:
        prev = json.load(fp)

    doc = Anim(open(xml_p, 'rb').read(), os.path.basename(xml_p)).to_dict()
    # Duong dan PNG lay lai tu lan xuat truoc; do lech xen vien doc tuoi tu
    # .plist — buoc nay khong dung toi pixel nen khong phai giai lai ETC1.
    geo = {}
    for fr in Atlas(plist_p).frames():
        geo[fr['name']] = fr
    merged = collections.OrderedDict()
    for n in doc['sprites']:
        old_e = prev['spriteFiles'].get(n)
        if old_e is None:
            merged[n] = None
            continue
        fr = geo.get(n) or geo.get(n + '.png') or {}
        merged[n] = _entry(fr, old_e['png'], old_e['w'], old_e['h'])
    doc['spriteFiles'] = merged
    doc['exported'] = prev['exported']

    with open(jp, 'w', encoding='utf-8') as fp:
        json.dump(doc, fp, ensure_ascii=False, indent=1)

    nanim = sum(len(g['animations']) for g in doc['groups'])
    nkey = sum(len(b['keys']) for g in doc['groups']
               for an in g['animations'] for b in an['bones'])
    e = doc['exported']
    return (e['pngCount'], e['placeholders'], e['outOfBounds'], nanim, nkey,
            sum(1 for v in doc['spriteFiles'].values() if v), len(doc['sprites']))


def export_one(name, paths, outdir, json_only=False):
    xml_p, plist_p, _ = paths
    sub = os.path.join(outdir, name)
    spr_dir = os.path.join(sub, 'sprites')
    os.makedirs(spr_dir, exist_ok=True)

    if json_only:
        # Chi dung lai bo xuong tu .xml, giu nguyen PNG da cat va khoi
        # spriteFiles/exported cua lan xuat truoc. Dung khi anim.py giai
        # them duoc truong moi ma pixel khong doi — khoi cat lai 12820 PNG.
        return _rewrite_json(name, xml_p, plist_p, sub)

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
        files[fr['name']] = _entry(fr, 'sprites/' + fn, w, h)

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
    ap.add_argument('--list', action='store_true', help='liet ke atlas xuat duoc')
    ap.add_argument('--json-only', action='store_true',
                    help='chi dung lai JSON tu .xml, giu nguyen PNG da cat')
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')

    # Thu muc sai thi index() tra ve rong, --all thanh danh sach rong, va
    # truoc day script bao "cho ten nhan vat" — nghe nhu goi sai cu phap
    # trong khi that ra la tro sai cho. Da ton mot buoi vi cau do.
    if not os.path.isdir(a.assets):
        sys.exit('khong thay thu muc tai nguyen %s — dung --assets <...>/vn/decrypted/assets'
                 % a.assets)
    idx, missing = index(a.assets)
    if a.list:
        print('%d atlas du ca ba file (.xml + .plist + .pkm):' % len(idx))
        for i, n in enumerate(idx):
            print('   %-28s' % n, end='\n' if i % 3 == 2 else '')
        print()
        if missing:
            print('\n%d atlas co .xml + .plist nhung texture khong duoc dong goi'
                  ' trong build (plist tro toi <ten>.png, file do khong ton tai'
                  ' o ca hai ban) — khong co nhan vat nao trong so nay:' % len(missing))
            for i, n in enumerate(missing):
                print('   %-28s' % n, end='\n' if i % 3 == 2 else '')
            print()
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
            np_, em, ob, na, nk, matched, nspr = export_one(n, idx[n], a.out, a.json_only)
            tp += np_; te += em; to += ob; ta += na; tk += nk
            print('  [%3d/%3d] %-26s %4d PNG, %2d dong tac, %6d keyframe, sprite khop %d/%d'
                  % (i, len(todo), n[:26], np_, na, nk, matched, nspr))
        except (SpriteError, AnimError, OSError) as e:
            fail.append((n, str(e)))
            print('  [%3d/%3d] %-26s LOI: %s' % (i, len(todo), n[:26], e))

    print()
    print('xong: %d atlas, %d PNG, %d dong tac, %d keyframe'
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
