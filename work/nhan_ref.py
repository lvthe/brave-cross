# -*- coding: utf-8 -*-
"""Rút bảng NHÃN SÁT THƯƠNG NỔI ra JSON.

    python nhan_ref.py

Nguồn : brave-cross/work/vn/decrypted/assets/map/global_config.xml  (khối `<label>`)
        brave-cross/work/vn/decrypted/assets/fonts/*.fnt            (bộ glyph của phông)
Đích  : bravecross-game/data_ref/nhan_ref.json

Vì sao cần: bản dựng KHÔNG có dòng mã nào cho số sát thương nổi, nhưng dữ liệu
thì đủ — sáu loại nhãn, mỗi loại một HỆ SỐ PHÓNG và một TRẦN SỐ NHÃN. Khối
`<label>` là 12 khoá, không hơn:

    <label>
        <sName>Label</sName>
        <fRiseLabel_Foe>0.825</fRiseLabel_Foe>          <!-- hệ số phóng, 6 loại -->
        ...
        <!-- 数量限制 -->                                (giới hạn số lượng)
        <nRiseLabelCountLimit_Foe>30</nRiseLabelCountLimit_Foe>
        ...

ĐO 2026-09-21 — hai điều KHÔNG suy ra được mà phải đo:

1. **Lua không đọc khoá nào trong đây.** Quét cả 1013 tệp `sc/*.lua`: chuỗi
   `RiseLabel` xuất hiện **0 lần**, và cả 11 tên phông trong `assets/fonts` cũng
   **0 lần**. Quét cả cây tài nguyên (9720 tệp): mỗi tên phông chỉ nằm ở
   `fonts/<tên>.fnt`, `sngPngDesData.bin` và `sc/sngCrcCache.sc` — tức danh sách
   tài nguyên nạp sẵn, KHÔNG phải bảng ghép loại → phông. Việc ghép ấy ở trong
   `libgame.so`, và **truy xref không được**: không một word 4 byte nào trong cả
   file trỏ vào vùng chuỗi 0x7b8000..0x7b81c0 (12 khoá nhãn) hay
   0x7c0e16..0x7c0e70 (5 tên `.fnt`) — cùng lối với `PosX` ở `0x7bc0b7`
   (`CLAUDE.md`). Nên bảng ghép loại → phông là **ĐẶT**, xem `ui/nhan_ref.gd`.

2. **Hai họ khoá có THỨ TỰ KHÁC NHAU** trong tệp: `fRiseLabel_*` ra
   Foe, Troop, Critical, Increase, Bonus, Shield; còn `nRiseLabelCountLimit_*` ra
   Foe, Critical, Troop, Increase, Bonus, Shield. Lệch ở chỗ Troop/Critical đổi
   cho nhau. Nếu mã gốc duyệt một mảng tên dùng chung thì hai thứ tự phải
   TRÙNG — nên chúng đọc riêng từng khoá. Ghi lại đây vì đó là bằng chứng, và
   để lần sau có ai "chuẩn hoá" thứ tự thì biết là đã đổi một thứ đo được.

Bộ glyph cũng được ghi kèm: nó là thứ PHÂN BIỆT phông số với phông chữ mà không
phải đoán (xem `fontart.py`).
"""
import glob
import io
import json
import os
import pathlib
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import cay                                              # noqa: E402
from fontart import doc_fnt, _ma_hoa, FONTS             # noqa: E402

NGUON = pathlib.Path(cay.ASSETS) / 'map' / 'global_config.xml'
DICH = pathlib.Path(cay.dich('nhan_ref.json'))

#: Sáu loại, theo ĐÚNG thứ tự của khối `<fRiseLabel_*>` trong tệp.
LOAI = ['Foe', 'Troop', 'Critical', 'Increase', 'Bonus', 'Shield']


def _so(s, k):
    return float(re.search(r'<%s>([^<]*)</%s>' % (k, k), s).group(1))


