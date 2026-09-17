# -*- coding: utf-8 -*-
"""Ba nguồn khung ảnh và ảnh hưởng của việc chọn sai nguồn — chạy được, không cần máy ảo.

    python khung_nguon.py --do          # đếm ba cặp + liệt kê chỗ lệch
    python khung_nguon.py --anh-huong   # ảnh hưởng lên bảng hộp chạm và mọi xương

CÙNG MỘT ẢNH, BA CẶP KHUNG
---------------------------
Bản ghi `.plist` (60 byte, 13 float từ `+0x08`) khai **ba** cặp cỡ, không phải
một:

    f2,f3   = khung ĐÃ CẮT trong atlas        (`sngxml.py` gọi là `sizeWH`)
    f9,f10  = LẶP LẠI y hệt `sizeWH`          (gọi là `sourceWH`)
    f11,f12 = `sourceSize`, khung TRƯỚC KHI CẮT (`f34_38`)

Còn bản ghi sprite của `.xml` (mảng ở header 0x60, bản ghi 40 byte, `+0x08`)
khai cặp thứ tư. Ba phép đếm ở đây cho biết cặp nào trùng cặp nào.

VÌ SAO PHẢI ĐẾM
---------------
Tài liệu về hộp chạm (`cham_ref.py`) từng kết luận "bản gốc đọc khung theo
`.xml`", dựa trên một phép so sai: nó lấy cặp ĐÃ CẮT của `.plist`
(`Hoplite_res-44` 1×1) đem so với `.xml` (3×3), thấy máy ảo trả 3 × 54,52 nên
tưởng `.xml` đúng. Nhưng `sourceSize` của ảnh ấy **cũng** là 3×3 — phép so ấy
không phân biệt được gì. Ba phép đo trên máy ảo mới phân biệt được, và đều nói
`sourceSize` (số đo: `emu_xuong.py`, mục D):

    rig               | đo được               | theo sourceSize     | theo .xml
    ------------------|-----------------------|---------------------|----------------
    BatFlight         | 145,00999450684 × 120 | 1 × 145,01 = 145,01 | 2 × 145,01 = 290,02
    DragonFlight      | 175 × 145             | 1 × 175             | 2 × 175 = 350
    DragonFlight Head | 64 × 64               | 64 × 64             | 65 × 64

BA MỨC ẢNH HƯỞNG (in ra ở đây, đo trên 418 file `.xml`)
--------------------------------------------------------
  * **Bảng hộp chạm của 224 rig** (biến thể mang tên file): đúng **2** rig sai ở
    bảng cũ — `BatFlight` 290,02 × 240 (phải là 145,01 × 120) và `DragonFlight`
    350 × 290 (phải là 175 × 145).
  * **Bảng ghi ra cho game** (`data_ref/cham_ref.json`, khoá theo TÊN BIẾN THỂ,
    cũng là bảng `tools/verify_cham_size.gd` đếm): **592 → 590** dòng, **7** biến
    thể đổi hộp (hai rig trên cộng `BatFlight_Fire`, `BatFlight_WeaponNormal`,
    `BatFlight_WeaponWake`, `DragonFlight_IcyRoad`, `DragonFlight_Weapon`) và
    **2** biến thể rơi khỏi bảng vì hộp thành `0 × 0` (`LvBuZhanShi_A2`,
    `LvBuZhanShi_Weapon1` — cùng dùng ảnh `LvBuZhanShi_res-44`, mà `sourceSize`
    của ảnh ấy là `0 × 0`). Hai biến thể ấy **không đo được trên máy ảo**
    (`getSpriteFromSpriteCatch("LvBuZhanShi_A2")` trả `nil`), nên giá trị `0 × 0`
    của chúng là **suy theo cùng một luật**, không phải số đo; rig
    `LvBuZhanShi` thì đo được và trả đúng `0 × 0`.
  * **Mọi xương** (hàm `_lua_getBoneRectInNode` sắp viết, khoá 0 của động tác
    đầu): **1.224/4.704** xương có hộp khác nhau giữa hai nguồn, lệch lớn nhất
    **175 điểm ảnh** (chính ca `DragonFlight`). Khung chỉ lệch ≤ 1 điểm ảnh, mà
    `sx` cỡ 50–175 thì lệch ấy nhân lên thành hàng trăm điểm ảnh.
"""
import argparse
import glob
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import cham_ref                                        # noqa: E402

