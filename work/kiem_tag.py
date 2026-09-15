# -*- coding: utf-8 -*-
"""Phep do tag da phu duoc bao nhieu — tinh tu CHINH BO CUC, khong tu long tin.

`emu_tags.py --cay` in ra "tron" khi no di het duoc cay ma khong chet. Nhung
"tron" khong co nghia la "du": PROBE_CAY xuat phat tu tung node CO TEN trong bo
cuc (`screens()`), chu khong tu goc file, nen tap do duoc chi la HOP CAC CAY CON
duoi node co ten, sau toi da `DEPTH_MAX`. Node nam ngoai hop do khong bao gio
duoc do, va khong co dong nao bao la thieu.

Script nay dem doc lap:

    do-duoc   = so node co trong tags_cay.json cho man do
    do-duoc-rong = so node thuoc hop tren, dem tu layout_ref
    ngoai-tam = so node cua bo cuc nam NGOAI hop tren (phep do khong voi toi)

nho vay moi biet con thieu bao nhieu la do PHEP DO, bao nhieu la do BO CUC.

    python kiem_tag.py [tags_cay.json] [--layout <thu muc>]
"""
import argparse
import collections
import json
import os
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
LAYOUT = HERE.parent.parent / 'bravecross-game' / 'layout_ref'

# Phai khop DEPTH_MAX cua emu_tags.py — lech mot ly la bao sai.
DEPTH_MAX = 8

TEN_HOP_LE = re.compile(r'^[A-Za-z_]\w*$')


def dem_rong(layout_dir, depth_max=DEPTH_MAX):
    """[(ten .xgg, do-duoc, qua-sau, khong-neo, co-tag, tong)] — dem tu bo cuc.

    `screens()` ben emu_tags.py gom MOI node co ten trong ca cay (khong chan do
    sau), roi moi cay con duoi no bi chan o `depth_max`. Nen phai dem y het:
    neo khong chan, con chau chan theo do sau TUONG DOI so voi neo.

    Ba so nay khac nhau ve CACH SUA, nen phai tach:
      do-duoc   — phep do voi toi
      qua-sau   — co neo nhung sau hon `depth_max`  -> nang `--sau`
      khong-neo — khong co node co ten nao o tren  -> phai di tu goc file

    Hai so cuoi la phep dem DOC LAP, tren NODE THAT chu khong tren duong do:
      co-tag    — node co truong `tag` khac null trong bo cuc (sau khi ghep)
      tong      — moi node cua bo cuc
    Day moi la con so duoc phep trich ra lam "do phu tag"; `do-duoc` dem theo
    DUONG nen dem trung node co ten long nhau (xem `main`).
    """
    out = []
    for f in sorted(pathlib.Path(layout_dir).glob('*.json')):
        doc = json.loads(f.read_text('utf-8'))
        duoc, sau, khong, co_tag, tong = 0, 0, 0, 0, 0

        def gom(n, sau_neo, co_neo):
            nonlocal duoc, sau, khong, co_tag, tong
            tong += 1
            if n.get('tag') is not None:
                co_tag += 1
            nm = n.get('name') or ''
            if nm and TEN_HOP_LE.match(nm):
                co_neo = True
                sau_neo = 0
            if not co_neo:
                khong += 1
            elif sau_neo > depth_max:
                sau += 1
            else:
                duoc += 1
            for c in n.get('children', []):
                gom(c, sau_neo + 1, co_neo)

        for r in doc.get('roots', []):
            gom(r, 0, False)
        out.append((doc.get('file') or (f.stem + '.xgg'), duoc, sau, khong,
                    co_tag, tong))
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('tags', nargs='?', default=str(HERE / 'tags_cay.json'))
    ap.add_argument('--layout', default=str(LAYOUT))
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')

    doc = json.loads(pathlib.Path(a.tags).read_text('utf-8'))
    cay = doc.get('cay', {})
    xong = doc.get('xong', {})

    if not pathlib.Path(a.layout).is_dir():
        raise SystemExit('khong thay bo cuc: %s' % a.layout)
    bang = {t: (duoc, sau, khong, co_tag, tong)
            for t, duoc, sau, khong, co_tag, tong in dem_rong(a.layout)}

    thieu, sau_tong, khong_tong, do_tong, phai_tong = [], 0, 0, 0, 0
    co_tag_tong, tong_tong = 0, 0
    for man, kd in sorted(bang.items()):
        got = len(cay.get(man, {}))
        do_tong += got
        phai_tong += kd[0]
        sau_tong += kd[1]
        khong_tong += kd[2]
        co_tag_tong += kd[3]
        tong_tong += kd[4]
        if got < kd[0]:
            thieu.append((man, got, kd[0], kd[1] + kd[2], bool(xong.get(man))))

    print('man co bo cuc        : %d' % len(bang))
    # Con so DUOC PHEP TRICH: dem tren NODE THAT cua bo cuc, khong theo duong do.
    print('node co tag (that)   : %d / %d (%.1f%%)'
          % (co_tag_tong, tong_tong, 100.0 * co_tag_tong / tong_tong))
    print('node do duoc         : %d / %d phai do duoc' % (do_tong, phai_tong))
    # Hai ve KHONG cung don vi, dung doc dong tren thanh "% phu". Long nhau:
    # mot node co ten nam TRONG cay con cua mot node co ten khac duoc di HAI lan
    # — mot lan duoi duong cua neo ngoai, mot lan khi chinh no lam neo — nen
    # `do` dem trung. Do duoc: UI_Equipment 1746 do / 479 phai, UI_Hero 2106/949.
    # Con so co nghia la bang theo TUNG MAN ben duoi, khong phai dong tong nay.
    print('  (hai ve khac don vi: node co ten long nhau bi dem hai lan — '
          'doc bang tung man, dung doc dong nay ra % phu)')
    print('node QUA SAU (co neo, > %d) : %d' % (DEPTH_MAX, sau_tong))
    print('node KHONG NEO       : %d  (khong co node co ten nao o tren)'
          % khong_tong)
    print('man do THIEU so voi bo cuc: %d' % len(thieu))
    if thieu:
        print()
        print('%-46s %6s %6s %7s  %s'
              % ('man', 'do-duoc', 'phai-co', 'ngoai', 'di tron?'))
        for man, got, kd, ngoai, tron in sorted(thieu, key=lambda r: r[1] - r[2]):
            print('%-46s %6d %6d %7d  %s'
                  % (man[:46], got, kd, ngoai, 'co' if tron else 'KHONG'))
    return 0


if __name__ == '__main__':
    sys.exit(main())
