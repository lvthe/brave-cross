# -*- coding: utf-8 -*-
"""Phan giai cay thu muc lam viec — mot cho duy nhat biet dang chay ban nao.

Ba ban cua cung dong game, ba cay khac nhau:

    cn125   ban CN 1.25 com.xh.dachui.xsj   work/            (layout kieu CN)
    vn      ban VN 1.26 com.cmn.buatanew    work/vn/         (co obb/)
    cn131   ban CN 1.31 com.wh.dachui       work/cn131/      (layout kieu CN)

Truoc day moi script tu viet duong dan cua minh, gan chat vao ban VN. Module
nay thay cho cac duong dan do:

    import cay
    BANKS = cay.BANKS

Chon ban bang bien moi truong `BC_TREE`, MAC DINH 'vn' — tuc la giu nguyen hanh
vi cu cua moi script da doi sang dung cay.*, khong pha gi dang chay.

    python build_spec.py --assets cn131/decrypted/assets --out server-spec-131
    BC_TREE=cn131 python bank.py --json

Hai kieu duong dan phai phan biet ro:

    cay.ASSETS      tai nguyen DA GIAI MA   work/<ban>/decrypted/assets
    cay.APK_ASSETS  tai nguyen GOC, con ma hoa 'sngFile'

Khong duoc lan lon: `sng_encrypt.py --selftest` doi cay GOC con ma hoa, chay
nham cay da giai ma thi moi file bi bo qua va bao "khong ma hoa" — trong nhu
dat ma vo nghia.

Cache sinh tu mot ban KHONG dung duoc cho ban khac (dia chi trong .so, bang
tham chieu cheo deu theo phiên ban). Dung `cay.cache('picmap.pkl')` de ten no
tu tach ra, vi du `picmap.cn131.pkl`.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

#: Thu muc CHA cua repo nay — `C:\Project\game`, khong phai repo git nao.
NGOAI = os.path.abspath(os.path.join(HERE, '..', '..'))

#: Kho chua phan NANG cua cac ban da doi ra ngoai repo (2026-09-19).
KHO = os.path.join(NGOAI, 'bravecross-source')

#: Ban nao co cay NGUON nam trong `KHO` thay vi `work/`.
#:
#: Doi vi mot lo DA XAY RA, khong phai so thich: `.gitignore` cua repo nay che
#: `*.apk`, `*.so`, `work/decrypted/`, `work/vn/`... nhung `work/cn131/` (1,2 GB,
#: 21.950 file) khong khop dong nao, nen no hien ra trong `git status` dang `??`
#: — chi mot lenh `git add -A` la toan bo noi dung game co ban quyen vao lich su.
#: Them mot dong `.gitignore` moi lan them ban la cach chua phai nho, va se quen.
NGAN = ('cn131',)


def goc_cua(ten):
    """Thu muc goc cua mot ban bat ky, theo TEN chu khong theo singleton.

    Can khi mot script lam viec voi HAI ban cung luc — `inventory.py` so kho
    tai nguyen cua ban nay voi ban kia.

        goc_cua('cn125') -> work/                        (ban cu nam ngay trong work/)
        goc_cua('vn')    -> work/vn/
        goc_cua('cn131') -> ../bravecross-source/cn131/  (xem `NGAN`)
    """
    if ten in ('cn125', '.'):
        return HERE
    if ten in NGAN:
        return os.path.join(KHO, ten)
    return os.path.join(HERE, ten)


#: Ten ban dang lam viec. Doi bang bien moi truong BC_TREE.
TEN = os.environ.get('BC_TREE', 'vn')

#: Thu muc goc cua ban dang lam viec. Ban cn125 nam ngay trong work/.
GOC = goc_cua(TEN)

#: Tai nguyen da giai ma.
ASSETS = os.path.join(GOC, 'decrypted', 'assets')

#: APK / XAPK da giai nen.
APK = os.path.join(GOC, 'apk')

#: Tai nguyen GOC trong APK — con nguyen lop ma hoa 'sngFile'.
APK_ASSETS = os.path.join(GOC, 'apk', 'assets')

#: Thu vien native cua engine.
SO = os.path.join(GOC, 'apk', 'lib', 'armeabi-v7a', 'libgame.so')

#: Thu vien FMOD — noi mang 32 khoi setup Vorbis ma bank tham chieu toi.
LIBFMOD = os.path.join(GOC, 'apk', 'lib', 'armeabi-v7a', 'libfmod.so')

#: Kho bank FMOD (chua giai ma — bank.py tu boc lop RIFF).
BANKS = os.path.join(GOC, 'apk', 'assets', 'banks')

#: OBB da giai nen. Chi ban VN moi co; ban nao khong co thi None.
_OBB = os.path.join(GOC, 'obb')
OBB = _OBB if os.path.isdir(_OBB) else None


def cache(ten):
    """Duong dan cache rieng cho tung ban — 'picmap.pkl' -> 'picmap.cn131.pkl'.

    Cache sinh tu ban khac thi KHONG dung lai duoc: dia chi trong .so lech
    nhau giua cac ban, nen bang tham chieu cheo cua ban nay vo nghia voi ban
    kia. Tach ten ra thi khong the lan.
    """
    goc, duoi = os.path.splitext(ten)
    return os.path.join(HERE, '%s.%s%s' % (goc, TEN, duoi))


def co(duong):
    """Co ton tai duong dan nay khong (file hoac thu muc). None -> False.

    De `tom_tat()` va khoi `__main__` kiem tra mot luot xem cay dang chon co
    du khong, thay vi de tung script bao loi rieng.
    """
    return bool(duong) and os.path.exists(duong)


def _goc_dich():
    """Thu muc CHUA cac thu muc dich. Ban 'vn' trong repo game, ban khac ra ngoai.

    Vi sao ban khac ra ngoai — khong phai so thich, ma la mot lo DA XAY RA
    (2026-09-19): `data_ref-cn131/` va `layout_ref-cn131/` sinh thang vao
    `bravecross-game/` trong khi `.gitignore` cua repo do che `data_ref/` va
    `layout_ref/` nhung KHONG che ten nao them hau to `-<ban>`. Hai thu muc ay
    hien ra trong `git status` dang `??`, tuc chi mot lenh `git add -A` la 32 MB
    du lieu co ban quyen vao thang lich su repo.

    Sua `.gitignore` moi lan them ban la cach chua phai nho, va se quen. Do ra
    ngoai repo game thi khong con gi phai che: `C:\\Project\\game` khong phai
    repo git nao.

    Do them (2026-09-19): cac ban trong `NGAN` khong con do ra `C:\\Project\\game`
    nua ma do vao `KHO` (`bravecross-source/`), de thu muc cha bot lon xon — nam
    thu muc `*-cn131` (942 MB) truoc day nam ngay canh hai repo.

        cay._goc_dich() -> .../bravecross-game          (vn)
        cay._goc_dich() -> .../bravecross-source        (cn131 — xem `NGAN`)
        cay._goc_dich() -> .../game                     (cn125, ...)
    """
    if TEN == 'vn':
        return os.path.join(NGOAI, 'bravecross-game')
    return KHO if TEN in NGAN else NGOAI


def dich(ten=None):
    """Thu muc dich cho BANG SO lieu, tach han theo ban.

    Cac script 'be du lieu ra game moi' (config_tables, wake_ref, trigger_ref,
    event_ref...) ghi vao `data_ref/`. Du lieu do dang dung la cua ban VN —
    chay ban khac ma ghi cung cho la DE MAT. Nen ban 'vn' giu nguyen
    `data_ref/` trong repo game, ban khac ra thu muc anh em rieng o NGOAI repo
    (xem `_goc_dich` de biet vi sao ngoai):

        cay.dich()         -> bravecross-game/data_ref            (vn)
        cay.dich()         -> game/data_ref-cn131                 (cn131)
        cay.dich('config') -> bravecross-game/data_ref/config     (vn)
        cay.dich('config') -> game/data_ref-cn131/config          (cn131)

    Tra ve chuoi, khong phai pathlib.Path, de script nao cung dung duoc.
    """
    goc = os.path.join(_goc_dich(), 'data_ref' if TEN == 'vn'
                       else 'data_ref-%s' % TEN)
    return os.path.join(goc, ten) if ten else goc


def dich_anh(ten=None):
    """Thu muc dich cho TAI NGUYEN XUAT RA (anh, am thanh, bo cuc), tach theo ban.

    `dich()` lo phan `data_ref/` (JSON so lieu). Nhung con bon thu muc nua cung
    do tu cay nguon ra va CUNG nguy hiem neu tron:

        assets_ref  27542 file   atlas -> PNG + JSON (export.py)
        ui_ref      15723 file   .pkm  -> PNG        (uiart.py)
        layout_ref    296 file   bo cuc man hinh    (layout.py)
        hat_ref        34 file   anh mu               (hatref.py)

    Ban 1.31 co 1647 subsound am thanh, ban VN co 1498. Ghi cung mot cho thi
    khong mot loi nao noi len — chi co hai bo am thanh lan vao nhau, va ten nao
    trung thi cai sau de cai truoc. Nen cung mot luat nhu `dich()`: ban 'vn'
    giu nguyen cho cu trong repo game, ban khac ra thu muc anh em them hau to
    o NGOAI repo game (xem `_goc_dich` de biet vi sao ngoai):

        cay.dich_anh()          -> bravecross-game/assets_ref   (vn)
        cay.dich_anh()          -> game/assets_ref-cn131        (cn131)
        cay.dich_anh('ui_ref')  -> bravecross-game/ui_ref       (vn)
        cay.dich_anh('ui_ref')  -> game/ui_ref-cn131            (cn131)

    Tra ve chuoi, khong phai pathlib.Path.
    """
    ten = ten or 'assets_ref'
    return os.path.join(_goc_dich(), ten if TEN == 'vn' else '%s-%s' % (ten, TEN))


#: Ten file moc ghi lai BAN nao da ghi ra mot thu muc dich.
MOC = '.ban'


def _moc_gan_nhat(out):
    """(duong dan moc, ten ban) cua moc `.ban` GAN NHAT tinh tu `out` di len.

    Phai di len chu khong chi doc `out/.ban`. Thu muc CON chua ton tai thi khong
    co moc rieng, nhung no van nam TRONG cay cua mot ban — va do la mot lo DA
    XAY RA (2026-09-19):

        BC_TREE=vn python hatref.py --out .../assets_ref-cn131/hat_mu

    `hat_mu` chua co nen `hat_mu/.ban` khong ton tai, phep kiem cu thay "khong
    moc" roi ket luan "cho nay vo chu" — trong khi moc cua thu muc CHA ghi ro
    'cn131'. Ket qua: 34 file cua ban VN ghi thang vao giua cay cua ban 1.31.
    Cung lop loi voi `layout.py` (xem README): khong co gi bao, chi co du lieu
    cua hai ban tron vao nhau.
    """
    p = os.path.abspath(out)
    for _ in range(12):
        moc = os.path.join(p, MOC)
        if os.path.exists(moc):
            try:
                with open(moc, encoding='utf-8') as f:
                    return moc, f.read().strip()
            except OSError:
                return moc, ''
        cha = os.path.dirname(p)
        if cha == p:                      # toi goc dia
            break
        p = cha
    return None, ''


def giu_cho(out):
    """None neu duoc phep ghi vao `out`; chuoi loi neu cho do la cua ban khac.

    Dat mot file moc `.ban` ghi ten ban da ghi ra thu muc. Lan sau ghi vao ma
    moc ghi ten BAN KHAC thi dung lai. Day la thu chan loi khong the tu phat
    hien: tron 1647 file .ogg cua ban 1.31 vao cho 1499 file cua ban VN thi
    khong mot ngoai le nao nem ra, chi co am thanh lan nhau — va ten nao trung
    thi cai sau de cai truoc, mat file ma khong biet.

    Moc duoc soi tu `out` DI LEN (xem `_moc_gan_nhat`), nen thu muc con cua mot
    cay cung bi chan theo moc cua thu muc cha.

    Con lai mot cho ho: duong dan HOAN TOAN MOI, khong moc o bat cu cap nao, va
    thu muc chua ton tai — thi khong co gi de doi chieu, nen cho qua. Do la gia
    phai tra de khong chan nham lan ghi hop le dau tien.
    """
    moc, cu = _moc_gan_nhat(out)
    if moc:
        if cu and cu != TEN:
            return ('%s\n  nam trong cay cua ban %r (moc %s), khong phai ban %r dang chay.\n'
                    '  Ghi tiep se tron hai bo file vao nhau va de mat file trung ten.\n'
                    '  Doi cho khac (cay.dich_anh(...)) hoac xoa %s neu chac chan muon de.'
                    % (out, cu, moc, TEN, moc))
        return None
    # Khong moc o bat cu cap nao: neu thu muc da co file thi coi nhu cua ban 'vn'.
    if TEN != 'vn':
        try:
            co_file = any(os.scandir(out))
        except OSError:
            co_file = False
        if co_file:
            return ('%s\n  da co file nhung khong co moc %s, nen day la cho ghi cu\n'
                    '  cua ban \'vn\'. Ban dang chay la %r. Ghi tiep se tron hai bo\n'
                    '  file vao nhau. Doi cho khac (cay.dich_anh(...)).'
                    % (out, MOC, TEN))
    return None


def danh_dau(out):
    """Ghi moc ban vao thu muc dich — goi SAU khi da qua `giu_cho()`."""
    try:
        os.makedirs(out, exist_ok=True)
        with open(os.path.join(out, MOC), 'w', encoding='utf-8') as f:
            f.write(TEN + '\n')
    except OSError:
        pass


#: Co (byte) cua file libgame.so ma MOI dia chi ham trong work/ duoc do ra —
#: tuc ban VN. Dia chi chi dung cho dung file nay.
SO_DA_DO = 10213832

#: Co (byte) cua `.so` cho TUNG ban da do ra hang so. Chi gom ban nao THAT SU
#: co hang so trong work/ — ban khong co mat thi bi tu choi, khong doan.
#:
#:   vn     10213832  do lai bang tim_bang.py, khop binder.py (2026-09-19)
#:   cn131  11306184  do bang tim_bang.py (2026-09-19), xem binder.py:SO_BAN
#:
#: cn125 (10231498 byte) CO trong cay nhung KHONG co mat o day: chua do hang so
#: cho no, nen no phai bi tu choi chu khong duoc roi vao nhanh nao.
CO_SO = {
    'vn': 10213832,
    'cn131': 11306184,
}


def kiem_so():
    """Chan cho cac script CON CUng dia chi VN: None neu dung, chuoi loi neu khac.

    Cac script nhu shaders.py / move_vt.py / picmap.py mang dia chi ham cung
    (BANG_NGUON, CTOR...) do ra tu MOT file .so cu the — ban VN. Tro chung sang
    .so cua ban khac ma khong do lai thi moi dia chi deu lech, va ket qua se SAI
    IM LANG, khong bao loi. Nen phai chan truoc:

        loi = cay.kiem_so()
        if loi:
            sys.exit(loi)

    KHONG dung ham nay cho script da co hang so theo tung ban (binder.py) — no se
    chan dung cai ma script ay lam duoc. Dung `kiem_so_ban()`.
    """
    if not os.path.exists(SO):
        return 'khong thay %s' % SO
    n = os.path.getsize(SO)
    if n != SO_DA_DO:
        return ('%s\n  la %d byte, khong phai ban da do dia chi (%d byte).\n'
                '  Moi dia chi ham trong work/ deu lech voi file nay. Phai do lai\n'
                '  dia chi cho ban nay truoc; chay tiep se ra ket qua sai am tham.'
                % (SO, n, SO_DA_DO))
    return None


def kiem_so_ban(ten=None):
    """Chan theo TUNG BAN: None neu `.so` dung la ban da do hang so, loi neu khac.

    Danh cho script da co hang so rieng cho tung ban (binder.py). Khac
    `kiem_so()` o cho: khong doi file phai la ban VN, ma doi file phai dung la
    ban ma BANG HANG SO SAP DUNG duoc do ra. Co file la dieu kien CAN, khong
    phai dieu kien DU — ba file .so cua ba ban khac han nhau ve bo cuc, nen mot
    hang so do tren ban nay dan sang file cung co nhung khac ban la sai het.

    Ban chua co trong `CO_SO` thi bi tu choi thang: doan mot con so se lam phep
    kiem nay thanh vo nghia (no luon dung).
    """
    ten = ten or TEN
    if not os.path.exists(SO):
        return 'khong thay %s' % SO
    if ten not in CO_SO:
        return ('ban %r chua duoc do hang so trong work/ (CO_SO khong co mat).\n'
                '  Chua biet dia chi nao dung cho ban nay, nen khong chay tiep.'
                % ten)
    n = os.path.getsize(SO)
    if n != CO_SO[ten]:
        return ('%s\n  la %d byte, khong phai ban %s da do hang so (%d byte).\n'
                '  Hang so cua ban %s lech voi file nay; chay tiep se ra ket qua\n'
                '  sai am tham.'
                % (SO, n, ten, CO_SO[ten], ten))
    return None


def tom_tat():
    """Cac duong dan da phan giai, dang 'ten  duong-dan' — de kiem tra nhanh."""
    return [
        ('ban', TEN),
        ('goc', GOC),
        ('ASSETS', ASSETS),
        ('APK', APK),
        ('APK_ASSETS', APK_ASSETS),
        ('SO', SO),
        ('LIBFMOD', LIBFMOD),
        ('BANKS', BANKS),
        ('OBB', OBB or '(khong co)'),
    ]


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    # Tien cho viec doi ban: BC_TREE=cn131 python cay.py  ->  thay ngay cai nao thieu.
    for ten, duong in tom_tat():
        dau = ' ' if (duong == TEN or co(duong) or duong == '(khong co)') else '!'
        print('%s %-11s %s' % (dau, ten, duong))
