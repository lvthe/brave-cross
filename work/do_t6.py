# Kiem chung: bo nap goc doc t6 the nao?  FUN_0026d51c (t5 -> CCMovementBoneData)
# lay off@0x10 va cnt@0x14 (cua ban ghi t5, buoc 0x18, duoc liet ke tu lop @0x20/0x24)
# roi doc cnt ban ghi buoc 0x50 KE TU off -- KHONG kiem tra chuoi offset.
# Vay "hut 8/24 byte" chi la lo hong dem vo hai neu:
#   (a) moi ban ghi nam trong vung t6, (b) moi ref chuoi tro dung trong pool.
import os, struct

ROOT = r'C:\Project\game\brave-cross\work\vn\decrypted\assets'
IDX = [0x44,0x48,0x4c,0x50,0x54,0x58,0x5c,0x60,0x64]
def u(d,o): return struct.unpack_from('<I',d,o)[0]

def kiem(p):
    d = open(p,'rb').read()
    if len(d) < 0x68 or d[:6] != b'sngXml': return None
    t = [u(d,o) for o in IDX]
    if any(t[i] > t[i+1] for i in range(8)) or t[8] > len(d) or t[0] < 0x68: return None
    blob = t[8]; c2 = u(d,0x28); g = []
    for i in range(c2):
        r = t[3] + i*0x10
        sb,sn = u(d,r+8), u(d,r+0xc)
        for k in range(sn):
            L = t[4] + sb + k*0x28
            to_,tc_ = u(d,L+0x20), u(d,L+0x24)
            for m in range(tc_):
                K = t[5] + to_ + m*0x18
                g.append((u(d,K+0x10), u(d,K+0x14)))
    g = sorted(set(g))
    t6a, t6b = t[6], t[7]; dai = t6b - t6a
    tong = nk = ngoai = ref_loi = 0; lo = []
    for j,(off,cnt) in enumerate(g):
        if off + cnt*0x50 > dai: ngoai += 1
        for q in range(cnt):
            F = t6a + off + q*0x50
            if F + 0x50 > t6b: continue
            nk += 1
            for x in (0x30, 0x38):
                o, ln = u(d,F+x), u(d,F+x+4)
                if ln and (blob + o + ln > len(d) or ln > 64): ref_loi += 1
        tong += cnt
        if j+1 < len(g) and g[j+1][0] != off + cnt*0x50:
            lo.append((off, cnt, g[j+1][0] - (off + cnt*0x50)))
    return dict(ten=os.path.basename(p), t6=dai, tong=tong, nk=nk, ngoai=ngoai,
                ref_loi=ref_loi, lo=lo, du=dai - tong*0x50, nb=len(g))

for ten in ('BingYing.xml','XSJiYouHeTiJi.xml','ADou01.xml','Archer.xml'):
    for dp,_,fns in os.walk(ROOT):
        if ten in fns:
            k = kiem(os.path.join(dp,ten))
            if k is None: print(ten, ': khong doc duoc'); break
            print('%-20s t6=%7d  duong=%4d  tong_khoa=%7d  ngoai=%d  ref_loi=%d  thua=%d'
                  % (k['ten'], k['t6'], k['nb'], k['tong'], k['ngoai'], k['ref_loi'], k['du']))
            if k['lo']: print('     lo hong (off, cnt, lech):', k['lo'][:8])
            break
