# -*- coding: utf-8 -*-
"""Dan nhieu anh .pkm thanh MOT tam de xem het trong mot lan.

Thu muc anh cua ban goc co hang tram file ten kieu ui_background135.pkm — mo
tung cai de tim mot khung vien thi mat ca buoi. Tam dan nay thu nho moi anh vao
mot o roi xep luoi, nhin phat la biet cai nao dung.

    python contact.py <thu_muc> --out tam.png
    python contact.py <thu_muc> --out tam.png --cell 160 --cols 8

Nen o duoi anh la o co-vua xam de phan biet vung trong suot voi vung mau trang.
"""
import os, sys, glob, argparse

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from sprites import write_png, SpriteError
from scenes import decode


def shrink(rgba, w, h, box):
    """Thu nho bang cach lay mau diem gan nhat. Du de nhan dang, va khong keo
    them phu thuoc nao."""
    if w <= 0 or h <= 0:
        return b'', 0, 0
    k = min(box / float(w), box / float(h), 1.0)
    nw, nh = max(1, int(w * k)), max(1, int(h * k))
    out = bytearray(nw * nh * 4)
    for y in range(nh):
        sy = min(h - 1, int(y / k)) if k < 1.0 else y
        srow = sy * w * 4
        drow = y * nw * 4
        for x in range(nw):
            sx = min(w - 1, int(x / k)) if k < 1.0 else x
            s = srow + sx * 4
            d = drow + x * 4
            out[d:d + 4] = rgba[s:s + 4]
    return bytes(out), nw, nh


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('folder')
    ap.add_argument('--out', required=True)
    ap.add_argument('--cell', type=int, default=150)
    ap.add_argument('--cols', type=int, default=9)
    ap.add_argument('--limit', type=int, default=0, help='0 = tat ca')
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')

    files = sorted(glob.glob(os.path.join(a.folder, '*.pkm')))
    if a.limit:
        files = files[:a.limit]
    if not files:
        sys.exit('khong co .pkm trong %s' % a.folder)

    cell = a.cell
    cols = a.cols
    rows = (len(files) + cols - 1) // cols
    W, H = cols * cell, rows * cell
    canvas = bytearray(W * H * 4)

    # nen o co-vua de nhin ra vung trong suot
    for y in range(H):
        for x in range(W):
            v = 60 if ((x // 8) + (y // 8)) % 2 else 45
            d = (y * W + x) * 4
            canvas[d] = canvas[d + 1] = canvas[d + 2] = v
            canvas[d + 3] = 255

    for i, p in enumerate(files):
        try:
            rgba, w, h = decode(p)
        except (SpriteError, OSError, ValueError) as e:
            print('  bo qua %-32s %s' % (os.path.basename(p), e))
            continue
        small, sw, sh = shrink(rgba, w, h, cell - 8)
        ox = (i % cols) * cell + (cell - sw) // 2
        oy = (i // cols) * cell + (cell - sh) // 2
        for y in range(sh):
            for x in range(sw):
                s = (y * sw + x) * 4
                al = small[s + 3]
                if al == 0:
                    continue
                d = ((oy + y) * W + ox + x) * 4
                for c in range(3):
                    canvas[d + c] = (small[s + c] * al + canvas[d + c] * (255 - al)) // 255
    write_png(a.out, W, H, bytes(canvas))
    print('ghi %s  %dx%d  (%d anh, %d cot)' % (a.out, W, H, len(files), cols))
    print('thu tu doc tu trai sang phai, tren xuong duoi:')
    for i, p in enumerate(files):
        end = '\n' if i % cols == cols - 1 else '  '
        print('%2d %-22s' % (i + 1, os.path.splitext(os.path.basename(p))[0]), end=end)
    print()
    return 0


if __name__ == '__main__':
    sys.exit(main())
