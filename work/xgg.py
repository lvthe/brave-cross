# -*- coding: utf-8 -*-
"""Bo doc dinh dang '.xgg' (magic 'sngXgg' / 'xgg5.0') cua game.

NGUON GOC CUA LAYOUT. Khong doan: doc thang tu ham phan tich header trong
libgame.so (ban CN: FUN_0048f0f0 @ 0x0048f0f0, tim qua xref toi chuoi
'sngXgg' @ 0x007d2c0c). Ghidra dich nguoc ra:

    __s1 = <buffer file>
    if (memcmp(__s1,"sngXgg",7) == 0 || memcmp(__s1,"xgg5.0",7) == 0) {
        p+0x1c = __s1 + *(int*)(__s1 + 0x08)
        p+0x20 = *(int*)(__s1 + *(int*)(__s1 + 0x0c))        <- count
        p+0x24 = __s1 + *(int*)(__s1 + 0x0c) + 4             <- data
        p+0x28 = *(int*)(__s1 + *(int*)(__s1 + 0x10))        <- count
        p+0x2c = __s1 + *(int*)(__s1 + 0x10) + 4             <- data
        p+0x30 = *(int*)(__s1 + *(int*)(__s1 + 0x14))        <- count
        p+0x34 = __s1 + *(int*)(__s1 + 0x14) + 4             <- data
        p+0x38 = __s1 + *(int*)(__s1 + 0x18)
    }

Tuc la header la mot bang muc luc 5 offset, trong do ba cai giua tro toi
khoi dang [uint32 count][count * ban ghi].

Ham tren chi dung 5 offset dau, nhung header con 3 offset nua o 0x1c-0x24 —
do duoc bang thong ke tren toan bo 580 file: ca ba deu nam trong file va deu
>= off_E, va off_G luon bang off_E + 8 (580/580). Voi ba cai do thi header
kin het: 7 byte magic + 1 + 8*4 = 40 = 0x28, khong con byte nao chua giai.

    0x00  char[7]   magic     "sngXgg\\0" hoac "xgg5.0\\0"
    0x07  byte      ?         luon 0x00 tren mau da xem
    0x08  uint32    off_A     luon = 0x28   (580/580)
    0x0c  uint32    off_B     luon = 0x90   (580/580)
    0x10  uint32    off_C
    0x14  uint32    off_D
    0x18  uint32    off_E
    0x1c  uint32    off_F
    0x20  uint32    off_G     luon = off_E + 8   (580/580)
    0x24  uint32    off_H

Thu tu GIA TRI khong trung thu tu o header: E <= G <= F <= H <= kich thuoc
file (dung tren ca 580 file).

Kich thuoc ban ghi KHONG nam trong header — suy ra tu khoang cach giua hai
section: (off_ke_tiep - off - 4) / count. Do tren ca 580 file cho ra 8 / 16 /
16 byte, khong mot truong hop nao chia khong het.

DA KIEM CHUNG: bo cuc header, khung [count][ban ghi] cua B/C/D, kich thuoc
ban ghi, va viec cot +8/+12 cua C/D la float32 (100% giai ra hop ly, bien do
khop dung do phan giai trong ten file: toi 768 va 960).

CHUA GIAI: y nghia cac cot SO NGUYEN trong ban ghi, va 104 byte cua section A
(nhin ra toan float, thay 1024.0 / 768.0 / 0.8 nhung chua ro tung truong).
Da thu va LOAI TRU gia thuyet cac cot so nguyen la offset chuoi: doc chung tu
moi goc deu khong ra chuoi, va vung sau off_E khong chua mot ky tu ASCII nao.

    python xgg.py <file>                 # doc header + tom tat
    python xgg.py <file> --dump B        # do tung ban ghi cua mot section
    python xgg.py --scan <thu_muc>       # kiem tra layout tren ca cay
    python xgg.py --fields <thu_muc>     # do dang cac cot, de doan kieu truong
"""
import os, sys, glob, math, struct, argparse, collections

MAGICS = (b'sngXgg\x00', b'xgg5.0\x00')
HEADER_SIZE = 0x28

