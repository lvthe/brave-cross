import os, struct
ROOT=r'C:\Project\game\brave-cross\work\vn\decrypted\assets'
IDX=[0x44,0x48,0x4c,0x50,0x54,0x58,0x5c,0x60,0x64]
def u(d,o): return struct.unpack_from('<I',d,o)[0]
bad={'arr1':0,'arr2':0,'arr3':0}; n=0; pl_passed=0; pl_n=0
for dp,_,fns in os.walk(ROOT):
  for fn in fns:
    if not fn.lower().endswith(('.xml','.plist')): continue
    p=os.path.join(dp,fn); d=open(p,'rb').read()
    if len(d)<0x68 or d[:6]!=b'sngXml': continue
    t=[u(d,o) for o in IDX]
    mono = all(t[i]<=t[i+1] for i in range(8)) and t[8]<=len(d) and t[0]>=0x68
    if fn.lower().endswith('.plist'):
      pl_n+=1
      if mono: pl_passed+=1
      continue
    if not mono: continue
    n+=1
    c1,c2,c3=u(d,0x20),u(d,0x28),u(d,0x40)
    if (t[1]-t[0])%0x10 or (t[1]-t[0])//0x10!=c1: bad['arr1']+=1
    if (t[4]-t[3])%0x10 or (t[4]-t[3])//0x10!=c2: bad['arr2']+=1
    if (t[8]-t[7])%0x28 or (t[8]-t[7])//0x28!=c3: bad["arr3"]+=1
print('tep .xml kieu armature :', n)
print('  kich thuoc vung / buoc == so dem  -> lech:', bad)
print()
print('tep .plist            :', pl_n)
print('  lot qua phep kiem "muc luc tang dan":', pl_passed)
