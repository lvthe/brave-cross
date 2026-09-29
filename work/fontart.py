# -*- coding: utf-8 -*-
"""Xuat bo phong bitmap cua ban goc (`assets/fonts`) ra .fnt + PNG dung ngay.

Game dung BMFont: moi phong la mot cap

    <Ten>.fnt    chi so glyph (van ban, khong phai nhi phan)
    <trang>.png  anh glyph — tren dia la `.pkm` ETC1

Tep `.fnt` chep NGUYEN VAN: no tro toi trang bang TEN, nen trang phai duoc ghi
ra DUNG cai ten ma `.fnt` ghi, chu khong phai ten ta thich. `ReduceBloodFont.fnt`
tro toi `ReduceBloodFont.png`, con `RedBackgroundWriteBorder.fnt` cung tro toi
CHINH tep do — nen hai `.fnt` dung chung mot trang.

KHO DO 2026-09-21 (ban VN 1.26, `work/vn/decrypted/assets/fonts/`):

    11 tep .fnt   ·   15 tep .pkm   ·   2 tep .ttf
    10 trang duoc .fnt tro toi; 5 .pkm con lai KHONG .fnt nao tro toi:
        RedBackgroundWriteBorder.pkm   BAN SAO y nguyen cua ReduceBloodFont.pkm
                                       (md5 cee13dd7c268 ca hai) — chi la cai
                                       ten thu hai cho cung mot phong
        ATP · DecorateCure · DecorateDanger · LeadershipNum
                                       anh roi, khong phai phong: khong co .fnt

Phong chia lam HAI HO theo BO GLYPH, do thang tu `.fnt`:

    HO SO (chi chu so) — day moi la ho cua nhan sat thuong:
        ImpactWhite.fnt    10 glyph   '0123456789'
        ImpactRed.fnt      11 glyph   '-0123456789'
        ShieldWhite.fnt    11 glyph   '-0123456789'
        CriticalFont.fnt   12 glyph   '!-0123456789'
        ImpactBlue.fnt     13 glyph   '!+-0123456789'
        ImpactGreen.fnt    13 glyph   '!+-0123456789'
        ImpactYellow.fnt   13 glyph   '!+-0123456789'

    HO CHU (ca bang ma ASCII 0x20..0x7E, 95 glyph) — KHONG phai nhan sat thuong:
        ReduceBloodFont.fnt / RedBackgroundWriteBorder.fnt   (hai tep y nguyen)
        GreenBackgroudWriteBorder.fnt
        npc_name.fnt        3 glyph   ' ', U+7CBE, U+82F1  = 精英 (nhãn "tinh anh")

Bo glyph la thu PHAN BIET duoc hai ho ma khong phai doan: mot nhan sat thuong
chi can chu so, dau tru, dau cong va dau cham than.

TEN TRANG KHONG DUOC DOAN THEO TEN PHONG. `ReduceBloodFont.fnt` tro toi
`ReduceBloodFont.png` chu khong phai `ReduceBloodFont_0.png`; nguoc lai nam
phong `Impact*` lai tro toi `Impact*_0.png`. Phai doc truong `page` trong `.fnt`.

    python fontart.py --list
    python fontart.py --out <thu_muc>
    python fontart.py --out <thu_muc> ImpactRed ShieldWhite
"""
import os, sys, re, glob, shutil, argparse, collections

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import cay                                        # noqa: E402
from sprites import read_pkm, write_png, SpriteError   # noqa: E402

#: Thu muc phong trong cay tai nguyen.
FONTS = 'fonts'


def doc_fnt(path):
    """(cac trang, cac glyph) cua mot tep .fnt — BMFont dang VAN BAN.

    Tra ve hai danh sach: `page id=N file="..."` va `char id=N`.

    Dang NHI PHAN (chu ky 'BMF') khong duoc ho tro: do ca 11 tep cua ban VN,
    KHONG tep nao o dang do. Gap thi bao thang chu khong doc bua ra so.
    """
    d = open(path, 'rb').read()
    if d[:3] == b'BMF':
        raise SpriteError('BMFont dang NHI PHAN — ban VN khong co tep nao o dang nay')
    s = d.decode('latin-1')
    trang = []
    for m in re.finditer(r'^page\s+id=(\d+)\s+file="([^"]+)"', s, re.M):
        trang.append((int(m.group(1)), m.group(2)))
    glyph = [int(m.group(1)) for m in re.finditer(r'^char\s+id=(\d+)', s, re.M)]
    if not trang:
        raise SpriteError('khong doc duoc dong `page` nao')
    return trang, glyph


def _ma_hoa(ids):
    """Doan ma cua cac glyph dang chuoi, de in va de nhan ra ho chu / ho so."""
    if not ids:
        return ''
    return ''.join(chr(c) for c in sorted(ids) if 32 <= c < 127)