# Ten section theo THU TU O TRONG HEADER (0x08, 0x0c, ... 0x24).
# Luu y thu tu gia tri khac: E <= G <= F <= H. B/C/D la khoi co count.
SECTIONS = ('A', 'B', 'C', 'D', 'E', 'F', 'G', 'H')
COUNTED = ('B', 'C', 'D')


class XggError(Exception):
    pass


class Xgg(object):
    """Mot file .xgg da giai header."""

    def __init__(self, data, name=''):
        self.data = data
        self.name = name
        self.size = len(data)
        if self.size < HEADER_SIZE:
            raise XggError('file qua ngan (%d byte)' % self.size)
        self.magic = data[:7]
        if self.magic not in MAGICS:
            raise XggError('magic la %r, khong phai .xgg' % self.magic[:7])

        self.byte7 = data[7]
        self.offsets = collections.OrderedDict(
            zip(SECTIONS, struct.unpack_from('<8I', data, 8)))

        for name_, off in self.offsets.items():
            if not 0 < off <= self.size:
                raise XggError('off_%s = 0x%X nam ngoai file (%d byte)'
                               % (name_, off, self.size))

        # count + kich thuoc ban ghi cua ba section giua
        self.counts, self.rec_size, self.data_at = {}, {}, {}
        order = list(self.offsets)
        for tag in COUNTED:
            off = self.offsets[tag]
            nxt = self.offsets[order[order.index(tag) + 1]]
            self.counts[tag] = struct.unpack_from('<I', data, off)[0]
            self.data_at[tag] = off + 4
            span = nxt - off - 4
            n = self.counts[tag]
            if n == 0:
                self.rec_size[tag] = 0
            elif span % n:
                raise XggError('section %s: span %d khong chia het cho count %d'
                               % (tag, span, n))
            else:
                self.rec_size[tag] = span // n

    # ---------------------------------------------------------------- truy cap
    def extent(self, tag):
        """(dau, cuoi) cua mot section.

        Cuoi = offset NHO NHAT lon hon no, chu khong phai o header ke tiep:
        thu tu gia tri la E <= G <= F <= H, khong trung thu tu o header.
        """
        start = self.offsets[tag]
        later = [v for v in self.offsets.values() if v > start]
        return start, (min(later) if later else self.size)

    def section_bytes(self, tag):
        """Toan bo vung byte cua mot section."""
        a, b = self.extent(tag)
        return self.data[a:b]

    def records(self, tag):
        """Cac ban ghi cua section co count (B/C/D)."""
        if tag not in COUNTED:
            raise XggError('section %s khong phai dang [count][ban ghi]' % tag)
        w, at = self.rec_size[tag], self.data_at[tag]
        return [self.data[at + i * w: at + (i + 1) * w]
                for i in range(self.counts[tag])]

    @property
    def pool(self):
        """Toan bo vung duoi off_E toi cuoi file.

        Vung nay bi F/G/H chia nho tiep; day la ca khoi, khong phai rieng E.
        """
        return self.data[self.offsets['E']:]


def load(path):
    with open(path, 'rb') as fp:
        return Xgg(fp.read(), os.path.basename(path))


def find_files(root):
    out = []
    for p in glob.glob(os.path.join(root, '**', '*'), recursive=True):
        if os.path.isfile(p):
            with open(p, 'rb') as fp:
                if fp.read(7) in MAGICS:
                    out.append(p)
    return sorted(out)


# ------------------------------------------------------------------ dien giai
def as_i32(b):
    return struct.unpack('<i', b)[0]


def as_f32(b):
    return struct.unpack('<f', b)[0]


def looks_float(v):
    """Float32 'trong hop ly': 0, hoac do lon nam trong khoang doi thuong."""
    if v == 0.0:
        return True
    if math.isnan(v) or math.isinf(v):
        return False
    return 1e-3 <= abs(v) < 1e7


def describe_word(word, xf):
    """Doan xem mot tu 4 byte co the la gi."""
    n = as_i32(word)
    hints = []
    if 0 <= n < xf.size:
        # CHI noi no nam trong khoang kich thuoc file. Khong goi la "offset":
        # gia thuyet do da thu va bi loai (xem ghi chu o dau file).
        hints.append('<= kich thuoc file')
    f = as_f32(word)
    if looks_float(f):
        hints.append('float %g' % f)
    return '%11d  0x%08X  %s' % (n, n & 0xFFFFFFFF, ', '.join(hints))


