# -*- coding: utf-8 -*-
"""Do do phu khung cua atlas bang manh roi trong sngSplitData/.

Nhieu atlas co .plist ma texture khong duoc dong goi (khong o APK, khong o OBB).
Khung cua chung khong mat: chung nam roi trong decrypted/assets/sngSplitData/,
moi khung mot file .pkm. Cong cu nay do xem bao nhieu khung THAT SU dung lai duoc.

BAY — doc truoc khi sua, ca ba deu da sap that:

 1. KHONG dem bang os.listdir(). sngSplitData/ co ~27 thu muc con ma os.listdir
    khong de quy, nen khung nam trong thu muc con bi coi la mat. Do kieu do ra
    415/506 va ra Scene_Main 0/56 — trong khi Scene_Main DU 56/56. Ket luan
    nguoc han ma khong co gi bao loi.

 2. KHONG khop bang ten suong. Ten trung nhau giua cac bo (moku.png cua
    Scene_Main2_BuildingIcon khop mot moku.pkm chang lien quan), va nhieu manh
    cung ten nhung la BAN HA NUA CO (valley_00-01: plist 512x143 <-> manh
    256x72). Khop ten suong ra 471/506.

 3. Phai so voi sourceSize, KHONG phai sizeWH. sizeWH la hinh chu nhat DA CAT
    nam trong atlas, sourceSize la kich thuoc sprite GOC — manh .pkm la ca
    sprite goc. So nham voi sizeWH ra "106/352 lech", nghe nhu manh sai.

Do bang ba quy tac tren:

  - 20 atlas thieu texture: 352/352 khung KHONG hau to ngon ngu khop ca ten lan
    co — giong y nhau o CA HAI cay VN 1.26 va CN 1.31. Khung khong hau to KHONG
    phai hinh trung tinh: no la TRANH CHU tieng Trung. Giai ma ra xem:
    ZhaoYunWake_res-#zi1 la 七進七出, con #zi1_vi la "Tien Xuat".

  - 274 khung mang hau to ngon ngu thi KHONG trung giua hai ban: moi ban chi
    dong goi dung thua tieng cua minh. Phai do MANH, dung do plist — plist ban
    nao cung mang du 8 thu tieng nen dem plist ra so sai:
        VN    : Background_vi_B 79/79,  Font_vi_T 121/121
        cn131 : Background_zh_Hans_B 91/91, Font_zh_Hans_T 128/128
    12 atlas tieng khac (_de/_en/_kr/_th/_zh_Hant/_jp) trang o CA HAI ban —
    do dung la phan tai luc chay, khong bao gio co.
    Rieng trong 20 atlas thieu texture: cn131 0/274, VN 61/274.
    Docstring nay tung ghi "ca hai cay trung tung dong" cho ca 0/274 — SAI.

  - 16 Scene_*.plist: 378/506 khung, 11/16 atlas du 100% ke ca Scene_Main —
    cai nay moi THUC SU trung tung dong o ca hai cay.

    python split_kiem.py                       # quet assets/map
    python split_kiem.py --img                 # quet assets/img_all (co Scene_*)
    python split_kiem.py --all                 # ca hai
    python split_kiem.py --atlas ZhaoYunWake Scene_Main2
    python split_kiem.py --day-du              # in ca atlas khong co van de
    python split_kiem.py --json --out split.json
    python split_kiem.py --doi-chieu cn131     # do lai tren ban khac, doi chieu

Thoat ma 1 khi: khong doc duoc plist/manh, thieu thu muc sngSplitData, hoac
--doi-chieu thay hai ban lech nhau. KHUNG THIEU KHONG PHAI loi — do la du lieu,
in ra roi thoat 0.
"""
import os
import re
import sys
import json
import glob
import struct
import argparse
import collections
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

