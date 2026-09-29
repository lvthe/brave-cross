# -*- coding: utf-8 -*-
"""Thu doc khoi setup Vorbis NGAY TRONG bank, theo hai truong sau `setup_id`.

    python setup_trong_bank.py <ten bank> [--sub <ten>] [--tat-ca]

VI SAO. Payload chunk 0x0B khong phai 4 byte: vd Archer.bank co payload 16 byte
`setup_id, 0x00000008, 47552, 9183`. Lan truoc ket luan hai so cuoi "tro vao
byte rac" — SAI, vi mot khoi codebook Vorbis chinh la du lieu entropy cao. Va
phep quet toan may truoc do tim `\\x05vorbis`, ma khoi setup luu trong bank co
the KHONG mang chu ky do (chu ky la phan header packet do nguoi ghep them vao).
Nen "khong file nao co khoi setup" khong suy ra duoc tu phep quet co chu ky.

Do gi o day: voi moi subsound, lay payload 0x0B, thu MOI cach cat (off, len) va
(len, off) tu hai truong cuoi, roi:
  - `zlib.crc32` cua mieng cat so voi `setup_id` (luat da kiem chung la dung
    tren khoi cua IceWitch: crc32(khoi) == id),
  - `bank.doc_setup` co phan tich tron mieng cat khong (thu ca chuc so kenh),
  - neu thieu, thu them tien to `\\x05vorbis`.
"""
import os
import struct
import sys
import zlib

import bank
import vorbis_probe

MONG = [0x84d3ac87, 0x38aa59ce]


def payload(p, ten_loc):
    """[(ten subsound, kenh, rate, sid, bytes payload 0x0B)] cua mot bank."""
    r = bank.mo_bank(p)
    if r is None:
        sys.exit('khong doc duoc bank %s' % p)
    d = open(p, 'rb').read()
    # `mo_bank` da phan tich; o day chi can lay lai payload tho nen di lai header.
    import xem_chunk
    fsb = xem_chunk.mo_fsb(p)
    _v, nsub, shsize, ntsize, dsize, codec = struct.unpack_from('<6I', fsb, 4)
    hdr = fsb[0x3c:0x3c + shsize]
    nt = fsb[0x3c + shsize:0x3c + shsize + ntsize]
    ten = []
    for k in range(nsub):
        o, = struct.unpack_from('<I', nt, 4 * k)
        e = nt.find(b'\x00', o)
        ten.append(nt[o:e].decode('utf-8', 'replace'))
    ra = []
    off = 0
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
            if t == bank.PHU_SETUP:
                if ten_loc is None or ten[k] == ten_loc:
                    s = r['subs'][k]
                    ra.append((ten[k], s['kenh'], s['rate'], pl))
    return ra, fsb, r


def thu(ten, kenh, rate, pl, fsb, r):
    """In moi cach giai thich payload; tra True neu tim duoc khoi CRC khop id."""
    sid, = struct.unpack_from('<I', pl, 0)
    print('  %-34s payload %2d byte  sid=0x%08x  %s'
          % (ten, len(pl), sid, pl.hex()))
    if len(pl) < 12:
        return False
    a, b = struct.unpack_from('<II', pl, 4)
    for ten_cap, (o, n) in (('(a,b)', (a, b)), ('(b,a)', (b, a))):
        if n == 0 or o + n > len(fsb):
            continue
        mieng = fsb[o:o + n]
        c = zlib.crc32(mieng) & 0xffffffff
        if c == sid:
            print('      >>> KHOP CRC: cat %s = (%d,%d)  crc=0x%08x' % (ten_cap, o, n, c))
            return True
        # Thu phan tich, ca khi thieu 7 byte chu ky.
        for tien_to in (b'', b'\x05vorbis'):
            for k in (2, 1):
                try:
                    n2, ncb, _fl = bank.doc_setup(tien_to + mieng, 0, k)
                except (ValueError, IndexError):
                    continue
                if n2 == n and len(tien_to) == 0:
                    pass
                print('      cat %s=(%d,%d) %s kenh=%d -> doc duoc %d/%d ncb=%d'
                      % (ten_cap, o, n, 'co chu ky' if tien_to else 'tran',
                         k, n2, n, ncb))
    if sid in MONG:
        print('      (id nay DANG CAN: %s)' % ('Archer/SFX' if sid == MONG[0] else 'nhac'))
    return False


def main():
    ten_bank = sys.argv[1] if len(sys.argv) > 1 else 'Archer'
    loc = None
    if '--sub' in sys.argv:
        loc = sys.argv[sys.argv.index('--sub') + 1]
    p = os.path.join(bank.BANKS, ten_bank + '.bank')
    if not os.path.isfile(p):
        p = os.path.join(bank.BANKS, ten_bank)
    ds, fsb, _r = payload(p, loc)
    print('bank %s  %d byte  %d subsound co chunk 0x0B' % (os.path.basename(p), len(fsb), len(ds)))
    thay = 0
    for ten, kenh, rate, pl in ds:
        if thu(ten, kenh, rate, pl, fsb, None):
            thay += 1
    print('so khoi tim duoc bang CRC: %d / %d' % (thay, len(ds)))


if __name__ == '__main__':
    main()
