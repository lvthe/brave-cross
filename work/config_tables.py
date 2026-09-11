"""Bê 104 bảng cấu hình của bản gốc vào dự án game.

    python config_tables.py

Nguồn: brave-cross/work/vn/decrypted/assets/config/**.xgg
Đích : bravecross-game/data_ref/config/**.xgg  (giữ nguyên tên và cây thư mục)

Các file này mang đuôi `.xgg` nhưng là **JSON thuần** — 103/104 file. Mã gốc
đọc chúng qua đúng một đường:

    ClientConfigManager:GetConfigTableWithName(ten)
        -> JsonFile.Load(LGG_GetPathWithFileName("config/share/<ten>.xgg"))

nên chỉ cần giữ nguyên đường dẫn tương đối là phần `ConfigManager` của bản
gốc (5.063 dòng) tự chạy, không phải chép lại dòng nào.

Có bản quyền — data_ref/ đã nằm trong .gitignore.
"""
import argparse
import json
import pathlib
import shutil
import sys

HERE = pathlib.Path(__file__).resolve().parent
NGUON = HERE / 'vn' / 'decrypted' / 'assets' / 'config'
DICH = HERE.parent.parent / 'bravecross-game' / 'data_ref' / 'config'


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--out', default=str(DICH))
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')

    if not NGUON.is_dir():
        print('KHONG thay %s' % NGUON)
        return 1
    out = pathlib.Path(a.out)
    if out.exists():
        shutil.rmtree(out)

    n = hong = 0
    for f in sorted(NGUON.rglob('*.xgg')):
        rel = f.relative_to(NGUON)
        dst = out / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        raw = f.read_bytes()
        # Vai file boc trong <?xml ...><string>JSON</string>; go ra cho dong bo.
        txt = raw.decode('utf-8', 'replace')
        if txt.lstrip().startswith('<?xml'):
            i, j = txt.find('<string>'), txt.rfind('</string>')
            if i >= 0 and j > i:
                txt = txt[i + 8:j]
        try:
            json.loads(txt)
        except ValueError:
            hong += 1
        dst.write_text(txt, encoding='utf-8')
        n += 1

    print('%d bang -> %s' % (n, out))
    if hong:
        print('   (%d file khong phai JSON hop le, van chep nguyen)' % hong)
    return 0


if __name__ == '__main__':
    sys.exit(main())
