# -*- coding: utf-8 -*-
"""Truy nguoc DO LECH (dx, dy) ma khung xuong da dung, roi thu mot loat cong thuc.

`v2 = ceil(x - dx)` nghia la `dx` nam trong NUA KHOANG [x - v2, x - v2 + 1). Do la
cach do NGUOC: khong doan cong thuc roi so ket qua, ma lay chinh (v2, v3) trong
file ra de biet do lech that nam o dau, roi xem cong thuc nao roi vao khoang ay.

    python hai_cap_do.py [thu_muc] [so_key_toi_da]
"""
import os, sys, math, struct, collections

sys.stdout.reconfigure(encoding='utf-8', errors='replace')
os.chdir(r'C:\Project\game\brave-cross')
sys.path.insert(0, os.path.join(os.getcwd(), 'work'))
import anim
import cay


def khoang(x, v):
    """Nua khoang chua `dx` sao cho ceil(x - dx) == v."""
    return (x - v, x - v + 1.0)


def _r(u, v, deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return (c * u - s * v, s * u + c * v)


def ung_vien(ax, ay, sx, sy, rot1, rot2):
    """Cac do lech ung vien, tra ve dict ten -> (dx, dy)."""
    u, v = ax * sx, ay * sy
    lat = math.isclose((rot2 - rot1) % 360.0, 180.0, abs_tol=1e-3)
    r1 = _r(u, v, rot1)
    r2 = _r(u, v, rot2)
    ra = {}
    ra['neo*s, khong quay'] = (u, v)
    ra['quay rot1 (khong lat)'] = r1
    ra['quay rot1 (lat LUON)'] = (-r1[0], r1[1])
    ra['quay rot1 (lat -x)'] = (-r1[0] if lat else r1[0], r1[1])
    ra['quay rot1 (lat -y)'] = (r1[0], -r1[1] if lat else r1[1])
    ra['quay rot1 (lat -x-y)'] = (-r1[0] if lat else r1[0], -r1[1] if lat else r1[1])
    ra['quay rot2 (lat -x)'] = (-r2[0] if lat else r2[0], r2[1])
    ra['x:rot2 y:rot1 (lat -x)'] = (-r2[0] if lat else r2[0], r1[1])
    ra['x:rot1 y:rot2 (lat -x)'] = (-r1[0] if lat else r1[0], r2[1])
    ra['quay (rot1+rot2)/2 (lat -x)'] = (
        -_r(u, v, (rot1 + rot2) / 2.0)[0] if lat else _r(u, v, (rot1 + rot2) / 2.0)[0],
        _r(u, v, (rot1 + rot2) / 2.0)[1])
    ra['neo roi quay rot1 roi *s (lat -x)'] = (
        -_r(ax, ay, rot1)[0] * sx if lat else _r(ax, ay, rot1)[0] * sx,
        _r(ax, ay, rot1)[1] * sy)
    return ra


GOC = [0, 45, 90, 135, 180, 225, 270, 315, 360]


def _goc_bucket(d):
    """Gom hieu (rot2 - rot1) mod 360 vao cac o 45 do."""
    return min(GOC, key=lambda g: abs(g - d))


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.join(cay.ASSETS, 'map')
    gioi_han = int(sys.argv[2]) if len(sys.argv) > 2 else 0

    d = collections.Counter()
    lat_ctl = collections.Counter()
    lat_vi_du = []
    lat_sai = 0
    khong_ra = []
    vi_du = collections.defaultdict(list)
    tong = 0
    for p in anim.find_files(root):
        try:
            a = anim.load(p)
        except anim.AnimError:
            continue
        for i in range(a.u(0x28)):
            r = a.grp_base + i * 0x10
            sub_off, sub_n = a.u(r + 8), a.u(r + 0xc)
            for k in range(sub_n):
                m = a.grp_sub + sub_off + k * anim.ANIM_REC
                nm = a.s(a.u(m), a.u(m + 4))
                if not nm or nm == 'None':
                    continue
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
                        rot1, rot2, sx, sy, ax, ay = v[4], v[5], v[6], v[7], v[8], v[9]
                        if math.isnan(v2) or math.isnan(v3) or sx == 0.0 or v[11] < 0:
                            continue
                        tong += 1
                        if gioi_han and tong > gioi_han:
                            break
                        cx, cy = khoang(x, v2), khoang(y, v3)
                        uv = ung_vien(ax, ay, sx, sy, rot1, rot2)
                        for nhan, (dx, dy) in uv.items():
                            if cx[0] <= dx < cx[1] and cy[0] <= dy < cy[1]:
                                d[nhan] += 1
                        # LUAT LAT: so sanh "khong lat" voi "lat LUON" theo tung o
                        # cua hieu (rot2 - rot1). Hai o dau tien la bang chung quyet
                        # dinh ve dieu kien lat that su la gi.
                        def khop(t):
                            dx, dy = uv[t]
                            return cx[0] <= dx < cx[1] and cy[0] <= dy < cy[1]
                        k0, k1 = khop('quay rot1 (khong lat)'), khop('quay rot1 (lat LUON)')
                        if not (k0 and k1):
                            b = _goc_bucket((rot2 - rot1) % 360.0)
                            lat_that = math.isclose((rot2 - rot1) % 360.0, 180.0,
                                                    abs_tol=1e-3)
                            lat_ctl[b] += 1
                            if lat_that != k1:
                                lat_sai += 1
                                if len(lat_vi_du) < 10:
                                    lat_vi_du.append((a.name, nm, ten, (x, y), (v2, v3),
                                                      (ax, ay), (sx, sy), (rot1, rot2),
                                                      (k0, k1), (cx[0], cx[1])))
                        if not any(khop(t) for t in uv):
                            d['KHONG CONG THUC NAO'] += 1
                            if len(khong_ra) < 14:
                                khong_ra.append((a.name, nm, ten, (x, y), (v2, v3),
                                                 (ax, ay), (sx, sy), (rot1, rot2), (cx, cy)))
                            vi_du[ten].append(1)
                        # Vi sao phep do `ceil` cung ban lai ra thap hon: chia ket qua
                        # cua mo hinh MANH NHAT theo viec (v2, v3) co phai so NGUYEN
                        # khong. Neu cho lech nam het o nhom KHONG nguyen thi nghia la
                        # file luu do lech THO, khong lam tron — chu khong phai cong
                        # thuc sai.
                        nguyen = (v2 == int(v2)) and (v3 == int(v3))
                        d['khop, v NGUYEN' if (khop('quay rot1 (lat -x)') and nguyen)
                          else 'khop, v KHONG nguyen' if khop('quay rot1 (lat -x)')
                          else 'truot, v NGUYEN' if nguyen
                          else 'truot, v KHONG nguyen'] += 1

    print('xet %d khung HIEN' % tong)
    print('\nmoi cong thuc: bao nhieu khung ma do lech roi DUNG vao khoang [x-v2, x-v2+1):')
    for nhan, z in d.most_common():
        if nhan.startswith('KHONG'):
            continue
        print('  %-34s %8d  (%6.2f%%)' % (nhan, z, 100.0 * z / max(1, tong)))
    print('  %-34s %8d  (%6.2f%%)' % ('KHONG CONG THUC NAO',
                                      d['KHONG CONG THUC NAO'],
                                      100.0 * d['KHONG CONG THUC NAO'] / max(1, tong)))
    print('\nLUAT LAT — so khung ma hai ban (khong lat / lat LUON) KHONG cung dung,'
          '\n  gom theo hieu (rot2 - rot1) mod 360:')
    for b in sorted(lat_ctl):
        print('  %4d do  %6d' % (b, lat_ctl[b]))
    print('\n  trong so ay, ban "lat khi hieu = 180" doan SAI: %d' % lat_sai)
    for t in lat_vi_du:
        print('     %-14s %-10s %-12s neo=%-20s s=%-10s goc=%-22s (khong lat, latLUON)=(%s,%s)'
              % (t[0], t[1], t[2], t[5], t[6], t[7], t[8][0], t[8][1]))
    print('\nchia mo hinh manh nhat theo (v2, v3) co phai so NGUYEN khong:')
    for k in ('khop, v NGUYEN', 'khop, v KHONG nguyen',
              'truot, v NGUYEN', 'truot, v KHONG nguyen'):
        print('  %-26s %8d  (%6.2f%%)' % (k, d[k], 100.0 * d[k] / max(1, tong)))
    print('\ntheo ten xuong (khi KHONG cong thuc nao ra):')
    for ten, n in collections.Counter(
            [t[2] for t in khong_ra]).most_common(15):
        print('  %-20s %6d' % (ten, n))
    print('\nvi du:')
    for t in khong_ra[:14]:
        print('  %-16s %-10s %-14s (x,y)=%-24s (v2,v3)=%-16s neo=%-18s s=%-14s goc=%-22s khoang x=[%.3f,%.3f)' % (
            t[0], t[1], t[2], t[3], t[4], t[5], t[6], t[7], t[8][0][0], t[8][0][1]))


main()