def preview_ascii(b, n=64):
    s = ''.join(chr(c) if 32 <= c < 127 else '.' for c in b[:n])
    return s


# --------------------------------------------------------------------- lenh
def cmd_show(path, dump_tag=None, limit=8):
    xf = load(path)
    print('%s  —  %d byte' % (path, xf.size))
    print('  magic        %r   byte[7] = 0x%02X' % (xf.magic[:6].decode(), xf.byte7))
    print()
    print('  %-4s %-8s %-10s %-8s %-10s %s'
          % ('sec', 'o header', 'offset', 'count', 'ban ghi', 'kich thuoc'))
    for i, tag in enumerate(xf.offsets):
        off = xf.offsets[tag]
        start, end = xf.extent(tag)
        slot = '0x%02X' % (8 + i * 4)
        if tag in COUNTED:
            print('  %-4s %-8s 0x%-8X %-8d %-10s %d byte'
                  % (tag, slot, off, xf.counts[tag],
                     '%d byte' % xf.rec_size[tag] if xf.counts[tag] else '—',
                     end - start))
        else:
            print('  %-4s %-8s 0x%-8X %-8s %-10s %d byte'
                  % (tag, slot, off, '—', '—', end - start))

    print()
    print('  section A (co dinh %d byte):' % len(xf.section_bytes('A')))
    a = xf.section_bytes('A')
    for i in range(0, min(len(a), 32), 16):
        print('    +%02X  %-47s |%s|' % (
            i, ' '.join('%02X' % c for c in a[i:i + 16]), preview_ascii(a[i:i + 16], 16)))
    print()
    print('  vung duoi off_E (%d byte, gom E+G+F+H) — 96 byte dau:' % len(xf.pool))
    print('    |%s|' % preview_ascii(xf.pool, 96))

    if dump_tag:
        print()
        cmd_dump(xf, dump_tag, limit)


def cmd_dump(xf, tag, limit):
    recs = xf.records(tag)
    w = xf.rec_size[tag]
    print('  section %s — %d ban ghi x %d byte (hien %d dau)'
          % (tag, len(recs), w, min(limit, len(recs))))
    for i, r in enumerate(recs[:limit]):
        print('   [%d] %s' % (i, ' '.join('%02X' % c for c in r)))
        for j in range(0, w, 4):
            print('        +%-2d %s' % (j, describe_word(r[j:j + 4], xf)))


def cmd_scan(root):
    files = find_files(root)
    if not files:
        sys.exit('khong thay file .xgg nao trong %s' % root)
    ok = 0
    rec = {t: collections.Counter() for t in COUNTED}
    consts = {t: collections.Counter() for t in SECTIONS}
    errs = []
    for p in files:
        try:
            xf = load(p)
        except XggError as e:
            errs.append((p, str(e)))
            continue
        ok += 1
        for t in SECTIONS:
            consts[t][xf.offsets[t]] += 1
        for t in COUNTED:
            if xf.counts[t]:
                rec[t][xf.rec_size[t]] += 1

    print('quet %s' % root)
    print('  file .xgg      : %d' % len(files))
    print('  giai duoc      : %d' % ok)
    print('  loi            : %d' % len(errs))
    for p, e in errs[:5]:
        print('     %s — %s' % (p, e))
    print()
    for t in SECTIONS:
        c = consts[t].most_common(3)
        fixed = ' (HANG SO)' if len(consts[t]) == 1 else ''
        print('  off_%s: %s%s' % (t, ', '.join('0x%X x%d' % (k, v) for k, v in c), fixed))
    print()
    for t in COUNTED:
        print('  section %s — kich thuoc ban ghi: %s'
              % (t, ', '.join('%d byte x%d file' % (k, v) for k, v in rec[t].most_common(3))))
    return 0 if not errs else 1


