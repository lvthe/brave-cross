# Doi dia chi Ghidra -> chuoi C trong .rodata.  Nhieu ten truong cocostudio
# ngan (<=3 ky tu) nen Ghidra dat ten DAT_ chu khong hien chuoi, va doc
# pseudocode chi thay "DAT_007b9dba" vo nghia.  Doc thang byte la ra ten.
import sys
from elftools.elf.elffile import ELFFile

PATH = r'C:\Project\game\decompiler\work\libgame.so'
f = open(PATH,'rb'); DATA = f.read(); ELF = ELFFile(f)
SEGS = [(s['p_vaddr'], s['p_filesz'], s['p_offset']) for s in ELF.iter_segments() if s['p_type']=='PT_LOAD']
IB = 0x10000   # Ghidra image base

def off(gh):
    va = gh - IB
    for a,sz,o in SEGS:
        if a <= va < a+sz: return o + va - a
    return None

def cstr(o, lim=64):
    e = o
    while e < len(DATA) and DATA[e] != 0 and e - o < lim: e += 1
    return DATA[o:e].decode('utf-8','replace')

addrs = [int(x,0) for x in sys.argv[1:]]
for gh in addrs:
    o = off(gh)
    if o is None: print('%#010x  NGOAI VUNG' % gh); continue
    print('%#010x  off %#08x  %r' % (gh, o, cstr(o)))

# Lien ke: in luon vung byte quanh dia chi dau tien de thay cac chuoi noi nhau
if addrs:
    o0 = off(addrs[0])
    if o0 is not None:
        print('\n--- dump %#x..%#x (moi chuoi cach nhau boi NUL) ---' % (o0-0x20, o0+0x100))
        blob = DATA[o0-0x20:o0+0x100]
        print(' '.join('%02x'%b for b in blob[:96]))
        print(repr(blob.decode('latin-1')))
