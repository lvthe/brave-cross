# Do lai TOAN BO corpus cho dinh dang .xml (kieu armature) truoc khi dong dinh
# cac offset vao C++.
#
# Bai hoc cua lan do truoc: kiem bang dang thuc "cuoi BAN GHI == het VUNG" cho
# tung ban ghi la SAI. Vung con duoc chia boi do-troi byte; ban ghi cuoi cung
# moi cham mep vung. Phai kiem hai ve rieng:
#   (a) moi ban ghi nam TRONG vung        -> do-troi + so*buoc <= kich thuoc
#   (b) vung dung chat (khong du)         -> max(do-troi + so*buoc) == kich thuoc
import os, struct, sys, collections

ROOT = r'C:\Project\game\brave-cross\work\vn\decrypted\assets'
IDX = [0x44,0x48,0x4c,0x50,0x54,0x58,0x5c,0x60,0x64]
STRIDE = [0x10,0x10,0x14,0x10,0x28,0x18,0x50,0x28]
O_CNT1, O_CNT2, O_CNT3 = 0x20, 0x28, 0x40

def u(d,o): return struct.unpack_from('<I',d,o)[0]

def xmlfiles():
    for dp,_,fns in os.walk(ROOT):
        for fn in fns:
            if fn.lower().endswith('.xml'):
                yield os.path.join(dp,fn)

n_xml = n_arm = 0
nonmagic = collections.Counter()
bad = collections.Counter()
diag = collections.Counter()
slot5 = collections.Counter(); slot6 = collections.Counter()
blend = collections.Counter(); disp = collections.Counter()
tot = collections.Counter()
samples = []