MAP = os.path.join(HERE, 'vn', 'decrypted', 'assets', 'map')
ANIM_REC = cham_ref.ANIM_REC


def khoa_xuong(r, bt, xuong, dong_tac=None):
    """Khoá đầu tiên của xương `xuong` trong biến thể bt (None nếu không có)."""
    a = r.a
    _, sub_off, sub_n = bt
    for k in range(sub_n):
        ar = a.grp_sub + sub_off + k * ANIM_REC
        if dong_tac is not None and a._name_at(ar) != dong_tac:
            continue
        for bi in range(a.u(ar + 0x24)):
            bp = a.bone_base + a.u(ar + 0x20) + bi * 24
            if a._name_at(bp) != xuong:
                continue
            ra = []
            for j in range(a.u(bp + 0x14)):
                q = a.key_base + a.u(bp + 0x10) + j * 80
                v = struct.unpack_from('<8f', a.d, q)
                ra.append(dict(x=v[0], y=v[1], v2=v[2], v3=v[3],
                               rot=v[4], rot2=v[5], sx=v[6], sy=v[7],
                               d=struct.unpack_from('<i', a.d, q + 0x2C)[0],
                               dur=struct.unpack_from('<i', a.d, q + 0x40)[0]))
            return a._name_at(ar), ra
    return None, None


def moi_rig():
    for p in sorted(glob.glob(os.path.join(MAP, '**', '*.xml'), recursive=True)):
        try:
            if open(p, 'rb').read(7) != b'sngXml\x00':
                continue
        except OSError:
            continue
        try:
            yield cham_ref.Rig(p)
        except Exception:
            continue                # *_config.xml khong phai file rig


def doc_plist(d):
    """(count, off_recs, off_pool, stride) của một file `.plist` sngXml."""
    if d[:6] != b'sngXml':
        return None
    count = struct.unpack_from('<I', d, 0x10)[0]
    off_recs = struct.unpack_from('<I', d, 0x38)[0]
    off_pool = struct.unpack_from('<I', d, 0x3c)[0]
    if not count or not off_recs or off_pool <= off_recs:
        return None
    return count, off_recs, off_pool, (off_pool - off_recs) // count


def dem():
    """Ba phép đếm: cặp nào trùng cặp nào, và ảnh `_res-44` lệch ở đâu."""
    trung910 = lech910 = trung1112 = lech1112 = 0
    trung_xml = lech_xml = 0
    mark = []
    n_file = 0
    for r in moi_rig():
        pl = os.path.join(os.path.dirname(r.duong_dan), r.ten + '.plist')
        if not os.path.isfile(pl):
            continue
        d = open(pl, 'rb').read()
        g = doc_plist(d)
        if g is None:
            continue
        n_file += 1
        count, off_recs, off_pool, stride = g
        X = r.kich_thuoc_sprite()
        for i in range(count):
            b = off_recs + i * stride
            f = struct.unpack_from('<13f', d, b + 8)
            no, nl = struct.unpack_from('<II', d, b)
            nm = d[off_pool + no:off_pool + no + nl].decode('utf-8', 'replace')
            base = nm[:-4] if nm.endswith('.png') else nm
            if (f[9], f[10]) == (f[2], f[3]):
                trung910 += 1
            else:
                lech910 += 1
            if (f[11], f[12]) == (f[2], f[3]):
                trung1112 += 1
            else:
                lech1112 += 1
            x = X.get(base)
            if x is None:
                continue
            if x == (f[11], f[12]):
                trung_xml += 1
            else:
                lech_xml += 1
            if base.endswith('_res-44'):
                mark.append((r.ten, base, x, (f[11], f[12]), (f[2], f[3])))

    print('file co .plist: %d' % n_file)
    print('f9_10  == sizeWH   : %6d trung | %5d lech' % (trung910, lech910))
    print('f11_12 == sizeWH   : %6d trung | %5d lech' % (trung1112, lech1112))
    print('ban ghi .xml == f11_12 : %6d trung | %5d lech' % (trung_xml, lech_xml))
    print('anh `_res-44` co .xml khac sourceSize: %d / %d'
          % (sum(1 for t in mark if t[2] != t[3]), len(mark)))
    for t in mark:
        if t[2] != t[3]:
            print('   %-16s %-28s .xml=%s sourceSize=%s sizeWH=%s' % t)


