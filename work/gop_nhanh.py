# -*- coding: utf-8 -*-
"""So ba nhanh quay neo va gop lai. Chay sau khi doi_chung.sh xong.

    python gop_nhanh.py            # chi so sanh, khong ghi
    python gop_nhanh.py --ghi      # gop vao tags_cay.json

Ket qua cua phep doi chung nay duoc ghi lai o README, muc "Quay neo", va o
ROADMAP phan noi ve tran do. Giu lai script de con do lai duoc, khong phai de
chay lai cho vui: no cung cap PHEP DO CHINH (tap neo toi duoc co phai tien to
lien mach hay khong), chu khong chi tong so node.

Ba nhanh:
  xoaytungnac = ban dau, `k = xoay % len(names)` (buoc nhay chi nhich trong 16 cho dau)
  khongxoay   = --khong-xoay
  traideu     = `k = xoay * len(names) // LUOT_MAX`

Phep so sanh CHINH khong phai tong so node, ma la TAP NEO TOI DUOC: voi moi man,
lay chi so (1-based) trong danh sach neo goc cua `emu_tags.screens()`, roi hoi
tap do co phai mot TIEN TO lien mach tu 1 hay khong. Do la gia thuyet duoc neu
ra TRUOC khi do: khong quay thi van tien to; trai deu thi phai co lo / lech.
"""
import argparse
import json
import pathlib
import sys

# Nay nam ngay canh emu_tags.py va tags_cay*.json nen lay theo thu muc cua
# chinh file — chay tu dau cung duoc. (Truoc o Temp thi phai lay theo CWD.)
HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import emu_tags as E                                   # noqa: E402

MAN = ('UI_ArmyGroup_Campsite_Info_960_640.xgg', 'UI_Destiny_960_640.xgg',
       'UI_Friends_960_640.xgg', 'UI_Hero_960_640.xgg',
       'UI_Mail_960_640.xgg', 'UI_Main_ControlPanel_960_640.xgg')
NHANH = (('xoaytungnac', 'tags_cay.xoaytungnac.json'),
         ('khongxoay', 'tags_cay.khongxoay.json'),
         ('traideu', 'tags_cay.traideu.json'))


def doc(ten):
    return json.loads((HERE / ten).read_text('utf-8'))


def neo_toi_duoc(doc, man, names):
    """(so neo toi duoc, chi so 1-based da sap, co phai tien to lien mach?)"""
    toi = {k for k in doc['cay'].get(man, {}) if '/' not in k}
    idx = sorted(names.index(n) + 1 for n in toi if n in names)
    lien = idx == list(range(1, len(idx) + 1))
    return len(idx), idx, lien


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--ghi', action='store_true',
                    help='gop hop cac duong do duoc vao tags_cay.json')
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')

    names_of = {fn: ns for fn, ns in E.screens()}
    docs = {nhan: doc(ten) for nhan, ten in NHANH}
    thieu = [n for n, _ in NHANH if not (HERE / _).exists()]
    if thieu:
        raise SystemExit('thieu file nhanh: %s' % ', '.join(thieu))

    # --- 1. Kiem tinh toan ven: 281 man khong do lai phai GIONG NHAU ---
    # Bo 6 man trong MAN ra: chung da bi xoa khoi ban sao truoc khi do lai, nen
    # khac la dung y do, khong phai loi.
    print('=== kiem toan ven: cac man KHONG do lai phai giong het ===')
    goc = docs['xoaytungnac']['cay']
    for nhan, _ in NHANH[1:]:
        khac = [m for m in goc if m not in MAN
                and docs[nhan]['cay'].get(m) != goc[m]]
        print('  %-12s so man cay khac ban goc: %d %s'
              % (nhan, len(khac), khac[:3]))
        print('  %-12s 6 man do lai co mat lai khong: %d/6 %s'
              % ('', sum(1 for m in MAN if m in docs[nhan]['cay']),
                 'OK' if all(m in docs[nhan]['cay'] for m in MAN)
                 else 'THIEU (nhanh chua chay xong?)'))

    # --- 2. Phep so sanh CHINH: tap neo toi duoc ---
    print()
    print('=== tap NEO toi duoc (chi so 1-based) ===')
    for man in MAN:
        names = names_of.get(man, [])
        print('%-44s %d neo' % (man[:44], len(names)))
        for nhan, _ in NHANH:
            n, idx, lien = neo_toi_duoc(docs[nhan], man, names)
            khoang = ('%d..%d' % (idx[0], idx[-1])) if idx else '-'
            print('    %-12s %3d/%3d  %-10s %s  xong=%-5s luot=%s'
                  % (nhan, n, len(names), khoang,
                     'TIEN TO' if lien else 'CO LO <--',
                     docs[nhan]['xong'].get(man), docs[nhan]['lan'].get(man)))
        print('    node do duoc: %s'
              % '  '.join('%s=%d' % (nhan, len(docs[nhan]['cay'].get(man, {})))
                          for nhan, _ in NHANH))
    if not a.ghi:
        print()
        print('(chua ghi gi; them --ghi de gop vao tags_cay.json)')
        return

    # --- 3. Gop: hop cac duong do duoc, lay co trang thai tu nhanh phu nhat ---
    ra = doc('tags_cay.json')
    for man in MAN:
        hop = {}
        tot_nhat = None
        for nhan, _ in NHANH:
            d = docs[nhan]
            hop.update(d['cay'].get(man, {}))
            if tot_nhat is None or \
                    len(d['cay'].get(man, {})) > len(tot_nhat['cay'].get(man, {})):
                tot_nhat = d
        ra['cay'][man] = hop
        for khoa in ('xong', 'lan', 'bo', 'treo', 'cut', 'loaded'):
            if man in tot_nhat.get(khoa, {}):
                ra[khoa][man] = tot_nhat[khoa][man]
        ra['xong'][man] = any(docs[n]['xong'].get(man) for n, _ in NHANH)
        ra['lan'][man] = max(docs[n]['lan'].get(man, 0) for n, _ in NHANH)
        print('%-44s hop %d node (nhanh phu nhat: %d node)'
              % (man[:44], len(hop), len(tot_nhat['cay'].get(man, {}))))
    (HERE / 'tags_cay.json').write_text(
        json.dumps(ra, ensure_ascii=False, indent=1), encoding='utf-8')
    print('da ghi tags_cay.json')
    return 0


if __name__ == '__main__':
    sys.exit(main())
