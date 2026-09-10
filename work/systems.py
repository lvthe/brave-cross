# -*- coding: utf-8 -*-
"""Lap ban do he thong cua ban goc tu ma nguon Lua.

Muc dich: doc MOT LAN cho ra mot tai lieu tra cuu, thay vi moi lan lam mot
tinh nang lai phai lan nguoc vao 973 file.

Voi moi module luat trong sc/share/ va cac lop logic client, trich:
  - muc dich (comment dau file hoac dau class)
  - hang so cau hinh khai bao trong ctor  (day la CAC CON SO CAN BANG)
  - ham cong khai
  - RPC server ma no dung toi

    python systems.py                 # bang tom tat
    python systems.py --detail Arena  # do chi tiet mot he thong
    python systems.py --json out.json
"""
import os
import re
import sys
import json
import glob
import argparse
import collections

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from extract_api import read, strip_comments

DEFAULT_SC = os.path.join(HERE, 'vn', 'decrypted', 'assets', 'sc')

FUNC = re.compile(r'^function\s+([A-Za-z_][\w.]*)[:.]([A-Za-z_]\w*)\s*\(([^)]*)\)', re.M)
CONST = re.compile(r'^\s*self\.([A-Za-z_]\w*)\s*=\s*([-\d][\d.]*)\s*(?:--\s*(.*))?$', re.M)
CALL = re.compile(r'CallServer\s*\(\s*[^,]+,\s*[^,]*,\s*"(\w+)"')
BIND = re.compile(r'CUIAssist\.bindRpcToEvent\s*\(\s*\w+\s*,\s*"([^"]+)"')


def head_doc(text):
    """Vai dong comment dau file — thuong la muc dich cua module."""
    out = []
    for ln in text.split('\n')[:14]:
        s = ln.strip()
        if s.startswith('--[['):
            continue
        if s.startswith('--'):
            t = s.lstrip('-').strip()
            if t and not t.startswith('=') and 'Date:' not in t and 'Company' not in t:
                if t.startswith('Purpose:'):
                    t = t.split(':', 1)[1].strip()
                out.append(t)
        elif s.startswith(']]'):
            break
        elif s and out:
            break
    return ' / '.join(out[:2])


def scan(path, root):
    raw = read(path)
    code = strip_comments(raw)
    rel = os.path.relpath(path, root).replace(os.sep, '/')
    consts = []
    for m in CONST.finditer(raw):
        consts.append((m.group(1), m.group(2), (m.group(3) or '').strip()))
    funcs = ['%s:%s(%s)' % (a, b, c.strip()) for a, b, c in FUNC.findall(code)]
    return collections.OrderedDict([
        ('file', rel),
        ('doc', head_doc(raw)),
        ('lines', raw.count('\n') + 1),
        ('consts', consts),
        ('funcs', funcs),
        ('rpc', sorted(set(CALL.findall(code)))),
        ('rpcGroups', sorted(set(BIND.findall(code)))),
    ])


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--sc', default=DEFAULT_SC)
    ap.add_argument('--detail', help='in day du cac module co ten chua chuoi nay')
    ap.add_argument('--json', help='ghi ra file JSON')
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')

    paths = sorted(glob.glob(os.path.join(a.sc, 'share', '**', '*.lua'), recursive=True))
    mods = [scan(p, a.sc) for p in paths]

    if a.detail:
        key = a.detail.lower()
        for m in mods:
            if key not in m['file'].lower():
                continue
            print('=' * 74)
            print('%s   %d dong' % (m['file'], m['lines']))
            if m['doc']:
                print('  %s' % m['doc'])
            if m['consts']:
                print('  -- hang so can bang --')
                for n, v, c in m['consts']:
                    print('     %-30s = %-10s %s' % (n, v, c[:40]))
            if m['funcs']:
                print('  -- ham (%d) --' % len(m['funcs']))
                for f in m['funcs'][:30]:
                    print('     %s' % f[:88])
            if m['rpc']:
                print('  -- RPC dung toi: %s' % ', '.join(m['rpc'][:12]))
        return 0

    print('%-42s %6s %6s %6s  %s' % ('module', 'dong', 'hang so', 'ham', 'muc dich'))
    print('-' * 108)
    for m in sorted(mods, key=lambda x: -x['lines']):
        if m['lines'] < 60:
            continue
        print('%-42s %6d %6d %6d  %s'
              % (m['file'].replace('share/', '')[:42], m['lines'],
                 len(m['consts']), len(m['funcs']), m['doc'][:44]))
    tot = sum(m['lines'] for m in mods)
    print()
    print('%d module, %d dong, %d hang so can bang'
          % (len(mods), tot, sum(len(m['consts']) for m in mods)))

    if a.json:
        json.dump(mods, open(a.json, 'w', encoding='utf-8'),
                  ensure_ascii=False, indent=1)
        print('-> %s' % a.json)
    return 0


if __name__ == '__main__':
    sys.exit(main())
