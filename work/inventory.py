# -*- coding: utf-8 -*-
"""So sanh kho tai nguyen giua ban CN (1.25) va ban VN (1.26).

So sanh tren file GOC (chua giai ma): ma hoa la XOR tat dinh nen hash bang nhau
khi va chi khi noi dung bang nhau — du de phan loai giong / khac / chi mot ben.
"""
import os, sys, json, hashlib, collections

SLASH = os.sep


def inv(root):
    out = {}
    for dirpath, _, files in os.walk(root):
        for f in files:
            p = os.path.join(dirpath, f)
            rel = os.path.relpath(p, root).replace(SLASH, '/')
            out[rel] = (os.path.getsize(p), hashlib.md5(open(p, 'rb').read()).hexdigest())
    return out


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    cn = inv('apk/assets')
    vn = inv('vn/obb/assets')
    for k, v in inv('vn/apk/assets').items():
        vn.setdefault(k, v)

    only_cn = sorted(set(cn) - set(vn))
    only_vn = sorted(set(vn) - set(cn))
    both = sorted(set(cn) & set(vn))
    same = [k for k in both if cn[k][1] == vn[k][1]]
    diff = [k for k in both if cn[k][1] != vn[k][1]]

    print('CN assets %d | VN assets %d' % (len(cn), len(vn)))
    print('chi co o CN  %d' % len(only_cn))
    print('chi co o VN  %d' % len(only_vn))
    print('co ca hai    %d  ->  giong het %d, khac noi dung %d' % (len(both), len(same), len(diff)))

    def ext(lst):
        return collections.Counter(os.path.splitext(x)[1] for x in lst).most_common(7)

    print()
    print('chi CN theo duoi :', ext(only_cn))
    print('chi VN theo duoi :', ext(only_vn))
    print('khac noi dung    :', ext(diff))

    def top(lst, n=10):
        return [x for x in lst if x.endswith('.lua') or x.endswith('.xgg') or x.endswith('.proto')][:n]

    print()
    print('lua/xgg chi co o VN:', top(only_vn))
    print('lua/xgg chi co o CN:', top(only_cn))

    json.dump({'only_cn': only_cn, 'only_vn': only_vn, 'same': same, 'diff': diff},
              open('inventory.json', 'w', encoding='utf-8'), ensure_ascii=False)
    print()
    print('-> inventory.json')


if __name__ == '__main__':
    main()
