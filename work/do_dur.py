# lop (movement, buoc 0x28): +0x08 / +0x0c / +0x10 la INT chu khong phai float
# (do_fps.py doc nham -> ra 0.0 het).  Do: ba so nguyen nay quan he gi voi SO
# KHUNG lon nhat cua lop?  Neu +0x08 == so khung => duration dem bang KHUNG,
# va truong frameRate (16/24/12) la he so doi sang giay.
# Tien the: ten nao chua '_seq' (co +0x81 cua CCTween)?
import os, struct, collections

ROOT = r'C:\Project\game\brave-cross\work\vn\decrypted\assets'
IDX = [0x44,0x48,0x4c,0x50,0x54,0x58,0x5c,0x60,0x64]
def u(d,o): return struct.unpack_from('<I',d,o)[0]

def xmlfiles():
    for dp,_,fns in os.walk(ROOT):
        for fn in fns:
            if fn.lower().endswith('.xml'): yield os.path.join(dp,fn)

def chuoi(d,blob,o,ln):
    if ln and blob+o+ln <= len(d):
        try: return d[blob+o:blob+o+ln].decode('utf-8')
        except: return None
    return None

c8=collections.Counter(); c0c=collections.Counter(); c10=collections.Counter()
t8=collections.Counter(); t0c=collections.Counter(); t10=collections.Counter()
seq=collections.Counter(); mau=[]; n=0
for p in xmlfiles():
    d=open(p,'rb').read()
    if len(d)<0x68 or d[:6]!=b'sngXml': continue
    t=[u(d,o) for o in IDX]
    if any(t[i]>t[i+1] for i in range(8)) or t[8]>len(d) or t[0]<0x68: continue
    blob=t[8]; c2=u(d,0x28)
    for i in range(c2):
        r=t[3]+i*0x10
        sb,sn=u(d,r+8),u(d,r+0xc)
        for k in range(sn):
            L=t[4]+sb+k*0x28
            d8,d0c,d10=u(d,L+8),u(d,L+0xc),u(d,L+0x10)
            nm=chuoi(d,blob,u(d,L+0),u(d,L+4))
            to_,tc_=u(d,L+0x20),u(d,L+0x24)
            mx=0; ten_con=[]
            for m in range(tc_):
                K=t[5]+to_+m*0x18
                mx=max(mx,u(d,K+0x14))
                ten_con.append(chuoi(d,blob,u(d,K+0),u(d,K+4)) or '')
            n+=1
            c8[d8]+=1; c0c[d0c]+=1; c10[d10]+=1
            if mx:
                t8[round(d8/mx,4)]+=1; t0c[round(d0c/mx,4)]+=1; t10[round(d10/mx,4)]+=1
            if len(mau)<8: mau.append((os.path.basename(p),k,nm,mx,d8,d0c,d10))
            for s in [nm]+ten_con:
                if s and '_seq' in s: seq[s]+=1

print('so lop:', n)
print('+0x08 (int):', c8.most_common(8))
print('+0x0c (int):', c0c.most_common(8))
print('+0x10 (int):', c10.most_common(8))
print()
print('+0x08 / maxKhung:', t8.most_common(8))
print('+0x0c / maxKhung:', t0c.most_common(8))
print('+0x10 / maxKhung:', t10.most_common(8))
print()
print('ten chua "_seq":', seq.most_common(6), 'tong', sum(seq.values()))
print('vai mau (tep, lop, ten, khung, d8, d0c, d10):')
for m in mau: print('   ', m)
