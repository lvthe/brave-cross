# -*- coding: utf-8 -*-
"""Do thi loi goi `bl` cua mot doan libgame.so (Thumb-2).

    python blgraph.py --xay              # quet .text mot lan, ghi blgraph.json
    python blgraph.py --goi 0x2ab118     # AI GOI ham nay
    python blgraph.py --tu 0x2ab932      # ham nay goi NHUNG DAU
    python blgraph.py --goi 0x2ab118 --ten   # kem ten ham (doc tu .symtab)

VI SAO
------
`xref.py` chi tim duoc tham chieu qua LITERAL POOL (dia chi nam trong .text
duoi dang 4 byte). Cach do **khong thay** loi goi `bl`: Thumb ma hoa `bl` bang
offset tuong doi, khong co dia chi tuyet doi nao trong file. Nen cau hoi "ai
goi ham C++ nay" — cau hoi dat ra lien tuc khi doc `_lua_*` cua armature — truoc
day khong tra loi duoc, va toi da mat mot luot doan sai vi the: xref cho
`CDFColliderBoneInfo::find` (0x2ab118) ra DUNG 0 ket qua, trong khi thuc te ham
do duoc goi tu 0x2ab860 ngay ben canh.

CACH LAM. Disassemble toan bo .text (5.595.976 byte, ~2,8 trieu lenh Thumb) va
ghi lai moi cap (cho_goi, dich). Mot lan quet ton vai chuc giay; ket qua duoc
CACHE ra `blgraph.json` de cac luot sau doc lai tuc thi.

HAI BAY DA GAP
--------------
* **Bit 0 cua dia chi Thumb.** Con tro ham Thumb co bit 0 = 1 (0x2ab119), con
  dia chi LENH that su la 0x2ab118. Bang bind cua Lua (`binder.py`) luu dang co
  bit 0, nen phai tru 1 truoc khi tra cuu. Da tra nham mot lan va no lech dung
  1 byte — du de roi vao mot ham khac.
* **Khong co `.symtab` cho moi ham.** 7.268 ten ham STT_FUNC, nhung khoang trong
  giua cac ham rat lon (co cho lech 58.417 byte), nen "ten ham gan nhat phia
  truoc" chi dung khi `dich - st_value < st_size`. Cong cu nay chi in ten khi
  thoa dieu kien do, va in `+N` (ngoai) khi khong.
"""
import os
import sys
import json
import bisect
import struct
import argparse

import capstone
from elftools.elf.elffile import ELFFile

HERE = os.path.dirname(os.path.abspath(__file__))
PATH = os.path.join(HERE, 'vn', 'apk', 'lib', 'armeabi-v7a', 'libgame.so')
CACHE = os.path.join(HERE, 'blgraph.json')

md = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
# KHONG co dong nay thi `disasm` DUNG HAN o byte khong dich duoc dau tien — ma
# .text bat dau bang du lieu, nen lan chay dau tien tra ve 0 loi goi bl trong
# 0,9 giay. Bat skipdata thi capstone phat `.byte` cho byte la va di tiep.
md.skipdata = True


def _sym():
    """(mang dia chi, mang (ten, dia chi, kich thuoc)) de tra ten ham."""
    el = ELFFile(open(PATH, 'rb'))
    fs = sorted((s['st_value'], s.name, s['st_size'])
                for s in el.get_section_by_name('.symtab').iter_symbols()
                if s.name and s['st_info']['type'] == 'STT_FUNC' and s['st_value'])
    return [f[0] for f in fs], fs


def ten(addrs, fs, a):
    """Ten ham chua dia chi `a`, hoac None neu `a` nam ngoai moi ham da dat ten."""
    i = bisect.bisect_right(addrs, a) - 1
    if i < 0:
        return None
    v, n, sz = fs[i]
    return n if a - v < sz else None


def xay():
    el = ELFFile(open(PATH, 'rb'))
    text = next(s for s in el.iter_sections() if s.name == '.text')
    base, data = text['sh_addr'], text.data()
    ra = []
    for i in md.disasm(data, base):
        if i.mnemonic == 'bl':
            try:
                ra.append((i.address, int(i.op_str.lstrip('#'), 16)))
            except ValueError:
                pass                 # blx <reg> — khong co dich tinh
    json.dump(ra, open(CACHE, 'w'))
    print('quet .text %d byte -> %d loi goi bl, ghi %s' % (len(data), len(ra), CACHE))
    return ra


def doc():
    if not os.path.exists(CACHE):
        print('chua co %s — chay: python blgraph.py --xay' % CACHE)
        sys.exit(1)
    return [(a, b) for a, b in json.load(open(CACHE))]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--xay', action='store_true')
    ap.add_argument('--goi', metavar='DIA_CHI')      # ai goi
    ap.add_argument('--tu', metavar='DIA_CHI')       # goi ai
    ap.add_argument('--ten', action='store_true')
    a = ap.parse_args()

    cap = xay() if a.xay else doc()
    if not a.xay and (a.goi or a.tu):
        addrs, fs = _sym()
        if a.goi:
            d = int(a.goi, 0)
            print('=== ai goi 0x%06x ===' % d)
            for cho, dich in cap:
                if dich == d or dich == (d | 1) or (dich & ~1) == d:
                    t = ten(addrs, fs, cho) if a.ten else None
                    print('   0x%06x %s' % (cho, ('  ' + t) if t else ''))
        if a.tu:
            d = int(a.tu, 0)
            print('=== 0x%06x goi nhung dau ===' % d)
            for cho, dich in cap:
                if cho == d or (d & ~1) == (cho & ~1):
                    t = ten(addrs, fs, dich) if a.ten else None
                    print('   0x%06x %s' % (dich, ('  ' + t) if t else ''))


if __name__ == '__main__':
    main()
