# -*- coding: utf-8 -*-
"""Test cho deploy.py — chay duoc ma khong can may Android.

deploy.py la phan duy nhat cua lop offline dung toi thiet bi that, nen truoc
day no la phan duy nhat khong co test. Rui ro nam o --flags: day la lenh duy
nhat GHI DE mot file cua game tren may. Duoi .xgg cung chinh la duoi cua tai
nguyen da ma hoa 'sngFile' / nen gzip, nen mot phep thay chuoi vo y la du de
lam hong file cai dat.

Bo test thay ham deploy.adb() bang mot may gia (dict duong dan -> bytes) roi
kiem tra dung ba loi hua cua deploy.py:

  1. khong dung vao file khong phai XML thuan
  2. khong bao "da them" khi phep chen khong an
  3. khong day gi len may khi khong sua duoc gi

    python test/test_deploy.py
"""
import io, os, sys, gzip, tempfile, contextlib

HERE = os.path.dirname(os.path.abspath(__file__))
OFFLINE = os.path.dirname(HERE)
WORK = os.path.dirname(OFFLINE)
sys.path.insert(0, OFFLINE)
sys.path.insert(0, WORK)

import deploy
from sng_encrypt import pack

nPass = nFail = 0


def check(bCond, strDesc, detail=None):
    global nPass, nFail
    if bCond:
        nPass += 1
        print('  dat   %s' % strDesc)
    else:
        nFail += 1
        print('  HONG  %s%s' % (strDesc, '' if detail is None else '  -> %s' % (detail,)))


# --------------------------------------------------------------- may gia lap
class FakeDevice(object):
    """May Android gia: mot dict duong dan -> noi dung, cong danh sach thu muc
    ghi duoc. Chan o dung cho deploy.adb(), tuc la moi thu ben duoi (tim adb,
    subprocess, USB) deu khong dinh toi."""

    def __init__(self, files=None, writable=None):
        self.files = dict(files or {})
        self.writable = set(writable or [])
        self.pushed = []                      # (local, remote) moi lan adb push

    def adb(self, *args, **kw):
        verb = args[0]
        if verb == 'devices':
            return 0, 'List of devices attached\nemulator-5554\tdevice', ''
        if verb == 'shell':
            return self._shell(args[1])
        if verb == 'pull':
            remote, local = args[1], args[2]
            if remote not in self.files:
                return 1, '', 'khong co %s' % remote
            os.makedirs(os.path.dirname(local), exist_ok=True)
            open(local, 'wb').write(self.files[remote])
            return 0, '', ''
        if verb == 'push':
            local, remote = args[1], args[2]
            self.pushed.append((local, remote))
            if os.path.isfile(local):
                self.files[remote.rstrip('/')] = open(local, 'rb').read()
            return 0, '', ''
        return 0, '', ''

    def _shell(self, cmd):
        if cmd.startswith('ls '):
            path = cmd[3:].split(' 2>')[0].strip()
            return 0, (path if path in self.files else ''), ''
        if 'mkdir -p' in cmd:                 # phep thu ghi cua deploy.writable()
            path = cmd.split('"')[1]
            return 0, ('YES' if path in self.writable else 'NO'), ''
        if cmd.startswith('getprop'):
            return 0, {'ro.build.version.release': '9',
                       'ro.build.version.sdk': '28',
                       'ro.product.cpu.abi': 'armeabi-v7a'}.get(cmd.split()[-1], ''), ''
        if 'pm list packages' in cmd:
            return 0, 'package:%s' % deploy.PKG, ''
        return 0, '', ''


@contextlib.contextmanager
def device(dev, candidates, home=None):
    """Cam may gia vao deploy, va tro HERE vao thu muc tam de khong ban repo."""
    tmp = home or tempfile.mkdtemp(prefix='deploy_test_')
    saved = (deploy.adb, deploy.CANDIDATES, deploy.HERE)
    deploy.adb, deploy.CANDIDATES, deploy.HERE = dev.adb, candidates, tmp
    buf = io.StringIO()
    try:
        with contextlib.redirect_stdout(buf):
            yield buf
    finally:
        deploy.adb, deploy.CANDIDATES, deploy.HERE = saved


