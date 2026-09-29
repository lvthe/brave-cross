# Phep kiem DOC LAP cho mo hinh .xml: dung lai ca cay bang cach XEP TUAN TU
# (cong don so luong, khong doc mot con tro byte nao) roi doi chieu voi duong
# doc DIA CHI TUYET DOI ma ban C++ dung.
#
# Hai duong nay khac han nhau ve nguyen ly:
#   - duong tuyet doi: moi ban ghi ghi ro {do-troi byte, so-luong} cua con no
#   - duong xep:       cac con nam lien nhau, con thu i bat dau ngay sau con
#                      thu i-1, va tong phai vua khit vung
#
# Neu hai duong cho cung ket qua tren ca 418 tep thi:
#   (a) con tro trong tep la THUA (co the bo qua, chi can so luong)
#   (b) khong vung nao ho, khong vung nao chong — moi byte deu thuoc ve mot
#       ban ghi nao do
# Va no cung la mot phep do THU BA, khong phai ban sao cua hai phep truoc.
import os, struct, collections

ROOT = r'C:\Project\game\brave-cross\work\vn\decrypted\assets'
IDX = [0x44,0x48,0x4c,0x50,0x54,0x58,0x5c,0x60,0x64]
BUOC = [0x10,0x10,0x14,0x10,0x28,0x18,0x50,0x28]
def u(d,o): return struct.unpack_from('<I',d,o)[0]

def xmlfiles():
    for dp,_,fns in os.walk(ROOT):
        for fn in fns:
            if fn.lower().endswith('.xml'): yield os.path.join(dp,fn)

lech = collections.Counter()
tot = collections.Counter()
n = 0

for p in xmlfiles():
    d=open(p,'rb').read()
    if len(d)<0x68 or d[:6]!=b'sngXml': continue
    t=[u(d,o) for o in IDX]
    if any(t[i]>t[i+1] for i in range(8)) or t[8]>len(d) or t[0]<0x68: continue
    n+=1
    size = lambda i: t[i+1]-t[i]
    c1,c2,c3 = u(d,0x20), u(d,0x28), u(d,0x40)

    # ---- arr1 -> xuong -> t2, xep tuan tu
    pb = pa = 0                      # con tro xep cua vung xuong / vung t2
    for i in range(c1):
        r = t[0]+i*0x10
        sb,sn = u(d,r+8), u(d,r+0xc)
        if sb != pb: lech['arr1->xuong'] += 1
        for k in range(sn):
            b = t[1]+pb+k*0x10
            ab,an = u(d,b+8), u(d,b+0xc)
            if ab != pa: lech['xuong->t2'] += 1
            pa += an*BUOC[2]; tot['diem gan'] += an
        pb += sn*BUOC[1]; tot['xuong'] += sn
        tot['nhom'] += 1
    if pb != size(1): lech['vung xuong khong khit'] += 1
    if pa != size(2): lech['vung t2 khong khit'] += 1

    # ---- arr2 -> lop -> t5 -> t6, xep tuan tu
    pl = pk = pf = 0
    for i in range(c2):
        r = t[3]+i*0x10
        sb,sn = u(d,r+8), u(d,r+0xc)
        if sb != pl: lech['arr2->lop'] += 1
        for k in range(sn):
            L = t[4]+pl+k*BUOC[4]
            to_,tc_ = u(d,L+0x20), u(d,L+0x24)
            if to_ != pk: lech['lop->t5'] += 1
            for m in range(tc_):
                K = t[5]+pk+m*BUOC[5]
                foff,fcnt = u(d,K+0x10), u(d,K+0x14)
                if foff != pf: lech['t5->t6'] += 1
                pf += fcnt*BUOC[6]; tot['keyframe'] += fcnt
            pk += tc_*BUOC[5]; tot['duong xuong'] += tc_
        pl += sn*BUOC[4]; tot['lop'] += sn
        tot['hoat anh'] += 1
    if pl != size(4): lech['vung lop khong khit'] += 1
    if pk != size(5): lech['vung t5 khong khit'] += 1
    if pf != size(6): lech['vung t6 khong khit'] += 1
    tot['hien thi'] += c3

print('tep kiem             :', n)
print()
print('TONG theo duong XEP TUAN TU:')
for k in ('nhom','xuong','diem gan','hoat anh','lop','duong xuong','keyframe','hien thi'):
    print('   %-13s %d' % (k, tot[k]))
print()
print('cho hai duong KHONG khop (con tro tuyet doi vs xep tuan tu):')
if lech:
    for k,v in lech.most_common(): print('   %-26s %d' % (k, v))
else:
    print('   khong co — hai duong trung khit hoan toan')