def bang_bien_the():
    """Bảng hộp chạm (khoá theo TÊN BIẾN THỂ) dựng theo HAI nguồn khung.

    Đây là bảng mà `cham_ref.py --json` ghi ra cho game (`data_ref/cham_ref.json`)
    và cũng là bảng mà `tools/verify_cham_size.gd` đếm. Dựng hai lần bằng đúng
    vòng lặp của bộ sinh, chỉ khác hàm lấy cỡ ảnh — nên chênh lệch dưới đây là
    **toàn bộ** ảnh hưởng lên bảng, không phải một mẫu.
    """
    goc = cham_ref.Rig.kich_thuoc_nguon_sprite
    ra = {}
    for nhan, f in (('xml', cham_ref.Rig.kich_thuoc_sprite), ('nguon', goc)):
        cham_ref.Rig.kich_thuoc_nguon_sprite = f
        b = {}
        for r in moi_rig():
            for bt in r.moi_bien_the():
                h = r.ho_cham(bien_the=bt)
                if h is None or not h['ten_anh'] or (h['w'], h['h']) == (0.0, 0.0):
                    continue
                b[bt] = (r.ten, h['rong'], h['cao'])
        ra[nhan] = b
    cham_ref.Rig.kich_thuoc_nguon_sprite = goc
    return ra['xml'], ra['nguon']


