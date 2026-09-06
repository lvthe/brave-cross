# -*- coding: utf-8 -*-
"""Cat sprite tu atlas cua game ra file PNG rieng le.

Mieng cuoi cua chuoi: sngxml.py cho toa do sprite trong atlas, anim.py cho
hoat anh, con file nay cho PIXEL.

TEXTURE. Game luu anh dang .pkm — ETC1, dinh dang nen cua GPU di dong. ETC1
KHONG co kenh alpha, nen game dung thu thuat kinh dien: anh cao gap doi vung
sprite, NUA TREN la mau RGB, NUA DUOI la alpha dang xam.

    do tren 397 cap plist+texture: ty le chieu cao / vung sprite = 2.00,
    dung 397/397 file, khong mot ngoai le

TOA DO SPRITE. Xac dinh bang cach lay kich thuoc texture lam chuan, thu tung
cap truong xem cap nao cho ra sprite nam gon trong anh:

    +0x08, +0x0c   vi tri trong atlas (x, y)
    +0x10, +0x14   kich thuoc (w, h)
    +0x20          co xoay — TexturePacker xoay sprite 90 do de xep chat hon,
                   luc do o trong atlas chieu rong va cao bi hoan doi

    khong xet xoay : 12613/12998 khung nam gon  (97.04%)
    co xet xoay    : 12996/12998 khung nam gon  (99.98%)

Khong dung thu vien ngoai: bo giai ETC1 va bo ghi PNG deu viet thang o day,
giu dung kieu cua repo (chi lupa cho test la phu thuoc duy nhat).

    python sprites.py <file.plist>                 # xem thong tin
    python sprites.py <file.plist> --out <thu_muc> # cat ra PNG
    python sprites.py --scan <thu_muc>             # kiem tra cap plist/texture
"""
import os, sys, zlib, glob, struct, argparse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sngxml import load as load_plist, SngXml, SngXmlError

PKM_MAGIC = b'PKM 10'

# Bang bo chinh cua ETC1: [codeword][chi so] -> luong cong vao mau nen.
ETC1_MODIFIER = (
    (2, 8, -2, -8), (5, 17, -5, -17), (9, 29, -9, -29), (13, 42, -13, -42),
    (18, 60, -18, -60), (24, 80, -24, -80), (33, 106, -33, -106),
    (47, 183, -47, -183),
)


class SpriteError(Exception):
    pass


# ----------------------------------------------------------------- ETC1
def _clamp(v):
    return 0 if v < 0 else (255 if v > 255 else v)


def _c31(v):
    return 0 if v < 0 else (31 if v > 31 else v)


def decode_etc1(data, width, height):
    """Giai ETC1 thanh bytearray RGB (3 byte moi diem).

    Moi khoi 8 byte ma hoa mot o 4x4. Hai che do: 'individual' dung hai mau
    nen 4 bit rieng, 'differential' dung mot mau nen 5 bit cong mot hieu 3 bit
    co dau. flipbit quyet dinh chia o theo chieu doc hay ngang.
    """
    out = bytearray(width * height * 3)
    bw, bh = width // 4, height // 4
    pos = 0
    for by in range(bh):
        for bx in range(bw):
            hi, lo = struct.unpack_from('>II', data, pos)
            pos += 8
            diff = (hi >> 1) & 1
            flip = hi & 1
            cw1, cw2 = (hi >> 5) & 7, (hi >> 2) & 7

            if diff:
                # mau nen 5 bit + hieu 3 bit co dau; mo rong 5->8 bit bang
                # cach lap lai 3 bit cao, dung chuan ETC1
                def s3(v):
                    return v - 8 if v > 3 else v

                r1, g1, b1 = (hi >> 27) & 0x1F, (hi >> 19) & 0x1F, (hi >> 11) & 0x1F
                r2 = _c31(r1 + s3((hi >> 24) & 7))
                g2 = _c31(g1 + s3((hi >> 16) & 7))
                b2 = _c31(b1 + s3((hi >> 8) & 7))
                e = lambda v: (v << 3) | (v >> 2)
                c1 = (e(r1), e(g1), e(b1))
                c2 = (e(r2), e(g2), e(b2))
            else:
                # hai mau nen 4 bit rieng; mo rong 4->8 bit bang nhan 17
                e = lambda v: v * 17
                c1 = (e((hi >> 28) & 0xF), e((hi >> 20) & 0xF), e((hi >> 12) & 0xF))
                c2 = (e((hi >> 24) & 0xF), e((hi >> 16) & 0xF), e((hi >> 8) & 0xF))

            m1, m2 = ETC1_MODIFIER[cw1], ETC1_MODIFIER[cw2]
            for i in range(16):
                px, py = i >> 2, i & 3
                if flip:
                    sub2 = py >= 2
                else:
                    sub2 = px >= 2
                base, mod = (c2, m2) if sub2 else (c1, m1)
                idx = ((lo >> (15 + i)) & 2) | ((lo >> i) & 1)
                d = mod[idx]
                x, y = bx * 4 + px, by * 4 + py
                o = (y * width + x) * 3
                out[o] = _clamp(base[0] + d)
                out[o + 1] = _clamp(base[1] + d)
                out[o + 2] = _clamp(base[2] + d)
    return out