# stdout tren Windows dung cp1252 khi bi day ra pipe/tep, va NO UnicodeEncodeError
# khi ten khung co ky tu ngoai bang ma do — da xay ra that voi --img tren ban
# cn131 (`print(json)` chet, stdout rong, thoat ma 1). Ep UTF-8 ngay tu dau.
for _f in (sys.stdout, sys.stderr):
    try:
        _f.reconfigure(encoding='utf-8')
    except Exception:
        pass

import cay
import sngxml

PKM_MAGIC = b'PKM 10'

#: Hau to ngon ngu trong ten khung: <ten>_vi.png, <ten>_zh_Hant.png, ...
#: Day la ban CHU cua cung mot khung, khong phai khung rieng.
NGON_NGU = re.compile(r'_(vi|en|kr|jp|th|tw|zh_Hans|zh_Hant|de|fr|es|pt|ru)$')


def la_sngxml(path):
    """File nay co phai atlas sngXml khong.

    Trong assets/map/ co lan ca plist XML thuong cua HE HAT — firefog.plist,
    trail.plist, potion_cure.plist, yellowTrail.plist, ... (Cocos Particle
    Designer, mo dau bang '<?xml'). Chung khong phai atlas nen bo qua, KHONG
    dem la loi — nhung van dem ra man hinh cho khong phai im lang.
    """
    with open(path, 'rb') as f:
        return f.read(7) == sngxml.MAGIC


