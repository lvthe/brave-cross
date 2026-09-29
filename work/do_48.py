# Bo cuc 0x48 chua gi?  In 18 tu (72 byte) cua vai ban ghi, dang ca int lan float,
# va so voi 32 byte tu 0x28..0x47 cua ban ghi 0x50 (Archer.xml).
import os, struct
ROOT = r'C:\Project\game\brave-cross\work\vn\decrypted\assets'
IDX = [0x44,0x48,0x4c,0x50,0x54,0x58,0x5c,0x60,0x64]
def u(d,o): return struct.unpack_from('<I',d,o)[0]
def f(d,o): return struct.unpack_from('<f',d,o)[0]

def dau(p):
    d=open(p,'rb').read(); t=[u(d,o) for o in IDX]
    g=[]
    for i in range(u(d,0x28)):
        r=t[3]+i*0x10
        for k in range(u(d,r+0xc)):
            L=t[4]+u(d,r+8)+k*0x28
            for m in range(u(d,L+0x24)):
                K=t[5]+u(d,L+0x20)+m*0x18
                g.append((u(d,K+0x10),u(d,K+0x14)))
    return d,t,sorted(set(g))

for ten,buoc in (('BingYing.xml',0x48),('XSJiYouHeTiJi.xml',0x48),('Archer.xml',0x50)):
    p=os.path.join(ROOT,'map',ten)
    if not os.path.exists(p): print(ten,'khong thay'); continue
    d,t,g=dau(p)
    print('===',ten,' buoc',hex(buoc))
    for j,(off,cnt) in enumerate(g[:2]):
        for q in range(min(cnt,3)):
            F=t[6]+off+q*buoc
            w=[u(d,F+4*s) for s in range(18)]
            print('  duong%d khoa%d  int: %s' % (j,q,' '.join('%d'%x for x in w)))
            print('              flt: %s' % ' '.join('%g'%f(d,F+4*s) for s in range(18)))
    print()
