# -*- coding: utf-8 -*-
"""tao_tai_khoan.py — tao tai khoan email/mat khau tren server (Postgres), KHONG can mo game.

Cung endpoint ma form trong game goi: POST /api/register, mat khau la **MD5 hex**
(cung hop dong voi LDPlayer va Axmol). Sau khi tao, mo game bang `mo_game.cmd`
(sua TAIKHOAN / MATKHAU) — lan dau se vao man TAO NHAN VAT.

    python -I tao_tai_khoan.py email@example.com matkhau
"""
import hashlib
import json
import sys
import urllib.error
import urllib.request

BASE = 'http://127.0.0.1:8787'


def main() -> int:
    if len(sys.argv) < 3:
        print('Cach dung: python tao_tai_khoan.py email@example.com matkhau')
        return 2
    email = sys.argv[1].strip().lower()
    pw = sys.argv[2]
    body = json.dumps({
        'email': email,
        'password': hashlib.md5(pw.encode('utf-8')).hexdigest(),
    }).encode('utf-8')
    req = urllib.request.Request(BASE + '/api/register', data=body,
                                 headers={'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(req, timeout=8) as r:
            print(r.read().decode('utf-8'))
            return 0
    except urllib.error.HTTPError as e:
        print(e.read().decode('utf-8'))
        return 1
    except Exception as e:  # noqa: BLE001
        print('KHONG GOI DUOC SERVER :8787 —', e)
        return 1


if __name__ == '__main__':
    sys.exit(main())
