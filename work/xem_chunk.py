# -*- coding: utf-8 -*-
"""Dump nguyen van payload cua chunk 0x0B (cho `setup_id`) trong vai bank.

    python xem_chunk.py

VI SAO. `bank.py:PHU_SETUP = 0x0B` la mot hang so VIET CUNG, va `mo_bank` chi
doc 4 byte dau cua payload lam `setup_id`. Neu payload dai hon 8 byte thi phan
con lai dang bi bo di — va rat co the trong do co DO DAI THAT cua khoi setup,
hoac chinh khoi do. Do truoc khi ket luan "khoi setup khong co trong may".
"""
import collections
import os
import struct
import sys

import bank


def mo_fsb(p):
    b = open(p, 'rb').read()
    q = 12
    while q + 8 <= len(b):
        cid = b[q:q + 4]
        sz, = struct.unpack_from('<I', b, q + 4)
        if cid == b'SND ':
            i = b[q + 8:q + 8 + sz].find(b'FSB5')
            return b[q + 8 + i:]
        q += 8 + sz + (sz & 1)
    return None


def dump(p, muon):
    d = mo_fsb(p)
    if d is None:
        print('  khong phai RIFF/SND')
        return
    _v, nsub, shsize, ntsize, dsize, codec = struct.unpack_from('<6I', d, 4)
    hdr = d[0x3c:0x3c + shsize]
    nt = d[0x3c + shsize:0x3c + shsize + ntsize]
    ten = []
    for k in range(nsub):
        o, = struct.unpack_from('<I', nt, 4 * k)
        e = nt.find(b'\x00', o)
        ten.append(nt[o:e].decode('utf-8', 'replace'))
    off = 0
    seen = collections.Counter()
    dai_nhat = collections.Counter()
    for k in range(nsub):
        m, = struct.unpack_from('<Q', hdr, off)
        off += 8
        con = m & 1
        while con:
            x, = struct.unpack_from('<I', hdr, off)
            off += 4
            t = (x >> 25) & 0x7F
            s_sz = (x >> 1) & 0xFFFFFF
            con = x & 1
            pl = hdr[off:off + s_sz]
            off += s_sz
            seen[t] += 1
            dai_nhat[t] = max(dai_nhat[t], s_sz)
            if t == bank.PHU_SETUP and ten[k] in muon:
                hai = struct.unpack_from('<II', pl, 0) if len(pl) >= 8 else ()
                print('  %-34s size=%-3d  pl=%s  u32=%s'
                      % (ten[k], s_sz, pl.hex(), ['0x%08x' % y for y in hai]))
    print('  chunk (loai: so lan, size lon nhat): %s'
          % {('0x%02x' % t): (seen[t], dai_nhat[t]) for t in sorted(seen)})


def main():
    muon = {'Archer__Act_Archer_Fight_Cast_01', 'BGM__BGM_Main02',
            'UI__UI_Click', 'IceWitch__Act_IceWitch_PoBing_Cast_01'}
    for p in sys.argv[1:] or bank.duong_bank():
        print('==', os.path.basename(p))
        dump(p, muon)
        if not sys.argv[1:]:
            break


if __name__ == '__main__':
    main()
