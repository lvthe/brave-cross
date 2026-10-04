# -*- coding: utf-8 -*-
"""Giai anh giao dien tu .pkm ra PNG, danh chi muc theo TEN FRAME.

Hoa ra anh UI khong nam trong atlas: moi anh la mot file .pkm rieng trong
sngSplitData/. Ten file trung khit ten trong section C cua .xgg — vi du
'item_55.png' trong bo cuc <-> sngSplitData/item_55.pkm. Kiem tren HUD man
tran: 93/94 anh tim thay.

ETC1 khong co kenh alpha nen game dung thu thuat quen thuoc: anh cao GAP DOI,
nua tren la mau, nua duoi la alpha dang xam. Chieu cao con duoc dem cho chia
het 4 (yeu cau cua ETC1), nen kich thuoc that lay tu bo cuc chu khong tu file.

Chi muc sinh ra cho Godot tra cuu y het S_CCSpriteFrameCache:spriteFrameByName
cua ban goc — do la cach ban goc gan anh, xem CUIGame.lua.

    python uiart.py --out <thu_muc>                # giai het
    python uiart.py --out <thu_muc> --only item_55 ui_background204
    python uiart.py --list                         # chi dem, khong ghi
"""
import os
import sys
import json
import glob
import struct
import argparse
import collections

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import cay
from sprites import read_pkm, write_png, SpriteError

DEFAULT_ASSETS = cay.ASSETS


def find_pkm(assets):
    """{duong dan tuong doi khong duoi: duong dan that}.

    PHAI giu ca duong dan, khong duoc rut ve ten tep. Co 26 cho trung ten ma
    khac anh — vi du `ui_background176` co hai ban: `png/book/` (152x155) va
    `sngSplitData/v6/` (76x77). Bo cuc ghi ro la ban nao (`v6/...`), nen rut
    ve ten tep roi giu cai gap truoc la lay nham anh: o thanh tuu phinh gap
    doi, tran ra ngoai dong va de len ca nhan ten ben canh.
    """
    out = collections.OrderedDict()
    for p in sorted(glob.glob(os.path.join(assets, '**', '*.pkm'), recursive=True)):
        rel = os.path.relpath(p, assets).replace('\\', '/')[:-4]
        out[rel] = p
    return out


PNG_MAGIC = b'\x89PNG\r\n\x1a\n'


def is_png(path):
    """Vai file .pkm that ra la PNG thuong (png/game_logo.pkm, png/logo.pkm).

    Chung khong qua ETC1 nen khong co tro nua-mau-nua-alpha; chep thang.
    """
    with open(path, 'rb') as fp:
        return fp.read(8) == PNG_MAGIC


def png_size(path):
    """(w, h) doc tu header PNG, hoac None neu khong doc duoc."""
    try:
        with open(path, 'rb') as fp:
            head = fp.read(24)
        if len(head) < 24 or head[:8] != PNG_MAGIC or head[12:16] != b'IHDR':
            return None
        return struct.unpack('>2I', head[16:24])
    except OSError:
        return None


def jpg_size(path):
    """(w, h) doc tu marker SOF cua JPEG, hoac None neu khong doc duoc.

    Khong dung thu vien ngoai: trinh doc JPEG that su chi can doc header. Di het
    cac marker 0xFFxx, bo qua phan du lieu theo do dai ghi trong marker, dung lai
    o SOF0..SOF15 (tru SOF4/8/12 la marker khac) — do la cho duy nhat co kich
    thuoc. Anh trong game deu la JPEG thuong, khong phai progressive, nhung
    duong nay dung ca cho progressive (SOF2).
    """
    try:
        with open(path, 'rb') as fp:
            if fp.read(2) != b'\xff\xd8':
                return None
            while True:
                b = fp.read(1)
                while b and b != b'\xff':
                    b = fp.read(1)
                if not b:
                    return None
                m = fp.read(1)
                while m == b'\xff':          # byte dem 0xFF truoc marker
                    m = fp.read(1)
                if not m:
                    return None
                mk = m[0]
                if mk in (0xd8, 0x01) or 0xd0 <= mk <= 0xd7:
                    continue                 # marker khong co do dai
                raw = fp.read(2)
                if len(raw) < 2:
                    return None
                n = struct.unpack('>H', raw)[0]
                if 0xc0 <= mk <= 0xcf and mk not in (0xc4, 0xc8, 0xcc):
                    head = fp.read(5)
                    if len(head) < 5:
                        return None
                    h, w = struct.unpack('>2H', head[1:5])
                    return w, h
                fp.seek(n - 2, os.SEEK_CUR)
    except OSError:
        return None


