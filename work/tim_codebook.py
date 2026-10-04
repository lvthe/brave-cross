# -*- coding: utf-8 -*-
"""Tim hai khoi setup con thieu (0x84d3ac87, 0x38aa59ce) o MOI cho co the.

    python tim_codebook.py [--ky-hieu]

Hai duong ma cac luot truoc CHUA di:

1. `libfmodstudio.so` — moi phep quet truoc chi nhin `libfmod.so`. Bank do
   FMOD *Studio* sinh ra, nen codebook rat co the nam o thu vien Studio.
2. Khoi setup KHONG mang chu ky `\\x05vorbis`. Chu ky la phan header packet do
   nguoi ghep .ogg them vao; neu FMOD luu khoi o dang TRAN thi moi phep quet
   theo chu ky deu mu. Dau khoi tran la 9 byte biet truoc:
   `00 00 00 00` (vorbis_version = 0), 1 byte so kenh, 4 byte rate nho —
   vd kenh 1 @48000 ra `00 00 00 00 01 80 BB 00 00`.

Voi moi mieng tim duoc, thu luon `bank.doc_setup` (co va khong co chu ky) chu
khong chi so CRC — mot khoi doc duoc ma CRC lech van dang ghi lai de nguoi sau
biet da tung thu.
"""
import glob
import os
import struct
import sys
import zlib

import bank
import vorbis_probe

CAN = {0x84d3ac87: 'Archer/SFX (1415 tep)', 0x38aa59ce: 'nhac (56 tep)'}
GOC = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
RATE = (44100, 48000, 22050, 32000)


def maus(kenh):
    """Cac byte dau cua mot setup header TRAN (khong chu ky) theo tung rate."""
    ra = []
    for r in RATE:
        ra.append(struct.pack('<IBI', 0, kenh, r), )
    return [struct.pack('<IBI', 0, kenh, r) for r in RATE]


def quet_tran(d):
    """[(offset, kenh, rate)] cho moi dau setup header TRAN trong du lieu."""
    ra = []
    for kenh in (1, 2, 6, 8):
        for r in RATE:
            mau = struct.pack('<IBI', 0, kenh, r)
            i = d.find(mau)
            while i >= 0:
                ra.append((i, kenh, r))
                i = d.find(mau, i + 1)
    return ra


def soi_tep(p, ds_ra):
    try:
        d = open(p, 'rb').read()
    except OSError:
        return
    kq = vorbis_probe.quet(d, 2)
    for off, n, _ncb, _fl in kq:
        c = zlib.crc32(d[off:off + n]) & 0xffffffff
        if c in CAN:
            ds_ra.append((p, 'co chu ky', off, n, c))
    for off, kenh, rate in quet_tran(d):
        # Do dai khong biet: thu vai do dai quanh 2..8 KB va so CRC.
        for n in (2182, 2575, 3006, 3189, 3528, 3547, 3768, 3832, 4225, 5256, 5824):
            if off + n > len(d):
                continue
            c = zlib.crc32(d[off:off + n]) & 0xffffffff
            if c in CAN:
                ds_ra.append((p, 'TRAN kenh=%d rate=%d n=%d' % (kenh, rate, n), off, n, c))
    if kq or quet_tran(d):
        print('  %-64s %d khoi chu ky, %d dau TRAN'
              % (os.path.relpath(p, GOC), len(kq), len(quet_tran(d))))


def main():
    ds_ra = []
    # 1. Moi thu vien dong tren dia.
    for pat in ('**/*.so', '**/*.so.*'):
        for p in glob.glob(os.path.join(GOC, pat), recursive=True):
            soi_tep(p, ds_ra)
    print('--- so file .so da quet: xong')
    for ten in ('Archer.bank', 'BGM.bank'):
        p = os.path.join(bank.BANKS, ten)
        if os.path.isfile(p):
            soi_tep(p, ds_ra)
    print('=== ket qua:')
    for p, kieu, off, n, c in ds_ra:
        print('  %s @%d len=%d crc=0x%08x  <- %s  (%s)'
              % (os.path.relpath(p, GOC), off, n, c, CAN[c], kieu))
    if not ds_ra:
        print('  KHONG tim thay khoi nao co CRC khop 0x84d3ac87 / 0x38aa59ce')


if __name__ == '__main__':
    main()
