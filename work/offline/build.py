# -*- coding: utf-8 -*-
"""Dung cay thu muc de tha vao may, cho lop offline.

Sinh hai ban:
    deploy/plain/  file .lua nguyen van
    deploy/sng/    file da ma hoa dinh dang sngFile nhu trong goc

Chua biet chac tang doc file cua libgame.so co chap nhan file khong ma hoa hay
khong (no kiem tra magic 'sngFile' o cuoi de quyet dinh co giai ma khong — nhung
day la suy doan tu dinh dang, chua kiem chung tren may). Nen thu ban plain
truoc, khong len thi dung ban sng.

Diem chen: sc/user/require.lua. Day la file duoc nap bang require() sau khi
package.path da tro toi external storage (sc/game.lua:60), va la file cuoi cung
keo vao toan bo lop client — dung cho de moc them mot dong.

    python build.py [--assets ../vn/decrypted/assets]
"""
import os, sys, shutil, argparse, time, stat

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.dirname(HERE)
sys.path.insert(0, WORK)

from sng_encrypt import pack

import cay

HOOK = '\n\n-- === lop offline: gia lap server ngay trong client ===\nrequire("offline.init")\n'


def build_require(assets, out_dir):
    """Ban require.lua co moc them mot dong o cuoi."""
    src = os.path.join(assets, 'sc', 'user', 'require.lua')
    if not os.path.exists(src):
        sys.exit('khong thay %s — chay sng_decrypt.py truoc da' % src)
    raw = open(src, 'rb').read()
    if b'offline.init' in raw:
        sys.exit('require.lua nguon da co moc roi, dung nham file?')
    dst = os.path.join(out_dir, 'sc', 'user', 'require.lua')
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    open(dst, 'wb').write(raw + HOOK.encode('utf-8'))
    return dst


def xoa_cay(path, so_lan=5):
    """Xoa cay thu muc, chiu duoc WinError 5 (Access is denied) tren Windows.

    NGUYÊN NHÂN ĐO ĐƯỢC (31/10): thư mục `handlers` mang thuộc tính **R
    (read-only)** — `cmd attrib` in ra `R` — và trên Windows **không xoá được
    thư mục read-only** (`rmdir` → Access denied) dù nó đã RỖNG. Vì
    `shutil.rmtree` xoá tệp trước rồi mới `rmdir`, nó chết SAU khi đã dọn sạch
    cây ⇒ để lại một cây CỤT trông như đã xoá xong. Đó chính là cái suýt xoá
    công ba ngày (28–30/10) lúc chép `sc/offline` ⇄ `deploy/plain`.

    Nên: gỡ cờ read-only của TỪNG mục (tệp lẫn thư mục) rồi thử lại, và vẫn
    thử lại vài lượt vì trình quét virus có thể giữ handle trong giây lát.
    """
    if not os.path.exists(path):
        return

    def go_co_ro(fn, p, _exc):
        try:
            os.chmod(p, stat.S_IWRITE)
            fn(p)
        except OSError:
            pass

    for lan in range(so_lan):
        try:
            try:
                shutil.rmtree(path, onexc=go_co_ro)      # Python >= 3.12
            except TypeError:
                shutil.rmtree(path, onerror=go_co_ro)    # Python <= 3.11
            return
        except PermissionError:
            if lan == so_lan - 1:
                raise
            time.sleep(0.3 * (lan + 1))


def copy_offline(out_dir):
    src = os.path.join(HERE, 'sc', 'offline')
    dst = os.path.join(out_dir, 'sc', 'offline')
    xoa_cay(dst)
    shutil.copytree(src, dst)
    return sum(len(f) for _, _, f in os.walk(dst))


def encrypt_tree(plain_dir, sng_dir):
    n = 0
    for dirpath, _, files in os.walk(plain_dir):
        for f in files:
            p = os.path.join(dirpath, f)
            rel = os.path.relpath(p, plain_dir)
            outp = os.path.join(sng_dir, rel)
            os.makedirs(os.path.dirname(outp), exist_ok=True)
            open(outp, 'wb').write(pack(open(p, 'rb').read(), f))
            n += 1
    return n


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--assets', default=cay.ASSETS,
                    help='thu muc assets da giai ma (mac dinh: ban dang lam, BC_TREE)')
    a = ap.parse_args()

    plain = os.path.join(HERE, 'deploy', 'plain')
    sng = os.path.join(HERE, 'deploy', 'sng')
    for d in (plain, sng):
        xoa_cay(d)
        os.makedirs(d)

    n_off = copy_offline(plain)
    build_require(a.assets, plain)
    n_sng = encrypt_tree(plain, sng)

    print('lop offline      : %d file' % n_off)
    print('them require.lua : 1 file (ban goc + 1 dong moc)')
    print('deploy/plain     : %d file' % (n_off + 1))
    print('deploy/sng       : %d file da ma hoa' % n_sng)
    print()
    print('Tha len may (thu ban plain truoc):')
    print('  adb push deploy/plain/sc  /sdcard/Android/data/com.cmn.buatanew/files/sc')
    print()
    print('Bat che do go loi trong set.xgg o cung thu muc do:')
    print('  <DebugTestMode>true</DebugTestMode>')
    print('  <CloseGuide>true</CloseGuide>')
    print()
    print('Xem tien do:  adb shell cat <thu_muc_ghi_duoc>/offline.log')


if __name__ == '__main__':
    main()
