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

21 armature nua co .xml + .plist nhung KHONG co .pkm: texture cua chung khong
duoc dong goi thanh atlas, ma tung sprite nam roi trong `sngSplitData/`, ten
tep DUNG BANG TEN KHUNG trong `.plist` (chi bo duoi `.png`). Khong nhan vat nao
choi duoc nam trong so 21 nay — toan UI*/XS* cong 3 *Multi (atlas gop) va
ZhaoYunWake / ZhaoYunExclusWake (lop chu phu de canh thuc tinh).

Do 2026-09-21 tren CA 21 armature / 636 khung: 417 khung co anh roi; 219 khung
con lai la cac ban dich `_en` / `_kr` / `_zh_Hant` khong duoc dong goi (ban VN
ship ban `_vi`), tuc KHONG phai loi tim duong dan. Tra theo TIEN TO ten armature
thi khop 0/636 — `PlayerMulti` dung ten `Player000_Eff-*` va `UIJianZhuWuJieSuo`
dung `XSJieSuoJianZhu_res-*`, nen doan tien to la sai hoan toan; tra thang theo
ten khung moi dung.

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

import cay
from anim import Anim, AnimError
from sngxml import load as load_plist
from sprites import Atlas, SpriteError, write_png, safe, read_sprite_pkm

#: Theo BAN dang lam (BC_TREE). Tro cung vao mot ban thi ban kia khong bao gio
#: duoc xuat, va khong mot dong nao noi len — xem layout.py, da mac mot lan.
DEFAULT_ASSETS = cay.ASSETS

#: Thu muc anh ROI. Armature khong dong goi atlas thi tung sprite cua no nam o
#: day, ten tep DUNG BANG TEN KHUNG trong `.plist` (chi bo duoi `.png`).
SPLIT = 'sngSplitData'


def index(assets):
    """(atlas du ba file, atlas thieu texture, armature anh roi).

    Phan ba la 21 armature co .xml + .plist ma khong co .pkm — xem docstring
    dau file. Chung di bang `split_index` chu khong bang atlas.
    """
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
    roi = collections.OrderedDict()
    for n in sorted(xml):
        if n in pl and n in tex:
            out[n] = (xml[n], pl[n], tex[n])
        elif n in pl:
            roi[n] = (xml[n], pl[n], None)
    return out, sorted(set(xml) - set(out) - set(roi)), roi


def split_index(assets):
    """{ten khung: duong dan .pkm} cua thu muc anh roi; {} khi khong co.

    KHONG ghep tien to ten armature: do tren 21 armature thieu atlas, ten khung
    cua chung khong phai luc nao cung bat dau bang ten armature — `PlayerMulti`
    dung `Player000_Eff-*`, `UIJianZhuWuJieSuo` dung `XSJieSuoJianZhu_res-*`.
    Doan tien to khop 0/636 khung; tra thang theo ten khung khop 417/636.
    """
    d = os.path.join(assets, SPLIT)
    if not os.path.isdir(d):
        return {}
    out = {}
    for f in os.listdir(d):
        if f.endswith('.pkm'):
            out[f[:-4]] = os.path.join(d, f)
    return out


def _ten_khung(n):
    """Ten khung trong `.plist` -> ten tep anh roi (`Cavalry_res-X.png` -> ...)."""
    return n[:-4] if n.lower().endswith('.png') else n


def _nguon_khung(geo, ten_sprite):
    """{ten sprite: [srcW, srcH]} cho MOI sprite, ke ca sprite khong cat duoc PNG.

    `spriteFiles[ten] = None` nghia la "sprite nay khong co anh" (o 0x0 trong
    atlas nen buoc cat bo qua), nhung O CUA NO van nam trong `.plist`, va
    `_lua_getBoneRectInNode` can o ay: hop cua mot xuong = o cua ANH xuong dang
    ve. Do tren `YuJin_res-44` — `spriteFiles` la `None` trong khi `sourceSize`
    la 1x1, nen thieu ban do nay thi hop xuong `Collision` ra (0, 0) chu khong
    phai 140,00547790527 x 179,98643493652 ma may ao do duoc (cung the voi
    `BatFlight` 145,00999450684 x 120, `ZhangLiangBao` 175 x 227,5).

    Ten nao khong co ban ghi trong `.plist` thi KHONG co trong ban do (khong bia
    so 0) — nguoi doc thay vang mat thi biet la khong tra duoc.
    """
    out = collections.OrderedDict()
    for n in ten_sprite:
        fr = geo.get(n) or geo.get(n + '.png')
        if fr is None:
            continue
        sw, sh = fr.get('sourceSize', [0.0, 0.0])
        out[n] = [round(sw, 4), round(sh, 4)]
    return out


