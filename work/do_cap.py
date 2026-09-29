# Bo doc NHI PHAN chon cap (x,y) theo PHIEN BAN DINH DANG, khong phai theo
# kieu "ban lam tron". Dao ma ARM cua FUN_0026d29c, dau ham:
#
#   0x25d2a8  vmov.f32 s15, #2.0
#   0x25d2b0  vldr     s14, [r3,#4]     ; DAT_0093c06c = truong "version"
#   0x25d2b4  vcmpe.f32 s14, s15
#   0x25d2be  blt      #0x25d2ee       ; version < 2.0  -> doc param_1[0], param_1[1]
#   0x25d2c0  vldr     s15, [r5,#8]     ; version >= 2.0 -> doc param_1[2], param_1[3]
#
# Ca 418 tep deu version 2.2  =>  cap SONG la [2],[3].  (Ghidra in "NAN(...)"
# cho vcmpe+blt nen doc pseudocode khong thay duoc chieu.)
#
# Do:
#   A. keyframe: [0],[1] voi [2],[3] co quan he gi (dao dau? trung? lech bao nhieu?)
#   B. arr3: 8 float nhung bo doc CHU chi doc 4 ten truong
#      (pX|pY -> cocos2d_pX/cocos2d_pY, width, height).  Vay 8 float nay co phai
#      HAI NHOM 4, nhom sau la ban doi ten cua nhom truoc?
import os, struct, collections

ROOT = r'C:\Project\game\brave-cross\work\vn\decrypted\assets'
IDX = [0x44,0x48,0x4c,0x50,0x54,0x58,0x5c,0x60,0x64]
def u(d,o): return struct.unpack_from('<I',d,o)[0]
def f(d,o): return struct.unpack_from('<f',d,o)[0]
def eq(a,b): return a == b
def near(a,b):
    return abs(a-b) <= 1e-4 * max(1.0, abs(a), abs(b))

def xmlfiles():
    for dp,_,fns in os.walk(ROOT):
        for fn in fns:
            if fn.lower().endswith('.xml'): yield os.path.join(dp,fn)

kf = collections.Counter()      # quan he hai cap keyframe
kf_f1z = kf_f3z = kf_f0z = kf_f2z = 0
n_kf = 0
diff2_0 = collections.Counter() # f2 - f0 (lam tron 4)
sum3_1  = collections.Counter() # f3 + f1
dif3_1  = collections.Counter() # f3 - f1
ti_le   = collections.Counter() # |f2|/|f0| khi ca hai khac 0

arr = collections.Counter()     # quan he nhom 4 sau voi nhom 4 truoc (arr3)
arr_w = collections.Counter()   # rieng cap width,height: [2],[3] voi [6],[7]
n_arr = 0

for p in xmlfiles():
    d = open(p,'rb').read()
    if len(d) < 0x68 or d[:6] != b'sngXml': continue
    t = [u(d,o) for o in IDX]
    if any(t[i] > t[i+1] for i in range(8)) or t[8] > len(d) or t[0] < 0x68: continue
    blob = t[8]

    # --- A. keyframe: dung lai phep do buoc cua do_kf.py (chi nhan buoc 0x50)
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
        ke = g[j+1][0] if j+1 < len(g) else t[7]-t[6]
        if ke < off or (ke-off) % cnt: continue
        if (ke-off)//cnt != 0x50: continue
        for q in range(cnt):
            F = t[6] + off + q*0x50
            v = [f(d,F+4*s) for s in range(12)]
            n_kf += 1
            if v[1] == 0.0: kf_f1z += 1
            if v[3] == 0.0: kf_f3z += 1
            if v[0] == 0.0: kf_f0z += 1
            if v[2] == 0.0: kf_f2z += 1
            # bon kieu quan he, so sanh CHINH XAC
            sx = '=' if eq(v[2],v[0]) else ('dao' if eq(v[2],-v[0]) else 'khac')
            sy = '=' if eq(v[3],v[1]) else ('dao' if eq(v[3],-v[1]) else 'khac')
            kf[(sx,sy)] += 1
            diff2_0[round(v[2]-v[0],4)] += 1
            sum3_1[round(v[3]+v[1],4)] += 1
            dif3_1[round(v[3]-v[1],4)] += 1
            if v[0] and v[2]:
                ti_le[round(abs(v[2]/v[0]),4)] += 1

    # --- B. arr3: 8 float
    c3 = u(d,0x40)
    for i in range(c3):
        r = t[7] + i*0x28
        w = [f(d,r+0x08+4*s) for s in range(8)]
        n_arr += 1
        for s in range(4):
            a, b_ = w[s], w[s+4]
            k = '=' if eq(a,b_) else ('dao' if eq(a,-b_) else 'khac')
            arr[(s,k)] += 1
        for s in (2,3):
            a, b_ = w[s], w[s+4]
            arr_w[('=' if eq(a,b_) else 'khac')] += 1

print('so khung doc duoc:', n_kf)
print()
print('A. [2],[3] so voi [0],[1] tren keyframe (khop CHINH XAC):')
for k,v in kf.most_common(): print('   x%-5s y%-5s  %8d  (%.2f%%)' % (k[0],k[1],v,100.0*v/n_kf))
print('   f0==0: %d   f2==0: %d   f1==0: %d   f3==0: %d' % (kf_f0z,kf_f2z,kf_f1z,kf_f3z))
print()
print('   f2-f0  (hay gap):', diff2_0.most_common(6))
print('   f3+f1  (hay gap):', sum3_1.most_common(6))
print('   f3-f1  (hay gap):', dif3_1.most_common(6))
print('   |f2|/|f0|        :', ti_le.most_common(6))
print()
print('B. arr3 — o thu s so voi o s+4:')
for s in range(4):
    tot = arr[(s,'=')]+arr[(s,'dao')]+arr[(s,'khac')]
    print('   o%-2d  bang %-8d  dao %-8d  khac %-8d' % (s,arr[(s,'=')],arr[(s,'dao')],arr[(s,'khac')]))
print('   rieng width/height (o2,o3):', arr_w.most_common(4), '/', n_arr, 'ban ghi')
