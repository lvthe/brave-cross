# Ban ghi keyframe co HAI co: 0x50 va 0x48 (chi o BingYing.xml va
# XSJiYouHeTiJi.xml). In thang byte cua ca hai loai de xem 8 byte bi thieu nam
# o dau — va cac string-ref nam o dau trong tung co.
#
# Cach quyet dinh: mot cap u32 la string-ref THAT neu (do-troi, do-dai) roi vao
# kho chuoi va chuoi ket qua la chuoi ten that ('normal', 'screen', '0'...).
import os, struct, collections

ROOT = r'C:\Project\game\brave-cross\work\vn\decrypted\assets'
IDX = [0x44,0x48,0x4c,0x50,0x54,0x58,0x5c,0x60,0x64]
def u(d,o): return struct.unpack_from('<I',d,o)[0]
def f(d,o): return struct.unpack_from('<f',d,o)[0]

def doc(p):
    d=open(p,'rb').read()
    t=[u(d,o) for o in IDX]
    blob=t[8]; c2=u(d,0x28); g=[]
    for i in range(c2):
        r=t[3]+i*0x10
        sb,sn=u(d,r+8),u(d,r+0xc)
        for k in range(sn):
            L=t[4]+sb+k*0x28
            to_,tc_=u(d,L+0x20),u(d,L+0x24)
            for m in range(tc_):
                K=t[5]+to_+m*0x18
                g.append((u(d,K+0x10), u(d,K+0x14)))
    g.sort()
    buoc=[]
    for j in range(len(g)-1):
        khe=g[j+1][0]-g[j][0]
        buoc.append(khe//g[j][1] if g[j][1] and khe%g[j][1]==0 else -1)
    return d,t,blob,g,buoc

def thu_ref(d,blob,base,slot,tong):
    """Cap (u32,u32) o base+slot co phai string-ref khong."""
    o,ln = u(d,base+slot), u(d,base+slot+4)
    if ln==0: return "rong"
    if blob+o+ln > len(d): return "ngoai kho"
    s=d[blob+o:blob+o+ln]
    try: s=s.decode('utf-8')
    except: return "khong phai utf8"
    return repr(s) if all(32<=ord(c)<127 for c in s) else "ky tu la"

def xem(ten, path):
    d,t,blob,g,buoc = doc(path)
    print('===', ten, '=== vung t6 =', t[7]-t[6], 'byte,', len(g), 'duong xuong')
    for co in (0x50,0x48):
        idx=[j for j,b in enumerate(buoc) if b==co]
        if not idx: continue
        j=idx[0]; off,cnt = g[j]
        print('\n  co 0x%02x  (khe thu %d, %d khung) — ban ghi dau o %d:'%(co,j,cnt,off))
        base=t[6]+off
        print('    float 0x00..0x2f :', ' '.join('%g'%f(d,base+4*s) for s in range(12)))
        for slot in (0x18,0x20,0x28,0x2c,0x30,0x34,0x38,0x3c):
            print('    +0x%02x u32=(%-10d,%-6d) doc ra: %s'%(slot,u(d,base+slot),u(d,base+slot+4),thu_ref(d,blob,base,slot,t[7]-t[6])))
    # doi chieu: co 0x50 o tep khac thi ref nam o dau
    print()

for ten in ('BingYing.xml','XSJiYouHeTiJi.xml','Archer.xml','Player000.xml'):
    for dp,_,fns in os.walk(ROOT):
        if ten in fns:
            xem(ten, os.path.join(dp,ten)); break
