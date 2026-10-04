# t6+0x40 la INT (khong phai float): do_kf.py doc dang float nen ra 1.4e-45 -> "0.0".
# Neu la so khung cua tung khoa thi: tong(int@0x40) cua mot xuong phai >= so khung
# cua lop, va xuong dai nhat phai BANG so khung cua lop (d8 = lop+0x08).
import os, struct, collections
ROOT = r'C:\Project\game\brave-cross\work\vn\decrypted\assets'
IDX = [0x44,0x48,0x4c,0x50,0x54,0x58,0x5c,0x60,0x64]
def u(d,o): return struct.unpack_from('<I',d,o)[0]

def xmlfiles():
    for dp,_,fns in os.walk(ROOT):
        for fn in fns:
            if fn.lower().endswith('.xml'): yield os.path.join(dp,fn)

dr = collections.Counter(); kq = collections.Counter(); n = 0; mau = []
for p in xmlfiles():
    d=open(p,'rb').read()
    if len(d)<0x68 or d[:6]!=b'sngXml': continue
    t=[u(d,o) for o in IDX]
    if any(t[i]>t[i+1] for i in range(8)) or t[8]>len(d) or t[0]<0x68: continue
    g=[]
    for i in range(u(d,0x28)):
        r=t[3]+i*0x10
        for k in range(u(d,r+0xc)):
            L=t[4]+u(d,r+8)+k*0x28
            for m in range(u(d,L+0x24)):
                K=t[5]+u(d,L+0x20)+m*0x18
                g.append((u(d,K+0x10),u(d,K+0x14)))
    g=sorted(set(g))
    if not g: continue
    dai=t[7]-t[6]; tong=sum(c for _,c in g)
    buoc = 0x50 if dai==tong*0x50 else (0x48 if dai==tong*0x48 else None)
    if buoc is None: continue
    for i in range(u(d,0x28)):
        r=t[3]+i*0x10
        for k in range(u(d,r+0xc)):
            L=t[4]+u(d,r+8)+k*0x28
            d8=u(d,L+8); to_,tc_=u(d,L+0x20),u(d,L+0x24)
            if not tc_: continue
            best=0; allc=[]
            for m in range(tc_):
                K=t[5]+to_+m*0x18
                off,cnt=u(d,K+0x10),u(d,K+0x14)
                s=0
                for q in range(cnt):
                    v=u(d,t[6]+off+q*buoc+0x40); dr[v]+=1; s+=v
                allc.append(s); best=max(best,s)
            n+=1
            if best==d8: kq['xuong_dai_nhat == d8']+=1
            elif best<d8: kq['xuong_dai_nhat < d8']+=1
            else: kq['xuong_dai_nhat > d8']+=1
            if min(allc)==d8: kq['moi_xuong == d8']+=1
            if len(mau)<6: mau.append((os.path.basename(p),k,d8,allc[:8]))

print('so lop:', n)
print('int@0x40 (so khung moi khoa):', dr.most_common(10))
print('ket qua:', kq.most_common())
print('mau (tep, lop, d8, tong tung xuong):')
for m in mau: print('   ', m)