def read_pkm(path):
    """(rgb, width, height) tu mot file .pkm."""
    d = open(path, 'rb').read()
    if len(d) < 16 or d[:6] != PKM_MAGIC:
        raise SpriteError('khong phai PKM 10')
    fmt, ew, eh, ow, oh = struct.unpack('>5H', d[6:16])
    if fmt != 0:
        raise SpriteError('fmt=%d, chi ho tro 0 (ETC1_RGB8)' % fmt)
    need = 16 + (ew // 4) * (eh // 4) * 8
    if len(d) < need:
        raise SpriteError('thieu du lieu: can %d co %d' % (need, len(d)))
    return decode_etc1(d[16:], ew, eh), ew, eh, ow, oh


# ------------------------------------------------------------------ PNG
def write_png(path, w, h, rgba):
    """Ghi PNG RGBA 8 bit, khong dung thu vien ngoai."""
    raw = bytearray()
    stride = w * 4
    for y in range(h):
        raw.append(0)                      # bo loc None cho tung dong
        raw += rgba[y * stride:(y + 1) * stride]

    def chunk(tag, payload):
        c = struct.pack('>I', len(payload)) + tag + payload
        return c + struct.pack('>I', zlib.crc32(tag + payload) & 0xFFFFFFFF)

    png = (b'\x89PNG\r\n\x1a\n'
           + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
           + chunk(b'IDAT', zlib.compress(bytes(raw), 6))
           + chunk(b'IEND', b''))
    with open(path, 'wb') as fp:
        fp.write(png)


# --------------------------------------------------------------- cat sprite
class Atlas(object):
    """Mot cap plist + texture."""

    def __init__(self, plist_path):
        self.plist_path = plist_path
        self.x = load_plist(plist_path)
        if not isinstance(self.x, SngXml):
            raise SpriteError('day la ban .xml, khong phai atlas .plist')
        base = os.path.splitext(plist_path)[0]
        self.tex_path = None
        for ext in ('.pkm', '.png'):
            q = base + ext
            if os.path.exists(q) and open(q, 'rb').read(6) == PKM_MAGIC:
                self.tex_path = q
                break
        if not self.tex_path:
            raise SpriteError('khong thay texture .pkm di kem')
        # Chi doc header o day. Giai nen ETC1 la viec nang (thuan Python) nen
        # de den luc that su can pixel — --scan khong bao gio can.
        hd = open(self.tex_path, 'rb').read(16)
        fmt, self.ew, self.eh, self.ow, self.oh = struct.unpack('>5H', hd[6:16])
        if fmt != 0:
            raise SpriteError('fmt=%d, chi ho tro 0 (ETC1_RGB8)' % fmt)
        self.half = self.oh // 2          # nua tren mau, nua duoi alpha
        self._rgb = None

    @property
    def rgb(self):
        if self._rgb is None:
            self._rgb = read_pkm(self.tex_path)[0]
        return self._rgb

    def frames(self):
        return self.x.frames()

    @staticmethod
    def why_skip(fr):
        """Vi sao mot khung khong cat duoc — None neu cat duoc."""
        w, h = int(round(fr['sizeWH'][0])), int(round(fr['sizeWH'][1]))
        if w <= 0 or h <= 0:
            # Moi nhan vat co dung mot muc kieu 'X_res-44.png' kich thuoc 0x0.
            # Day la muc danh dau, khong phai sprite — bo la dung.
            return 'kich thuoc 0'
        return None

    def cut(self, fr):
        """Cat mot khung ra bytearray RGBA, da xoay ve dung chieu."""
        x, y = int(round(fr['atlasXY'][0])), int(round(fr['atlasXY'][1]))
        w, h = int(round(fr['sizeWH'][0])), int(round(fr['sizeWH'][1]))
        if w <= 0 or h <= 0:
            return None, 0, 0
        aw, ah = (h, w) if fr['rotated'] else (w, h)     # kich thuoc TRONG atlas
        if x < 0 or y < 0 or x + aw > self.ew or y + ah > self.half:
            return None, 0, 0

        rgb = self.rgb
        out = bytearray(aw * ah * 4)
        for j in range(ah):
            src = ((y + j) * self.ew + x) * 3
            asrc = ((y + j + self.half) * self.ew + x) * 3
            dst = j * aw * 4
            for i in range(aw):
                s, a, d = src + i * 3, asrc + i * 3, dst + i * 4
                out[d] = rgb[s]
                out[d + 1] = rgb[s + 1]
                out[d + 2] = rgb[s + 2]
                out[d + 3] = rgb[a]           # alpha lay tu nua duoi
        if not fr['rotated']:
            return out, aw, ah
        # TexturePacker xoay 90 do nguoc chieu kim dong ho khi xep vao atlas
        rot = bytearray(w * h * 4)
        for j in range(ah):
            for i in range(aw):
                s = (j * aw + i) * 4
                ni, nj = j, aw - 1 - i
                t = (nj * w + ni) * 4
                rot[t:t + 4] = out[s:s + 4]
        return rot, w, h


def safe(name):
    """Ten file an toan. Ten sprite trong plist thuong da co san duoi .png nen
    bo di, khong thi thanh 'X.png.png'."""
    if name.lower().endswith('.png'):
        name = name[:-4]
    out = ''.join(c if c.isalnum() or c in '-_. ' else '_' for c in name)
    return out.strip() or 'sprite'


# --------------------------------------------------------------------- lenh
def cmd_show(path):
    a = Atlas(path)
    fr = a.frames()
    print('%s' % path)
    print('  texture   : %s' % os.path.basename(a.tex_path))
    print('  kich thuoc: %dx%d (ext %dx%d) — nua tren mau, nua duoi alpha, moc o y=%d'
          % (a.ow, a.oh, a.ew, a.eh, a.half))
    print('  khung     : %d' % len(fr))
    nrot = sum(1 for f in fr if f['rotated'])
    print('  bi xoay   : %d' % nrot)
    print()
    print('  %-40s %-14s %-12s %s' % ('ten', 'vi tri', 'kich thuoc', 'xoay'))
    for f in fr[:12]:
        print('  %-40s %-14s %-12s %s'
              % (f['name'][:40], '%.0f, %.0f' % tuple(f['atlasXY']),
                 '%.0f x %.0f' % tuple(f['sizeWH']), 'co' if f['rotated'] else ''))
    if len(fr) > 12:
        print('  ... con %d khung' % (len(fr) - 12))


def cmd_extract(path, outdir):
    a = Atlas(path)
    sub = os.path.join(outdir, os.path.splitext(os.path.basename(path))[0])
    os.makedirs(sub, exist_ok=True)
    n = skip = 0
    for f in a.frames():
        rgba, w, h = a.cut(f)
        if rgba is None:
            skip += 1
            continue
        write_png(os.path.join(sub, safe(f['name']) + '.png'), w, h, rgba)
        n += 1
    print('  %-34s %4d PNG%s -> %s'
          % (os.path.basename(path)[:34], n, ('  (bo %d)' % skip) if skip else '', sub))
    return n, skip


def cmd_scan(root):
    ok = nofr = notex = other = plain = nfr = 0
    errs = []
    for p in sorted(glob.glob(os.path.join(root, '**', '*.plist'), recursive=True)):
        # Mot so .plist khong he duoc bien dich — van la XML thuan cua Apple.
        # Khong phai loi, chi la loai khac; doc bang XML parser bat ky.
        if open(p, 'rb').read(5) == b'<?xml':
            plain += 1
            continue
        try:
            a = Atlas(p)
            ok += 1
            fr = a.frames()
            nfr += len(fr)
            if not fr:
                nofr += 1
        except SpriteError as e:
            if 'texture' in str(e):
                notex += 1
            elif 'ban .xml' in str(e):
                other += 1
            else:
                errs.append((p, str(e)))
        except (SngXmlError, struct.error, UnicodeDecodeError) as e:
            errs.append((p, str(e)))
    print('quet %s' % root)
    print('  atlas cat duoc      : %d  (%d khung)' % (ok, nfr))
    print('  XML thuan chua bien dich : %d' % plain)
    print('  khong co texture .pkm    : %d' % notex)
    print('  la ban .xml hoat anh     : %d' % other)
    print('  loi                      : %d' % len(errs))
    for p, e in errs[:5]:
        print('     %s — %s' % (os.path.basename(p), e))
    return 0 if not errs else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('target', help='file .plist, hoac thu muc khi dung --scan')
    ap.add_argument('--out', metavar='THU_MUC', help='cat sprite ra PNG vao day')
    ap.add_argument('--scan', action='store_true', help='kiem tra cap plist/texture')
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')
    if a.scan:
        sys.exit(cmd_scan(a.target))
    try:
        if a.out:
            cmd_extract(a.target, a.out)
        else:
            cmd_show(a.target)
    except SpriteError as e:
        sys.exit('khong doc duoc: %s' % e)


if __name__ == '__main__':
    main()
