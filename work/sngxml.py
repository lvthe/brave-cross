# -*- coding: utf-8 -*-
"""Bo doc dinh dang 'sngXml' — plist atlas da bien dich san.

MOT MAGIC, HAI CAU TRUC. 904 file mang magic 'sngXml' chia lam hai loai khac
han nhau, va chi loai thu nhat giai duoc:

    .plist   493 file   atlas sprite  — DA GIAI, doc duoc bang file nay
    .xml     411 file   CHUA GIAI     — bo cuc khac, xem ghi chu cuoi

NGUON GOC. Bo nap trong libgame.so (ban CN) la FUN_0050da18, tim qua xref toi
chuoi 'sngXml' @ 0x007dfb74; no chi kiem magic roi cat buffer vao doi tuong
32 byte, khong phan tich gi. Ham giai chuoi la FUN_0050daac, cung khuon voi
ban .xgg:

    if (rec[1] == 0)  ->  chuoi rong
    else  ->  chuoi tai  base + rec[0] + <goc kho chuoi>,  dai rec[1]

Goc kho chuoi thi doc tu file: header giu no o 0x3c. (Luu y: nhanh code di qua
FUN_0026f704 dung cac offset khac — 0x44/0x50/0x60 va ba mang buoc
0x10/0x10/0x28 — nhung do la nhanh phuc vu loai .xml, khong phai .plist.)

BO CUC .plist

    0x00  char[7]  magic     "sngXml\\0"
    0x08  float    1.0       tren moi file da xem
    0x10  uint32   count     so ban ghi
    0x18  uint32   str_off   } chuoi header 1
    0x1c  uint32   str_len   }
    0x28  uint32   str_off   } chuoi header 2
    0x2c  uint32   str_len   }
    0x30  uint32   str_off   } chuoi header 3
    0x34  uint32   str_len   }
    0x38  uint32   off_recs  goc mang ban ghi
    0x3c  uint32   off_pool  goc kho chuoi

    ban ghi 60 byte:
      +0x00  uint32  str_off      ) tu code: FUN_0050daac
      +0x04  uint32  str_len      )
      +0x08  float, +0x0c  float      vi tri trong atlas (suy dien)
      +0x10  float, +0x14  float      kich thuoc khung   (suy dien)
      +0x18  float, +0x1c  float      do lech, 85% bang 0 (suy dien)
      +0x20  uint32  CHI NHAN 0 hoac 1 — gan chac la co 'rotated'
      +0x24  float, +0x28  float      82% bang 0
      +0x2c  float, +0x30  float      kich thuoc goc      (suy dien)
      +0x34  float, +0x38  float

    Kieu tung cot (float hay nguyen) do duoc tu 18980 ban ghi that. TEN goi
    cho cac cap float la SUY DIEN theo khuon plist cocos2d, chua doi chieu
    tung truong voi code — cho nao chac chan thi ghi ro nguon o tren.

DA KIEM CHUNG tren 493 file .plist:
    - (off_pool - off_recs) / count = 60 byte, 493/493, khong ngoai le
    - 20459 chuoi: 20306 giai duoc (16 co ten tieng Trung UTF-8),
      153 do dai 0, 0 HONG

    python sngxml.py <file.plist>          # doc
    python sngxml.py <file.plist> --json   # xuat JSON
    python sngxml.py --scan <thu_muc>      # kiem tra ca cay
"""
import os, sys, json, glob, struct, argparse, collections

MAGIC = b'sngXml\x00'
REC_SIZE = 60
HDR_STRINGS = (0x18, 0x28, 0x30)


class SngXmlError(Exception):
    pass


