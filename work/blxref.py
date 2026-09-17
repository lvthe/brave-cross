"""Tim moi lenh BL / B.W trong .text tro toi mot dia chi (Thumb-2).

Thumb-2 ma hoa BL bang HAI halfword lien tiep:
    H1 = 11110 S imm10
    H2 = 11111 J1 1 J2 imm11          (BL: bit 12 = 1)
    B.W: H2 = 10 J1 1 J2 imm11
Dich: I1 = NOT(J1 XOR S), I2 = NOT(J2 XOR S)
      off = S:I1:I2:imm10:imm11:0  (co dau)
      dich = dia chi lenh + 4 + off
Khong dung capstone: quet thang byte nen khong bi lech khi gap literal pool.
"""
import struct
import sys
import armdis

BASE, DATA = armdis.TEXT


def targets():
    """[(dia chi lenh, dia chi dich, loai)] cho moi BL/B.W trong .text."""
    out = []
    n = len(DATA)
    for i in range(0, n - 4, 2):
        h1 = struct.unpack_from('<H', DATA, i)[0]
        if (h1 & 0xF800) != 0xF000:
            continue
        h2 = struct.unpack_from('<H', DATA, i + 2)[0]
        if (h2 & 0xD000) != 0xD000:      # 1101 / 1001 -> BL / B.W
            continue
        s = (h1 >> 10) & 1
        j1 = (h2 >> 13) & 1
        j2 = (h2 >> 11) & 1
        i1 = 1 - (j1 ^ s)
        i2 = 1 - (j2 ^ s)
        off = ((s << 24) | (i1 << 23) | (i2 << 22)
               | ((h1 & 0x3FF) << 12) | ((h2 & 0x7FF) << 1))
        if s:
            off -= 0x2000000
        a = BASE + i
        kind = 'bl' if (h2 & 0x4000) else 'b.w'
        out.append((a, (a + 4 + off) & 0xFFFFFFFF, kind))
    return out


_CACHE = None


def callers(addr):
    global _CACHE
    if _CACHE is None:
        _CACHE = targets()
    return [(a, k) for a, t, k in _CACHE if t == addr]


def to(addr):
    global _CACHE
    if _CACHE is None:
        _CACHE = targets()
    return [(t, k) for a, t, k in _CACHE if a == addr]


if __name__ == '__main__':
    for x in sys.argv[1:]:
        a = int(x, 0)
        cs = callers(a)
        print('0x%x <- %d cho goi: %s' % (a, len(cs),
              ', '.join('%s@0x%x' % (k, c) for c, k in cs[:20])))
