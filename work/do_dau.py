# Phan dau tep .xml (0x00..0x43) chua ai do. Trong cocostudio, nhip khung la
# truong frameRate o cap armature — va no KHONG nam trong bat ky ban ghi nao
# da giai (arr1 0x10 / xuong 0x10 / t2 0x14 / arr2 0x10 / lop 0x28 / t5 0x18 /
# t6 0x50 / arr3 0x28). Vay kha nang cao no o phan dau tep.
#
# In moi o u32 o 0x00..0x43 dang CA HAI kieu (int va float) de tim hang so
# 24/30/60 hoac 0.0416/0.0333/0.0166.
import os, struct, collections

ROOT = r'C:\Project\game\brave-cross\work\vn\decrypted\assets'
IDX = [0x44,0x48,0x4c,0x50,0x54,0x58,0x5c,0x60,0x64]
def u(d,o): return struct.unpack_from('<I',d,o)[0]
def f(d,o): return struct.unpack_from('<f',d,o)[0]

def xmlfiles():
    for dp,_,fns in os.walk(ROOT):
        for fn in fns:
            if fn.lower().endswith('.xml'): yield os.path.join(dp,fn)

o_int = collections.defaultdict(collections.Counter)
o_flt = collections.defaultdict(collections.Counter)
n = 0

for p in xmlfiles():
    d = open(p,'rb').read()
    if len(d) < 0x68 or d[:6] != b'sngXml': continue
    t = [u(d,o) for o in IDX]
    if any(t[i] > t[i+1] for i in range(8)) or t[8] > len(d) or t[0] < 0x68: continue
    n += 1
    for o in range(0x08, 0x44, 4):
        o_int[o][u(d,o)] += 1
        o_flt[o][round(f(d,o), 6)] += 1

print('so tep xuong:', n)
print()
for o in range(0x08, 0x44, 4):
    ci = o_int[o].most_common(3)
    cf = o_flt[o].most_common(3)
    print('+0x%02x  int: %-46s  float: %s' % (
        o,
        ', '.join('%d (%d tep)' % (v,c) for v,c in ci),
        ', '.join('%g (%d tep)' % (v,c) for v,c in cf)))
