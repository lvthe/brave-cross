# -*- coding: utf-8 -*-
"""Ma hoa nguoc ve dinh dang 'sngFile' — dao cua sng_decrypt.py.

Dung de nhet file da sua (vi du lop offline) tro lai game dung dinh dang goc.
Phep XOR doi xung nen ham ma hoa gan nhu trung ham giai ma; khac o cho phai
gan lai magic va, voi mot so loai file, nen gzip truoc.

    python sng_encrypt.py <src_dir> <dst_dir> [glob]
    python sng_encrypt.py --selftest <thu_muc_file_goc>
"""
import sys, os, glob, gzip, io

from sng_decrypt import KEY, MAGIC, NOT_TABLE, GZIP_MAGIC, unpack, is_encrypted

# Cac duoi duoc nen gzip truoc khi ma hoa (xem sng_decrypt.unpack).
GZIP_EXT = {'.pkm', '.plist', '.xgg', '.xml', '.json'}


def encrypt(plain, gzip_it=False):
    if gzip_it:
        # mtime=0 de ket qua tat dinh, chay hai lan ra cung mot file
        buf = io.BytesIO()
        with gzip.GzipFile(fileobj=buf, mode='wb', mtime=0) as fp:
            fp.write(plain)
        plain = buf.getvalue()
    n = min(256, len(plain))
    head = bytes(c ^ KEY[i % 32] for i, c in enumerate(plain[:n]))
    return head + plain[n:].translate(NOT_TABLE) + MAGIC


def pack(plain, name=''):
    return encrypt(plain, os.path.splitext(name)[1].lower() in GZIP_EXT)


def selftest(root):
    """Ma hoa lai chinh cac file goc va doi chieu.

    Voi file khong nen gzip (.lua, .sc...) ket qua phai trung tung byte.
    Voi file gzip thi chi doi hoi giai ma lai ra dung noi dung ban dau, vi
    luong gzip phu thuoc bo nen.
    """
    n_exact = n_content = n_skip = n_bad = 0
    for path in glob.glob(os.path.join(root, '**', '*'), recursive=True):
        if not os.path.isfile(path):
            continue
        orig = open(path, 'rb').read()
        if not is_encrypted(orig):
            n_skip += 1
            continue
        plain = unpack(orig)
        again = pack(plain, path)
        if again == orig:
            n_exact += 1
        elif unpack(again) == plain:
            n_content += 1
        else:
            n_bad += 1
            if n_bad <= 5:
                print('   HONG:', path)
    print('trung tung byte      : %d' % n_exact)
    print('trung noi dung (gzip): %d' % n_content)
    print('khong ma hoa (bo qua): %d' % n_skip)
    print('SAI                  : %d' % n_bad)
    return n_bad == 0


def main():
    if sys.argv[1:2] == ['--selftest']:
        sys.exit(0 if selftest(sys.argv[2]) else 1)

    src, dst = sys.argv[1], sys.argv[2]
    pattern = sys.argv[3] if len(sys.argv) > 3 else '**/*'
    n = 0
    for path in glob.glob(os.path.join(src, pattern), recursive=True):
        if not os.path.isfile(path):
            continue
        outp = os.path.join(dst, os.path.relpath(path, src))
        os.makedirs(os.path.dirname(outp), exist_ok=True)
        open(outp, 'wb').write(pack(open(path, 'rb').read(), path))
        n += 1
    print('encrypted: %d' % n)


if __name__ == '__main__':
    main()
