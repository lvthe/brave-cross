# -*- coding: utf-8 -*-
"""Do nghia cap +0x08 (v2, v3) cua khung xuong.

KET QUA (do tren 641.536 keyframe cua 418 file .xml, trong do 617.664 khung HIEN):

    do lech = quay( (ax * sx, ay * sy), rot1 )
    v2 = ceil(x - do lech.x),  v3 = ceil(y - do lech.y)

trong do `x, y` la +0x00, `rot1` / `rot2` la +0x10 / +0x14, `sx, sy` la +0x18,
va `ax, ay` la +0x20 / +0x24 — dung hai truong ma truoc day ghi "chua giai".
Nghia hinh hoc: (v2, v3) la **goc TRAI-TREN cua o anh** khi anh duoc dat neo
`(ax, ay)` (tinh bang pixel CUA CHINH ANH, khong chuan hoa) ngay tai vi tri
xuong. `ceil` la de o anh khong bi duong ranh giua hai o.

Them mot luat nua: **khi `rot2 - rot1 = 180 do` (mod 360) thi phan x doi dau** —
dung nhu cocos doi dau `relativeOffset.x` khi lat truc x.

DO BANG HAI CACH DOC LAP. Hai con so khac nhau, va khac nhau CO LY DO:

  `work/hai_cap_do.py` — do NGUOC do lech that: `v2 = ceil(x - d)` nghia la `d`
      nam trong nua khoang `[x - v2, x - v2 + 1)`; lay chinh (v2, v3) trong file
      lam thuoc roi xem cong thuc nao roi vao khoang ay. Ra **607.943 / 617.664
      = 98,43%**. Cac ban khac trong cung phep do: khong quay 596.685 (96,60%);
      quay theo `rot2` 605.438 (98,02%); lat VO DIEU KIEN tut xuong 575.423
      (93,16%) — nen luat lat la that chu khong phai chuyen them vao cho dep.

  `work/hai_cap.py` (file nay) — doi cong thuc ra so roi so BANG voi (v2, v3),
      tuc gia dinh file luu so DA LAM TRON. Ra **576.347 = 93,31%**.

Hai so lech nhau dung 5,12%, va do chinh la cau tra loi: **31.598 keyframe
(5,12%) vua luu do lech THO vua khop cong thuc** — (v2, v3) la so le o nhung
khung ay (vd ZhuGeLiangCircle `Layer000` x = 0, y = 1564,4, s = 5 -> v3 = 1564,4
chu khong phai 1565). 93,31% + 5,12% = 98,43%, khop tung phan. Noi rong hon: ca
thay co **36.271 khung (5,87%) luu so tho**; phan con lai cua nhom do nam trong
so 1,18% chua giai o duoi. Cong thuc dung o ca hai cho; chi la file khong phai
luc nao cung lam tron.

LUAT LAT do duoc la dung o phan lon va **SAI o 3.033 keyframe (0,49%)** (xem muc
LUAT LAT cua `hai_cap_do.py`). Cho sai gom CA HAI chieu — co khung hieu = 0 ma
van phai lat (ArcherN `Defend` / `Neck`), co khung hieu = 180 ma khong lat
(ArcherN `WakeLoop` / `Neck`) — nen thu that su quyet dinh co le la co lat-theo-
bien-the (cocos `isFlipX`) chu khong nam trong ban ghi khung. Ghi ra, KHONG suy
dien them.

Con lai **7.295 keyframe (1,18%)** khong cong thuc ung vien nao ra, don vao xuong
lop HIEU UNG: `LayerName000`, `LayerName002`, `deng1`, `LayerName001`, `Layer000`,
`Layer002`, `deng2`… — nhung xuong co neo RAT LON (|neo| 3169..3550 px, co mot
gia tri rac 1,67e24). CHUA KHOI PHUC, ghi ro la chua.

Xuong THAN nhan vat thi neo luon (0, 0) nen do lech bang 0: hai cap chi lech nhau
duoi 1 px (dung 96,60% khung co do lech duoi 1 px ke ca xuong hieu ung), nen ban
dung doc `+0x08` cho `_lua_getBonePosInNode` la du, khong phai doi duong ve.

NAM xuong doi chieu doc lap duoc voi may ao (`work/emu_xuong.py`); bon trong nam
co neo khac 0 nen phep kiem nay co suc phan biet:

    ZhangLiangBao Collision  (x,y)=(-0,50; -113,50) (ax,ay)=(0,5; 0,5)
                             (sx,sy)=(175,00; 227,50) -> ceil(-88,00; -227,25) = (-88, -227)
    Hoplite       Collision  (x,y)=(-45,09; -129,61) (ax,ay)=(0,6; 0,6)
                             (sx,sy)=(54,52; 54,40)   -> ceil(-77,802; -162,25) = (-77, -162)
    Gashapon      Collision  (x,y)=(-78,85; -72,52)  (ax,ay)=(1,4; 2,8)
                             (sx,sy)=(38,00; 44,40)   -> ceil(-132,05; -196,84) = (-132, -196)
    ElephantSoldier Collision (x,y)=(-69,17; -69,85) (ax,ay)=(0,6; 1,16)
                             (sx,sy)=(56,84; 39,50)    -> ceil(-103,27; -115,67) = (-103, -115)
    YuJin         Head       (x,y)=(0,59; -127,67)   (ax,ay)=(0; 0)   -> (1, -127)

Nam so nay la nam so MA HAM `_lua_getBonePosInNode` cua ban goc tra ve — nen cong
thuc nay giai thich duoc duong Lua do.

    python hai_cap.py [thu_muc]
    python hai_cap.py [thu_muc] <rig> <dong tac> <xuong>   # in 20 so tho tung khung
"""
import os, sys, math, struct, collections