def liet_ke(assets):
    """[{ten, fnt, trang, glyph, chu, so}] cua moi phong, sap theo ten."""
    d = os.path.join(assets, FONTS)
    out = []
    for p in sorted(glob.glob(os.path.join(d, '*.fnt'))):
        ten = os.path.splitext(os.path.basename(p))[0]
        trang, glyph = doc_fnt(p)          # nem loi neu khong phai van ban
        out.append(collections.OrderedDict([
            ('ten', ten), ('fnt', p), ('trang', [t for _, t in trang]),
            ('glyph', sorted(glyph)), ('chu', _ma_hoa(glyph)),
            ('so', os.path.getsize(p)), ('nGlyph', len(set(glyph))),
        ]))
    return out


def xuat_mot(f, outdir, assets):
    """Ghi `.fnt` + trang cua no. Tra ve (so trang ghi, so trang thieu, ghi chu).

    Trang duoc giai tu `.pkm` cung ten (bo duoi). Cung dinh dang ETC1 'nua tren
    mau / nua duoi alpha' nhu atlas — xem `sprites.read_pkm`.
    """
    n = 0
    thieu = []
    ghi_chu = []
    shutil.copyfile(f['fnt'], os.path.join(outdir, f['ten'] + '.fnt'))
    for t in f['trang']:
        stem = os.path.splitext(t)[0]
        pkm = os.path.join(assets, FONTS, stem + '.pkm')
        if not os.path.isfile(pkm):
            thieu.append(t)
            continue
        rgb, ew, eh, ow, oh = read_pkm(pkm)
        if oh % 2:
            raise SpriteError('%s: chieu cao le (%d) — khong phai nua mau / nua alpha'
                              % (stem, oh))
        h = oh // 2
        rgba = bytearray(ow * h * 4)
        for y in range(h):
            s, a, d = y * ew * 3, (y + h) * ew * 3, y * ow * 4
            for x in range(ow):
                rgba[d + x * 4] = rgb[s + x * 3]
                rgba[d + x * 4 + 1] = rgb[s + x * 3 + 1]
                rgba[d + x * 4 + 2] = rgb[s + x * 3 + 2]
                rgba[d + x * 4 + 3] = rgb[a + x * 3]
        write_png(os.path.join(outdir, t), ow, h, rgba)
        n += 1
        ghi_chu.append('%s %dx%d' % (t, ow, h))
    return n, thieu, ghi_chu


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('names', nargs='*', help='ten phong, vd ImpactRed; bo trong = tat ca')
    ap.add_argument('--assets', default=cay.ASSETS)
    ap.add_argument('--out', help='thu muc ket qua (mac dinh: assets_ref/fonts)')
    ap.add_argument('--list', action='store_true')
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')

    d = os.path.join(a.assets, FONTS)
    if not os.path.isdir(d):
        sys.exit('khong thay thu muc phong %s; dung --assets <...>/<ban>/decrypted/assets' % d)

    try:
        ds = liet_ke(a.assets)
    except SpriteError as e:
        sys.exit('khong doc duoc bo phong: %s' % e)

    if a.list:
        print('%d phong trong %s' % (len(ds), d))
        print('  %-28s %5s %-52s %s' % ('ten', 'glyph', 'ma', 'trang'))
        for f in ds:
            print('  %-28s %5d %-52s %s'
                  % (f['ten'], f['nGlyph'], repr(f['chu'])[:50], ', '.join(f['trang'])))
        return 0

    outdir = a.out or os.path.join(cay.dich_anh('assets_ref'), FONTS)
    os.makedirs(outdir, exist_ok=True)
    loi = cay.giu_cho(outdir)
    if loi:
        sys.exit(loi)
    cay.danh_dau(outdir)

    todo = [f for f in ds if not a.names or f['ten'] in a.names]
    if not todo:
        sys.exit('khong phong nao khop: %s' % ' '.join(a.names))

    n_trang = n_thieu = 0
    for f in todo:
        try:
            n, thieu, ghi_chu = xuat_mot(f, outdir, a.assets)
        except SpriteError as e:
            print('  %-28s LOI: %s' % (f['ten'], e))
            continue
        n_trang += n
        n_thieu += len(thieu)
        print('  %-28s %2d glyph, %d trang  %s'
              % (f['ten'], f['nGlyph'], n, '; '.join(ghi_chu)))
        for t in thieu:
            print('     THIEU trang %s (%s.pkm khong co tren dia)' % (t, os.path.splitext(t)[0]))

    # Cac .pkm khong .fnt nao tro toi: in ra de nguoi doc biet chung KHONG bi bo quen.
    tro = set()
    for f in ds:
        tro.update(os.path.splitext(t)[0] for t in f['trang'])
    la = sorted(os.path.splitext(os.path.basename(p))[0]
                for p in glob.glob(os.path.join(a.assets, FONTS, '*.pkm')))
    mo_coi = [x for x in la if x not in tro]
    print()
    print('xong: %d phong, %d trang, thieu %d' % (len(todo), n_trang, n_thieu))
    if mo_coi:
        print('  %d .pkm khong .fnt nao tro toi (KHONG phai loi): %s'
              % (len(mo_coi), ', '.join(mo_coi)))
        print('    — anh roi (DecorateCure/DecorateDanger/ATP/LeadershipNum) va')
        print('      ban sao cua ReduceBloodFont (RedBackgroundWriteBorder).')
    return 0 if not n_thieu else 1


if __name__ == '__main__':
    sys.exit(main())
