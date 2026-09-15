# -*- coding: utf-8 -*-
"""Quet mot file xem no mang nhung khoi setup Vorbis nao, o dau, dai bao nhieu.

    python vorbis_probe.py ../vn/apk/lib/armeabi-v7a/libfmod.so
    python vorbis_probe.py <file> <so_kenh>

Bo doc khoi setup nam o `bank.py` (`doc_setup`) — MOT dinh nghia duy nhat, bam
sat libvorbis tung bit mot. File nay chi con phan quet: tim moi cho co
`\\x05vorbis` roi thu doc. No la thu da tim ra ba khoi setup ma cac bank dung
trong `libfmod.so` (bank FSB5 khong mang khoi setup, chi tham chieu bang
`setup_id`).

Vi sao phai thu doc chu khong chi tim chuoi: trong 1,2 MB cua libfmod.so co
chuoi `\\x05vorbis` nam trong du lieu khac nua, doc vao la truot ngay. Bo doc
nghiêm ngat den muc bit framing cuoi cung phai bang 1, nen no tu loc dung.
"""
import sys

import bank


def quet(b, kenh):
    """Tra danh sach (offset, do_dai, so_codebook, [blockflag tung mode])."""
    ra = []
    i = -1
    while True:
        i = b.find(b'\x05vorbis', i + 1)
        if i < 0:
            break
        try:
            n, ncb, fl = bank.doc_setup(b, i, kenh)
        except (ValueError, IndexError):
            continue
        ra.append((i, n, ncb, fl))
    return ra


if __name__ == '__main__':
    if len(sys.argv) < 2:
        sys.exit(__doc__.split('\n')[3].strip())
    kenh = int(sys.argv[2]) if len(sys.argv) > 2 else 2
    with open(sys.argv[1], 'rb') as f:
        b = f.read()
    ds = quet(b, kenh)
    print('== %s  %d byte  doc voi %d kenh: %d khoi setup'
          % (sys.argv[1], len(b), kenh, len(ds)))
    for off, n, ncb, fl in ds:
        print('  @%-9d dai %-6d codebook=%-3d mode=%-3d khoi=%s'
              % (off, n, ncb, len(fl), fl))
    # Trong so nay, khoi nao ma cac bank dung?
    for sid, (at, dai) in sorted(bank.SETUP_AT.items()):
        for off, n, _ncb, _fl in ds:
            if off == at:
                print('  bank dung: 0x%08x @%d dai %d (bang nay: %s)'
                      % (sid, at, dai, 'khop' if n == dai else 'LECH %d' % n))