def doc_co(path):
    """(rong, cao) that cua manh .pkm — chi doc 16 byte dau, khong giai ETC1.

    PKM 10: magic 6 byte + 5 so 16 bit: fmt, ew, eh, ow, oh.
    ETC1 khong mang kenh alpha nen game xep DOI chieu cao (nua tren mau, nua
    duoi la alpha), nen chieu cao that la oh/2. Lay `ow` chu khong lay `ew`:
    `ew`/`eh` da bi dem cho chia het 4, `ow`/`oh` moi la co that.

    Tra None neu khong phai PKM 10 (manh con ma hoa, hoac file la).
    """
    with open(path, 'rb') as f:
        b = f.read(16)
    if len(b) < 16 or b[:6] != PKM_MAGIC:
        return None
    _fmt, _ew, _eh, ow, oh = struct.unpack('>5H', b[6:16])
    return (ow, oh // 2)


def tim_manh(split, ten):
    """Duong dan manh cua mot khung, hoac None.

    HOI THANG DIA bang os.path.exists, khong dung tap ten dung tu os.listdir:
    sngSplitData/ co thu muc con, xem BAY so 1 o docstring.
    """
    q = os.path.join(split, ten + '.pkm')
    return q if os.path.exists(q) else None


def xet_khung(split, f):
    """Xep mot khung vao mot o. Xem docstring o `kiem_atlas`."""
    ten = os.path.splitext(f['name'])[0]
    ss = (int(f['sourceSize'][0]), int(f['sourceSize'][1]))
    q = tim_manh(split, ten)
    nn = bool(NGON_NGU.search(ten))
    if q is None:
        return ('thieu', nn, None)
    co = doc_co(q)
    if co is None:
        return ('hong', nn, None)
    if ss == (0, 0):
        # plist khong ghi co goc — khong kiem duoc gi them. Van tinh la CO manh.
        return ('khong-ro-co', nn, co)
    if co == ss:
        return ('khop', nn, co)
    if co == (ss[1], ss[0]):
        # Khop khi hoan vi. Hop le khi `rotated`; neu khong thi dang ngo.
        return ('khop-nguoc' if not f.get('rotated') else 'khop', nn, co)
    if co == (ss[0] * 2, ss[1] * 2) or co == (ss[1] * 2, ss[0] * 2):
        return ('ha-nua', nn, co)
    return ('ten-trung', nn, co)


#: Cac o duoc tinh la "dung lai duoc". `khop-nguoc` van tinh: kich thuoc khop
#: sourceSize khi hoan vi, chi la plist khong danh dau `rotated`.
O_DUNG = ('khop', 'khop-nguoc', 'khong-ro-co')


def kiem_atlas(split, path, thu_muc):
    """Do mot atlas. Tra dict, hoac None neu plist khong doc duoc.

    Moi khung roi vao dung mot o:

        khop        co manh, kich thuoc = sourceSize (ke ca khi hoan vi)
        khop-nguoc  khop khi hoan vi NHUNG plist ghi rotated = False (dang ngo)
        khong-ro-co plist ghi sourceSize = 0 nen khong kiem duoc co
        ha-nua      co manh, kich thuoc dung bang MOT NUA sourceSize
                    (ban ha do phan giai — KHONG dung cho atlas goc)
        ten-trung   co file cung ten nhung kich thuoc khac han
                    (tai nan trung ten giua cac bo)
        thieu       khong co file cung ten
        hong        file cung ten nhung khong phai PKM 10
    """
    try:
        d = sngxml.load(path).to_dict()
    except Exception:
        return None
    dem = collections.Counter()
    vi_du = collections.defaultdict(list)
    nn_dem = collections.Counter()
    nn_tong = 0
    for f in d['frames']:
        o, nn, _co = xet_khung(split, f)
        dem[o] += 1
        if nn:
            nn_dem[o] += 1
            nn_tong += 1
        if o not in O_DUNG and len(vi_du[o]) < 5:
            vi_du[o].append(f['name'])
    return {
        'ten': os.path.splitext(os.path.basename(path))[0],
        'thu_muc': thu_muc,
        'khung': d['count'],
        'khung_ngon_ngu': nn_tong,
        'dem': dict(dem),
        'dem_ngon_ngu': dict(nn_dem),
        'vi_du': dict(vi_du),
        'texture': (d['headerStrings'][0] if d['headerStrings'] else ''),
    }


def gom_atlas(a):
    """Danh sach (thu_muc, duong dan plist) theo pham vi nguoi dung chon."""
    ra = []
    if a.atlas:
        for ten in a.atlas:
            for tm in ('map', 'img_all'):
                p = os.path.join(cay.ASSETS, tm, ten + '.plist')
                if os.path.exists(p):
                    ra.append((tm, p))
                    break
            else:
                sys.stderr.write('khong thay plist cua "%s" trong map/ lan img_all/\n' % ten)
        return ra
    tm_list = ['map', 'img_all'] if a.all else (['img_all'] if a.img else ['map'])
    for tm in tm_list:
        ra += [(tm, p) for p in sorted(glob.glob(os.path.join(cay.ASSETS, tm, '*.plist')))]
    return ra


def in_bang(kq, day_du):
    """In bang. Tra (so_atlas_co_van_de, so_khung_khong_dung_duoc)."""
    print('%-30s %6s %6s %6s %6s %6s %5s' %
          ('atlas', 'khung', 'khop', 'ha-nua', 'trung', 'thieu', 'NN'))
    print('-' * 76)
    tong = collections.Counter()
    so_co_van_de = so_khong_dung = 0
    for r in kq:
        dem = r['dem']
        khop = dem.get('khop', 0) + dem.get('khop-nguoc', 0) + dem.get('khong-ro-co', 0)
        ha = dem.get('ha-nua', 0)
        tr = dem.get('ten-trung', 0)
        th = dem.get('thieu', 0)
        hong = dem.get('hong', 0)
        # Cac khung mang hau to ngon ngu — do la ban CHU, khong phai mat manh.
        nn = sum(v for k, v in r['dem_ngon_ngu'].items() if k not in O_DUNG)
        xau = ha + tr + th + hong
        for k, v in dem.items():
            tong[k] += v
        tong['khung'] += r['khung']
        tong['ngon_ngu'] += nn
        tong['khung_nn'] += r['khung_ngon_ngu']
        tong['khop_nn'] += sum(v for k, v in r['dem_ngon_ngu'].items() if k in O_DUNG)
        if xau:
            so_co_van_de += 1
            so_khong_dung += xau
        elif not day_du:
            continue
        co = ''
        if r['dem'].get('khop-nguoc'):
            co = ' nguoc=%d' % r['dem']['khop-nguoc']
        if hong:
            co += ' HONG=%d' % hong
        print('%-30s %6d %6d %6d %6d %6d %5d%s' %
              (r['ten'], r['khung'], khop, ha, tr, th, nn, co))
    print('-' * 76)
    khop_t = tong.get('khop', 0) + tong.get('khop-nguoc', 0) + tong.get('khong-ro-co', 0)
    print('%-30s %6d %6d %6d %6d %6d %5d' %
          ('TONG (%d atlas)' % len(kq), tong['khung'], khop_t,
           tong.get('ha-nua', 0), tong.get('ten-trung', 0), tong.get('thieu', 0),
           tong['ngon_ngu']))
    print()
    print('%d/%d khung dung lai duoc (khop ca ten lan co).' % (khop_t, tong['khung']))
    if tong['khung_nn'] or tong['khop_nn']:
        print('  khung KHONG hau to ngon ngu : %d/%d  <- phan that su can'
              % (khop_t - tong['khop_nn'], tong['khung'] - tong['khung_nn']))
        print('  khung CO hau to ngon ngu    : %d/%d  <- ban CHU (_vi/_en/_kr/_zh_Hant),'
              % (tong['khop_nn'], tong['khung_nn']))
        print('                                          phai ve lai du sao')
    if so_co_van_de:
        print('%d atlas co khung khong dung duoc.' % so_co_van_de)
    return so_co_van_de, so_khong_dung


def doi_chieu(a):
    """Do lai tren mot ban khac bang chinh cong cu nay, roi so tung dong.

    Chay lai chinh tep nay qua subprocess voi BC_TREE khac — cay.py doc BC_TREE
    luc import nen doi trong cung tien trinh la khong dang tin.
    """
    ban = a.doi_chieu
    argv = [sys.executable, os.path.abspath(__file__)]
    if a.atlas:
        argv += ['--atlas'] + list(a.atlas)
    elif a.all:
        argv.append('--all')
    elif a.img:
        argv.append('--img')
    else:
        argv.append('--map')
    argv.append('--json')
    env = dict(os.environ, BC_TREE=ban, PYTHONIOENCODING='utf-8')
    r = subprocess.run(argv, capture_output=True, env=env, cwd=HERE)
    # Con thoat ma 1 ca khi chay dung (co plist hong) LAN khi no ra — khong phan
    # biet duoc bang ma thoat. Phan biet bang stdout: JSON doc duoc tuc la chay
    # duoc, khong doc duoc thi in stderr cua con ra (do moi la cho co traceback).
    try:
        kia = json.loads(r.stdout.decode('utf-8'))
    except ValueError:
        sys.stderr.write('--- stderr cua ban %s (thoat ma %d) ---\n'
                         % (ban, r.returncode))
        sys.stderr.write(r.stderr.decode('utf-8', 'replace')[-2000:])
        sys.exit('ban "%s": khong doc duoc JSON' % ban)

    print('Doi chieu %s (%s) voi %s (%s)\n' % (cay.TEN, cay.ASSETS, ban, kia['assets']))
    minh = {r_['thu_muc'] + '/' + r_['ten']: r_ for r_ in kq_toan_cuc}
    kia_m = {r_['thu_muc'] + '/' + r_['ten']: r_ for r_ in kia['atlas']}
    lech = 0
    for k in sorted(set(minh) | set(kia_m)):
        x, y = minh.get(k), kia_m.get(k)
        if x is None or y is None:
            print('  %-40s CHI CO o %s' % (k, cay.TEN if y is None else ban))
            lech += 1
            continue
        if (x['khung'], x['dem']) != (y['khung'], y['dem']):
            print('  %-40s %s -> %s' % (k, x['dem'], y['dem']))
            lech += 1
    if lech:
        print('\n%d/%d atlas LECH nhau - hai ban khac nhau, phai doc lai tung ben.'
              % (lech, len(set(minh) | set(kia_m))))
        return 1
    print('Khop ca %d atlas, tung o dem giong het. Hai bo doc doc lap cung ra '
          'mot ket qua.' % len(minh))
    return 0


kq_toan_cuc = []


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0],
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--atlas', nargs='+', help='chi kiem cac atlas nay (tim trong map/ va img_all/)')
    ap.add_argument('--map', action='store_true', help='quet assets/map (mac dinh)')
    ap.add_argument('--img', action='store_true', help='quet assets/img_all (co Scene_*)')
    ap.add_argument('--all', action='store_true', help='quet ca hai')
    ap.add_argument('--day-du', action='store_true', help='in ca atlas khong co van de')
    ap.add_argument('--chi-tiet', action='store_true', help='in ten vai khung khong dung duoc')
    ap.add_argument('--json', action='store_true', help='ra JSON thay vi bang')
    ap.add_argument('--out', help='ghi JSON ra file nay (di kem --json)')
    ap.add_argument('--doi-chieu', metavar='BAN', help='do lai tren ban khac (BC_TREE) va so tung dong')
    a = ap.parse_args()

    split = os.path.join(cay.ASSETS, 'sngSplitData')
    if not os.path.isdir(split):
        sys.exit('khong thay %s' % split)

    ds = gom_atlas(a)
    if not ds:
        sys.exit('khong co plist nao')
    so_manh = len([f for f in os.listdir(split) if f.endswith('.pkm')])
    so_tm = len([d for d in os.listdir(split) if os.path.isdir(os.path.join(split, d))])

    kq = []
    hong = []
    bo_qua = []
    for tm, p in ds:
        if not la_sngxml(p):
            bo_qua.append(p)
            continue
        r = kiem_atlas(split, p, tm)
        if r is None:
            hong.append(p)
            continue
        kq.append(r)
    kq_toan_cuc.extend(kq)

    if a.doi_chieu:
        return doi_chieu(a)

    if a.json:
        ra = {
            'cay': cay.TEN,
            'assets': cay.ASSETS,
            'split': split,
            'so_manh': so_manh,
            'so_thu_muc_con': so_tm,
            'so_atlas': len(kq),
            'plist_hong': hong,
            'plist_bo_qua': bo_qua,
            'atlas': kq,
        }
        s = json.dumps(ra, ensure_ascii=False, indent=1)
        if a.out:
            with open(a.out, 'w', encoding='utf-8') as f:
                f.write(s + '\n')
            print('da ghi %s (%d atlas)' % (a.out, len(kq)))
        else:
            # Ghi thang ra stdout dang byte, khong qua `print`: `print` da tung
            # chet o day va lam con bat doi chieu doc ra stdout rong.
            sys.stdout.buffer.write(s.encode('utf-8') + b'\n')
            sys.stdout.buffer.flush()
        return 1 if hong else 0

    print('cay %s | %s' % (cay.TEN, cay.ASSETS))
    print('sngSplitData: %d manh .pkm, %d thu muc con' % (so_manh, so_tm))
    if bo_qua:
        print('bo qua %d plist khong phai sngXml (he hat: firefog, trail, ...)' % len(bo_qua))
    print()
    so_van_de, so_khong_dung = in_bang(kq, a.day_du)
    if a.chi_tiet:
        print()
        for r in kq:
            if r['vi_du']:
                print('%s:' % r['ten'])
                for o, tens in sorted(r['vi_du'].items()):
                    print('   %-10s %s' % (o, ', '.join(tens)))
    if hong:
        print()
        for p in hong:
            print('KHONG DOC DUOC plist: %s' % p)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
