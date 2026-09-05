# -*- coding: utf-8 -*-
"""Tha lop offline len may va theo doi ket qua, qua adb.

Game xay package.path tu BA goc va tim ca ba (sc/game.lua:60):

    LGG_GetExternalStorageDirectory()   <- Cocos2dxHelper.sExternalStorageDirectory
    LGG_GetDownloadPath()               <- thu muc cap nhat nong
    LGG_GetAssetsPath()                 <- trong APK/OBB

Chua xac dinh duoc chinh xac hai goc dau tro toi dau (chung do libgame.so hoi
JNI luc chay). Nhung tap ung vien thi biet chac, doc tu Cocos2dxHelper.init
trong classes.dex ban VN:

    getExternalFilesDir()        -> /sdcard/Android/data/<pkg>/files
    getExternalStorageState()    -> /sdcard  (app targetSdk 23 nen van ghi duoc)
    getFilesDir()                -> /data/data/<pkg>/files  (can root)

Nen thay vi doan, day file vao TAT CA ung vien ghi duoc. Tam file nho, khong
ton gi, va chac chan trung mot cho.

    python deploy.py --status
    python deploy.py --push
    python deploy.py --flags
    python deploy.py --log
"""
import os, sys, glob, shutil, subprocess, argparse, posixpath

PKG = 'com.cmn.buatanew'
HERE = os.path.dirname(os.path.abspath(__file__))

CANDIDATES = [
    '/sdcard/Android/data/%s/files' % PKG,
    '/sdcard/%s' % PKG,
    '/sdcard',
    '/storage/emulated/0/Android/data/%s/files' % PKG,
]


# Tim adb ke ca khi PATH chua duoc nap lai (winget vua them thi terminal dang
# mo van chua thay). Cac cho duoi day la noi winget/Android Studio dat no.
ADB_GUESSES = [
    os.path.expandvars(r'%LOCALAPPDATA%\Microsoft\WinGet\Packages'
                       r'\Google.PlatformTools_Microsoft.Winget.Source_8wekyb3d8bbwe'
                       r'\platform-tools\adb.exe'),
    os.path.expandvars(r'%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe'),
    os.path.expandvars(r'%ProgramFiles%\Android\platform-tools\adb.exe'),
    os.path.expanduser('~/Android/Sdk/platform-tools/adb'),
    '/usr/bin/adb',
]

_adb_path = None


def nearby_adb():
    """Tim platform-tools giai nen san quanh repo.

    Cach cai pho bien nhat van la tai zip platform-tools ve roi bung ra mot cho
    nao do — kieu do khong sua PATH va cung khong nam o duong winget/Android
    Studio hay dat, nen hai nhanh tren deu truot. Do nguoc len vai cap thu muc
    la bat duoc.
    """
    root = os.path.abspath(HERE)
    for _ in range(4):                    # offline -> work -> repo -> cha repo
        root = os.path.dirname(root)
        for pat in ('platform-tools*/platform-tools/adb*', 'platform-tools*/adb*'):
            for p in sorted(glob.glob(os.path.join(root, pat))):
                if os.path.isfile(p) and os.path.basename(p) in ('adb', 'adb.exe'):
                    return p
    return None


def find_adb():
    global _adb_path
    if _adb_path:
        return _adb_path

    # Bien moi truong ADB thang thua tat ca: co may ban platform-tools thi day
    # la cach chi dinh ban nao, khong phai doan.
    env = os.environ.get('ADB')
    if env:
        if not os.path.isfile(env):
            sys.exit('bien moi truong ADB tro toi cho khong co file: %s' % env)
        _adb_path = env
        return env

    found = shutil.which('adb') or nearby_adb()
    if not found:
        for g in ADB_GUESSES:
            if g and os.path.exists(g):
                found = g
                break
    if not found:
        print('khong tim thay adb. Ba cach:')
        print('  1. winget install Google.PlatformTools   (roi MO LAI terminal:')
        print('     winget sua PATH, cua so dang mo chua thay)')
        print('  2. giai nen platform-tools canh repo — deploy.py tu do ra')
        print('  3. tro thang:  set ADB=D:/duong/dan/platform-tools/adb.exe')
        sys.exit(1)
    _adb_path = found
    return found