def find_roi(assets, da_co):
    """Anh ROI nam ngoai .pkm: {khoa: duong dan that}.

    Vi sao phai co. `find_pkm` chi gom `**/*.pkm`, nen **64 anh roi** (37 .jpg +
    27 .png) khong he co mat trong chi muc — trong do co ca nam anh nen hoi thoai
    `png/background/v6/ui_background26{2,3}.jpg`, `ui_background436.jpg`,
    `ui_tongque_bg.jpg`, `juntuanyingdi.jpg`. Ban goc goi chung bang DUONG DAN DAY
    DU: `lNormalDlgBackGround:initWithFile("png/background/v6/ui_background263.jpg")`
    (CSceneManager.lua:588, CUIManager.lua:1676).

    Do duoc truoc khi sua: ten ay khong co trong chi muc, nen `UiFrames` rot
    xuong luat "ten tran trung thi chon sngSplitData/" va tra ve
    `sngSplitData/v6/ui_background263` — **124x124**, khong phai 1665x768. Man
    Doanh Trai vi the khong co nen.

    KHONG thay the bang ban .pkm cung ten: `png/background/ui_background263.pkm`
    (1665x768) la mot ANH KHAC, khong phai ban nen cua tep .jpg — do lech mau
    trung binh 83/255 khi doi chieu tung diem (lat doc cung 85, nen khong phai
    loi huong). Phai doc dung tep ma ma goc goi.
    """
    out = collections.OrderedDict()
    for pat in ('*.png', '*.jpg', '*.jpeg'):
        for p in sorted(glob.glob(os.path.join(assets, '**', pat), recursive=True)):
            rel = os.path.relpath(p, assets).replace('\\', '/')
            khoa = rel.rsplit('.', 1)[0]
            if khoa in da_co or khoa in out:
                continue                 # .pkm cung ten da co: .pkm la ban chinh
            out[khoa] = p
    return out


