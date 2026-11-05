# -*- coding: utf-8 -*-
"""phan_tich_vitri.py — doc `frida/trace_danh.out.jsonl` cua `trace_vitri.js` va in so do.

    python -I phan_tich_vitri.py [duong_dan.jsonl]

Ba khoi:
  1. DAN TRAN — moi ban ghi `dan*`: liet ke don vi theo x, kem priority (`uu`), tam ban
     (`tam`), AttackLocation (`al`). Dung de doi chieu THU TU va BUOC 110 px cua sim.
  2. DUONG DI — moi `di`: quang X lon nhat tung don vi, khoang cach dong doi nho nhat
     theo moc thoi gian, va phan bo `dist` (khoang cach toi muc tieu luc dang di).
  3. KIEM TRA — so ban ghi, so mover, khoang thoi gian.
"""
import collections
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
MAC_DINH = os.path.join(HERE, 'trace_danh.out.jsonl')


def doc(p):
    ra = []
    with open(p, encoding='utf-8') as f:
        for dong in f:
            dong = dong.strip()
            if not dong or dong.startswith('['):
                continue
            try:
                ra.append(json.loads(dong))
            except Exception:
                pass
    return ra


def pct(ds, q):
    if not ds:
        return None
    ds = sorted(ds)
    return ds[max(0, min(len(ds) - 1, int(len(ds) * q)))]


def main():
    p = sys.argv[1] if len(sys.argv) > 1 else MAC_DINH
    if not os.path.exists(p):
        print('khong thay', p)
        return 1
    ds = doc(p)
    print('tep: %s\nban ghi: %d' % (p, len(ds)))

    # ── 1) DÀN TRẬN
    for ten in ('dan20c', 'dan1bc', 'dan200'):
        for b in [x for x in ds if x.get('ten') == ten]:
            print('\n[%s] n=%s' % (ten, b.get('n')))
            for u in sorted(b.get('ds') or [], key=lambda z: -(z.get('x') or -1e9)):
                print('   x=%8.1f y=%7.1f uu=%s tam=%s al=%s co308=%s' % (
                    u.get('x') or 0, u.get('y') or 0, u.get('uu'),
                    u.get('tam'), u.get('al'), u.get('co308')))

    # ── 2) ĐƯỜNG ĐI
    di = [x for x in ds if x.get('ten') == 'di' and x.get('x') is not None]
    if not di:
        print('\n[di] KHONG CO ban ghi — hook 0x413a98 khong ban (xem stderr)')
    else:
        t0 = min(x['t'] for x in di)
        t1 = max(x['t'] for x in di)
        print('\n[di] %d mau · %d mover · %.1f giay' % (
            len(di), len(set(x['sp'] for x in di)), (t1 - t0) / 1000.0))

        theo = collections.defaultdict(list)
        for x in di:
            theo[x['sp']].append(x)
        print('[di] quang X tung don vi (chi don vi co >=5 mau):')
        for sp, ls in theo.items():
            if len(ls) < 5:
                continue
            xs = [z['x'] for z in ls]
            print('   %-14s mau=%4d x=%7.1f..%7.1f  di=%6.1f px' % (
                sp, len(ls), min(xs), max(xs), max(xs) - min(xs)))

        # khoảng cách đồng đội nhỏ nhất theo từng mốc 0,5 s
        moc = collections.defaultdict(list)
        for x in di:
            moc[int((x['t'] - t0) / 500)].append(x)
        gan, rong = None, []
        for k, ls in sorted(moc.items()):
            if len(ls) < 2:
                continue
            lo = min(z['x'] for z in ls)
            hi = max(z['x'] for z in ls)
            rong.append(hi - lo)
            for i in range(len(ls)):
                for j in range(i + 1, len(ls)):
                    d = abs(ls[i]['x'] - ls[j]['x'])
                    if gan is None or d < gan:
                        gan = d
        if rong:
            print('[di] do rong hang (max-min x): trung vi %.0f px · lon nhat %.0f px'
                  % (pct(rong, 0.5), max(rong)))
        if gan is not None:
            print('[di] hai don vi gan nhau nhat (truc X): %.0f px' % gan)

        dist = [x['dist'] for x in di if x.get('dist') is not None]
        if dist:
            print('[di] khoang cach toi muc tieu khi DANG DI: min=%.0f p25=%.0f '
                  'trung_vi=%.0f p75=%.0f max=%.0f'
                  % (min(dist), pct(dist, .25), pct(dist, .5), pct(dist, .75), max(dist)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
