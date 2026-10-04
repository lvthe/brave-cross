# Gia thuyet: KHONG phai 2 tep hong -- ma co HAI buoc ban ghi keyframe.
# Do tren ca 418 tep: du50 = co(t6) - tong(cnt)*0x50 ; du48 = co(t6) - tong(cnt)*0x48
# Dem xem bao nhieu tep khop CHINH XAC tung kieu, roi doi chieu voi cac truong header
# (0x0c, 0x10, 0x2c, 0x30) de tim truong CHON buoc.
import os, struct, collections
ROOT = r'C:\Project\game\brave-cross\work\vn\decrypted\assets'
IDX = [0x44,0x48,0x4c,0x50,0x54,0x58,0x5c,0x60,0x64]
def u(d,o): return struct.unpack_from('<I',d,o)[0]
def f(d,o): return struct.unpack_from('<f',d,o)[0]

def xmlfiles():
    for dp,_,fns in os.walk(ROOT):
        for fn in fns:
            if fn.lower().endswith('.xml'): yield os.path.join(dp,fn)

kq = collections.Counter(); hdr = collections.defaultdict(collections.Counter); te = []
n = 0
for p in xmlfiles():
    d = open(p,'rb').read()
    if len(d) < 0x68 or d[:6] != b'sngXml': continue
    t = [u(d,o) for o in IDX]
    if any(t[i] > t[i+1] for i in range(8)) or t[8] > len(d) or t[0] < 0x68: continue
    # bo qua *_config.xml: khong co bang muc luc 9 offset hop le (da lot qua kiem tra tren)
    c2 = u(d,0x28)
    g = []
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
    if not g: continue
    n += 1
    dai = t[7]-t[6]; tong = sum(c for _,c in g)
    du50 = dai - tong*0x50; du48 = dai - tong*0x48
    kieu = 'khop50' if du50 == 0 else ('khop48' if du48 == 0 else 'khac')
    kq[(kieu, du48 == 0, du50 == 0)] += 1
    cac = (u(d,0x0c), u(d,0x10), u(d,0x2c), u(d,0x30))
    hdr[kieu][cac] += 1
    if kieu != 'khop50' and len(te) < 12:
        te.append((os.path.basename(p), dai, tong, du50, du48, cac, len(g)))
    # do luon: chuoi offset co noi tiep voi buoc 0x48?
print('so tep xuong:', n)
print('phan loai:', kq.most_common())
print()
for k in ('khop50','khop48','khac'):
    print(k, '-> header (0x0c, 0x10, 0x2c, 0x30):', hdr[k].most_common(4))
print()
print('tep khong khop 0x50 (ten, co(t6), tong_khoa, du50, du48, header, so_duong):')
for x in te: print('   ', x)
