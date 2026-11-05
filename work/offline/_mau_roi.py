# -*- coding: utf-8 -*-
"""_mau_roi.py - in mot mau DropData de biet hinh dang PrizeData."""
import json
import sys

f = r'D:\PROJECT\ProjectOut\game\decompiler\out\vn126\xgg-json\config\share\KDBGameNpcConfig.json'
d = json.load(open(f, encoding='utf-8'))
print('kieu du lieu:', type(d).__name__, 'so phan tu:', len(d))
mau = None
for npc in (d if isinstance(d, list) else d.values()):
    dd = npc.get('DropData')
    if not dd:
        continue
    try:
        ds = json.loads(dd) if isinstance(dd, str) else dd
    except Exception:
        continue
    if isinstance(ds, list) and ds:
        mau = ds[0]
        print('NpcID:', npc.get('NpcID') or npc.get('ID'), '| TotalDropValue:', npc.get('TotalDropValue'))
        break
print(json.dumps(mau, ensure_ascii=False)[:600])
