# Doi chieu loi doc ma voi du lieu that.
#
# FUN_0026d29c noi ro ban ghi keyframe 0x50 doc the nao:
#   0x00/0x04  float x,y            (nhanh A)
#   0x08/0x0c  float x,y du phong    (nhanh B, chon bang co toan cuc)
#   0x10/0x14  float rotation, skew  (do -> rad, skew DAO DAU)
#   0x18/0x1c  float scaleX,scaleY
#   0x20/0x24  float  [8],[9]  -> KHONG ham nao doc
#   0x28/0x2c  float [10],[0xb] -> +0x20 / +0x64
#   0x30       ref display  -> atoi, mac dinh 10000
#   0x38       ref blend    -> screen / multiply / con lai la normal
#   0x40       float duration
#   0x44..0x4c 9 byte: co + a,r,g,b (/255) + 4 gia tri (/100)
#
# Kiem tra: neu loi doc ma dung thi
#   - [2],[3] phai LA BAN LAM TRON cua [0],[1] (do tren nhieu ban ghi)
#   - [8],[9] phai la hang so hoac it bien thien (khong ai doc)
#   - byte 0x49..0x4c phai thuong la 100 (1.0)
#   - ten blend chi thuoc {rong, screen, multiply}
import os, struct, collections

ROOT = r'C:\Project\game\brave-cross\work\vn\decrypted\assets'
IDX = [0x44,0x48,0x4c,0x50,0x54,0x58,0x5c,0x60,0x64]
def u(d,o): return struct.unpack_from('<I',d,o)[0]
def f(d,o): return struct.unpack_from('<f',d,o)[0]

def xmlfiles():
    for dp,_,fns in os.walk(ROOT):
        for fn in fns:
            if fn.lower().endswith('.xml'): yield os.path.join(dp,fn)

blend_n = collections.Counter()
disp_n  = collections.Counter()
f89     = collections.Counter()          # [8],[9] -> (0,0)?
b49     = collections.Counter()
flag44  = collections.Counter()
dur     = collections.Counter()
n_khung = 0; n_ds = 0; n_tep = 0
lech_y  = 0; lech_x = 0; tong_xy = 0    # [2],[3] co phai ban lam tron cua [0],[1]?
am_skew = 0; tong_skew = 0

for p in xmlfiles():
    d = open(p,'rb').read()
    if len(d) < 0x68 or d[:6] != b'sngXml': continue
    t = [u(d,o) for o in IDX]
    if any(t[i] > t[i+1] for i in range(8)) or t[8] > len(d) or t[0] < 0x68: continue
    blob = t[8]; n_tep += 1
    c2 = u(d,0x28); g = []
    for i in range(c2):
        r = t[3] + i*0x10
        sb,sn = u(d,r+8), u(d,r+0xc)
        for k in range(sn):
            L = t[4] + sb + k*0x28
            to_,tc_ = u(d,L+0x20), u(d,L+0x24)
            for m in range(tc_):
                K = t[5] + to_ + m*0x18
                g.append((u(d,K+0x10), u(d,K+0x14)))
    g.sort()
    for j in range(len(g)):
        off,cnt = g[j]
        if cnt == 0: continue
        # buoc suy ra tu khe that, KHONG gia dinh
        if j+1 < len(g): ke = g[j+1][0]
        else: ke = t[7]-t[6]
        if ke < off or (ke-off) % cnt: continue
        if (ke-off)//cnt != 0x50: continue          # chi do co 0x50
        for q in range(cnt):
            F = t[6] + off + q*0x50
            n_khung += 1
            v = [f(d,F+4*s) for s in range(12)]
            o,ln = u(d,F+0x30), u(d,F+0x34)
            if ln and blob+o+ln <= len(d):
                try: disp_n[d[blob+o:blob+o+ln].decode('utf-8')] += 1; n_ds += 1
                except: pass
            o,ln = u(d,F+0x38), u(d,F+0x3c)
            if ln and blob+o+ln <= len(d):
                try: blend_n[d[blob+o:blob+o+ln].decode('utf-8')] += 1
                except: pass
            f89[(v[8], v[9])] += 1
            flag44[d[F+0x44]] += 1
            b49[(d[F+0x49], d[F+0x4a], d[F+0x4b], d[F+0x4c])] += 1
            dur[round(f(d,F+0x40), 4)] += 1
            # [2],[3] co phai lam tron cua [0],[1]?
            for a, b_ in ((v[0], v[2]), (v[1], v[3])):
                tong_xy += 1
                if abs(a) < 1e6 and abs(b_) < 1e6:
                    if int(b_) != int(a): (lech_x if a is v[0] else lech_y)
            if v[0] != v[2]: lech_x += 1
            if v[1] != v[3]: lech_y += 1
            tong_skew += 1
            if v[5] < 0: am_skew += 1

print('tep xuong doc duoc:', n_tep, ' khung:', n_khung)
print('ten HIEN THI khac nhau:', len(disp_n), ' tong so khung co ten:', n_ds)
print('   vai ten dau:', disp_n.most_common(12))
print('ten BLEND khac nhau:', len(blend_n))
for k,v in blend_n.most_common(12): print('   %-14r %d'%(k,v))
print()
print('[8],[9] — phan bo:', f89.most_common(6))
print('co @0x44 (byte dau):', flag44.most_common(6))
print('byte 0x49..0x4c  — phan bo:', b49.most_common(8))
print('duration @0x40 — phan bo:', dur.most_common(10))
print()
print('[2],[3] KHAC [0],[1]:  x %d/%d   y %d/%d' % (lech_x, tong_skew, lech_y, tong_xy//2))
print('[5] (skew) am: %d/%d' % (am_skew, tong_skew))
