"""Tim moi cho ma ARM PIC tham chieu toi mot dia chi, tren CA .text.

Ma PIC khong chua dia chi tuyet doi. No lam hai buoc:

    ldr rX, [pc, #imm]   ; nap DO LECH W tu literal pool
    add rX, pc           ; tai dia chi A: rX = W + A + 4

Nen voi moi tu 4 byte W trong .text ta suy nguoc: neu W tro toi `target` thi
lenh 'add rX, pc' phai nam o A = target - W - 4. Kiem A co phai dia chi ma
hop le va co dung la 'add rX, pc' khong. Khong phai dich ca 5,5 MB.
"""
import struct
import capstone
from armdis import TEXT

BASE, DATA = TEXT
_md = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)

# 'add rX, pc' dang Thumb 16 bit: 0100 0100 1 Rdn(3) 1111 -> 0x4479 kieu
# (rd=1) ... de chac chan thi cu dich thu.
def is_add_pc(addr):
    if not (BASE <= addr < BASE + len(DATA) - 2):
        return None
    for i in _md.disasm(DATA[addr - BASE:addr - BASE + 4], addr):
        if i.mnemonic == 'add' and i.op_str.endswith(', pc'):
            return i.op_str.split(',')[0]
        return None
    return None


def refs_to(target, max_gap=0x2000):
    """[(dia chi literal, dia chi add-pc, thanh ghi)]"""
    out = []
    n = len(DATA) // 4 * 4
    for off in range(0, n, 2):          # literal pool luon can 4, nhung quet 2 cho chac
        if off % 4:
            continue
        w = struct.unpack_from('<I', DATA, off)[0]
        a = (target - w - 4) & 0xffffffff
        if not (BASE <= a < BASE + len(DATA)):
            continue
        lit = BASE + off
        if abs(a - lit) > max_gap:
            continue
        reg = is_add_pc(a)
        if reg:
            out.append((lit, a, reg))
    return out
