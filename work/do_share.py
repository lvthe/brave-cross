# 22 cho con tro t5->t6 khac vi tri xep tuan tu. Tra xem khac theo kieu gi:
#   - con tro NHO hon vi tri xep  -> co the DUNG CHUNG khoi cua ban ghi truoc
#   - con tro LON hon             -> co the co KHOANG TRONG
# Va dem xem mot khoi t6 co bi nhieu duong xuong cung tro toi khong.
import os, struct, collections

ROOT = r'C:\Project\game\brave-cross\work\vn\decrypted\assets'
IDX = [0x44,0x48,0x4c,0x50,0x54,0x58,0x5c,0x60,0x64]
def u(d,o): return struct.unpack_from('<I',d,o)[0]

def xmlfiles():
    for dp,_,fns in os.walk(ROOT):
        for fn in fns:
            if fn.lower().endswith('.xml'): yield os.path.join(dp,fn)

kieu = collections.Counter()
mau = []
share_trong_tep = 0
tep_share = []
khit_t6 = collections.Counter()

for p in xmlfiles():
    d=open(p,'rb').read()
    if len(d)<0x68 or d[:6]!=b'sngXml': continue
    t=[u(d,o) for o in IDX]
    if any(t[i]>t[i+1] for i in range(8)) or t[8]>len(d) or t[0]<0x68: continue
    c2=u(d,0x28)
    pf=0; dung=collections.Counter(); ghi=[]
    for i in range(c2):
        r=t[3]+i*0x10
        sb,sn=u(d,r+8),u(d,r+0xc)
        for k in range(sn):
            L=t[4]+sb+k*0x28
            to_,tc_=u(d,L+0x20),u(d,L+0x24)
            for m in range(tc_):
                K=t[5]+to_+m*0x18
                foff,fcnt=u(d,K+0x10),u(d,K+0x14)
                dung[foff]+=1
                if foff!=pf:
                    hieu=foff-pf
                    kieu['nho hon (dung chung?)' if hieu<0 else 'lon hon (khoang trong?)']+=1
                    if len(mau)<6:
                        mau.append((os.path.basename(p), foff, pf, hieu, fcnt))
                    ghi.append((foff,pf,hieu))
                pf+=fcnt*0x50
    sh=[k for k,v in dung.items() if v>1]
    if sh:
        share_trong_tep+=1
        if len(tep_share)<6: tep_share.append((os.path.basename(p), len(sh), max(dung[k] for k in sh)))
    end=pf
    if end==t[7]-t[6]: khit_t6['khit']+=1
    else: khit_t6['lech %d'%(end-(t[7]-t[6]))]+=1

print('kieu lech cua con tro t5->t6:')
for k,v in kieu.most_common(): print('   %-28s %d'%(k,v))
print()
print('vi du (tep, foff ghi trong tep, vi tri xep, hieu, so khung):')
for m in mau: print('   %-24s foff=%-8d xep=%-8d hieu=%-7d fcnt=%d'%m)
print()
print('tep co khoi t6 bi nhieu duong xuong CUNG tro toi:', share_trong_tep, '/418')
for x in tep_share: print('   %-24s %d khoi bi dung lai, nhieu nhat %d lan'%x)
print()
print('vung t6 khit (tong fcnt*0x50 so voi t7-t6):', dict(khit_t6))
