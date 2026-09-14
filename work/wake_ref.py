"""Bê số liệu kỹ năng thức tỉnh của bản gốc ra JSON.

    python wake_ref.py

Nguồn : brave-cross/work/vn/decrypted/assets/map/{hero,sprite,boss,evil,...}_config.xml
Đích  : bravecross-game/data_ref/wake_ref.json

Luật GHÉP các con số này nằm trong ~80 lớp C++ `CDFSpriteFight*Wake` (mỗi
tướng một cây hành vi) và KHÔNG khôi phục được từ dữ liệu. Cái khôi phục được
là bản thân các con số, nằm trong khối `<fight>` tên `fight_<Sprite>Wake`:

  * `fAttackFrameWake`        — khung hình đòn thức tỉnh trúng đích.
  * `fSectionIntervalWake_F<n>` — khung hình của các NHỊP đòn tiếp theo.
  * `nAttackSectionLimitWake` — chặn trên số nhịp.
  * `fDamageBonusWake`        — hệ số sát thương thêm của đòn thức tỉnh.
  * `nSplitWake`              — số mục tiêu mà sát thương được CHIA ĐỀU.
    Nghĩa của "split" đọc từ chính bản gốc: `global_config.xml` có
    `<nSplitNumForAOE>6</nSplitNumForAOE>` ngay dưới chú thích
    "群攻分摊个数" = "số mục tiêu đòn đánh diện rộng chia đều sát thương".
    Vậy nó KHÔNG phải số đòn.
  * `fSplitFloorWake`         — mức sàn của hệ số chia.
  * `nStatusWake` / `nStatusOddsWake` / `fStatusTimeWake` — trạng thái gây ra.

`so_don` suy ra = 1 + số trường `fSectionIntervalWake_F<n>`, chặn trên bởi
`nAttackSectionLimitWake` khi có. Ví dụ: Triệu Vân 1 đòn, Quan Vũ 6, Tào Thực 3.
"""
import glob
import io
import json
import os
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
NGUON = HERE / 'vn' / 'decrypted' / 'assets' / 'map'
DICH = HERE.parent.parent / 'bravecross-game' / 'data_ref' / 'wake_ref.json'

SO = re.compile(r'^-?\d+(\.\d+)?$')


def _so(v):
    return float(v) if SO.match(v.strip()) else v.strip()


def main() -> int:
    ra = {}
    for f in sorted(glob.glob(str(NGUON / '*config*.xml'))):
        s = re.sub(r'<!--.*?-->', '', io.open(f, encoding='utf-8-sig', errors='replace').read(),
                   flags=re.S)
        for b in re.findall(r'<fight>((?:(?!<fight>|</fight>).)*?)</fight>', s, re.S):
            t = re.search(r'<sName>([^<]*)</sName>', b)
            if t is None:
                continue
            ten = t.group(1)
            w = {k: _so(v) for k, v in re.findall(r'<(\w+)>([^<]*)</\1>', b) if 'Wake' in k}
            if not w:
                continue
            nhip = sum(1 for k in w if k.startswith('fSectionIntervalWake_F'))
            so_don = 1 + nhip
            gioi = w.get('nAttackSectionLimitWake')
            if isinstance(gioi, float) and gioi > 0:
                so_don = min(so_don, int(gioi))
            w['_so_don'] = so_don
            ra[ten] = w
            # Khoa phu theo ten sprite: "fight_ZhaoYunWake" -> "ZhaoYun".
            m = re.match(r'^fight_(.+?)Wake\d*$', ten)
            if m and m.group(1) not in ra:
                ra[m.group(1)] = w
    DICH.parent.mkdir(parents=True, exist_ok=True)
    io.open(DICH, 'w', encoding='utf-8', newline='\n').write(
        json.dumps(ra, ensure_ascii=False, indent=1, sort_keys=True))
    co_don = sum(1 for v in ra.values() if v.get('_so_don', 1) > 1)
    print('%d khoi <fight> co tham so thuc tinh (%d khoi nhieu hon mot don) -> %s'
          % (len(ra), co_don, os.path.relpath(DICH, HERE)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
