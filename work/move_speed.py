# -*- coding: utf-8 -*-
"""Bê TỐC ĐỘ DI CHUYỂN của từng sprite ra JSON cho Godot dùng.

    python move_speed.py --out <thư_mục_data_ref>

Vì sao cần: bảng chỉ số trận có trường `MovingSpeed`, và màn trận của ta từng
dùng nó (nhân 1,5 cho đỡ chậm). Nhưng `MovingSpeed` **không hề xuất hiện trong
libgame.so** — quét bảng tên chỉ số của engine (quanh 0x7b42f0) thì có
`AttackInterval`, `InjuryRates`, `MaxAttackDistance`, `NpcSize`,
`ClosePressing`, `Jump`… mà không có nó. Client cũng chỉ dùng nó làm chỉ số
hiển thị (`PropertyType.MovingSpeed = 21`).

Tốc độ thật nằm trong các file `map/*_config.xml`: mỗi sprite có `<sMove>` trỏ
tới một khối `<move>`, và khối đó có

    <ptVector>{1.3,0}</ptVector>       -- đi
    <ptRunVector>{3,0}</ptRunVector>   -- chạy

Đơn vị là **ô**, và 1 ô = 100 px ("单位:格 100pix", chú thích trong
hero_config.xml) — nên 1.3 ô/s = 130 px/s.

Đo được: gần như mọi sprite đi cùng một tốc độ 1.3 ô/s; khác nhau là ở tốc độ
CHẠY (bộ binh 3, cung 2.5, kỵ binh 3.5). Còn engine chọn đi hay chạy lúc nào
thì nằm bên C++ — script này chỉ bê số ra.
"""
import os
import re
import sys
import json
import glob
import argparse

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_MAP = os.path.join(HERE, 'vn', 'decrypted', 'assets', 'map')

## 1 ô = 100 px.
O_PX = 100.0


def _doc(path):
    with open(path, 'rb') as fp:
        return fp.read().decode('utf-8', 'replace')


def _khoi_move(s):
    """{tên khối move: thân}"""
    return dict(re.findall(r'<move>\s*<sName>([^<]+)</sName>(.*?)</move>', s, re.S))


def _vector(body, tag):
    m = re.search(r'<%s>\{([^,}]*)' % tag, body)
    if not m:
        return None
    try:
        return float(m.group(1))
    except ValueError:
        return None


def quet(thu_muc):
    moves, sprites = {}, {}
    for p in sorted(glob.glob(os.path.join(thu_muc, '*config*.xml'))):
        s = _doc(p)
        moves.update(_khoi_move(s))
        for b in re.findall(r'<item>(.*?)</item>', s, re.S):
            n = re.search(r'<sName>([^<]+)</sName>', b)
            m = re.search(r'<sMove>([^<]+)</sMove>', b)
            if n and m:
                sprites[n.group(1)] = m.group(1)

    def giai(ten, sau=0):
        """Tốc độ (đi, chạy) của một khối move, theo cả <sBaseItem>."""
        body = moves.get(ten)
        if body is None or sau > 6:
            return None, None
        di = _vector(body, 'ptVector')
        chay = _vector(body, 'ptRunVector')
        base = re.search(r'<sBaseItem>([^<]+)</sBaseItem>', body)
        if base is not None and (di is None or chay is None):
            bdi, bchay = giai(base.group(1), sau + 1)
            di = di if di is not None else bdi
            chay = chay if chay is not None else bchay
        return di, chay

    out = {}
    for ten, khoi in sorted(sprites.items()):
        di, chay = giai(khoi)
        if di is None and chay is None:
            continue
        e = {'move': khoi}
        if di is not None:
            e['di'] = round(di * O_PX, 2)
        if chay is not None:
            e['chay'] = round(chay * O_PX, 2)
        out[ten] = e
    return out, len(moves)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--map', default=DEFAULT_MAP, help='mac dinh: %(default)s')
    ap.add_argument('--out', default=os.path.join(
        HERE, '..', '..', 'bravecross-game', 'data_ref'))
    a = ap.parse_args()
    if not os.path.isdir(a.map):
        raise SystemExit('khong thay %s' % a.map)
    bang, so_khoi = quet(a.map)
    if not bang:
        raise SystemExit('khong doc duoc toc do nao')
    os.makedirs(a.out, exist_ok=True)
    dich = os.path.join(a.out, 'move_ref.json')
    with open(dich, 'w', encoding='utf-8') as fp:
        json.dump({
            'note': 'toc do di chuyen theo sprite, px/giay. 1 o = 100 px.',
            'sprites': bang,
        }, fp, ensure_ascii=False, indent=1, sort_keys=True)
    di = sorted({e['di'] for e in bang.values() if 'di' in e})
    chay = sorted({e['chay'] for e in bang.values() if 'chay' in e})
    print('%d sprite co toc do (tu %d khoi move) -> %s' % (len(bang), so_khoi, dich))
    print('   toc do DI khac nhau:   %s' % di)
    print('   toc do CHAY khac nhau: %s' % chay)
    return 0


if __name__ == '__main__':
    sys.exit(main())
