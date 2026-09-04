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
import os, sys, shutil, argparse

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.dirname(HERE)
sys.path.insert(0, WORK)

from sng_encrypt import pack

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


def copy_offline(out_dir):
    src = os.path.join(HERE, 'sc', 'offline')
    dst = os.path.join(out_dir, 'sc', 'offline')
    if os.path.exists(dst):
        shutil.rmtree(dst)
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
    ap.add_argument('--assets', default=os.path.join(WORK, 'vn', 'decrypted', 'assets'),
                    help='thu muc assets da giai ma cua ban dich (mac dinh: ban VN)')
    a = ap.parse_args()

    plain = os.path.join(HERE, 'deploy', 'plain')
    sng = os.path.join(HERE, 'deploy', 'sng')
    for d in (plain, sng):
        if os.path.exists(d):
            shutil.rmtree(d)
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