def doc_khoi(duong):
    """(he_so, tran, thu_tu_he_so, thu_tu_tran) của khối `<label>`.

    Trả về thứ tự ĐỌC ĐƯỢC trong tệp, không phải thứ tự ta muốn — xem docstring
    đầu tệp, mục 2.
    """
    s = io.open(duong, encoding='utf-8', errors='replace').read()
    i = s.find('<label>')
    if i < 0:
        raise SystemExit('khong thay khoi <label> trong %s' % duong)
    j = s.find('</label>', i)
    if j < 0:
        raise SystemExit('khoi <label> khong dong trong %s' % duong)
    blk = s[i:j]

    he_so, tran = {}, {}
    tt_he_so = [m.group(1) for m in re.finditer(r'<fRiseLabel_([A-Za-z]+)>', blk)]
    tt_tran = [m.group(1) for m in re.finditer(r'<nRiseLabelCountLimit_([A-Za-z]+)>', blk)]
    for k in LOAI:
        if '<fRiseLabel_%s>' % k not in blk:
            raise SystemExit('thieu khoa <fRiseLabel_%s>' % k)
        if '<nRiseLabelCountLimit_%s>' % k not in blk:
            raise SystemExit('thieu khoa <nRiseLabelCountLimit_%s>' % k)
        he_so[k] = _so(blk, 'fRiseLabel_' + k)
        tran[k] = int(_so(blk, 'nRiseLabelCountLimit_' + k))

    la = set(tt_he_so) | set(tt_tran)
    if la != set(LOAI):
        raise SystemExit('khoi <label> co loai la: %s' % ', '.join(sorted(la - set(LOAI))))
    return he_so, tran, tt_he_so, tt_tran


def doc_phong(assets):
    """Bộ glyph của từng phông, đọc thẳng từ `.fnt` — xem `fontart.py`."""
    ra = {}
    d = os.path.join(assets, FONTS)
    for p in sorted(glob.glob(os.path.join(d, '*.fnt'))):
        ten = os.path.splitext(os.path.basename(p))[0]
        trang, glyph = doc_fnt(p)
        ids = sorted(set(glyph))
        ra[ten] = {
            'nGlyph': len(ids),
            'ma': _ma_hoa(ids),
            # `_ma_hoa` bo glyph ngoai ASCII, nen dem rieng: npc_name co 3 glyph
            # ma `ma` chi hien 1 (hai chu CJK 精英 bi bo). Khong dem thi nguoi
            # doc tuong phong thieu glyph.
            'ngoai': len([c for c in ids if not (32 <= c < 127)]),
            'trang': [t for _, t in trang],
            # Ho SO = chi chu so, dau, it ky hieu; ho CHU = ca bang ma ASCII.
            'ho': 'so' if not any(c > 0x7E for c in ids) and len(ids) <= 16 else 'chu',
        }
    return ra


def main():
    if not NGUON.is_file():
        raise SystemExit('khong thay %s' % NGUON)
    he_so, tran, tt_he_so, tt_tran = doc_khoi(str(NGUON))
    phong = doc_phong(cay.ASSETS)
    if not phong:
        raise SystemExit('khong doc duoc phong nao trong %s' % os.path.join(cay.ASSETS, FONTS))

    ra = {
        'nguon': {
            'cau_hinh': 'map/global_config.xml khoi <label>',
            'phong': 'assets/fonts/*.fnt (bo glyph)',
            'so_loai': len(LOAI),
            'thu_tu_he_so': tt_he_so,
            'thu_tu_tran': tt_tran,
            'doc_bang': ('engine C++ doc theo TEN (nhu ptLayout); Lua 0 dong — '
                         'quet 1013 tep sc/*.lua khong thay `RiseLabel`'),
            'ghep_loai_phong': ('DAT — khong truy duoc: khong Lua, khong cau hinh, '
                                'khong xref trong libgame.so. Xem ui/nhan_ref.gd'),
        },
        'he_so': he_so,
        'tran': tran,
        'phong': phong,
    }
    os.makedirs(os.path.dirname(os.path.abspath(DICH)), exist_ok=True)
    with io.open(DICH, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(ra, f, ensure_ascii=False, indent=1, sort_keys=True)

    so = [k for k in phong if phong[k]['ho'] == 'so']
    print('%-10s %8s %6s' % ('loai', 'he so', 'tran'))
    for k in LOAI:
        print('%-10s %8.3f %6d' % (k, he_so[k], tran[k]))
    print('thu tu doc duoc: <fRiseLabel_*> %s | <nRiseLabelCountLimit_*> %s'
          % (','.join(tt_he_so), ','.join(tt_tran)))
    print('phong: %d — ho SO %d (%s)' % (len(phong), len(so), ', '.join(so)))
    print('da ghi', DICH)
    return 0


if __name__ == '__main__':
    sys.exit(main())
