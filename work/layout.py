# -*- coding: utf-8 -*-
"""Xuat bo cuc mot man hinh (.xgg) ra JSON cho Godot dung.

Doc cay node bang xgg.py roi ghi ra dang goc — GIU NGUYEN he toa do Cocos2d,
khong quy doi o day. Viec doi truc thuoc ve phia engine (xem XggLayout ben
repo bravecross-game), de file JSON con doi chieu duoc voi ban goc.

He toa do Cocos2d, can nho khi dung:

    - goc o GOC DUOI-TRAI, y huong LEN     (Godot: tren-trai, y huong XUONG)
    - x,y la vi tri cua DIEM NEO, khong phai goc tren-trai cua o
    - toa do TUONG DOI VOI CHA

    python layout.py Game_UI_Control_Panel_960_640 --out <thu_muc>
    python layout.py --all --out <thu_muc>
    python layout.py <ten> --print
"""
import os
import sys
import json
import glob
import argparse
import collections

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from xgg import load, XggError

DEFAULT_CONF = os.path.join('vn', 'decrypted', 'assets', 'conf')

KEEP = ('cls', 'name', 'res', 'x', 'y', 'scaleX', 'scaleY',
        'rot', 'anchorX', 'anchorY', 'w', 'h')


def trim(node):
    """Bo cac truong noi bo (nKids, bytes), de quy xuong con."""
    out = collections.OrderedDict((k, node[k]) for k in KEEP)
    kids = [trim(c) for c in node['children']]
    if kids:
        out['children'] = kids
    return out


def doc_for(path):
    x = load(path)
    roots = x.tree()
    return collections.OrderedDict([
        ('file', os.path.basename(path)),
        ('design', {'w': 960, 'h': 640}),
        ('origin', 'cocos2d: goc duoi-trai, y len, x/y la diem neo, toa do tuong doi cha'),
        ('atlas', [r['name'] for r in x.records('B')]),
        ('images', [{'name': r['name'], 'w': r['x'], 'h': r['y']}
                    for r in x.records('D')]),
        ('sprites', [{'name': r['name'], 'w': r['x'], 'h': r['y']}
                     for r in x.records('C')]),
        ('roots', [trim(r) for r in roots]),
    ])


def count(node):
    return 1 + sum(count(c) for c in node.get('children', []))


def show(node, depth=0):
    print('%s%-26s %-22s %8.1f %8.1f  %6.0fx%-6.0f %s'
          % ('  ' * depth, node['cls'][:26], node['name'][:22],
             node['x'], node['y'], node['w'], node['h'], node['res'][:20]))
    for c in node.get('children', []):
        show(c, depth + 1)


def resolve(name, conf):
    if os.path.isfile(name):
        return name
    p = os.path.join(conf, name if name.endswith('.xgg') else name + '.xgg')
    if not os.path.isfile(p):
        raise SystemExit('khong thay %s' % p)
    return p


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('names', nargs='*')
    ap.add_argument('--conf', default=DEFAULT_CONF, help='mac dinh: %(default)s')
    ap.add_argument('--out', help='thu muc ghi JSON')
    ap.add_argument('--all', action='store_true')
    ap.add_argument('--print', dest='dump', action='store_true', help='in cay ra man hinh')
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')

    if a.all:
        paths = sorted(glob.glob(os.path.join(a.conf, '*.xgg')))
    else:
        if not a.names:
            raise SystemExit('cho ten man hinh, hoac --all')
        paths = [resolve(n, a.conf) for n in a.names]

    if not a.out and not a.dump:
        raise SystemExit('thieu --out (hoac --print)')

    total = nodes = fail = skip = 0
    for p in paths:
        # Duoi .xgg bi dung cho hai thu khac han: file bo cuc that su, va vai
        # file JSON/text (text_zh_Hans2.0.xgg...). Bo qua loai sau, dung dem
        # thanh loi.
        with open(p, 'rb') as fp:
            if fp.read(7) not in (b'sngXgg\x00', b'xgg5.0\x00'):
                skip += 1
                continue
        try:
            doc = doc_for(p)
        except (XggError, OSError) as e:
            fail += 1
            print('  LOI %-44s %s' % (os.path.basename(p), e))
            continue
        n = sum(count(r) for r in doc['roots'])
        total += 1
        nodes += n
        if a.dump:
            print('=== %s — %d node, %d goc' % (doc['file'], n, len(doc['roots'])))
            for r in doc['roots']:
                show(r)
        if a.out:
            os.makedirs(a.out, exist_ok=True)
            stem = os.path.splitext(os.path.basename(p))[0]
            with open(os.path.join(a.out, stem + '.json'), 'w', encoding='utf-8') as fp:
                json.dump(doc, fp, ensure_ascii=False, indent=1)
    if a.out:
        print('xong: %d man hinh, %d node -> %s' % (total, nodes, a.out))
    if skip:
        print('bo qua %d file .xgg khong phai bo cuc (JSON/text)' % skip)
    if fail:
        print('that bai: %d' % fail)
    return 1 if fail else 0


if __name__ == '__main__':
    sys.exit(main())