for path in xmlfiles():
    d = open(path,'rb').read()
    n_xml += 1
    if len(d) < 0x68 or d[:6] != b'sngXml':
        nonmagic[os.path.basename(path)] += 1; continue
    t = [u(d,o) for o in IDX]
    if any(t[i] > t[i+1] for i in range(8)) or t[8] > len(d) or t[0] < 0x68:
        bad['muc luc khong tang'] += 1; continue
    n_arm += 1
    c1, c2, c3 = u(d,O_CNT1), u(d,O_CNT2), u(d,O_CNT3)
    size = lambda i: t[i+1]-t[i] if i < 8 else len(d)-t[8]
    blob = t[8]
    def ref(o):
        if o+8 > len(d): return None
        so, sl = u(d,o), u(d,o+4)
        if sl == 0: return ''
        if blob+so+sl > len(d): return None
        return d[blob+so:blob+so+sl].decode('utf-8','replace')

    # ---- vi sao arr1 lech? in thu vai ca
    if size(0) % 0x10 or size(0)//0x10 != c1:
        diag['arr1 lech'] += 1
        if len(samples) < 5:
            samples.append((os.path.basename(path), c1, size(0), size(0)//0x10, size(0)%0x10))

    # ---- arr1 -> xuong -> t2
    mx = 0
    for i in range(c1):
        r = t[0] + i*0x10
        if r+0x10 > len(d) or ref(r) is None: bad['arr1 ten'] += 1; continue
        sb, sn = u(d,r+8), u(d,r+0xc)
        for k in range(sn):
            b = t[1] + sb + k*0x10
            if b+0x10 > len(d) or ref(b) is None: bad['xuong ten'] += 1; continue
            ab, an = u(d,b+8), u(d,b+0xc)
            for j in range(an):
                a = t[2] + ab + j*0x14
                if a+0x14 > len(d): bad['t2 tran'] += 1; break
                if ref(a) is None: bad['t2 ten'] += 1
            if ab + an*0x14 > size(2): bad['xuong->t2 qua vung'] += 1
            if ab + an*0x14 > mx: mx = ab + an*0x14
        if sb + sn*0x10 > size(1): bad['arr1->xuong qua vung'] += 1
        if sb + sn*0x10 > mx2 if False else False: pass
    if mx == size(2): tot['xuong->t2 chat'] += 1
    elif mx: bad['xuong->t2 khong chat'] += 1

    # ---- arr2 -> lop -> t5 -> t6
    mxA = mxL = 0
    for i in range(c2):
        r = t[3] + i*0x10
        if r+0x10 > len(d) or ref(r) is None: bad['arr2 ten'] += 1; continue
        sb, sn = u(d,r+8), u(d,r+0xc)
        for k in range(sn):
            L = t[4] + sb + k*0x28
            if L+0x28 > len(d) or ref(L) is None: bad['lop ten'] += 1; continue
            to_, tc_ = u(d,L+0x20), u(d,L+0x24)
            for s in range(8, 0x20, 4):
                o_, c_ = u(d,L+s), u(d,L+s+4)
                if o_ + c_*0x18 <= size(5) and c_ and o_: slot5[s] += 1
            slot5[0x20 if to_ + tc_*0x18 <= size(5) else -1] += 1
            if to_ + tc_*0x18 > size(5): bad['lop->t5 qua vung'] += 1
            if to_ + tc_*0x18 > mxL: mxL = to_ + tc_*0x18
            for m in range(tc_):
                K = t[5] + to_ + m*0x18
                if K+0x18 > len(d): bad['t5 tran'] += 1; break
                if ref(K) is None: bad['t5 ten'] += 1; continue
                foff = u(d,K+0x10); fcnt = u(d,K+0x14)
                for s in range(8, 0x10, 4):
                    o_, c_ = u(d,K+s), u(d,K+s+4)
                    if c_ and o_ + c_*0x50 <= size(6): slot6[s] += 1
                slot6[0x10 if foff + fcnt*0x50 <= size(6) else -1] += 1
                if foff + fcnt*0x50 > size(6): bad['t5->t6 qua vung'] += 1; continue
                for q in range(fcnt):
                    F = t[6] + foff + q*0x50
                    if F+0x50 > len(d): bad['t6 tran'] += 1; break
                    bt = ref(F+0x38)
                    if bt is None: bad['t6 blend'] += 1
                    else: blend[bt or '(rong)'] += 1
                    dp_ = ref(F+0x30)
                    if dp_ is None: bad['t6 display'] += 1
                    else: disp[dp_ or '(rong)'] += 1
                tot['keyframe'] += fcnt
            tot['t5'] += tc_
        tot['lop'] += sn
        if sb + sn*0x28 > size(4): bad['arr2->lop qua vung'] += 1
        if sb + sn*0x28 > mxA: mxA = sb + sn*0x28
    if mxL == size(5): tot['lop->t5 chat'] += 1
    elif mxL: bad['lop->t5 khong chat'] += 1
    if mxA == size(4): tot['arr2->lop chat'] += 1
    elif mxA: bad['arr2->lop khong chat'] += 1

    # ---- arr3 phai la frame co that trong .plist cung tep
    for i in range(c3):
        r = t[7] + i*0x28
        if r+0x28 > len(d): bad['arr3 tran'] += 1; break
        if ref(r) is None: bad['arr3 ten'] += 1
    tot['nhom'] += c1; tot['hoat anh'] += c2; tot['hien thi'] += c3

print('tep .xml                 :', n_xml)
print('  kieu armature          :', n_arm)
print('  khong co magic sngXml  :', sum(nonmagic.values()))
for k,v in nonmagic.most_common(8): print('      ', k)
print()
print('TONG  nhom xuong         :', tot['nhom'])
print('      hoat anh           :', tot['hoat anh'])
print('      lop                :', tot['lop'])
print('      duong xuong        :', tot['t5'])
print('      keyframe           :', tot['keyframe'])
print('      hien thi           :', tot['hien thi'])
print()
print('vung DUNG CHAT (max do-troi == kich thuoc vung):')
for k in ('xuong->t2 chat','arr2->lop chat','lop->t5 chat'):
    print('   %-20s %d/%d' % (k, tot[k], n_arm))
print()
print('slot cua LOP co tro vao t5 (nam trong vung):')
for s in sorted(slot5): print('   +0x%02x  %d' % (s, slot5[s]))
print('slot cua t5 co tro vao t6 (nam trong vung):')
for s in sorted(slot6): print('   +0x%02x  %d' % (s, slot6[s]))
print()
print('kieu tron   :', dict(blend.most_common(5)))
print('ten hien thi:', dict(disp.most_common(5)))
print()
print('arr1 lech   :', diag['arr1 lech'])
for s in samples: print('   %-28s c1=%-4d vung=%-6d /0x10=%-4d du=%d' % s)
print()
print('LOI:', dict(bad) or 'khong co')
