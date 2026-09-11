"""Tim doan ma tham chieu toi mot chuoi, trong ma ARM PIC.

Ma PIC khong chua dia chi tuyet doi cua chuoi. No lam hai buoc:
    ldr rX, [pc, #imm]     ; nap DO LECH tu literal pool
    add rX, pc             ; cong vao pc -> ra dia chi that
Nen phai mo phong dung hai buoc do.
"""
import re
import struct
import capstone
from armdis import TEXT
from xref import load, cstr

_e, SECS = load()
_md = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
BASE, DATA = TEXT

_LDR = re.compile(r'^(\w+), \[pc, #(0x[0-9a-f]+|\d+)\]$')


def word(addr):
    for _n, a, d in SECS:
        if a <= addr < a + len(d):
            return struct.unpack_from('<I', d, addr - a)[0]
    return None


def dis_all(start, end):
    out, a = [], start
    while a < end:
        n = 0
        for i in _md.disasm(DATA[a - BASE:end - BASE], a):
            out.append(i)
            n += 1
            a = i.address + i.size
        if n == 0:
            a += 2
    return out


def string_refs(start, end):
    """[(dia chi lenh ldr, chuoi)] cho moi cap ldr-pc / add-pc trong doan."""
    insns = dis_all(start, end)
    by = {i.address: i for i in insns}
    out = []
    for i in insns:
        if not i.mnemonic.startswith('ldr'):
            continue
        m = _LDR.match(i.op_str)
        if not m:
            continue
        reg = m.group(1)
        imm = int(m.group(2), 16) if m.group(2).startswith('0x') else int(m.group(2))
        off = word(((i.address + 4) & ~3) + imm)
        if off is None:
            continue
        for k in (2, 4, 6, 8):
            n2 = by.get(i.address + k)
            if n2 is not None and n2.mnemonic == 'add' and n2.op_str == '%s, pc' % reg:
                s = cstr(SECS, (off + n2.address + 4) & 0xffffffff)
                if s and 1 <= len(s) < 120 and all(32 <= ord(c) < 127 for c in s):
                    out.append((i.address, s))
                break
    return out