def adb(*args, check=False):
    try:
        r = subprocess.run((find_adb(),) + args, capture_output=True, text=True,
                           encoding='utf-8', errors='replace', timeout=120)
    except FileNotFoundError:
        sys.exit('khong chay duoc adb: ' + str(_adb_path))
    except subprocess.TimeoutExpired:
        return 1, '', 'qua thoi gian'
    if check and r.returncode != 0:
        sys.exit('adb %s that bai:\n%s' % (' '.join(args), r.stderr.strip()))
    return r.returncode, (r.stdout or '').strip(), (r.stderr or '').strip()


def need_device():
    code, out, _ = adb('devices')
    lines = [l for l in out.splitlines()[1:] if l.strip() and not l.startswith('*')]
    ready = [l.split()[0] for l in lines if l.split()[-1] == 'device']
    if not ready:
        print(out)
        sys.exit('chua co may nao san sang. Cam day + bat USB debugging, hoac mo gia lap.')
    if len(ready) > 1:
        print('co %d may, adb se tu chon may dau; dung ANDROID_SERIAL de chi dinh' % len(ready))
    return ready[0]


def writable(path):
    """Thu ghi that su — quyen tren Android khong suy duoc tu ls."""
    probe = posixpath.join(path, '.offline_probe')
    _, out, _ = adb('shell', 'mkdir -p "%s" 2>/dev/null; (echo ok > "%s") 2>/dev/null '
                             '&& rm -f "%s" && echo YES || echo NO' % (path, probe, probe))
    return out.strip().endswith('YES')


def cmd_status():
    need_device()
    _, ver, _ = adb('shell', 'getprop ro.build.version.release')
    _, sdk, _ = adb('shell', 'getprop ro.build.version.sdk')
    _, abi, _ = adb('shell', 'getprop ro.product.cpu.abi')
    print('Android %s (API %s), ABI %s' % (ver, sdk, abi))
    if abi and not (abi.startswith('arm') or 'arm' in abi):
        print('  CANH BAO: APK chi co thu vien armeabi-v7a. May/gia lap x86 phai co')
        print('            lop dich ARM (LDPlayer, Nox, hoac anh he thong arm64).')
    if sdk.isdigit() and int(sdk) >= 35:
        print('  CANH BAO: Android 15+ chan cai app targetSdk < 24; APK nay targetSdk 23.')

    _, inst, _ = adb('shell', 'pm list packages %s' % PKG)
    print('game da cai       :', 'co' if PKG in inst else 'CHUA')
    _, obb, _ = adb('shell', 'ls /sdcard/Android/obb/%s 2>/dev/null' % PKG)
    print('OBB               :', obb if obb else 'CHUA co')

    print('\nung vien thu muc ghi de:')
    for p in CANDIDATES:
        ok = writable(p)
        _, has, _ = adb('shell', 'ls %s/sc/offline/init.lua 2>/dev/null' % p)
        print('   %-52s %-10s %s' % (p, 'ghi duoc' if ok else 'khong',
                                     'da co lop offline' if has else ''))


def cmd_push(flavour):
    need_device()
    src = os.path.join(HERE, 'deploy', flavour, 'sc')
    if not os.path.isdir(src):
        sys.exit('chua co %s — chay `python build.py` truoc' % src)
    n = 0
    for p in CANDIDATES:
        if not writable(p):
            continue
        code, out, err = adb('push', src, p + '/')
        if code == 0:
            print('   day duoc -> %s/sc' % p)
            n += 1
        else:
            print('   that bai  -> %s  (%s)' % (p, err.splitlines()[-1] if err else '?'))
    if n == 0:
        sys.exit('khong day duoc vao dau ca. Chay --status xem quyen.')
    print('\nda day vao %d cho. Mo game roi chay: python deploy.py --log' % n)


SET_FLAGS = [b'<DebugTestMode>true</DebugTestMode>', b'<CloseGuide>true</CloseGuide>']


