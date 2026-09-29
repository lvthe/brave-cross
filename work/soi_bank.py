# -*- coding: utf-8 -*-
"""Soi mot bank: hai truong sau `setup_id` la (offset, len) CUA CAI GI?

    python soi_bank.py <ten bank> [--sub <ten>]

Viec lam: doi chieu cap (offset, len) voi vung du lieu NEN cua tung subsound ma
`bank.mo_bank` da phan tich, do entropy cua mieng cat, va quet ca blob tim mot
khoi setup Vorbis khong mang chu ky (`\\x00\\x00\\x00\\x00` + so kenh + rate +
so codebook — dung 11 byte dau cua setup header khi bo `\\x05vorbis`).
"""
import math
import os
import struct
import sys
import zlib

import bank
import xem_chunk

MONG = {0x84d3ac87: 'Archer/SFX', 0x38aa59ce: 'nhac', 0xc55efa16: 'IceWitch'}


def entropy(b):
    if not b:
        return 0.0
    c = [0] * 256
    for x in b:
        c[x] += 1
    n = len(b)
    return -sum((v / n) * math.log2(v / n) for v in c if v)


def tim_setup_khong_chu_ky(b):
    """[(offset, so kenh, rate, so codebook)] cho moi cho giong dau setup header."""
    ra = []
    for i in range(0, len(b) - 12):
        if b[i:i + 4] != b'\x00\x00\x00\x00':
            continue
        k = b[i + 4]
        if k not in (1, 2, 6, 8):
            continue
        rate, = struct.unpack_from('<I', b, i + 5)
        if not (8000 <= rate <= 192000):
            continue
        ncb = b[i + 9]
        if not (1 <= ncb <= 255):
            continue
        ra.append((i, k, rate, ncb))
    return ra


def main():
    ten = sys.argv[1] if len(sys.argv) > 1 else 'Archer'
    loc = sys.argv[sys.argv.index('--sub') + 1] if '--sub' in sys.argv else None
    p = os.path.join(bank.BANKS, ten + '.bank')
    if not os.path.isfile(p):
        p = os.path.join(bank.BANKS, ten)
    b = open(p, 'rb').read()
    fsb = xem_chunk.mo_fsb(p)
    v, nsub, shsize, ntsize, dsize, codec = struct.unpack_from('<6I', fsb, 4)
    print('tep %s  %d byte   FSB5 %d byte' % (os.path.basename(p), len(b), len(fsb)))
    print('  ver=%d nsub=%d shsize=%d ntsize=%d dsize=%d codec=%d  (0x3c+sh+nt+dsize=%d)'
          % (v, nsub, shsize, ntsize, dsize, codec, 0x3c + shsize + ntsize + dsize))
    r = bank.mo_bank(p)
    for s in r['subs']:
        if loc and s['ten'] != loc:
            continue
        print('  %-32s sid=0x%08x %s kenh=%d rate=%d mau=%d doff=%d end=%d'
              % (s['ten'], s['sid'], MONG.get(s['sid'], '?'), s['kenh'], s['rate'],
                 s['mau'], s['doff'], s['end']))
        pl = None
        # Lay lai payload 0x0B cho chinh subsound nay.
        import setup_trong_bank as stb
        ds, _f, _r = stb.payload(p, s['ten'])
        for _t, _k, _ra, _pl in ds:
            pl = _pl
        if pl and len(pl) >= 12:
            a, c = struct.unpack_from('<II', pl, 4)
            for ten_cap, (o, n) in (('(a,b)', (a, c)), ('(b,a)', (c, a))):
                if n == 0 or o + n > len(fsb):
                    print('    %s=(%d,%d) NGOAI blob' % (ten_cap, o, n))
                    continue
                mieng = fsb[o:o + n]
                print('    %s=(%d,%d) entropy=%.2f  crc=0x%08x  trung vung du lieu: %s'
                      % (ten_cap, o, n, entropy(mieng), zlib.crc32(mieng) & 0xffffffff,
                         'CO' if o >= s['doff'] and o + n <= s['end'] else 'khong'))
    print('  quet dau setup header khong chu ky: %d cho' % len(tim_setup_khong_chu_ky(fsb)))
    for i, k, rate, ncb in tim_setup_khong_chu_ky(fsb)[:12]:
        print('    @%-8d kenh=%d rate=%-6d ncb=%d' % (i, k, rate, ncb))


if __name__ == '__main__':
    main()
