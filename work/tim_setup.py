# -*- coding: utf-8 -*-
"""Thu MOI khoi setup Vorbis trong libfmod.so voi mot subsound cua ban goc.

    python tim_setup.py <ten bank> <ten subsound> [--ra <thu muc>]

VI SAO CAN. `bank.py` ghep file .ogg bang khoi setup tra theo `setup_id` trong
bang `SETUP_AT` — mot bang VIET CUNG, va bang do chi duoc kiem bang DO DAI
(`vorbis_probe.py` in ra `khop`/`LECH`), khong bang noi dung. Do la mot lo hong
that: do duoc la khoi o `SETUP_AT[0xc55efa16]` co `zlib.crc32` DUNG BANG id,
con hai khoi kia thi khong — va dung hai khoi do giai ma ra nhieu toan thang.

Do duoc bang `tools/do_tieng.gd` ben repo game:

    IceWitch (setup 0xc55efa16, CRC khop)  dinh 0,8133  nang>8kHz 25,8%
    Archer   (setup 0x84d3ac87, CRC lech)  dinh 5,3447  nang>8kHz 88,3%

Cong cu nay khong doan: no thu LAN LUOT ca 33 khoi `\\x05vorbis` co trong
libfmod.so voi cung mot subsound, roi de ben do noi khoi nao ra am thanh sach.
"""
import os
import struct
import sys

import bank
import vorbis_probe


def cac_khoi_ung_vien(kenh_thu):
    """[(offset, goi_setup, [so_kenh doc duoc])] cho moi khoi `\\x05vorbis` trong libfmod.

    Mot khoi chi vao danh sach khi `doc_setup` phan tich TRON no (tra ve dung do
    dai) o it nhat mot so kenh — khoi khong phan tich duoc thi khong dung duoc.
    """
    with open(bank.LIBFMOD, 'rb') as f:
        d = f.read()
    ra = []
    for off, n, _ncb, _fl in vorbis_probe.quet(d, 2):
        goi = d[off:off + n]
        kenh = []
        for k in kenh_thu:
            try:
                n2, _ncb2, _fl2 = bank.doc_setup(goi, 0, k)
            except (ValueError, IndexError):
                continue
            if n2 == n:
                kenh.append(k)
        if kenh:
            ra.append((off, goi, kenh))
    return ra


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__.split('\n')[3].strip())
    ten_bank, ten_sub = sys.argv[1], sys.argv[2]
    ra = None
    ra_kenh = '1,2'
    if '--ra' in sys.argv:
        ra = sys.argv[sys.argv.index('--ra') + 1]
    if '--kenh' in sys.argv:
        ra_kenh = sys.argv[sys.argv.index('--kenh') + 1]
    duong = os.path.join(bank.BANKS, ten_bank + '.bank')
    if not os.path.isfile(duong):
        duong = os.path.join(bank.BANKS, ten_bank)
    r = bank.mo_bank(duong)
    if r is None:
        sys.exit('khong doc duoc bank %s' % duong)
    s = None
    for x in r['subs']:
        if x['ten'] == ten_sub:
            s = x
    if s is None:
        sys.exit('bank %s khong co subsound %s' % (ten_bank, ten_sub))
    cac = bank.cac_goi(r['dat'], s)
    print('bank %s  subsound %s  kenh_fsb %d  rate %d  mau %d  %d goi'
          % (ten_bank, ten_sub, s['kenh'], s['rate'], s['mau'], len(cac)))
    if ra is None:
        ra = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                          '..', '..', 'tmp_setup')
    os.makedirs(ra, exist_ok=True)
    # Xoa file cu de lan do sau khong lan voi lan truoc.
    for f in os.listdir(ra):
        if f.endswith('.ogg'):
            os.remove(os.path.join(ra, f))

    n = 0
    truot = 0
    co = cac_khoi_ung_vien(kenh_thu(ra_kenh))
    print('khoi ung vien: %d  (moi khoi: cac so kenh doc duoc)' % len(co))
    for off, goi, ds_kenh in co:
        khoi = None
        for k in ds_kenh:
            try:
                _n2, _ncb2, fl2 = bank.doc_setup(goi, 0, k)
            except (ValueError, IndexError):
                continue
            khoi = bank._khoi(fl2)
            break
        for kenh in ds_kenh:
            try:
                b = bank.ghep_ogg(goi, khoi, kenh, s['rate'], cac, s['mau'])
            except (ValueError, IndexError, KeyError):
                truot += 1
                continue
            tep = 'o%d_k%d.ogg' % (off, kenh)
            with open(os.path.join(ra, tep), 'wb') as f:
                f.write(b)
            n += 1
    print('ghi %d bien the vao %s  (%d to hop bi bo vi mode khong co trong setup)'
          % (n, ra, truot))


def kenh_thu(s):
    return [int(x) for x in s.split(',') if x.strip()]


if __name__ == '__main__':
    main()