# ------------------------------------------------------------- du lieu mau
P = '/sdcard/Android/data/%s/files' % deploy.PKG
REMOTE = P + '/set.xgg'

XML_OK = b'<set>\n<user>\n\t<Volume>1</Volume>\n</user>\n</set>'
XML_HAS = (b'<set>\n<user>\n\t<DebugTestMode>true</DebugTestMode>\n'
           b'\t<CloseGuide>true</CloseGuide>\n</user>\n</set>')
XML_NO_USER = b'<set>\n<config>\n\t<Volume>1</Volume>\n</config>\n</set>'
ENCRYPTED = pack(XML_OK, 'set.xgg')           # gzip + XOR + magic sngFile
GZIPPED = gzip.compress(XML_OK)
BINARY = b'<set>\x00\x01<user></user></set>'


def run_flags(raw):
    dev = FakeDevice(files={REMOTE: raw}, writable=[P])
    with device(dev, [P]) as buf:
        deploy.cmd_flags()
    return dev, buf.getvalue()


# ------------------------------------------------------------------- chay
print('=== 1. plain_xml: nhan dien file khong duoc dung cham ===')
for name, raw, want in [('XML thuan', XML_OK, True),
                        ('da ma hoa sngFile', ENCRYPTED, False),
                        ('nen gzip', GZIPPED, False),
                        ('co byte NUL', BINARY, False),
                        ('UTF-16', XML_OK.decode().encode('utf-16-le'), False)]:
    ok, why = deploy.plain_xml(raw)
    check(ok == want, '%s -> %s' % (name, 'sua duoc' if want else 'phai bo qua'),
          'plain_xml tra ve %s (%s)' % (ok, why))

print('\n=== 2. --flags tren XML thuan ===')
dev, out = run_flags(XML_OK)
now = dev.files[REMOTE]
check(b'<DebugTestMode>true</DebugTestMode>' in now, 'da chen DebugTestMode')
check(b'<CloseGuide>true</CloseGuide>' in now, 'da chen CloseGuide')
check(b'<Volume>1</Volume>' in now, 'giu nguyen phan con lai cua file')
check(not now.startswith(b'\xef\xbb\xbf'), 'khong chen BOM vao file')
check(len(dev.pushed) == 1, 'day len may dung 1 lan', len(dev.pushed))

print('\n=== 3. --flags khi da co san ca hai cong tac ===')
dev, out = run_flags(XML_HAS)
check('da co san' in out, 'bao la da co san', out.strip())
check(len(dev.pushed) == 0, 'khong day lai file khong doi', len(dev.pushed))

print('\n=== 4. --flags khi file thieu the </user> ===')
dev, out = run_flags(XML_NO_USER)
check('KHONG chen duoc' in out, 'bao ro la khong chen duoc', out.strip()[:70])
check('them' not in out, 'KHONG duoc bao thanh cong')
check(len(dev.pushed) == 0, 'khong day gi len may', len(dev.pushed))
check(dev.files[REMOTE] == XML_NO_USER, 'file tren may nguyen ven')

print('\n=== 5. --flags khi set.xgg da bi ma hoa / nen ===')
for name, raw in [('sngFile', ENCRYPTED), ('gzip', GZIPPED), ('nhi phan', BINARY)]:
    dev, out = run_flags(raw)
    check('BO QUA' in out and len(dev.pushed) == 0 and dev.files[REMOTE] == raw,
          '%s: tu choi sua, khong day len, file trung tung byte' % name,
          out.strip()[:70])

print('\n=== 6. --push ===')
tmp = tempfile.mkdtemp(prefix='deploy_nobuild_')
dev = FakeDevice(writable=[P])
bStopped = False
try:
    with device(dev, [P], home=tmp):
        deploy.cmd_push('plain')