def convert(path):
    """.pkm -> (rgba, w, h) voi alpha lay tu nua duoi.

    read_pkm tra ve RGB (3 byte/diem) o kich thuoc DA DEM (ew x eh, boi so 4
    cua ETC1), kem kich thuoc goc (ow x oh). Phai doc theo hang cua anh dem
    nhung chi lay ow cot va oh hang, neu khong la lech xeo.
    """
    rgb, ew, eh, ow, oh = read_pkm(path)
    if oh < 2:
        raise SpriteError('anh cao %d, khong tach duoc alpha' % oh)
    half = oh // 2
    out = bytearray(ow * half * 4)
    for y in range(half):
        src = y * ew * 3
        asrc = (y + half) * ew * 3
        dst = y * ow * 4
        for x in range(ow):
            out[dst + x * 4 + 0] = rgb[src + x * 3 + 0]
            out[dst + x * 4 + 1] = rgb[src + x * 3 + 1]
            out[dst + x * 4 + 2] = rgb[src + x * 3 + 2]
            out[dst + x * 4 + 3] = rgb[asrc + x * 3 + 0]   # do xam -> alpha
    return bytes(out), ow, half


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--assets', default=DEFAULT_ASSETS, help='mac dinh: %(default)s')
    ap.add_argument('--out', help='thu muc ghi PNG + index.json')
    ap.add_argument('--only', nargs='*', help='chi giai vai ten')
    ap.add_argument('--list', action='store_true', help='chi dem')
    ap.add_argument('--force', action='store_true',
                    help='giai lai ca nhung anh da co')
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')

    # Duong dan mac dinh la TUONG DOI: chay tu thu muc khac thi khong thay gi
    # ma van chay tiep, ghi ra mot index.json rong. Chan ngay o day.
    if not os.path.isdir(a.assets):
        raise SystemExit('khong co thu muc %s\n'
                         'chay tu brave-cross/work, hoac dua --assets tro toi '
                         '<giai nen>/assets' % os.path.abspath(a.assets))
    pkm = find_pkm(a.assets)
    if not pkm:
        raise SystemExit('khong thay file .pkm nao trong %s'
                         % os.path.abspath(a.assets))
    if a.only:
        pkm = collections.OrderedDict((k, v) for k, v in pkm.items() if k in set(a.only))
    print('file .pkm: %d' % len(pkm))
    if a.list:
        return 0
    if not a.out:
        raise SystemExit('thieu --out')

    os.makedirs(a.out, exist_ok=True)
    # Chan truoc khi giai 7629 anh: thu muc nay thuoc mot BAN cu the. Ban 1.31 co
    # 7629 file .pkm, ban VN co 15723 file — va ten PNG sinh ra theo TEN TRAN
    # (`ten_png`), nen hai ban ghi cung cho thi khong phai "lan vao nhau" ma la
    # DE HAN: cung ten `item_55.png` thi ban sau de ban truoc, khong loi nao nem
    # ra. Xem `cay.giu_cho`.
    loi = cay.giu_cho(a.out)
    if loi:
        sys.exit(loi)
    cay.danh_dau(a.out)
    index = collections.OrderedDict()
    ok = fail = copied = reused = 0
    fails = []

    # Ten tep PNG: giu ten TRAN khi khong trung, de chay lai van dung duoc
    # anh da giai lan truoc (6.248 anh, giai lai rat lau). Chi cho nao trung
    # ten moi phai dat theo ca duong dan.
    dem_ten = collections.Counter(k.rsplit('/', 1)[-1] for k in pkm)

    def ten_png(khoa):
        base = khoa.rsplit('/', 1)[-1]
        if dem_ten[base] == 1:
            return base + '.png'
        return khoa.replace('/', '_') + '.png'
    for i, (name, path) in enumerate(pkm.items(), 1):
        fn = ten_png(name)
        dst = os.path.join(a.out, fn)
        # Chay lai duoc nhieu lan: anh da giai va moi hon nguon thi dung lai,
        # chi doc kich thuoc tu header PNG. Nho vay --only khong lam mat chi
        # muc cua nhung anh da co, va giai dut quang van tiep duoc.
        if not a.force and os.path.isfile(dst) \
                and os.path.getmtime(dst) >= os.path.getmtime(path):
            wh = png_size(dst)
            if wh:
                index[name] = collections.OrderedDict(
                    [('png', fn), ('w', wh[0]), ('h', wh[1])])
                ok += 1
                reused += 1
                continue
        try:
            if is_png(path):
                with open(path, 'rb') as src, open(dst, 'wb') as out:
                    out.write(src.read())
                w = h = 0                      # kich thuoc doc tu chinh PNG khi dung
                copied += 1
            else:
                rgba, w, h = convert(path)
                write_png(dst, w, h, rgba)
        except (SpriteError, OSError, ValueError) as e:
            fail += 1
            fails.append((name, str(e)))
            continue
        index[name] = collections.OrderedDict([('png', fn), ('w', w), ('h', h)])
        ok += 1
        if i % 400 == 0:
            print('  ... %d/%d' % (i, len(pkm)), flush=True)

    # Anh ROI (ngoai .pkm) — xem `find_roi` de biet vi sao can.
    #
    # Ten tep: uu tien ten TRAN (de nhan ra trong thu muc), nhung ten tran co the
    # da bi mot .pkm chiem (`ui_background263.png` la ten cua ban .pkm da giai).
    # Luc do dat theo ca duong dan. Them duoi `.jpg` cho .jpg nen tran KHONG bao
    # gio dung nhau giua hai dinh dang.
    #
    # KHONG them vao `alias`. Bi danh la duong tra cuu ten TRAN, ma ten tran thi
    # ban goc chi dung cho khung trong `sngSplitData/`; con anh ROI ban goc goi
    # bang duong dan day du (xem `find_roi`). Them vao alias se doi ket qua tra
    # cuu cua nhung ten dang chay dung — rui ro khong can thiet.
    da_dung = set(v['png'] for v in index.values())
    roi = find_roi(a.assets, set(pkm))
    if a.only:
        roi = collections.OrderedDict((k, v) for k, v in roi.items()
                                      if k in set(a.only))
    print('anh roi ngoai .pkm: %d' % len(roi))
    for name, path in roi.items():
        # Duoi THAT cua tep, khong phai duoi trong ten. Hai tep
        # `png/loading/dol_1026A_1366x768_02.jpg` va `png/v6/ui_backgroundtimehero.jpg`
        # deu la PNG that (magic `89 50 4E 47`). Godot chon trinh doc theo DUOI
        # ten tep, nen ghi ra `.jpg` thi no dem nap bang trinh doc JPEG va hong
        # — du noi dung la PNG hoan toan hop le.
        png_that = is_png(path)
        if png_that:
            ext = '.png'
        else:
            with open(path, 'rb') as f:
                magic = f.read(4)
            if magic[:2] == b'\xff\xd8':
                ext = '.jpg'
            else:
                # Khong phai anh: `sngDefaultTexture_release aaa.png` (55 byte)
                # mo dau bang `43 43 5A 21` = "CCZ!" — mot go Cocos nen, khong
                # phai anh. Dem vao chi muc thi `UiFrames` se nap mot tep rac.
                fail += 1
                fails.append((name, 'khong phai anh, dau tep %s' % magic.hex()))
                continue
        base = name.rsplit('/', 1)[-1]
        fn = base + ext
        if fn in da_dung:
            fn = name.replace('/', '_') + ext
        while fn in da_dung:                 # van trung: danh so
            fn = '%s_%d%s' % (base, len(da_dung), ext)
        da_dung.add(fn)
        dst = os.path.join(a.out, fn)
        if not a.force and os.path.isfile(dst) \
                and os.path.getmtime(dst) >= os.path.getmtime(path):
            wh = png_size(dst) if png_that else jpg_size(dst)
        else:
            with open(path, 'rb') as src, open(dst, 'wb') as out:
                out.write(src.read())
            wh = png_size(path) if png_that else jpg_size(path)
        if not wh:
            fail += 1
            fails.append((name, 'khong doc duoc kich thuoc %s' % ext))
            continue
        index[name] = collections.OrderedDict([('png', fn), ('w', wh[0]), ('h', wh[1])])
        ok += 1
        copied += 1

    # Bi danh: ten tran -> khoa day du, CHI khi ten do khong trung. Bo cuc
    # phan lon ghi ten tran, nen tra cuu nhanh; con cho nao ghi ca duong dan
    # ("v6/ui_background176.png") thi UiFrames doi chieu duoi khoa.
    alias = collections.OrderedDict()
    for k in index:
        base = k.rsplit('/', 1)[-1]
        if dem_ten[base] == 1:
            alias[base] = k

    with open(os.path.join(a.out, 'index.json'), 'w', encoding='utf-8') as fp:
        json.dump(collections.OrderedDict([
            ('note', 'khoa = duong dan tuong doi khong duoi. '
                     '"alias" la ten tran, chi co khi khong trung ten.'),
            ('count', len(index)),
            ('frames', index),
            ('alias', alias),
        ]), fp, ensure_ascii=False, indent=1)
    print('%d ten trung phai dat theo ca duong dan'
          % sum(1 for b, n in dem_ten.items() if n > 1))

    print('xong: %d anh -> %s' % (ok, a.out))
    if reused:
        print('trong do %d anh da co san, dung lai' % reused)
    if copied:
        print('%d file von da la PNG, chep thang' % copied)
    if fail:
        print('that bai: %d' % fail)
        for n, e in fails[:8]:
            print('   %-30s %s' % (n, e))
    return 0


if __name__ == '__main__':
    sys.exit(main())
