# -*- coding: utf-8 -*-
"""Do ti le `dinh giai ma / dinh THAT` (chunk 0x0D) tren nhieu tep da ship.

    python do_dinh.py chon [--moi-nhom=10] [--ra=C:/tmp/mau_dinh]
    python do_dinh.py phan-tich <thu muc .raw>

VI SAO. Ba tep do truoc cho ti le 10,05 / 30,61 / 3,32 — nhung ba tep khong noi
duoc dieu gi ve NGUYEN NHAN. Neu giai ma sai codebook chi lam SAI DO LOI thi
ti le phai la MOT HANG SO trong ca nhom (moi tep cung mot codebook); khi do sua
bang mot phep chia va am thanh gan dung tro lai. Neu ti le tan loan thi noi dung
da la rac, va chuan hoa chi lam tieng rit nho hon.

Phan nhom theo `setup_id` chu khong theo ten bank: `0x84d3ac87` = 1415 tep,
`0x38aa59ce` = 56 tep (toan nhac), `0xc55efa16` = 27 tep (nhom DUY NHAT giai ma
dung, dung lam chuan).
"""
import json
import os
import shutil
import struct
import sys

import bank
import cay
import xem_chunk

#: Tep .raw cua ban DANG LAM. Ban 1.31 co 1647 subsound, ban VN co 1498 — tro
#: cung vao `assets_ref/audio` thi ban nay do tren am thanh cua ban kia.
AUDIO = os.path.join(cay.dich_anh(), 'audio')
PHU_DINH = 0x0D   # payload 4 byte = bien do dinh cua subsound (float)


def dinh_that(p, ten_muon):
    """{(ten subsound): (sid, dinh)} cho mot bank."""
    fsb = xem_chunk.mo_fsb(p)
    _v, nsub, shsize, ntsize, dsize, codec = struct.unpack_from('<6I', fsb, 4)
    hdr = fsb[0x3c:0x3c + shsize]
    nt = fsb[0x3c + shsize:0x3c + shsize + ntsize]
    ten = []
    for k in range(nsub):
        o, = struct.unpack_from('<I', nt, 4 * k)
        e = nt.find(b'\x00', o)
        ten.append(nt[o:e].decode('utf-8', 'replace'))
    ra = {}
    off = 0
    for k in range(nsub):
        m, = struct.unpack_from('<Q', hdr, off)
        off += 8
        con = m & 1
        sid = None
        dinh = None
        while con:
            x, = struct.unpack_from('<I', hdr, off)
            off += 4
            t = (x >> 25) & 0x7F
            s_sz = (x >> 1) & 0xFFFFFF
            con = x & 1
            pl = hdr[off:off + s_sz]
            off += s_sz
            if t == bank.PHU_SETUP and len(pl) >= 4:
                sid, = struct.unpack_from('<I', pl, 0)
            elif t == PHU_DINH and len(pl) >= 4:
                dinh, = struct.unpack_from('<f', pl, 0)
        ra[ten[k]] = (sid, dinh)
    return ra


def tim_bank(ten_bank):
    for duoi in ('.bank',):
        p = os.path.join(bank.BANKS, ten_bank + duoi)
        if os.path.isfile(p):
            return p
    return None


def chon(moi_nhom, ra):
    d = {}
    for f in sorted(os.listdir(AUDIO)):
        if not f.endswith('.ogg'):
            continue
        ten_bank, _, ten_sub = f[:-4].partition('__')
        p = tim_bank(ten_bank)
        if p is None:
            continue
        if p not in d:
            d[p] = dinh_that(p, None)
        if ten_sub not in d[p]:
            continue
        sid, dinh = d[p][ten_sub]
        d.setdefault('__nhom', {}).setdefault(sid, []).append((f, dinh))
    nhom = d.pop('__nhom')
    os.makedirs(ra, exist_ok=True)
    for f in os.listdir(ra):
        os.remove(os.path.join(ra, f))
    print('%-12s %6s  %s' % ('setup_id', 'so tep', 'nhom'))
    mau = []
    for sid, ds in sorted(nhom.items(), key=lambda x: -len(x[1])):
        print('  0x%08x %6d  %s' % (sid, len(ds), 'nhom DUNG (chuan)' if sid == 0xc55efa16 else 'nhom HONG'))
        # Rai deu tren ca nhom, khong lay 10 tep dau (deu cung mot bank).
        n = min(moi_nhom, len(ds))
        for i in range(n):
            j = i * len(ds) // n
            f, dinh = ds[j]
            shutil.copyfile(os.path.join(AUDIO, f), os.path.join(ra, f))
            mau.append({'tep': f, 'sid': sid, 'dinh_that': dinh})
    with open(os.path.join(ra, 'mau.json'), 'w') as fh:
        json.dump(mau, fh, indent=1)
    print('chep %d tep vao %s' % (len(mau), ra))


def phan_tich(thu_muc):
    import numpy as np
    mau = json.load(open(os.path.join(thu_muc, 'mau.json')))
    theo = {}
    print('%-38s %10s %10s %9s' % ('tep', 'dinh that', 'dinh gd', 'ti le'))
    for m in mau:
        p = os.path.join(thu_muc, m['tep'][:-4] + '.raw')
        if not os.path.isfile(p):
            print('%-38s thieu .raw' % m['tep'][:38])
            continue
        b = np.fromfile(p, dtype=np.uint8)
        if b.size < 8:
            print('%-38s .raw rong' % m['tep'][:38])
            continue
        n, = np.frombuffer(b[:4].tobytes(), dtype=np.uint32)
        x = np.frombuffer(b[8:8 + n * 8].tobytes(), dtype=np.float32)
        dinh = float(np.abs(x).max()) if x.size else 0.0
        ti = dinh / m['dinh_that'] if m['dinh_that'] else float('nan')
        theo.setdefault(m['sid'], []).append(ti)
        print('%-38s %10.4f %10.4f %9.3f' % (m['tep'][:38], m['dinh_that'], dinh, ti))
    print()
    for sid, ds in sorted(theo.items()):
        a = np.array(ds)
        print('setup_id 0x%08x  n=%-3d  ti le: min %.2f  max %.2f  trung vi %.2f  lech chuan %.2f  (tan so %.2f)'
              % (sid, len(a), a.min(), a.max(), float(np.median(a)), float(a.std()),
                 a.max() / a.min() if a.min() > 0 else float('inf')))


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__.split('\n')[3].strip())
    if sys.argv[1] == 'chon':
        moi = 10
        ra = 'C:/tmp/mau_dinh'
        for x in sys.argv[2:]:
            if x.startswith('--moi-nhom='):
                moi = int(x.split('=')[1])
            elif x.startswith('--ra='):
                ra = x.split('=', 1)[1]
        chon(moi, ra)
    else:
        phan_tich(sys.argv[2] if len(sys.argv) > 2 else 'C:/tmp/mau_dinh')


if __name__ == '__main__':
    main()