except SystemExit:
    bStopped = True
check(bStopped, 'dung lai khi chua chay build.py')
check(len(dev.pushed) == 0, 'khong day gi khi chua build', len(dev.pushed))

tmp = tempfile.mkdtemp(prefix='deploy_built_')
os.makedirs(os.path.join(tmp, 'deploy', 'plain', 'sc', 'offline'))
open(os.path.join(tmp, 'deploy', 'plain', 'sc', 'offline', 'init.lua'), 'w').write('-- test')
KHONG_GHI_DUOC = '/sdcard/chi-doc'
dev = FakeDevice(writable=[P])
with device(dev, [P, KHONG_GHI_DUOC], home=tmp):
    deploy.cmd_push('plain')
check(len(dev.pushed) == 1, 'chi day vao thu muc ghi duoc', len(dev.pushed))
check(dev.pushed and dev.pushed[0][1] == P + '/', 'day dung dich',
      dev.pushed[0][1] if dev.pushed else None)

print('\n=== 7. tim adb ===')


@contextlib.contextmanager
def adb_env(value, here=None):
    """Do sach cache va PATH de moi lan do lai tu dau."""
    saved_env = os.environ.get('ADB')
    saved = (deploy._adb_path, deploy.HERE, deploy.ADB_GUESSES, os.environ.get('PATH'))
    deploy._adb_path = None
    deploy.ADB_GUESSES = []                          # bo cac duong doan co san
    os.environ['PATH'] = ''                          # bo shutil.which('adb')
    if here:
        deploy.HERE = here
    if value is None:
        os.environ.pop('ADB', None)
    else:
        os.environ['ADB'] = value
    try:
        yield
    finally:
        deploy._adb_path, deploy.HERE, deploy.ADB_GUESSES = saved[0], saved[1], saved[2]
        os.environ['PATH'] = saved[3] or ''
        if saved_env is None:
            os.environ.pop('ADB', None)
        else:
            os.environ['ADB'] = saved_env


tmp = tempfile.mkdtemp(prefix='adb_test_')
fake_adb = os.path.join(tmp, 'adb.exe')
open(fake_adb, 'w').write('')

with adb_env(fake_adb):
    check(deploy.find_adb() == fake_adb, 'bien moi truong ADB duoc uu tien')

with adb_env(os.path.join(tmp, 'khong-ton-tai.exe')):
    try:
        deploy.find_adb()
        bStopped = False
    except SystemExit:
        bStopped = True
    check(bStopped, 'ADB tro toi cho khong co file thi bao loi, khong im lang di tiep')

# platform-tools giai nen canh repo: <cha>/platform-tools_rXX/platform-tools/adb.exe
sib = os.path.join(tmp, 'repo', 'work', 'offline')
os.makedirs(sib)
pt = os.path.join(tmp, 'platform-tools_r33.0.2-windows', 'platform-tools')
os.makedirs(pt)
open(os.path.join(pt, 'adb.exe'), 'w').write('')
with adb_env(None, here=sib):
    got = deploy.find_adb()
    check(got == os.path.join(pt, 'adb.exe'), 'do ra platform-tools giai nen canh repo', got)

with adb_env(None, here=tempfile.mkdtemp(prefix='trong_')):
    buf = io.StringIO()
    try:
        # find_adb() in huong dan ra stdout; nuot lai cho khoi lam ban output test
        with contextlib.redirect_stdout(buf):
            deploy.find_adb()
        bStopped = False
    except SystemExit:
        bStopped = True
    check(bStopped, 'khong tim thay o dau thi dung lai')
    check('winget' in buf.getvalue() and 'ADB=' in buf.getvalue(),
          'va chi ra ca ba cach cai', buf.getvalue().strip()[:60])

print('\n===== dat %d, hong %d =====' % (nPass, nFail))
sys.exit(0 if nFail == 0 else 1)
