# FPS o dau?  [DA BI THAY BOI do_dau.py + do_dr.py — tien de duoi day SAI]
#
# Tien de cu: "duration @0x40 = 0.0 ca 644.556 khung" — do la doc u32 DANG FLOAT
# (ban ghi 0x00000001 ra 1,4e-45 ≈ 0.0). Thuc te +0x40 la SO KHUNG cua khoa, va
# Σ cua no tren moi xuong bang dung so khung cua lop (8.317/8.340). Nhip khung la
# truong int +0x10 DAU TEP: 16 (326 tep), 24 (40), 12 (33) — xem do_dau.py.
# Giu lai script nay vi phan do cac truong `lop` van dung.
#
# Do: voi moi lop (0x28), doc
#   +0x08  duration  (FUN_0026d5bc: chi nhan khi >= 0)
#   +0x0c  scale
#   +0x10  ?
#   +0x14  isLoop (khac 0)
#   +0x18  ref chuoi -> atoi, mac dinh 10000
#   +0x20/+0x24  con t5, buoc 0x18
# roi so duration voi so khung LON NHAT trong cac duong cua lop do.
# Neu duration ~ maxKhung thi don vi la KHUNG; neu duration ~ maxKhung/N thi
# don vi la GIAY va N chinh la FPS.
import os, struct, collections

ROOT = r'C:\Project\game\brave-cross\work\vn\decrypted\assets'
IDX = [0x44,0x48,0x4c,0x50,0x54,0x58,0x5c,0x60,0x64]
def u(d,o): return struct.unpack_from('<I',d,o)[0]
def f(d,o): return struct.unpack_from('<f',d,o)[0]

def xmlfiles():
    for dp,_,fns in os.walk(ROOT):
        for fn in fns:
            if fn.lower().endswith('.xml'): yield os.path.join(dp,fn)

n_lop = 0
dur_f = collections.Counter()
ratio = collections.Counter()
scale_c = collections.Counter()
f10_c = collections.Counter()
loop_c = collections.Counter()
chuoi18 = collections.Counter()
mau = []

for p in xmlfiles():
    d = open(p,'rb').read()
    if len(d) < 0x68 or d[:6] != b'sngXml': continue
    t = [u(d,o) for o in IDX]
    if any(t[i] > t[i+1] for i in range(8)) or t[8] > len(d) or t[0] < 0x68: continue
    blob = t[8]
    c2 = u(d,0x28)
    for i in range(c2):
        r = t[3] + i*0x10
        sb,sn = u(d,r+8), u(d,r+0xc)
        for k in range(sn):
            L = t[4] + sb + k*0x28
            n_lop += 1
            dv = f(d, L+0x08)
            dur_f[round(dv,4)] += 1
            scale_c[round(f(d,L+0x0c),4)] += 1
            f10_c[f(d,L+0x10)] += 1
            loop_c[u(d,L+0x14)] += 1
            o,ln = u(d,L+0x18), u(d,L+0x1c)
            s = ''
            if ln and blob+o+ln <= len(d):
                try: s = d[blob+o:blob+o+ln].decode('utf-8')
                except: pass
            chuoi18[s if len(s) < 24 else s[:24]+'...'] += 1
            # so khung lon nhat trong lop
            to_,tc_ = u(d,L+0x20), u(d,L+0x24)
            mx = 0
            for m in range(tc_):
                K = t[5] + to_ + m*0x18
                mx = max(mx, u(d,K+0x14))
            if mx and dv > 0:
                ratio[round(dv/mx, 4)] += 1
                if len(mau) < 10: mau.append((os.path.basename(p), k, round(dv,3), mx, round(dv/mx,4)))

print('so lop:', n_lop)
print()
print('duration @0x08 (doc dang float):', dur_f.most_common(12))
print('scale    @0x0c:', scale_c.most_common(6))
print('truong   @0x10:', f10_c.most_common(6))
print('isLoop   @0x14:', loop_c.most_common(6))
print('chuoi    @0x18:', chuoi18.most_common(10))
print()
print('duration / maxKhung:', ratio.most_common(12))
print('vai mau:')
for m in mau: print('   %-22s lop%-3d duration=%-10s khung=%-5d ti le=%s' % m)
