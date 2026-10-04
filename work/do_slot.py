# Ban ghi LOP (0x28) co toi bon cap (do-troi, so-luong): +0x08, +0x10, +0x18,
# +0x20. Neu lop that su co nhieu mang con thi bo doc se MAT DU LIEU IM LANG.
#
# Phan biet that/gia bang phep thu CHAT theo TUNG TEP: mot cap la that neu
#   max(do-troi + so*buoc) == kich thuoc vung dich
# tren ca tep. Cap gia chi tinh co nam trong vung nen hiem khi dung chat.
import os, struct, collections

ROOT = r'C:\Project\game\brave-cross\work\vn\decrypted\assets'
IDX = [0x44,0x48,0x4c,0x50,0x54,0x58,0x5c,0x60,0x64]
def u(d,o): return struct.unpack_from('<I',d,o)[0]

REG = {  # ten vung -> (chi so trong IDX, buoc)
    't2': (2,0x14), 't5': (5,0x18), 't6': (6,0x50), 'arr3': (7,0x28), 'xuong': (1,0x10),
}
LOP_SLOTS = [0x08,0x10,0x18,0x20]
T5_SLOTS  = [0x08,0x0c,0x10]

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

# --- lop: voi MOI slot, cap nao dung chat voi MOT vung nao do?
print('LOP (0x28) — cap o slot nao dung chat voi vung nao (dem theo tep):')
res = collections.Counter()
detail = collections.defaultdict(collections.Counter)
for p,d,t in arm:
    c2=u(d,0x28)
    for s in LOP_SLOTS:
        for rn,(ri,st) in REG.items():
            size = t[ri+1]-t[ri] if ri<8 else len(d)-t[8]
            mx=0; any_=False
            for i in range(c2):
                r=t[3]+i*0x10
                if r+0x10>len(d): break
                sb,sn=u(d,r+8),u(d,r+0xc)
                for k in range(sn):
                    L=t[4]+sb+k*0x28
                    if L+0x28>len(d): break
                    o_,c_=u(d,L+s),u(d,L+s+4)
                    if c_: any_=True; mx=max(mx,o_+c_*st)
            if any_ and mx==size:
                res[(s,rn)]+=1; detail[s][rn]+=1
for s in LOP_SLOTS:
    row=', '.join('%s=%d'%(rn,n) for rn,n in detail[s].most_common())
    print('   +0x%02x  %s' % (s, row or '(khong vung nao)'))

# --- t5: xac nhan lai +0x10 la do-troi, +0x14 la so-luong
print()
print('t5 (0x18) — cap o slot nao dung chat voi vung nao (dem theo tep):')
det2=collections.defaultdict(collections.Counter)
for p,d,t in arm:
    c2=u(d,0x28)
    for s in T5_SLOTS:
        for rn,(ri,st) in REG.items():
            size = t[ri+1]-t[ri] if ri<8 else len(d)-t[8]
            mx=0; any_=False
            for i in range(c2):
                r=t[3]+i*0x10
                if r+0x10>len(d): break
                sb,sn=u(d,r+8),u(d,r+0xc)
                for k in range(sn):
                    L=t[4]+sb+k*0x28
                    if L+0x28>len(d): break
                    to_,tc_=u(d,L+0x20),u(d,L+0x24)
                    for m in range(tc_):
                        K=t[5]+to_+m*0x18
                        if K+0x18>len(d): break
                        o_,c_=u(d,K+s),u(d,K+s+4)
                        if c_: any_=True; mx=max(mx,o_+c_*st)
            if any_ and mx==size:
                det2[s][rn]+=1
for s in T5_SLOTS:
    row=', '.join('%s=%d'%(rn,n) for rn,n in det2[s].most_common())
    print('   +0x%02x  %s' % (s, row or '(khong vung nao)'))