def cmd_fields(root):
    """Do dang tung cot 4 byte trong ban ghi, gop ca cay.

    Muc dich: doan kieu tung truong. Mot cot ma gia tri luon nho va tang dan
    thi giong chi so; luon nam trong [off_E, size) thi giong con tro vao kho
    chuoi; giai ra float hop ly thi giong toa do.
    """
    files = find_files(root)
    stat = {}
    for p in files:
        try:
            xf = load(p)
        except XggError:
            continue
        for t in COUNTED:
            w = xf.rec_size[t]
            if not w:
                continue
            for r in xf.records(t):
                for j in range(0, w, 4):
                    word = r[j:j + 4]
                    if len(word) < 4:
                        continue
                    k = (t, j)
                    s = stat.setdefault(k, {'n': 0, 'min': None, 'max': None,
                                            'in_file': 0, 'in_E': 0, 'flt': 0, 'zero': 0})
                    v = as_i32(word)
                    s['n'] += 1
                    s['min'] = v if s['min'] is None else min(s['min'], v)
                    s['max'] = v if s['max'] is None else max(s['max'], v)
                    if v == 0:
                        s['zero'] += 1
                    if 0 <= v < xf.size:
                        s['in_file'] += 1
                        if v >= xf.offsets['E']:
                            s['in_E'] += 1
                    if looks_float(as_f32(word)):
                        s['flt'] += 1

    print('do dang cot 4 byte tren %d file\n' % len(files))
    print('  %-9s %9s %14s %14s %7s %7s %7s %7s %s' %
          ('cot', 'so mau', 'min', 'max', 'bang0', 'trong', 'vao E', 'float', 'doan'))
    for (t, j), s in sorted(stat.items()):
        n = s['n']
        pct = lambda x: '%5.1f%%' % (100.0 * x / n)
        # Cot nao gan nhu luon giai ra float hop ly thi hien min/max DANG FLOAT,
        # de dang int cua no chi la rac (vd 1073741824 == 2.0f).
        is_f = s['flt'] > 0.98 * n
        fmt = (lambda v: '%14.3f' % struct.unpack('<f', struct.pack('<i', v))[0]) if is_f \
            else (lambda v: '%14d' % v)
        # Chi khang dinh cai da kiem chung. Cot float thi chac (100% giai ra
        # float hop ly, bien do khop do phan giai man hinh trong ten file).
        # Cot so nguyen thi CHUA biet la gi: da thu doc chung nhu offset tinh
        # tu dau file va tu tung section — khong goc nao cho ra chuoi doc duoc,
        # va section E khong chua ASCII nao. Nen khong goi chung la offset.
        if is_f:
            guess = 'float — bien do khop toa do man hinh'
        else:
            guess = 'so nguyen, y nghia CHUA RO'
        print('  %-9s %9d %s %s %7s %7s %7s %7s %s'
              % ('%s+%d' % (t, j), n, fmt(s['min']), fmt(s['max']),
                 pct(s['zero']), pct(s['in_file']), pct(s['in_E']), pct(s['flt']), guess))
    print()
    print('  "trong" = gia tri nam trong [0, kich thuoc file)')
    print('  "vao E" = gia tri >= off_E (KHONG co nghia la con tro — xem ghi chu duoi)')
    print('  "float" = giai ra float32 co do lon doi thuong')
    print()
    print('  Da thu va LOAI TRU: cac cot so nguyen khong phai offset chuoi. Doc chung')
    print('  nhu offset tinh tu dau file va tu tung section deu khong ra chuoi hop le,')
    print('  va section E khong chua mot ky tu ASCII nao. Muon biet chung la gi phai')
    print('  doc tiep trong Ghidra: xem ham nao TIEU THU cac con tro ma bo doc header')
    print('  cat vao p+0x1c ... p+0x38.')
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('target', help='file .xgg, hoac thu muc khi dung --scan/--fields')
    ap.add_argument('--dump', metavar='SEC', choices=COUNTED,
                    help='do tung ban ghi cua section B, C hoac D')
    ap.add_argument('--limit', type=int, default=8, help='so ban ghi hien ra (mac dinh 8)')
    ap.add_argument('--scan', action='store_true', help='kiem tra layout tren ca cay thu muc')
    ap.add_argument('--fields', action='store_true', help='do dang cac cot 4 byte tren ca cay')
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')

    if a.scan:
        sys.exit(cmd_scan(a.target))
    if a.fields:
        sys.exit(cmd_fields(a.target))
    try:
        cmd_show(a.target, a.dump, a.limit)
    except XggError as e:
        sys.exit('khong doc duoc: %s' % e)


if __name__ == '__main__':
    main()