def anh_huong():
    """Ảnh hưởng lên bảng hộp chạm và lên hộp của MỌI xương."""
    n_rig = n_rig_lech = 0
    lech_rig = []
    n_xuong = n_xuong_lech = 0
    max_lech, max_ca = 0.0, None
    for r in moi_rig():
        pl = os.path.join(os.path.dirname(r.duong_dan), r.ten + '.plist')
        if not os.path.isfile(pl):
            continue
        X = r.kich_thuoc_sprite()
        N = cham_ref.kich_thuoc_nguon(pl) or {}
        k = r.khoa_cham()
        if k is not None and k['keys']:
            anh = r.anh_cua_xuong().get(k['xuong'], [])
            d0 = k['keys'][0]['d']
            ta = anh[d0] if 0 <= d0 < len(anh) else ''
            x, src = X.get(ta), N.get(ta)
            if x is not None and src is not None:
                n_rig += 1
                if x != src:
                    n_rig_lech += 1
                    k0 = k['keys'][0]
                    lech_rig.append((r.ten, ta, x, src,
                                     cham_ref.hop(x[0], x[1], k0['rot'], k0['rot2'],
                                                  k0['sx'], k0['sy']),
                                     cham_ref.hop(src[0], src[1], k0['rot'], k0['rot2'],
                                                  k0['sx'], k0['sy'])))
        bt = r.bien_the_theo_ten()
        if bt is None:
            continue
        for xuong, ds in r.anh_cua_xuong().items():
            if not ds:
                continue
            dt, keys = khoa_xuong(r, bt, xuong)
            if not keys:
                continue
            k0 = keys[0]
            if k0['d'] < 0 or k0['d'] >= len(ds):
                continue
            ta = ds[k0['d']]
            x, src = X.get(ta), N.get(ta)
            if x is None or src is None:
                continue
            n_xuong += 1
            b1 = cham_ref.hop(x[0], x[1], k0['rot'], k0['rot2'], k0['sx'], k0['sy'])
            b2 = cham_ref.hop(src[0], src[1], k0['rot'], k0['rot2'], k0['sx'], k0['sy'])
            dl = max(abs(b1[0] - b2[0]), abs(b1[1] - b2[1]))
            if dl > 1e-6:
                n_xuong_lech += 1
            if dl > max_lech:
                max_lech, max_ca = dl, (r.ten, xuong, dt, ta, x, src, k0, b1, b2)

    print('--- bang hop cham (bien the mang ten file) ---')
    print('   rig co xuong Collision: %d | so rig ma hai nguon LECH: %d'
          % (n_rig, n_rig_lech))
    for ten, ta, x, src, b1, b2 in lech_rig:
        print('   %-16s %-26s .xml=%s sourceSize=%s' % (ten, ta, x, src))
        print('        hop cu (theo .xml) = %g x %g   |  hop dung = %g x %g  | lech %g'
              % (b1[0], b1[1], b2[0], b2[1], max(abs(b1[0] - b2[0]), abs(b1[1] - b2[1]))))
    print('--- hop cua MOI xuong (khoa 0 cua dong tac dau) ---')
    print('   so xuong xet: %d | so xuong co hop lech: %d | lech lon nhat: %g'
          % (n_xuong, n_xuong_lech, max_lech))
    if max_ca:
        ten, xuong, dt, ta, x, src, k0, b1, b2 = max_ca
        print('   ca lon nhat: %s %s (%s) anh %s .xml=%s sourceSize=%s'
              % (ten, xuong, dt, ta, x, src))
        print('      khoa 0: rot %g rot2 %g sx %g sy %g' % (k0['rot'], k0['rot2'],
                                                           k0['sx'], k0['sy']))
        print('      hop .xml = %g x %g  |  hop dung = %g x %g' % (b1[0], b1[1],
                                                                   b2[0], b2[1]))

    # Muc (3) la muc lam BO KIEM cua game do: bang ghi ra theo nguon moi co 590
    # dong chu khong phai 592, vi hai bien the cua `LvBuZhanShi` co hop 0x0 nen
    # bo sinh bo qua chung.
    x, n = bang_bien_the()
    doi = [bt for bt in x if bt in n and x[bt][1:] != n[bt][1:]]
    mat = [bt for bt in x if bt not in n]
    print('--- bang hop cham khoa theo TEN BIEN THE (thu do --json ghi ra) ---')
    print('   so dong: theo .xml %d | theo sourceSize %d' % (len(x), len(n)))
    print('   so bien the DOI hop: %d | ROT khoi bang: %d' % (len(doi), len(mat)))
    for bt in sorted(doi):
        print('   doi  %-24s %-16s %g x %g  ->  %g x %g'
              % (bt, x[bt][0], x[bt][1], x[bt][2], n[bt][1], n[bt][2]))
    for bt in sorted(mat):
        print('   rot  %-24s %-16s %g x %g  ->  (0 x 0 nen khong ghi)'
              % (bt, x[bt][0], x[bt][1], x[bt][2]))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--do', action='store_true', help='in cac phep dem')
    ap.add_argument('--anh-huong', action='store_true',
                    help='in anh huong len bang hop cham va len moi xuong')
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')
    if not (a.do or a.anh_huong):
        print(__doc__)
        return 0
    if a.do:
        dem()
    if a.anh_huong:
        anh_huong()
    return 0


if __name__ == '__main__':
    sys.exit(main())
