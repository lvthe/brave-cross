# -*- coding: utf-8 -*-
"""So sanh hai dac ta server do build_spec.py sinh ra.

  python build_spec.py --assets decrypted/assets     --out server-spec
  python build_spec.py --assets vn/decrypted/assets  --out server-spec-vn
  python diff_api.py server-spec server-spec-vn

Diff chay tren server_api.json chu khong tren danh sach ten roi: nho vay bat
duoc ca doi chu ky tham so, doi enum server va doi bang ma loi — khong chi
"them/bot ham".
"""
import os, sys, json, argparse, collections


def load(d):
    p = d if d.endswith('.json') else os.path.join(d, 'server_api.json')
    return json.load(open(p, encoding='utf-8'))


def api_key(r):
    """Mot API dinh danh boi (module, ten ham) — dung khoa cua build_spec."""
    return '%s.%s' % (r['module'], r['funcName'])


def sig(r):
    return [a['type'] for a in r['args']]


def diff_maps(a, b):
    """(chi o a, chi o b, co ca hai)."""
    ka, kb = set(a), set(b)
    return sorted(ka - kb), sorted(kb - ka), sorted(ka & kb)


def diff_errors(a, b):
    out = {'groupsAdded': [], 'groupsRemoved': [], 'codes': []}
    rm, add, both = diff_maps(a, b)
    out['groupsRemoved'], out['groupsAdded'] = rm, add
    for g in both:
        crm, cadd, cboth = diff_maps(a[g], b[g])
        for n in cadd:
            out['codes'].append({'group': g, 'name': n, 'change': 'added', 'to': b[g][n]})
        for n in crm:
            out['codes'].append({'group': g, 'name': n, 'change': 'removed', 'from': a[g][n]})
        for n in cboth:
            if a[g][n] != b[g][n]:
                out['codes'].append({'group': g, 'name': n, 'change': 'renumbered',
                                     'from': a[g][n], 'to': b[g][n]})
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('base', help='dac ta goc (thu muc hoac server_api.json)')
    ap.add_argument('new', help='dac ta can so')
    ap.add_argument('-o', '--out', default='api_diff.json')
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')

    A, B = load(a.base), load(a.new)
    ra = {api_key(r): r for r in A['requests']}
    rb = {api_key(r): r for r in B['requests']}
    removed, added, both = diff_maps(ra, rb)

    def brief(r):
        return {'module': r['module'], 'funcName': r['funcName'], 'objName': r['objName'],
                'args': [[x['expr'], x['type']] for x in r['args']],
                'handler': (r.get('handler') or {}).get('name'),
                'bound': bool(r.get('bound')), 'doc': r['doc'], 'src': r['src']}

    changed = []
    for k in both:
        x, y = ra[k], rb[k]
        d = {}
        if sig(x) != sig(y):
            d['args'] = {'from': [[i['expr'], i['type']] for i in x['args']],
                         'to': [[i['expr'], i['type']] for i in y['args']]}
        hx = (x.get('handler') or {}).get('name')
        hy = (y.get('handler') or {}).get('name')
        if hx != hy:
            d['handler'] = {'from': hx, 'to': hy}
        if x['objName'] != y['objName']:
            d['objName'] = {'from': x['objName'], 'to': y['objName']}
        if d:
            d.update(module=x['module'], funcName=x['funcName'])
            changed.append(d)

    srm, sadd, sboth = diff_maps(A['servers'], B['servers'])
    servers = {'added': {k: B['servers'][k] for k in sadd},
               'removed': {k: A['servers'][k] for k in srm},
               'renumbered': {k: [A['servers'][k], B['servers'][k]]
                              for k in sboth if A['servers'][k] != B['servers'][k]}}
    hrm, hadd, _ = diff_maps(A['handlers'], B['handlers'])
    errors = diff_errors(A['errorCodes'], B['errorCodes'])

    res = {
        'base': {'spec': a.base, 'game': A.get('game'), 'apis': len(ra)},
        'new': {'spec': a.new, 'game': B.get('game'), 'apis': len(rb)},
        'apisAdded': [brief(rb[k]) for k in added],
        'apisRemoved': [brief(ra[k]) for k in removed],
        'apisChanged': changed,
        'servers': servers,
        'handlersAdded': hadd, 'handlersRemoved': hrm,
        'errors': errors,
    }
    json.dump(res, open(a.out, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)

    print('%-28s %s  (%d API)' % ('goc :', A.get('game'), len(ra)))
    print('%-28s %s  (%d API)' % ('moi :', B.get('game'), len(rb)))
    print()
    print('API them   %3d   |  bo %3d  |  doi chu ky/handler %3d'
          % (len(added), len(removed), len(changed)))
    print('handler them %3d |  bo %3d' % (len(hadd), len(hrm)))
    print('ma loi them %3d nhom, %d ma thay doi'
          % (len(errors['groupsAdded']), len(errors['codes'])))
    if servers['added'] or servers['removed'] or servers['renumbered']:
        print('enum SERVER:', json.dumps(servers, ensure_ascii=False))
    print()

    if added:
        by = collections.OrderedDict()
        for k in added:
            by.setdefault(rb[k]['objName'] or '(toan cuc)', []).append(rb[k])
        print('API MOI, gom theo doi tuong server:')
        for obj, items in by.items():
            print('  %s  (%d)' % (obj, len(items)))
            for r in items:
                print('     + %-38s %s%s' % (r['funcName'], '⟳ ' if r.get('bound') else '',
                                             (r['doc'] or '')[:44]))
    if removed:
        print('\nAPI BI BO:')
        for k in removed:
            print('     - %s.%s' % (ra[k]['module'], ra[k]['funcName']))
    if errors['groupsAdded']:
        print('\nNhom ma loi moi:', ', '.join(errors['groupsAdded']))
    print('\n-> %s' % a.out)


if __name__ == '__main__':
    main()