def _lam_sach_json(node, dem):
    """Ban sao cua `node` voi moi so KHONG HUU HAN thay bang `0.0`, dem vao `dem`.

    `json.dump` cua Python ghi thang `NaN`/`Infinity` — khong phai JSON hop le,
    va `JSON.parse_string` cua Godot TU CHOI CA FILE. Do duoc: bo kiem `rig nhan
    vat` do ra 1 hong, `ERROR: Parse JSON failed. Error at line 517: Expected
    'true', 'false', or 'null', got 'NaN'`, tuc rig `XSJiYouHeTiJi` khong dung
    duoc — va no la file DUY NHAT trong 397 (quet ca cay: dung 2 lan `NaN`).

    Cho rac ay DA BIET va CHUA GIAI, khong phai loi giai ma moi: `anim.py` ghi
    "13 cho lech deu o BingYing.xml va XSJiYouHeTiJi.xml — hai file do bo cuc
    khung khac". Hai khoa cuoi cua hai xuong o file nay doc ra `d` = 0xC4800000
    (=-1024,0 neu doc theo float) va `dur` = 0x3F800000 (= 1,0) — tuc vung
    float32 chu khong phai ban ghi khung. Vi vay KHONG bia gia tri khac: ghi
    `0.0` va dem lai, de con so hien ra o dong tong ket chu khong im lang.
    """
    if isinstance(node, float):
        if node != node or node in (float('inf'), float('-inf')):
            dem[0] += 1
            return 0.0
        return node
    if isinstance(node, dict):
        return collections.OrderedDict(
            (k, _lam_sach_json(v, dem)) for k, v in node.items())
    if isinstance(node, list):
        return [_lam_sach_json(v, dem) for v in node]
    return node


def _ghi_json(path, doc):
    """Ghi JSON da lam sach so khong huu han. Tra ve so cho da thay.

    `allow_nan=False` de lan sau con cho nao lot luoi thi `json.dump` nem loi
    NGAY, chu khong ghi ra mot file hong roi de nguoi doc phia Godot phat hien.
    """
    dem = [0]
    with open(path, 'w', encoding='utf-8') as fp:
        json.dump(_lam_sach_json(doc, dem), fp, ensure_ascii=False, indent=1,
                  allow_nan=False)
    return dem[0]


def _entry(fr, png, w, h):
    """Mot muc spriteFiles.

    offX/offY la DO LECH XEN VIEN: atlas cat bo vien trong suot de tiet kiem
    cho, nen tam cua anh da cat khong con trung tam cua khung goc. Thieu so
    nay thi rap xuong lai se lech tung manh.

    srcW/srcH la khung TRUOC KHI CAT (`sourceSize` cua ban ghi `.plist`), tuc o
    cua sprite theo dung nghia engine dung (`CCSpriteFrame::getOriginalSize`).
    Truoc day cho nay lay `sourceWH` — ma `sourceWH` lai la cap f9,f10, do ra
    thi LAP LAI y het `w/h` (13.634/13.634 khung), nen truong nay khong he mang
    khung truoc khi cat. Xem `khung_nguon.py`."""
    ox, oy = fr.get('offsetXY', [0.0, 0.0])
    sw, sh = fr.get('sourceSize', [w, h])
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
    # Doc thang `.plist`, KHONG dung `Atlas`: buoc nay khong dung toi pixel, ma
    # `Atlas` doi phai co texture — armature anh roi khong co .pkm nen se nem
    # loi ngay tai day.
    geo = {}
    for fr in load_plist(plist_p).frames():
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
    doc['sourceSize'] = _nguon_khung(geo, doc['sprites'])
    doc['exported'] = prev['exported']

    nrac = _ghi_json(jp, doc)

    nanim = sum(len(g['animations']) for g in doc['groups'])
    nkey = sum(len(b['keys']) for g in doc['groups']
               for an in g['animations'] for b in an['bones'])
    e = doc['exported']
    return (e['pngCount'], e['placeholders'], e['outOfBounds'], nanim, nkey,
            sum(1 for v in doc['spriteFiles'].values() if v), len(doc['sprites']),
            nrac, int(e.get('splitMissing', 0)))


