# -*- coding: utf-8 -*-
"""_chay_het.py — CỔNG của lớp offline: chạy MỌI bộ thử `_thu_*.lua` bằng chính
`lua51.dll` của BraveCross (không cần game, không cần máy), rồi cộng số.

    python _chay_het.py

Vì sao có cổng này: tới 30/10 lớp offline có **12 bộ thử** mỗi bộ một tệp, chạy
lẻ từng tệp bằng `_thu_nha_cua.py <tệp>`. Một cổng gom lại cho biết NGAY lượt
nào làm đỏ bộ nào — cùng vai với `npm run test:do_phu` bên server.

Mã thoát: 0 = mọi bộ XANH · 1 = có bộ đỏ (hoặc không nạp được).
"""
import glob
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SC = os.path.join(HERE, 'deploy', 'plain', 'sc')
DLL = os.path.abspath(os.path.join(HERE, '..', '..', '..', 'bravecross-ax',
                                   'build', 'bin', 'BraveCross', 'lua51.dll'))
KQ = re.compile(r'KET QUA: dat (\d+), hong (\d+)')


def main():
    if not os.path.exists(DLL):
        print('KHONG thay lua51.dll: %s' % DLL)
        return 1
    files = sorted(glob.glob(os.path.join(HERE, '_thu_*.lua')))
    if not files:
        print('khong co bo thu _thu_*.lua nao')
        return 1

    tong_dat = tong_hong = 0
    do = []
    for f in files:
        ten = os.path.basename(f)
        out = os.popen('python "%s" "%s" 2>&1' % (os.path.join(HERE, '_thu_nha_cua.py'), ten))
        noi_dung = out.read()
        out.close()
        m = KQ.search(noi_dung)
        if m is None:
            do.append(ten)
            dong = [x for x in noi_dung.strip().splitlines() if x.strip()]
            print('DO   %-28s %s' % (ten, (dong[-1] if dong else 'khong co dau ra')[:70]))
            continue
        dat, hong = int(m.group(1)), int(m.group(2))
        tong_dat += dat
        tong_hong += hong
        if hong:
            do.append(ten)
        print('%s %-28s dat %3d, hong %d' % ('XANH' if hong == 0 else 'DO  ', ten, dat, hong))

    print('')
    print('TONG: %d tep · dat %d · hong %d · do %d' % (len(files), tong_dat, tong_hong, len(do)))
    if do:
        print('BO DO: ' + ', '.join(do))
    return 0 if not do else 1


if __name__ == '__main__':
    sys.exit(main())
