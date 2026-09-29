# d8 (=d10) cua lop la gi?  Doi chieu voi tung xuong cua lop (t5, buoc 0x18:
# float scale @0x08, float delay @0x0c, off @0x10, cnt @0x14).
# Ung vien: max(cnt) | sum(cnt) | max(delay+cnt) | max(delay)+max(cnt)
import os, struct, collections
ROOT = r'C:\Project\game\brave-cross\work\vn\decrypted\assets'
IDX = [0x44,0x48,0x4c,0x50,0x54,0x58,0x5c,0x60,0x64]
def u(d,o): return struct.unpack_from('<I',d,o)[0]
def f(d,o): return struct.unpack_from('<f',d,o)[0]

def xmlfiles():
    for dp,_,fns in os.walk(ROOT):
        for fn in fns:
            if fn.lower().endswith('.xml'): yield os.path.join(dp,fn)

kq=collections.Counter(); n=0
delay_c=collections.Counter(); scale_c=collections.Counter(); nb=collections.Counter()
mau=[]
for p in xmlfiles():
    d=open(p,'rb').read()
    if len(d)<0x68 or d[:6]!=b'sngXml': continue
    t=[u(d,o) for o in IDX]
    if any(t[i]>t[i+1] for i in range(8)) or t[8]>len(d) or t[0]<0x68: continue
    c2=u(d,0x28)
    for i in range(c2):
        r=t[3]+i*0x10
        sb,sn=u(d,r+8),u(d,r+0xc)
        for k in range(sn):
            L=t[4]+sb+k*0x28
            d8=u(d,L+8)
            to_,tc_=u(d,L+0x20),u(d,L+0x24)
            cnts=[]; dels=[]
            for m in range(tc_):
                K=t[5]+to_+m*0x18
                cnts.append(u(d,K+0x14)); dels.append(f(d,K+0x0c))
                delay_c[round(f(d,K+0x0c),4)]+=1; scale_c[round(f(d,K+0x08),4)]+=1
            if not cnts: continue
            n+=1; nb[len(cnts)]+=1
            c1=max(cnts); c2v=sum(cnts)
            c3=max(int(dl)+c for dl,c in zip(dels,cnts))
            c4=int(max(dels))+max(cnts)
            for nm,v in (('max(cnt)',c1),('sum(cnt)',c2v),('max(delay+cnt)',c3),('max(delay)+max(cnt)',c4)):
                if v==d8: kq[nm]+=1
            if len(mau)<10: mau.append((os.path.basename(p),k,d8,cnts,[round(x,3) for x in dels]))

print('so lop:', n, ' so xuong/lop:', nb.most_common(6))
print('khop d8:', kq.most_common())
print('delay @t5+0x0c:', delay_c.most_common(6))
print('scale @t5+0x08:', scale_c.most_common(6))
print('mau (tep, lop, d8, cnt tung xuong, delay tung xuong):')
for m in mau: print('   ', m)