sys.stdout.reconfigure(encoding='utf-8', errors='replace')
os.chdir(r'C:\Project\game\brave-cross')
sys.path.insert(0, os.path.join(os.getcwd(), 'work'))
import anim


def _c(z):
    """ceil nhung chiu duoc NaN (co 2 keyframe NaN trong toan cay)."""
    return z if math.isnan(z) else float(math.ceil(z))


def _lat(rot1, rot2):
    """Co doi dau phan x khong: cocos doi dau `relativeOffset.x` khi lat truc x,
    va trong du lieu dieu do hien ra la `rot2 - rot1 = 180 do`."""
    return math.isclose((rot2 - rot1) % 360.0, 180.0, abs_tol=1e-3)


def _quay(u, v, deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return (c * u - s * v, s * u + c * v)


def _mo_hinh(x, y, rot1, rot2, sx, sy, ax, ay):
    """Do lech = quay((ax*sx, ay*sy), rot1), doi dau phan x khi rot2 - rot1 = 180.

    Bon phep do doc lap da chot cong thuc nay:
      - `work/hai_cap_do.py` do NGUOC do lech that tu (v2, v3): ban nay dung dau
        (607.943 / 617.664 = 98,43%), ban khong quay 596.685 (96,60%), ban lat vo
        dieu kien tut xuong 575.423 (93,16%).
      - ADou01 `Walk` / `图层 22` tinh tay: quay neo (48,88; -20,86) theo rot1
        (7,56 do) ra 51,199 -> x - 51,199 = 13,89 -> ceil 14 = v2 dung file ghi.
      - Nam xuong do bang may ao (rot = 0 nen cong thuc rut ve `x - ax*sx`):
        ZhangLiangBao (-88, -227), Hoplite (-77, -162), Gashapon (-132, -196),
        ElephantSoldier (-103, -115), YuJin Head (1, -127) — khop ca nam.
      - ADou01 `PlugIn_1` co rot2 = 180: khong doi dau thi ra 9, doi dau ra 10,
        file ghi 10 — nen luat lat la that, khong phai suy dien.
    """
    u, v = ax * sx, ay * sy
    a = math.radians(rot1)
    c, s = math.cos(a), math.sin(a)
    dx = u * c - v * s
    if _lat(rot1, rot2):
        dx = -dx
    return (_c(x - dx), _c(y - (u * s + v * c)))


def _models(x, y, rot1, rot2, sx, sy, ax, ay):
    """Cac mo hinh ung vien cho (v2, v3). Tra ve dict ten -> (mx, my).

    Moi ban deu co mot ban "lat" rieng, va ban lat ay CHI duoc tinh khi `_lat()`
    dung — do lat vo dieu kien la mot gia thuyet khac han (va do ra la sai).
    """
    ra = {}
    u, v = ax * sx, ay * sy
    ra['neo*s, khong quay'] = (_c(x - u), _c(y - v))
    for ten, deg in (('quay rot1', rot1), ('quay rot2', rot2),
                     ('quay (rot1+rot2)/2', (rot1 + rot2) / 2.0)):
        dx, dy = _quay(u, v, deg)
        ra[ten] = (_c(x - dx), _c(y - dy))
        if _lat(rot1, rot2):
            ra[ten + ' + lat -x'] = (_c(x + dx), _c(y - dy))
    ra['MO HINH (quay rot1 + lat -x)'] = _mo_hinh(x, y, rot1, rot2, sx, sy, ax, ay)
    return ra


def do(root):
    """`anim.keys()` an mat +0x18/+0x20 (ti le va neo), nen phep do nay di lai
    theo cau truc dong tac -> xuong -> khung va doc thang 20 so thuc cua khung."""
    d = collections.Counter()
    theoxuong = collections.Counter()
    vid = collections.defaultdict(list)
    for p in anim.find_files(root):
        try:
            a = anim.load(p)
        except anim.AnimError:
            continue
        base = a.name
        # ten xuong + chi so: di lai tu mang dong tac de co key_off/key_count
        for i in range(a.u(0x28)):
            r = a.grp_base + i * 0x10
            sub_off, sub_n = a.u(r + 8), a.u(r + 0xc)
            for k in range(sub_n):
                m = a.grp_sub + sub_off + k * anim.ANIM_REC
                nm = a.s(a.u(m), a.u(m + 4))
                if not nm or nm == 'None':
                    continue
                an_ten = nm
                bo, bn = a.u(m + 0x20), a.u(m + 0x24)
                for j in range(bn):
                    bp = a.bone_base + bo + j * anim.BONE_REC
                    if bp + anim.BONE_REC > a.size:
                        break
                    ten = a._name_at(bp)
                    ko, kc = a.u(bp + 0x10), a.u(bp + 0x14)
                    for q_i in range(kc):
                        q = a.key_base + ko + q_i * anim.KEY_REC
                        if q + anim.KEY_REC > a.size:
                            break
                        v = struct.unpack_from('<20f', a.d, q)
                        x, y, v2, v3 = v[0], v[1], v[2], v[3]
                        rot1, rot2 = v[4], v[5]
                        sx, sy = v[6], v[7]
                        ax, ay = v[8], v[9]
                        if math.isnan(v2) or math.isnan(v3):
                            d['NaN'] += 1
                            continue
                        d['key'] += 1
                        # Nhom KHUNG AN: ban goc dat (v2, v3) = (0, 0).
                        if sx == 0.0 or v[11] < 0:
                            d['an'] += 1
                            if v2 == 0.0 and v3 == 0.0:
                                d['an v=(0,0)'] += 1
                            continue
                        d['hien'] += 1
                        if _lat(rot1, rot2):
                            d['lat 180'] += 1
                        if ax == 0.0 and ay == 0.0:
                            d['neo (0,0)'] += 1
                        if v2 == int(v2) and v3 == int(v3):
                            d['v NGUYEN'] += 1
                        for nhan, (mx, my) in _models(x, y, rot1, rot2, sx, sy,
                                                      ax, ay).items():
                            if mx == v2 and my == v3:
                                d[nhan] += 1
                        mx, my = _mo_hinh(x, y, rot1, rot2, sx, sy, ax, ay)
                        if mx == v2 and my == v3:
                            d['MO HINH'] += 1
                        else:
                            theoxuong[ten] += 1
                            if len(vid['sai']) < 12:
                                vid['sai'].append(
                                    (base, an_ten, ten, (x, y), (v2, v3),
                                     (ax, ay), (sx, sy), (rot1, rot2)))
    return d, vid, theoxuong


TEN_TRUONG = ['+0x00', '+0x04', '+0x08', '+0x0c', '+0x10', '+0x14', '+0x18', '+0x1c',
              '+0x20', '+0x24', '+0x28', '+0x2c', '+0x30', '+0x34', '+0x38', '+0x3c',
              '+0x40', '+0x44', '+0x48', '+0x4c']


def khoa_tho(root, rig, an_ten, xuong, gioi_han=4):
    """In 20 so thuc cua tung khung, de tay doi chieu cong thuc tren mot xuong cu
    the (dung khi mot khung nam trong nhom 1,18% chua giai)."""
    a = anim.load(os.path.join(root, rig + '.xml'))
    for i in range(a.u(0x28)):
        r = a.grp_base + i * 0x10
        sub_off, sub_n = a.u(r + 8), a.u(r + 0xc)
        for k in range(sub_n):
            m = a.grp_sub + sub_off + k * anim.ANIM_REC
            if a.s(a.u(m), a.u(m + 4)) != an_ten:
                continue
            bo, bn = a.u(m + 0x20), a.u(m + 0x24)
            for j in range(bn):
                bp = a.bone_base + bo + j * anim.BONE_REC
                if a._name_at(bp) != xuong:
                    continue
                ko, kc = a.u(bp + 0x10), a.u(bp + 0x14)
                print('%s / %s / %s  (%d khoa)' % (rig, an_ten, xuong, kc))
                for q_i in range(min(kc, gioi_han)):
                    q = a.key_base + ko + q_i * anim.KEY_REC
                    v = struct.unpack_from('<20f', a.d, q)
                    x, y, v2, v3 = v[0], v[1], v[2], v[3]
                    rot1, rot2, sx, sy, ax, ay = v[4], v[5], v[6], v[7], v[8], v[9]
                    ra = _mo_hinh(x, y, rot1, rot2, sx, sy, ax, ay)
                    print('  k%d %s   (x,y)=(%.4f,%.4f) (v2,v3)=(%g,%g)  mo hinh ra (%g,%g)'
                          % (q_i, 'KHOP' if ra == (v2, v3) else 'LECH',
                             x, y, v2, v3, ra[0], ra[1]))
                    print('        %s' % ' '.join('%s=%g' % (TEN_TRUONG[t], v[t])
                                                   for t in range(20)))


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else 'work/vn/decrypted/assets/map'
    if len(sys.argv) > 4:
        khoa_tho(root, sys.argv[2], sys.argv[3], sys.argv[4])
        return
    d, vd, theoxuong = do(root)
    print('quet %s' % root)
    print('  keyframe huu ich  %8d' % d['key'])
    print('  NaN (bo ra)      %8d' % d['NaN'])
    print('  khung AN (sx=0 hoac d=-1) %8d, trong do v=(0,0): %d (%.2f%%)'
          % (d['an'], d['an v=(0,0)'],
             100.0 * d['an v=(0,0)'] / max(1, d['an'])))
    print('  khung HIEN       %8d   (lat 180 do: %d)' % (d['hien'], d['lat 180']))
    print('     trong do neo (0,0): %d (%.2f%%)  |  (v2,v3) la so NGUYEN: %d (%.2f%%)'
          % (d['neo (0,0)'], 100.0 * d['neo (0,0)'] / max(1, d['hien']),
             d['v NGUYEN'], 100.0 * d['v NGUYEN'] / max(1, d['hien'])))
    print('\ncac mo hinh ung vien (tren so khung HIEN):')
    for k in ('neo*s, khong quay', 'quay rot1', 'quay rot1 + lat -x',
              'quay rot2', 'quay rot2 + lat -x',
              'quay (rot1+rot2)/2', 'quay (rot1+rot2)/2 + lat -x'):
        z = d[k]
        print('  %-28s %8d   (%6.2f%%)' % (k, z, 100.0 * z / max(1, d['hien'])))
    z = d['MO HINH']
    print('  %-28s %8d   (%6.2f%%)   <- mo hinh ghi o docstring'
          % ('MO HINH', z, 100.0 * z / max(1, d['hien'])))
    print('     cong them %d khung luu do lech THO (v2,v3) le = %.2f%%'
          % (d['hien'] - d['v NGUYEN'], 100.0 * (d['hien'] - d['v NGUYEN'])
             / max(1, d['hien'])))
    print('\ncho sai cua MO HINH, theo ten xuong (20 dong dau):')
    for ten, n in theoxuong.most_common(20):
        print('  %-22s %6d' % (ten, n))
    print('\nvi du cho sai (toi da 12):')
    for t in vd['sai']:
        print('  %-16s %-12s %-16s (x,y)=%-22s (v2,v3)=%-18s neo=%-16s ti le=%-14s goc=%s' % t)


main()
