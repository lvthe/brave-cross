# -*- coding: utf-8 -*-
"""Dung ca cay thu muc lam viec tu file APK / XAPK goc.

Day la buoc DAU TIEN cua toan bo quy trinh. Cac script khac (sng_decrypt,
extract_api, build_spec...) deu gia dinh cay thu muc nay da co san.

    python unpack.py OAR1_XGSDK_1.25_jinshan_gwbb_sec.apk          # ban CN
    python unpack.py "Bua+Ta...1.26.81485_APKPure.xapk" --out vn   # ban VN

APK la file zip thuong. XAPK cung la zip, ben trong chua:
    <pkg>.apk
    Android/obb/<pkg>/main.<ver>.<pkg>.obb        <- tai nguyen nang nam o day
    icon.png, manifest.json

Sau khi giai nen, moi file tai nguyen con bi ma hoa 'sngFile' nen phai chay
sng_decrypt, va AndroidManifest.xml la nhi phan nen phai chay axml.

Cay ket qua (dung cai ma cac script khac cho doi):

    <out>/apk/                  APK da giai nen
    <out>/obb/                  OBB da giai nen (chi ban co OBB)
    <out>/decrypted/assets/     tai nguyen da giai ma
    <out>/decrypted/apk_assets/ tai nguyen trong APK (khi tai nguyen chinh o OBB)
    <out>/AndroidManifest.xml   manifest da giai nhi phan
"""
import os, sys, glob, shutil, zipfile, argparse, subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import sng_decrypt


def show(path):
    """Duong dan goc HERE cho gon, nhung khong de thanh chuoi ../../.. dai loong ngoong."""
    rel = os.path.relpath(path, HERE)
    return path if rel.startswith('..') else rel


def unzip(src, dst, label):
    os.makedirs(dst, exist_ok=True)
    with zipfile.ZipFile(src) as z:
        names = z.namelist()
        # zip khong tin cay duoc: chan duong dan vuot ra ngoai thu muc dich
        for n in names:
            p = os.path.normpath(os.path.join(dst, n))
            if not p.startswith(os.path.abspath(dst)):
                sys.exit('duong dan dang ngo trong zip: %s' % n)
        z.extractall(dst)
    print('  %-22s %5d file -> %s' % (label, len(names), show(dst)))
    return names


def decrypt_tree(src, dst, label):
    if not os.path.isdir(src):
        return 0, 0
    n_dec = n_copy = 0
    for path in glob.glob(os.path.join(src, '**', '*'), recursive=True):
        if not os.path.isfile(path):
            continue
        data = open(path, 'rb').read()
        outp = os.path.join(dst, os.path.relpath(path, src))
        os.makedirs(os.path.dirname(outp), exist_ok=True)
        if sng_decrypt.is_encrypted(data):
            open(outp, 'wb').write(sng_decrypt.unpack(data))
            n_dec += 1
        else:
            open(outp, 'wb').write(data)
            n_copy += 1
    print('  %-22s giai ma %d, chep nguyen %d -> %s'
          % (label, n_dec, n_copy, show(dst)))
    return n_dec, n_copy


def decode_manifest(binary, out):
    """axml.py in ra stdout nen goi qua subprocess cho gon."""
    if not os.path.exists(binary):
        return False
    r = subprocess.run([sys.executable, os.path.join(HERE, 'axml.py'), binary],
                       capture_output=True)
    if r.returncode != 0:
        print('  manifest: giai that bai — %s' % r.stderr.decode('utf-8', 'replace')[:120])
        return False
    open(out, 'wb').write(r.stdout)
    print('  %-22s %d byte -> %s' % ('AndroidManifest', len(r.stdout), show(out)))
    return True


def unpack_xapk(src, out):
    """Boc lop ngoai: lay APK va OBB ra, dat theo dung cau truc goc."""
    stage = os.path.join(out, '_xapk')
    unzip(src, stage, 'XAPK')
    apks = glob.glob(os.path.join(stage, '*.apk'))
    if not apks:
        sys.exit('trong XAPK khong co file .apk nao')
    apk = apks[0]

    # giu lai nguyen ban de con cai len may: adb install / adb push
    for f in glob.glob(os.path.join(stage, '*')):
        name = os.path.basename(f)
        dst = os.path.join(out, name)
        if os.path.isdir(f):
            if os.path.exists(dst):
                shutil.rmtree(dst)
            shutil.move(f, dst)
        else:
            shutil.move(f, dst)
    shutil.rmtree(stage, ignore_errors=True)

    apk = os.path.join(out, os.path.basename(apk))
    obbs = glob.glob(os.path.join(out, 'Android', 'obb', '*', '*.obb'))
    return apk, (obbs[0] if obbs else None)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('archive', help='file .apk hoac .xapk goc')
    ap.add_argument('--out', default='.',
                    help='thu muc dich, tuong doi voi work/ (mac dinh: work/ luon)')
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')

    src = os.path.abspath(a.archive)
    if not os.path.isfile(src):
        sys.exit('khong thay %s' % src)
    out = os.path.abspath(os.path.join(HERE, a.out))
    os.makedirs(out, exist_ok=True)

    print('nguon : %s (%.0f MB)' % (os.path.basename(src), os.path.getsize(src) / 1048576))
    print('dich  : %s\n' % out)

    obb = None
    if src.lower().endswith('.xapk'):
        src, obb = unpack_xapk(src, out)

    unzip(src, os.path.join(out, 'apk'), 'APK')
    if obb:
        unzip(obb, os.path.join(out, 'obb'), 'OBB')

    print()
    decode_manifest(os.path.join(out, 'apk', 'AndroidManifest.xml'),
                    os.path.join(out, 'AndroidManifest.xml'))

    # Tai nguyen chinh nam o OBB neu co OBB, nguoc lai nam trong APK. Khi co ca
    # hai, phan trong APK di rieng ra apk_assets de khoi de len.
    if obb:
        decrypt_tree(os.path.join(out, 'obb', 'assets'),
                     os.path.join(out, 'decrypted', 'assets'), 'tai nguyen OBB')
        decrypt_tree(os.path.join(out, 'apk', 'assets'),
                     os.path.join(out, 'decrypted', 'apk_assets'), 'tai nguyen APK')
    else:
        decrypt_tree(os.path.join(out, 'apk', 'assets'),
                     os.path.join(out, 'decrypted', 'assets'), 'tai nguyen APK')

    rel = show(out).replace(os.sep, '/')
    assets = 'decrypted/assets' if rel == '.' else (rel + '/decrypted/assets')
    print('\nxong. Buoc tiep:')
    print('  python build_spec.py --assets %s --out server-spec%s'
          % (assets, '-vn' if obb else ''))


if __name__ == '__main__':
    main()
