# -*- coding: utf-8 -*-
"""fight_ref.py — trích mọi khối `<fight>` từ config gốc (bản VN 1.26) ra JSON.

Vì sao: **thời điểm đánh và hộp đòn đánh là DỮ LIỆU**, không phải hằng số trong mã
(xem `work/offline/HIT-BOX-TU-CONFIG.md`). Bản dựng cần bảng này thay vì đoán.

    python -I -X utf8 fight_ref.py                 # in JSON ra stdout
    python -I -X utf8 fight_ref.py > fight_ref.json
    python -I -X utf8 fight_ref.py --tom-tat        # chỉ in bảng đếm

Nguồn: `decompiler/out/vn126/assets/map/<tệp>_config.xml` (đã giải mã `sngFile`).
KHÔNG đọc nhánh Godot — luật chủ dự án 21–22/10.
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
GOC = os.path.normpath(os.path.join(HERE, '..', '..', 'decompiler', 'out',
                                    'vn126', 'assets', 'map'))
TEP = ['player_config.xml', 'hero_config.xml', 'heroex_config.xml',
       'sprite_config.xml', 'boss_config.xml', 'evil_config.xml', 'pet_config.xml']

# Trường cần lấy; còn lại vẫn giữ nguyên trong `tho` nếu cần tra.
TRUONG = [
    'sName', 'sClass', 'sBaseItem', 'nAttackType', 'nSortTargets',
    'fAttackFrameFight', 'fAttackFrameFight2', 'fAttackFrameFight3',
    'fAttackFrameWake', 'fAttackFrameCritical', 'fAttackFrameLoopFight',
    'ptAttackExpandUnitLB', 'ptAttackExpandUnitRT',
    'nAttackTargetLimit', 'nAttackSectionLimit', 'fAttackSectionInterval',
    'bAttackSectionReorientation', 'nComboNum', 'nComboNumFight',
    'fDamageBonusFight', 'sWeaponFight', 'sAttackAction', 'lsPlugins',
]


def so(v):
    """'{-1,-1}' -> [-1,-1]; '6.0' -> 6.0; '3' -> 3; còn lại giữ chuỗi."""
    v = v.strip()
    if v.startswith('{') and v.endswith('}'):
        return [so(x) for x in v[1:-1].split(',') if x.strip()]
    try:
        f = float(v)
        return int(f) if f.is_integer() and '.' not in v else f
    except ValueError:
        return v


def doc(ten):
    m = os.path.join(GOC, ten)
    if not os.path.exists(m):
        return []
    s = open(m, encoding='utf-8-sig').read()
    s = re.sub(r'<!--.*?-->', '', s, flags=re.S)      # bỏ khối mẫu trong comment
    ra = []
    for blk in re.findall(r'<fight>(.*?)</fight>', s, flags=re.S):
        d = {'_tep': ten}
        for k in TRUONG:
            m2 = re.search(r'<%s>(.*?)</%s>' % (k, k), blk, flags=re.S)
            if not m2:
                continue
            v = m2.group(1).strip()
            if k == 'lsPlugins':
                d[k] = re.findall(r'<item>(.*?)</item>', v, flags=re.S)
            else:
                d[k] = so(v)
        if 'sName' in d:
            ra.append(d)
    return ra


def main():
    tatca = {}
    for t in TEP:
        ra = doc(t)
        if ra:
            tatca[t] = ra
    if '--tom-tat' in sys.argv:
        for t, ra in tatca.items():
            co = sum(1 for d in ra if 'fAttackFrameFight' in d)
            hop = sum(1 for d in ra if 'ptAttackExpandUnitLB' in d)
            print('%-22s %4d module · %4d co fAttackFrameFight · %3d co hop LB'
                  % (t, len(ra), co, hop))
        print('TONG', sum(len(v) for v in tatca.values()), 'module')
        return 0
    json.dump(tatca, sys.stdout, ensure_ascii=False, indent=1)
    print()
    return 0


if __name__ == '__main__':
    sys.exit(main())
