"""Bê bảng chữ của bản gốc vào dự án game.

    python text_table.py                      # ban VN (mac dinh)
    BC_TREE=cn131 python text_table.py        # ban CN 1.31

`conf/text_vi.xgg` mang đuôi .xgg nhưng KHÔNG phải bố cục — nó là JSON thuần,
16.894 khoá, chữ tiếng Việt đã dịch sẵn. Mã gốc đọc nó qua
`GetStringWithKey(key)` → `g_CLuaFont:GetStringByKey(key)`, và mọi dòng chữ
trên giao diện đều đi qua đó.

Ban Trung **không có** bảng tiếng Việt — nó chỉ có `text_zh_hans.json` và
`text_zh_hans2.0.json` (bảng gốc). Script tự chọn bảng có thật và đặt tên file
ra theo tên bảng, nên bản VN vẫn ra `text_vi.json` như cũ.

Có bản quyền — đích nằm trong data_ref/, thư mục đã gitignore.
"""
import argparse
import json
import pathlib
import sys

import cay

HERE = pathlib.Path(__file__).resolve().parent
CONF = pathlib.Path(cay.ASSETS) / 'conf'

## Ban VN co ban dich tieng Viet; ban Trung chi co bang chu goc. Chon cai co
## that, de cung mot script chay duoc cho ca ba ban.
NGUON = next((CONF / t for t in ('text_vi.xgg', 'text_zh_hans.json',
                                 'text_zh_hans2.0.json', 'text_zh_Hans2.0.xgg')
              if (CONF / t).exists()), CONF / 'text_vi.xgg')
DICH = pathlib.Path(cay.dich())


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--out', default=str(DICH))
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')

    if not NGUON.exists():
        print('KHONG thay %s' % NGUON)
        return 1
    d = json.loads(NGUON.read_text('utf-8'))
    out = pathlib.Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    f = out / ('%s.json' % NGUON.stem)
    f.write_text(json.dumps(d, ensure_ascii=False), encoding='utf-8')
    print('%d khoa -> %s' % (len(d), f))
    return 0


if __name__ == '__main__':
    sys.exit(main())
