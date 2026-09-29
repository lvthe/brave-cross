# Bang truong day du cua keyframe t6, do tren TOAN BO khoa cua 418 tep,
# voi buoc tu chon theo tung tep (0x50 hay 0x48).
import os, struct, collections
ROOT = r'C:\Project\game\brave-cross\work\vn\decrypted\assets'
IDX = [0x44,0x48,0x4c,0x50,0x54,0x58,0x5c,0x60,0x64]
def u(d,o): return struct.unpack_from('<I',d,o)[0]
def f(d,o): return struct.unpack_from('<f',d,o)[0]

def xmlfiles():
    for dp,_,fns in os.walk(ROOT):
        for fn in fns:
            if fn.lower().endswith('.xml'): yield os.path.join(dp,fn)

fl = collections.defaultdict(collections.Counter)
z_c=collections.Counter(); di_c=collections.Counter()
ref30=collections.Counter(); ref38=collections.Counter(); bl=collections.Counter()
flag=collections.Counter(); mau_c=collections.Counter()
nk=0; ntep=0
for p in xmlfiles():
    d=open(p,'rb').read()
    if len(d)<0x68 or d[:6]!=b'sngXml': continue
    t=[u(d,o) for o in IDX]
    if any(t[i]>t[i+1] for i in range(8)) or t[8]>len(d) or t[0]<0x68: continue
    blob=t[8]; g=[]
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
    ntep+=1
    def s_(F,off):
        o,ln=u(d,F+off),u(d,F+off+4)
        if not ln: return ''
        if blob+o+ln>len(d) or ln>64: return '<ngoai pool>'
        return d[blob+o:blob+o+ln].decode('utf-8','replace')
    for off,cnt in g:
        for q in range(cnt):
            F=t[6]+off+q*buoc
            if F+buoc>len(d): continue
            nk+=1
            for s in range(10): fl[s][round(f(d,F+4*s),4)]+=1
            z_c[u(d,F+0x28)]+=1; di_c[u(d,F+0x2c)]+=1
            ref30[s_(F,0x30)]+=1; ref38[s_(F,0x38)]+=1
            flag[d[F+0x44]]+=1
            mau_c[(d[F+0x45],d[F+0x46],d[F+0x47],d[F+0x48])]+=1

print('tep:',ntep,' khoa:',nk)
for s in range(10):
    print('  f[%d] @%#04x:'%(s,4*s), fl[s].most_common(4))
print('z  @0x28 (int):', z_c.most_common(6))
print('dI @0x2c (int):', di_c.most_common(6))
print('ref hien thi @0x30:', ref30.most_common(5))
print('ref kieu tron @0x38:', ref38.most_common(5))
print('co mau @0x44 (byte):', flag.most_common(5))
print('a,r,g,b @0x45..0x48:', mau_c.most_common(5))
