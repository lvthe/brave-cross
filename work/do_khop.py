# Khop so khung: duong xep (644.623, gom CA 24 duong co 0x48) tru di tong so
# khung cua 24 duong do phai ra so cua C++ (644.556).
import os, struct
ROOT=r'C:\Project\game\brave-cross\work\vn\decrypted\assets'
IDX=[0x44,0x48,0x4c,0x50,0x54,0x58,0x5c,0x60,0x64]
def u(d,o): return struct.unpack_from('<I',d,o)[0]
tong=0; tong48=0; n48=0; tong50=0
for dp,_,fns in os.walk(ROOT):
  for fn in fns:
    if not fn.lower().endswith('.xml'): continue
    d=open(os.path.join(dp,fn),'rb').read()
    if len(d)<0x68 or d[:6]!=b'sngXml': continue
    t=[u(d,o) for o in IDX]
    if any(t[i]>t[i+1] for i in range(8)) or t[8]>len(d) or t[0]<0x68: continue
    c2=u(d,0x28); g=[]
    for i in range(c2):
      r=t[3]+i*0x10; sb,sn=u(d,r+8),u(d,r+0xc)
      for k in range(sn):
        L=t[4]+sb+k*0x28; to_,tc_=u(d,L+0x20),u(d,L+0x24)
        for m in range(tc_):
          K=t[5]+to_+m*0x18; g.append([u(d,K+0x10),u(d,K+0x14),None])
    g.sort(key=lambda x:x[0])
    for j in range(len(g)-1):
      khe=g[j+1][0]-g[j][0]
      if g[j][1] and khe%g[j][1]==0: g[j][2]=khe//g[j][1]
    j=len(g)-1; khe=(t[7]-t[6])-g[j][0]
    if g[j][1] and khe%g[j][1]==0: g[j][2]=khe//g[j][1]
    for off,cnt,b in g:
      tong+=cnt
      if b==0x48: tong48+=cnt; n48+=1
      elif b==0x50: tong50+=cnt
print('tong khung moi duong          :', tong)
print('  duong buoc 0x50             :', tong50)
print('  duong buoc 0x48 (%d duong)   : %d'%(n48,tong48))
print()
print('C++ bao 644556; xep bao', tong, '-> hieu', tong-644556)
print('hieu nay phai bang so khung cua 24 duong 0x48:', tong48, '->', 'KHOP' if tong48==tong-644556 else 'LECH')