class SngXml(object):

    def __init__(self, data, name=''):
        self.data, self.name, self.size = data, name, len(data)
        if self.size < 0x40 or data[:7] != MAGIC:
            raise SngXmlError('khong phai file sngXml')
        u = lambda o: struct.unpack_from('<I', data, o)[0]
        self.count = u(0x10)
        self.off_recs = u(0x38)
        self.off_pool = u(0x3c)
        if not (0 < self.off_recs <= self.off_pool <= self.size):
            raise SngXmlError(
                'bo cuc .xml chu khong phai .plist (recs=%d pool=%d size=%d)'
                % (self.off_recs, self.off_pool, self.size))
        span = self.off_pool - self.off_recs
        if self.count and span % self.count:
            raise SngXmlError('span %d khong chia het cho count %d' % (span, self.count))
        if self.count and span // self.count != REC_SIZE:
            raise SngXmlError('ban ghi %d byte, khong phai %d'
                              % (span // self.count, REC_SIZE))

    def string(self, off, length):
        """Giai chuoi y het FUN_0050daac."""
        if length == 0:
            return ''
        a = self.off_pool + off
        if a + length > self.size:
            raise SngXmlError('chuoi tai pool+%d dai %d vuot cuoi file' % (off, length))
        return self.data[a:a + length].decode('utf-8', 'replace')

    def header_strings(self):
        u = lambda o: struct.unpack_from('<I', self.data, o)[0]
        return [self.string(u(o), u(o + 4)) for o in HDR_STRINGS]

    def frames(self):
        out = []
        for i in range(self.count):
            r = self.off_recs + i * REC_SIZE
            off, ln = struct.unpack_from('<II', self.data, r)
            f = struct.unpack_from('<14f', self.data, r + 4)[1:]   # bo qua str_len
            rotated = struct.unpack_from('<I', self.data, r + 0x20)[0]
            out.append(collections.OrderedDict([
                ('name', self.string(off, ln)),
                ('atlasXY', [f[0], f[1]]),
                ('sizeWH', [f[2], f[3]]),
                ('offsetXY', [f[4], f[5]]),
                ('rotated', bool(rotated)),
                ('f24_28', [f[7], f[8]]),
                ('sourceWH', [f[9], f[10]]),
                ('f34_38', [f[11], f[12]]),
            ]))
        return out

    def to_dict(self):
        return collections.OrderedDict([
            ('file', self.name), ('size', self.size), ('count', self.count),
            ('offRecs', self.off_recs), ('offPool', self.off_pool),
            ('headerStrings', self.header_strings()),
            ('frames', self.frames()),
        ])


def load(path):
    with open(path, 'rb') as fp:
        return SngXml(fp.read(), os.path.basename(path))


def find_files(root):
    out = []
    for p in glob.glob(os.path.join(root, '**', '*'), recursive=True):
        if os.path.isfile(p):
            with open(p, 'rb') as fp:
                if fp.read(7) == MAGIC:
                    out.append(p)
    return sorted(out)


def cmd_show(path, limit):
    x = load(path)
    print('%s  —  %d byte, %d khung' % (path, x.size, x.count))
    print('  chuoi header : %s' % ', '.join(repr(s) for s in x.header_strings()))
    print('  mang ban ghi : 0x%X    kho chuoi: 0x%X' % (x.off_recs, x.off_pool))
    print()
    fr = x.frames()
    print('  %-34s %-17s %-17s %s' % ('ten', 'vi tri atlas', 'kich thuoc', 'xoay'))
    for f in fr[:limit]:
        print('  %-34s %-17s %-17s %s'
              % (f['name'][:34],
                 '%.0f, %.0f' % tuple(f['atlasXY']),
                 '%.0f x %.0f' % tuple(f['sizeWH']),
                 'co' if f['rotated'] else ''))
    if len(fr) > limit:
        print('  ... con %d khung nua' % (len(fr) - limit))


def cmd_scan(root):
    files = find_files(root)
    if not files:
        sys.exit('khong thay file sngXml nao trong %s' % root)
    ok = other = nstr = nempty = 0
    errs = []
    for p in files:
        try:
            x = load(p)
            for s in x.header_strings():
                nempty += (s == '')
                nstr += (s != '')
            for f in x.frames():
                nempty += (f['name'] == '')
                nstr += (f['name'] != '')
            ok += 1
        except SngXmlError as e:
            if 'bo cuc .xml' in str(e):
                other += 1
            else:
                errs.append((p, str(e)))

    print('quet %s' % root)
    print('  file sngXml     : %d' % len(files))
    print('  .plist giai duoc: %d' % ok)
    print('  bo cuc .xml     : %d  (chua giai)' % other)
    print('  loi that su     : %d' % len(errs))
    for p, e in errs[:5]:
        print('     %s — %s' % (p, e))
    print()
    print('  chuoi           : %d giai duoc, %d rong' % (nstr, nempty))
    return 0 if not errs else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('target', help='file .plist, hoac thu muc khi dung --scan')
    ap.add_argument('--json', action='store_true', help='xuat JSON')
    ap.add_argument('--scan', action='store_true', help='kiem tra ca cay')
    ap.add_argument('--limit', type=int, default=12, help='so khung hien ra')
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')

    if a.scan:
        sys.exit(cmd_scan(a.target))
    try:
        if a.json:
            print(json.dumps(load(a.target).to_dict(), ensure_ascii=False, indent=1))
        else:
            cmd_show(a.target, a.limit)
    except SngXmlError as e:
        sys.exit('khong doc duoc: %s' % e)


if __name__ == '__main__':
    main()
