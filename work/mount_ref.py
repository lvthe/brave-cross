# -*- coding: utf-8 -*-
"""Rút luật NGỰA MẶC ĐỊNH của tướng ra JSON.

    python mount_ref.py

Nguồn : brave-cross/work/vn/decrypted/assets/map/*.xml  (khoá `<sDefaultMount>`)
Đích  : bravecross-game/data_ref/mount_ref.json

Vì sao cần: tướng có ngựa thì vào trận phải có ngựa, mà ngựa KHÔNG nằm trong
xương của tướng — nó là một món đồ kiểu `node_con` (`loai = Mount`) trong
`map/gear_config.xml`, gắn bằng đúng đường `setGear` (xem `rig/gear_ref.gd`).
Đường trận đã gọi đường gắn đồ, nhưng chỉ gắn những món mà KỊCH BẢN đưa ra; còn
luật "tướng này mặc định cưỡi con gì" thì chưa ai đọc.

Đo 2026-09-21 trên cây VN 1.26: quét CẢ 434 tệp `map/*.xml`, khoá này có ĐÚNG
**1** mục, trong `heroex_config.xml`, khối `<limited>`:

    <item>
        <sName>LvBuGod</sName>
        ...
        <!-- 定制坐骑 -->            (ngựa riêng)
        <sDefaultMount>PonyChiTuGod</sDefaultMount>

Không tệp Lua nào trong `sc/` đọc khoá này (0 dòng) — như engine C++ đọc
`ptLayout` ở `+0x460`, khoá này cũng do C++ đọc theo TÊN. `PonyChiTuGod` là một
trong 10 món `Mount` của bảng đồ (8 món `mount_169..176` + hai tên trần
`PonyChiTuGod`, `PonyBlue`).

QUÉT CẢ `map/*.xml` chứ không chỉ `heroex_config.xml`: luật này là một khoá cấu
hình, bản 1.31 có thể có nhiều mục hơn, và một luật chỉ đọc đúng một tệp thì
mục thứ hai sẽ im lặng không ai thấy.

CÁCH BÓC: neo vào chính khoá `<sDefaultMount>` rồi tìm ngược về `<sName>` gần
nhất, KHÔNG cắt khối `<item>...</item>`. Lý do đo được: khối `<item>` của
`LvBuGod` chứa `<lsAdapt>` mà bên trong đã có hai `<item>` con
(`adapt_LvBuGodFight`, `adapt_LvBuGodWake`) NẰM TRƯỚC `<sDefaultMount>`, nên
phép cắt khối không tham lam dừng ở `</item>` của đứa con đầu và mất luôn khoá
cần tìm — bản đầu của tệp này ra 0 mục vì đúng cái bẫy ấy.
"""
import glob
import io
import json
import os
import pathlib
import re
import sys

import cay

NGUON = pathlib.Path(cay.ASSETS) / 'map'
DICH = pathlib.Path(cay.dich('mount_ref.json'))

TEN = re.compile(r'<sName>(.*?)</sName>')
NGUA = re.compile(r'<sDefaultMount>(.*?)</sDefaultMount>')


def main():
    mac_dinh = {}
    nguon_muc = {}
    for p in sorted(glob.glob(str(NGUON / '*.xml'))):
        s = io.open(p, encoding='utf-8', errors='replace').read()
        if '<sDefaultMount>' not in s:
            continue
        ten_tep = os.path.basename(p)
        for m in NGUA.finditer(s):
            # `<sName>` gan nhat NAM TRUOC khoa = chu cua khoi dang chua no.
            truoc = list(TEN.finditer(s, 0, m.start()))
            if not truoc:
                print('HONG: %s co <sDefaultMount> nhung khong co <sName> truoc no'
                      % ten_tep)
                return 1
            ten = truoc[-1].group(1).strip()
            mac_dinh[ten] = m.group(1).strip()
            nguon_muc[ten] = ten_tep

    if not mac_dinh:
        print('HONG: khong tim thay <sDefaultMount> nao trong %s' % NGUON)
        return 1

    ra = {
        'nguon': {
            'cau_hinh': 'map/*.xml khoa <sDefaultMount>',
            'so_muc': len(mac_dinh),
            'muc_o': nguon_muc,
            'doc_bang': 'engine C++ doc theo TEN (nhu ptLayout); Lua 0 dong',
        },
        'mac_dinh': mac_dinh,
    }
    os.makedirs(os.path.dirname(os.path.abspath(DICH)), exist_ok=True)
    with io.open(DICH, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(ra, f, ensure_ascii=False, indent=1, sort_keys=True)
    for ten in sorted(mac_dinh):
        print('%-16s -> %-16s (%s)' % (ten, mac_dinh[ten], nguon_muc[ten]))
    print('da ghi', DICH, '—', len(mac_dinh), 'muc')
    return 0


if __name__ == '__main__':
    sys.exit(main())
