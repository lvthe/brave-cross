# -*- coding: utf-8 -*-
"""So sanh kho tai nguyen giua hai ban bat ky.

    python inventory.py                          # cn125 (1.25) vs vn (1.26) — nhu cu
    python inventory.py --a cn125 --b cn131      # 1.25 vs 1.31
    python inventory.py --a vn --b cn131         # 1.26 vs 1.31

So sanh tren file GOC (chua giai ma): ma hoa la XOR tat dinh nen hash bang nhau
khi va chi khi noi dung bang nhau — du de phan loai giong / khac / chi mot ben.

Ban co OBB thi tai nguyen chinh nam trong OBB; lay them phan trong APK cho nhung
file OBB khong co. Ban khong OBB (layout kieu CN) chi co `apk/assets`.

Khoa trong JSON ket qua van la `only_cn` / `only_vn` — chung nghia la "chi co o
A" / "chi co o B" — giu nguyen ten cu de khong pha nguoi doc dang co.
"""
import argparse, os, sys, json, hashlib, collections

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cay

SLASH = os.sep


def inv(root):
    out = {}
    for dirpath, _, files in os.walk(root):
        for f in files:
            p = os.path.join(dirpath, f)
            rel = os.path.relpath(p, root).replace(SLASH, '/')
            out[rel] = (os.path.getsize(p), hashlib.md5(open(p, 'rb').read()).hexdigest())
    return out


def kho(ten):
    """Kho tai nguyen GOC cua mot ban. OBB truoc, APK sau (setdefault)."""
    goc = cay.goc_cua(ten)
    out = {}
    for sub in ('obb/assets', 'apk/assets'):
        d = os.path.join(goc, *sub.split('/'))
        if os.path.isdir(d):
            for k, v in inv(d).items():
                out.setdefault(k, v)
    if not out:
        sys.exit('ban %r khong co tai nguyen nao — kiem tra lai ten ban' % ten)
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--a', default='cn125', help='ban thu nhat (mac dinh cn125)')
    ap.add_argument('--b', default='vn', help='ban thu hai (mac dinh vn)')
    ap.add_argument('-o', '--out', help='file JSON ket qua')
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')

    out_path = a.out or ('inventory.json' if (a.a, a.b) == ('cn125', 'vn')
                         else 'inventory_%s_%s.json' % (a.a, a.b))

    cn = kho(a.a)
    vn = kho(a.b)

    only_cn = sorted(set(cn) - set(vn))
    only_vn = sorted(set(vn) - set(cn))
    both = sorted(set(cn) & set(vn))
    same = [k for k in both if cn[k][1] == vn[k][1]]
    diff = [k for k in both if cn[k][1] != vn[k][1]]

    print('%s assets %d | %s assets %d' % (a.a, len(cn), a.b, len(vn)))
    print('chi co o %-6s %d' % (a.a, len(only_cn)))
    print('chi co o %-6s %d' % (a.b, len(only_vn)))
    print('co ca hai        %d  ->  giong het %d, khac noi dung %d' % (len(both), len(same), len(diff)))

    def ext(lst):
        return collections.Counter(os.path.splitext(x)[1] for x in lst).most_common(7)

    print()
    print('chi %s theo duoi :' % a.a, ext(only_cn))
    print('chi %s theo duoi :' % a.b, ext(only_vn))
    print('khac noi dung    :', ext(diff))

    def top(lst, n=10):
        return [x for x in lst if x.endswith('.lua') or x.endswith('.xgg') or x.endswith('.proto')][:n]

    print()
    print('lua/xgg chi co o %s:' % a.b, top(only_vn))
    print('lua/xgg chi co o %s:' % a.a, top(only_cn))

    json.dump({'a': a.a, 'b': a.b, 'only_cn': only_cn, 'only_vn': only_vn,
               'same': same, 'diff': diff},
              open(out_path, 'w', encoding='utf-8'), ensure_ascii=False)
    print()
    print('-> %s' % out_path)


if __name__ == '__main__':
    main()