def plain_xml(raw):
    """set.xgg co that su la XML thuan khong.

    Game tu ghi file nay luc chay (sc/user/Public/set.lua:83) nen binh thuong
    la text. Nhung duoi .xgg cung la duoi cua tai nguyen da ma hoa 'sngFile' /
    nen gzip — sua mot file nhu the bang phep thay chuoi roi day nguoc len may
    la lam hong no. Tha khong lam gi con hon.
    """
    if raw.endswith(b'sngFile'):
        return False, 'da ma hoa sngFile'
    if raw[:3] == b'\x1f\x8b\x08':
        return False, 'da nen gzip'
    if b'\x00' in raw:
        return False, 'co byte NUL, khong phai text'
    try:
        raw.decode('utf-8')
    except UnicodeDecodeError:
        return False, 'khong phai UTF-8'
    return True, ''


def cmd_flags():
    """Bat cong tac go loi co san cua game trong set.xgg.

    set.xgg chi duoc tao o lan chay dau (sc/user/Public/set.lua:83), nen phai
    mo game it nhat mot lan truoc khi goi lenh nay.
    """
    need_device()
    found = False
    for p in CANDIDATES:
        remote = '%s/set.xgg' % p
        _, out, _ = adb('shell', 'ls %s 2>/dev/null' % remote)
        if not out:
            continue
        found = True
        local = os.path.join(HERE, 'deploy', 'set.xgg')
        os.makedirs(os.path.dirname(local), exist_ok=True)
        adb('pull', remote, local, check=True)
        raw = open(local, 'rb').read()

        ok, why = plain_xml(raw)
        if not ok:
            print('   %s: BO QUA — %s.' % (remote, why))
            print('      Sua bang phep thay chuoi se lam hong file; phai giai ma truoc'
                  ' (xem ../sng_decrypt.py).')
            continue

        # Sua tren bytes, va chi tinh la "da them" khi phep thay THAT SU an —
        # thieu the </user> thi khong duoc bao thanh cong roi day file y nguyen.
        edited, added, no_anchor = raw, [], []
        for f in SET_FLAGS:
            tag = f[1:f.index(b'>')]
            if b'<' + tag + b'>' in edited:
                continue
            before = edited
            edited = edited.replace(b'</user>', b'\t' + f + b'\n</user>', 1)
            (added if edited != before else no_anchor).append(tag.decode())

        if no_anchor:
            print('   %s: KHONG chen duoc %s — file khong co the </user>.'
                  % (remote, ', '.join(no_anchor)))
            print('      Dau file: %s'
                  % raw.decode('utf-8', 'replace')[:120].replace('\n', ' '))
        if not added:
            if not no_anchor:
                print('   %s: da co san ca hai cong tac' % remote)
            continue

        open(local, 'wb').write(edited)
        adb('push', local, remote, check=True)
        print('   %s: them %s' % (remote, ', '.join(added)))
    if not found:
        print('chua thay set.xgg o dau — mo game mot lan truoc da.')


def cmd_log(follow):
    need_device()
    for p in CANDIDATES:
        remote = '%s/offline.log' % p
        _, out, _ = adb('shell', 'ls %s 2>/dev/null' % remote)
        if not out:
            continue
        print('=== %s ===' % remote)
        if follow:
            subprocess.run([find_adb(), 'shell', 'tail', '-f', remote])
        else:
            _, body, _ = adb('shell', 'cat %s' % remote)
            print(body)
        return
    print('chua thay offline.log. Nghia la lop offline chua chay:')
    print('  - kiem tra da day file chua      : python deploy.py --status')
    print('  - xem game co crash khong        : adb logcat -d | grep -iE "lua|cocos|OFFLINE"')


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--status', action='store_true', help='kiem tra may, quyen, thu muc')
    ap.add_argument('--push', action='store_true', help='day lop offline len may')
    ap.add_argument('--sng', action='store_true', help='day ban da ma hoa thay vi ban nguyen van')
    ap.add_argument('--flags', action='store_true', help='bat DebugTestMode / CloseGuide')
    ap.add_argument('--log', action='store_true', help='doc offline.log tren may')
    ap.add_argument('-f', '--follow', action='store_true', help='theo doi log lien tuc')
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')

    if a.status: cmd_status()
    elif a.push: cmd_push('sng' if a.sng else 'plain')
    elif a.flags: cmd_flags()
    elif a.log or a.follow: cmd_log(a.follow)
    else: ap.print_help()


if __name__ == '__main__':
    main()
