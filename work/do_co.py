# Hai co ban ghi keyframe: 0x50 (132.343 khe) va 0x48 (24 khe, chi o hai tep).
# Cau hoi: 8 byte thieu nam o DAU, va string-ref nam o slot nao trong tung co.
#
# Cach quyet dinh KHONG phai doc vai mau: doi chieu voi TU DIEN ten tron that.
# Ten tron lay tu chinh cac ban ghi 0x50 (o do ref @0x38 da biet chac chan).
# Roi hoi: trong co 0x48, slot nao cho ra dung nhung ten do?
import os, struct, collections

ROOT = r'C:\Project\game\brave-cross\work\vn\decrypted\assets'
IDX = [0x44,0x48,0x4c,0x50,0x54,0x58,0x5c,0x60,0x64]
def u(d,o): return struct.unpack_from('<I',d,o)[0]

def xmlfiles():
    for dp,_,fns in os.walk(ROOT):
        for fn in fns:
            if fn.lower().endswith('.xml'): yield os.path.join(dp,fn)

def ghi(d,t):
    """Danh sach (foff, fcnt, buoc) — buoc suy ra tu khe voi duong ke tiep."""
    c2=u(d,0x28); g=[]
    for i in range(c2):
        r=t[3]+i*0x10
        sb,sn=u(d,r+8),u(d,r+0xc)
        for k in range(sn):
            L=t[4]+sb+k*0x28
            to_,tc_=u(d,L+0x20),u(d,L+0x24)
            for m in range(tc_):
                K=t[5]+to_+m*0x18
                g.append([u(d,K+0x10), u(d,K+0x14), None])
    g.sort(key=lambda x:x[0])
    for j in range(len(g)-1):
        khe=g[j+1][0]-g[j][0]
        if g[j][1] and khe%g[j][1]==0: g[j][2]=khe//g[j][1]
    j=len(g)-1
    khe=(t[7]-t[6])-g[j][0]
    if g[j][1] and khe%g[j][1]==0: g[j][2]=khe//g[j][1]
    return g

# luot 1: tu dien ten tron + ten hien thi, lay tu cac ban ghi co buoc 0x50
tron_that=collections.Counter(); hien_that=collections.Counter()
tep=[]
for p in xmlfiles():
    d=open(p,'rb').read()
    if len(d)<0x68 or d[:6]!=b'sngXml': continue
    t=[u(d,o) for o in IDX]
    if any(t[i]>t[i+1] for i in range(8)) or t[8]>len(d) or t[0]<0x68: continue
    tep.append((p,d,t))
    blob=t[8]
    for off,cnt,b in ghi(d,t):
        if b!=0x50: continue
        for q in range(cnt):
            base=t[6]+off+q*0x50
            o,ln=u(d,base+0x38),u(d,base+0x3c)
            if ln and blob+o+ln<=len(d):
                try: tron_that[d[blob+o:blob+o+ln].decode('utf-8')]+=1
                except: pass
            o,ln=u(d,base+0x30),u(d,base+0x34)
            if ln and blob+o+ln<=len(d):
                try: hien_that[d[blob+o:blob+o+ln].decode('utf-8')]+=1
                except: pass

print('ten TRON that (tu ban ghi 0x50, ref @0x38):')
for k,v in tron_that.most_common(8): print('   %-14r %d'%(k,v))
print('ten HIEN THI (tu ban ghi 0x50, ref @0x30):')
for k,v in hien_that.most_common(8): print('   %-14r %d'%(k,v))

# luot 2: trong co 0x48, slot nao cho ra ten TRON that?
print()
print('co 0x48 — slot nao chua ten TRON that?')
for p,d,t in tep:
    blob=t[8]
    for off,cnt,b in ghi(d,t):
        if b!=0x48: continue
        for q in range(cnt):
            base=t[6]+off+q*0x48
            for slot in (0x18,0x20,0x28,0x2c,0x30,0x34,0x38,0x3c):
                o,ln=u(d,base+slot),u(d,base+slot+4)
                if not ln or blob+o+ln>len(d): continue
                try: s=d[blob+o:blob+o+ln].decode('utf-8')
                except: continue
                if s in tron_that: print('   %-22s +0x%02x -> %r'%(os.path.basename(p),slot,s))
