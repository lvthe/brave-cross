"""Bê bảng chữ tiếng Việt của bản gốc vào dự án game.

    python text_table.py --out ../../bravecross-game/data_ref

`conf/text_vi.xgg` mang đuôi .xgg nhưng KHÔNG phải bố cục — nó là JSON thuần,
16.894 khoá, chữ tiếng Việt đã dịch sẵn. Mã gốc đọc nó qua
`GetStringWithKey(key)` → `g_CLuaFont:GetStringByKey(key)`, và mọi dòng chữ
trên giao diện đều đi qua đó.

Có bản quyền — đích nằm trong data_ref/, thư mục đã gitignore.
"""
import argparse
import json
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
NGUON = HERE / 'vn' / 'decrypted' / 'assets' / 'conf' / 'text_vi.xgg'
DICH = HERE.parent.parent / 'bravecross-game' / 'data_ref'


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
    f = out / 'text_vi.json'
    f.write_text(json.dumps(d, ensure_ascii=False), encoding='utf-8')
    print('%d khoa -> %s' % (len(d), f))
    return 0


if __name__ == '__main__':
    sys.exit(main())