def export_one(name, paths, outdir, json_only=False, split=None):
    xml_p, plist_p, tex_p = paths
    sub = os.path.join(outdir, name)
    spr_dir = os.path.join(sub, 'sprites')
    os.makedirs(spr_dir, exist_ok=True)

    if json_only:
        # Chi dung lai bo xuong tu .xml, giu nguyen PNG da cat va khoi
        # spriteFiles/exported cua lan xuat truoc. Dung khi anim.py giai
        # them duoc truong moi ma pixel khong doi — khoi cat lai 12820 PNG.
        return _rewrite_json(name, xml_p, plist_p, sub)

    # --- pixel
    # `tex_p` co the la None: armature anh roi (xem docstring dau file). Khi ay
    # khung nao khong co tep trong `sngSplitData` thi dem rieng, chu khong lan
    # vao "khung ngoai bien atlas" — hai benh khac han nhau.
    atlas = Atlas(plist_p) if tex_p else None
    fr_list = atlas.frames() if atlas else load_plist(plist_p).frames()
    geo = collections.OrderedDict((fr['name'], fr) for fr in fr_list)
    files = {}
    empty = oob = thieu = 0
    for fr in geo.values():
        # Kiem muc danh dau TRUOC khi doc pixel, cho CA HAI duong: khung o 0x0
        # (`<Ten>_res-44`) la muc danh dau, ban goc khong ve no. Voi armature
        # anh roi thi tep VAN ton tai (anh that, 4x4), nen doc theo duong atlas
        # se am tham ve them mot hinh ma ban goc khong co.
        if Atlas.why_skip(fr):
            empty += 1
            continue
        if atlas:
            rgba, w, h = atlas.cut(fr)
        else:
            p = split.get(_ten_khung(fr['name'])) if split else None
            rgba, w, h = read_sprite_pkm(p) if p else (None, 0, 0)
        if rgba is None:
            # Hai nguyen nhan con lai: khung nam ngoai bien atlas (bat thuong,
            # dang nghi bo cuc doc sai) va thieu tep anh roi (thuong la ban dich
            # `_en`/`_kr`/`_zh_Hant` khong duoc dong goi).
            if atlas:
                oob += 1
            else:
                thieu += 1
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
    doc['sourceSize'] = _nguon_khung(geo, doc['sprites'])
    doc['exported'] = collections.OrderedDict([
        ('pngCount', len(files)), ('placeholders', empty), ('outOfBounds', oob),
        ('splitMissing', thieu),
        ('spritesMatched', sum(1 for v in doc['spriteFiles'].values() if v)),
    ])

    nrac = _ghi_json(os.path.join(sub, name + '.json'), doc)

    nanim = sum(len(g['animations']) for g in doc['groups'])
    nkey = sum(len(b['keys']) for g in doc['groups']
               for an in g['animations'] for b in an['bones'])
    return (len(files), empty, oob, nanim, nkey,
            doc['exported']['spritesMatched'], len(doc['sprites']), nrac, thieu)


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
        sys.exit('khong thay thu muc tai nguyen %s; dung --assets <...>/<ban>/decrypted/assets'
                 % a.assets)
    idx, missing, roi = index(a.assets)
    if a.list:
        print('%d atlas du ca ba file (.xml + .plist + .pkm):' % len(idx))
        for i, n in enumerate(idx):
            print('   %-28s' % n, end='\n' if i % 3 == 2 else '')
        print()
        if roi:
            print('\n%d armature anh ROI (.xml + .plist, khong co .pkm): tung'
                  ' sprite nam rieng trong %s/ — xuat duoc:' % (len(roi), SPLIT))
            for i, n in enumerate(roi):
                print('   %-28s' % n, end='\n' if i % 3 == 2 else '')
            print()
        if missing:
            print('\n%d muc co .xml nhung khong co .plist, hoac plist tro toi'
                  ' <ten>.png khong duoc dong goi o ca hai ban — khong co nhan'
                  ' vat nao trong so nay:' % len(missing))
            for i, n in enumerate(missing):
                print('   %-28s' % n, end='\n' if i % 3 == 2 else '')
            print()
        return 0

    if not a.out:
        sys.exit('thieu --out')
    # Chan truoc khi cat 12820 PNG: thu muc nay thuoc mot BAN cu the. Ban 1.31 co
    # 433 atlas, ban VN co 397 — ghi cung cho thi khong loi nao nem ra, chi co
    # hai bo anh lan vao nhau. Xem `cay.giu_cho`.
    os.makedirs(a.out, exist_ok=True)
    loi = cay.giu_cho(a.out)
    if loi:
        sys.exit(loi)
    cay.danh_dau(a.out)
    split = split_index(a.assets)
    todo = (list(idx) + list(roi)) if a.all else a.names
    if not todo:
        sys.exit('cho ten nhan vat, hoac dung --all / --list')

    tp = te = to = ta = tk = tr = ts = 0
    fail = []
    for i, n in enumerate(todo, 1):
        p = idx.get(n) or roi.get(n)
        if p is None:
            fail.append((n, 'khong co, hoac thieu file'))
            continue
        try:
            np_, em, ob, na, nk, matched, nspr, nrac, nthieu = export_one(
                    n, p, a.out, a.json_only, split)
            tp += np_; te += em; to += ob; ta += na; tk += nk; tr += nrac; ts += nthieu
            print('  [%3d/%3d] %-26s %4d PNG, %2d dong tac, %6d keyframe, sprite khop %d/%d%s'
                  % (i, len(todo), n[:26], np_, na, nk, matched, nspr,
                     (', thieu anh roi %d' % nthieu) if nthieu else ''))
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
    if ts:
        print('  khung thieu anh roi trong %s/ (ban dich _en/_kr/_zh_Hant'
              ' khong duoc dong goi): %d' % (SPLIT, ts))
    if tr:
        print('  so khong huu han (NaN/Inf) da thay bang 0.0: %d — JSON khong hop le'
              ' voi Godot, xem _lam_sach_json' % tr)
    if fail:
        print('  that bai: %d' % len(fail))
        for n, e in fail[:6]:
            print('     %-24s %s' % (n, e))
    return 0 if not fail else 1


if __name__ == '__main__':
    sys.exit(main())
