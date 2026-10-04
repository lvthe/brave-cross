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
CHẠY (bộ binh 3, cung 2.5, kỵ binh 3.5). Script này chỉ bê số ra.

ENGINE CHỌN ĐI HAY CHẠY LÚC NÀO — ĐÃ ĐO (2026-09-18), bản vn
-----------------------------------------------------------
Cờ chạy là byte `+0x295` của đơn vị; cả hai bản `.so` chỉ đụng tới nó ở 4 chỗ:
xoá trong hàm dựng (`0x412540`), xoá sau mỗi bước chạy (`0x415b18`), và **bật**
tại `0x413c4c` — trong hàm `0x413bd4`, nơi duy nhất quyết định:

    0x413c12  ldr r3,[pc,#0x44]; add r3,pc; ldr r3,[r3]   ; singleton sàn trận
    0x413c1c  ldr r0,[r3]; bl 0x462e5e ; 0x462e5e = ldr.w r0,[r0,#0x1b8]
    0x413c2a  ldr r3,[r0]; ldr.w r3,[r3,#0x270]; blx r3   ; -> bản đồ + 0x180
    0x413c36  vldr s14,[r0]                               ; BỀ NGANG Ô, tính px
    0x413c3a  vmul.f32 s15,s14,#4.0
    0x413c42  vcmpe.f32 s16,s15                           ; |Δx| (s16) với 4 x ô
    0x413c4c  strbpl.w r0,[r5,#0x295]                     ; xa thì BẬT CHẠY

Nên: **|Δx| tới mục tiêu ≥ 4 ô (400 px) thì chạy**; `>=` chứ không phải `>`
(`vcmpe` + `it pl`), và chỉ trục X (`vsub` rồi `vabs`, không đụng tới Y).

`W` trong luật ấy là gì — câu này từng để mở, nay chốt: `+0x270` =
`0x35e73a` = `add.w r0,r0,#0x180; bx lr`. Quét cả file thì đó là **stub duy
nhất** kiểu `this + 0x180` (35 chỗ cộng hằng 0x180, chỉ 1 chỗ theo kiểu này),
và nó nằm trong **đúng hai** vtable: `CDFTMXTiledMap` (vt `0x895ac8`, RTTI
`14CDFTMXTiledMap`) và `cocos2d::CCTMXTiledMap` (vt `0x921780`). Vậy đối tượng
lấy qua `[sàn trận + 0x1b8]` chắc chắn là **bản đồ tmx**, và `+0x180` là cỡ ô
tính bằng px = 100 (`map/map_1.tmx` khai `tilewidth="100"`; cùng chỗ đó,
`0x35f43e` nhân `fLaneWidth` với nó để ra bề ngang làn px).

Còn lại CHƯA đo được: nhánh chạy (`0x415a9a`..`0x415b18`) đẩy vị trí đi một
bước **cứng 3,8 ô** (`vldr s15,[pc,#0x13c]` = 3.8, nhân với bề ngang ô) rồi gọi
`+0x2a4(this, bản_đồ, &đích, 0, …)` — tức bản gốc đi theo BƯỚC rồi để armature
chạy hết quãng đường đó. Màn trận của bản dựng đi LIÊN TỤC theo px/giây nên
dùng thẳng `<ptRunVector>` (cùng nguồn với `<ptVector>` của đường đi); quan hệ
giữa bước 3,8 ô kia và `<ptRunVector>` thì chưa đo được (máy ảo không chạy nổi
bản gốc — SIGSEGV trong RepaleceScene, xem `emu_dom.py`).
"""
import os
import re
import sys
import json
import glob
import argparse

HERE = os.path.dirname(os.path.abspath(__file__))

import cay

DEFAULT_MAP = os.path.join(cay.ASSETS, 'map')

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
    ap.add_argument('--out', default=cay.dich(),
                    help='mac dinh: %(default)s')
    a = ap.parse_args()
    if not os.path.isdir(a.map):
        raise SystemExit('khong thay %s' % a.map)
    bang, so_khoi = quet(a.map)
    if not bang:
        raise SystemExit('khong doc duoc toc do nao')
    os.makedirs(a.out, exist_ok=True)
    loi = cay.giu_cho(a.out)
    if loi:
        sys.exit(loi)
    cay.danh_dau(a.out)
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
