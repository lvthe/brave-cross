# Do NOT ba moi noi con lai, va voi MOI slot chu khong chi slot da doan:
#   1. arr1     (0x10) -> bang xuong  [t1,t2) buoc 0x10
#   2. xuong    (0x10) -> t2          [t2,t3) buoc 0x14
#   3. arr2     (0x10) -> bang lop    [t4,t5) buoc 0x28
# Cung phep thu CHAT theo tung tep: max(do-troi + so*buoc) == kich thuoc vung.
import os, struct, collections

ROOT = r'C:\Project\game\brave-cross\work\vn\decrypted\assets'
IDX = [0x44,0x48,0x4c,0x50,0x54,0x58,0x5c,0x60,0x64]
def u(d,o): return struct.unpack_from('<I',d,o)[0]

def xmlfiles():
    for dp,_,fns in os.walk(ROOT):
        for fn in fns:
            if fn.lower().endswith('.xml'): yield os.path.join(dp,fn)

arm=[]
for p in xmlfiles():
    d=open(p,'rb').read()
    if len(d)<0x68 or d[:6]!=b'sngXml': continue
    t=[u(d,o) for o in IDX]
    if any(t[i]>t[i+1] for i in range(8)) or t[8]>len(d) or t[0]<0x68: continue
    arm.append((p,d,t))

SLOTS4 = [0x08,0x0c,0x10,0x14]   # trong ban ghi 0x10
det = collections.defaultdict(collections.Counter)

for p,d,t in arm:
    c1,c2 = u(d,0x20), u(d,0x28)
    # 1. arr1 -> bang xuong
    for s in SLOTS4:
        mx=0; any_=False
        for i in range(c1):
            r=t[0]+i*0x10
            if r+0x10>len(d): break
            o_,c_=u(d,r+s),u(d,r+s+4)
            if c_: any_=True; mx=max(mx,o_+c_*0x10)
        if any_ and mx==t[2]-t[1]: det['arr1->xuong'][s]+=1
    # 2. xuong -> t2
    for s in SLOTS4:
        mx=0; any_=False
        for i in range(c1):
            r=t[0]+i*0x10
            if r+0x10>len(d): break
            sb,sn=u(d,r+8),u(d,r+0xc)
            for k in range(sn):
                b=t[1]+sb+k*0x10
                if b+0x10>len(d): break
                o_,c_=u(d,b+s),u(d,b+s+4)
                if c_: any_=True; mx=max(mx,o_+c_*0x14)
        if any_ and mx==t[3]-t[2]: det['xuong->t2'][s]+=1
    # 3. arr2 -> bang lop
    for s in SLOTS4:
        mx=0; any_=False
        for i in range(c2):
            r=t[3]+i*0x10
            if r+0x10>len(d): break
            o_,c_=u(d,r+s),u(d,r+s+4)
            if c_: any_=True; mx=max(mx,o_+c_*0x28)
        if any_ and mx==t[5]-t[4]: det['arr2->lop'][s]+=1

print('moi noi — slot nao dung chat voi vung dich (dem theo TEP, %d tep):' % len(arm))
for k in ('arr1->xuong','xuong->t2','arr2->lop'):
    row=', '.join('+0x%02x=%d'%(s,n) for s,n in det[k].most_common())
    print('   %-13s %s' % (k, row or '(khong slot nao)'))
