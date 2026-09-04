# -*- coding: utf-8 -*-
"""Giai ma tai nguyen 'sngFile' (cocos2d-x + lop engine sng) cua game.

Cau truc file:
    file = payload + b'sngFile'          # 7 byte magic o cuoi
    payload[0:256] = plain XOR KEY32 (lap lai)
    payload[256:]  = plain XOR 0xFF
Sau khi giai ma, mot so loai (pkm/plist/xgg/xml/json) con duoc nen gzip.
"""
import sys, os, glob, gzip

KEY = bytes.fromhex('5e44dddbbfa6b41684c7cb8347a3ec3d5fcecb8607ad0d2e12379d79ed0fb468')
MAGIC = b'sngFile'
NOT_TABLE = bytes(i ^ 0xFF for i in range(256))
GZIP_MAGIC = bytes([0x1f, 0x8b, 0x08])


def is_encrypted(data):
    return data.endswith(MAGIC)


def decrypt(data):
    if data.endswith(MAGIC):
        data = data[:-len(MAGIC)]
    n = min(256, len(data))
    head = bytes(c ^ KEY[i % 32] for i, c in enumerate(data[:n]))
    return head + data[n:].translate(NOT_TABLE)


def unpack(data):
    out = decrypt(data)
    if out[:3] == GZIP_MAGIC:
        try:
            out = gzip.decompress(out)
        except Exception as exc:
            sys.stderr.write('gunzip failed: %s\n' % exc)
    return out


def main():
    src, dst = sys.argv[1], sys.argv[2]
    pattern = sys.argv[3] if len(sys.argv) > 3 else '**/*'
    n_dec = n_copy = 0
    for path in glob.glob(os.path.join(src, pattern), recursive=True):
        if not os.path.isfile(path):
            continue
        data = open(path, 'rb').read()
        outp = os.path.join(dst, os.path.relpath(path, src))
        os.makedirs(os.path.dirname(outp), exist_ok=True)
        if is_encrypted(data):
            open(outp, 'wb').write(unpack(data)); n_dec += 1
        else:
            open(outp, 'wb').write(data); n_copy += 1
    print('decrypted: %d, copied as-is: %d' % (n_dec, n_copy))


if __name__ == '__main__':
    main()
