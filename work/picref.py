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
from xref import load
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


# `add rD, pc`: 0100 0100 D 1111 Rdn -> (v & 0xFF00) == 0x4400 va (v & 0x78) == 0x78
_M_ADD_PC = 0xFF00
_V_ADD_PC = 0x4400
_M_RM = 0x78
_V_RM = 0x78
# `ldr rT, [pc, #imm8*4]`: 0100 1 TTT imm8 -> (v & 0xF800) == 0x4800
_M_LDR_PC = 0xF800
_V_LDR_PC = 0x4800


def build(path=None):
    """Quet .text mot luot. Tra ve dict {dia chi dich: [dia chi cho nap]}."""
    _e, secs = load(path) if path else load()
    text = next(d for n, a, d in secs if n == '.text')
    base = next(a for n, a, d in secs if n == '.text')
    secmap = [(a, a + len(d), d) for n, a, d in secs]
    out = {}
    n = len(text)
    for i in range(0, n - 4, 2):
        add_v = struct.unpack_from('<H', text, i)[0]
        if (add_v & _M_ADD_PC) != _V_ADD_PC or (add_v & _M_RM) != _V_RM:
            continue
        rd = ((add_v >> 4) & 0x8) | (add_v & 0x7)
        pcval = base + i + 4
        # `ldr rD, [pc, #imm8*4]` nap chinh thanh ghi ay, trong vai lenh truoc.
        # KHONG ke lien nhau: o 0x2c933e `ldr r1` roi 0x2c9342 `mov` roi
        # 0x2c9344 `add r1, pc` — nen phai lui toi 8 lenh.
        for j in range(i - 2, max(-2, i - 18), -2):
            ldr_v = struct.unpack_from('<H', text, j)[0]
            if (ldr_v & _M_LDR_PC) != _V_LDR_PC:
                continue
            if ((ldr_v >> 8) & 0x7) != rd:   # Rt la bit 10..8, KHONG phai 2..0
                continue
            imm = (ldr_v & 0xFF) * 4
            pool = ((base + j + 4) & ~3) + imm
            w = _word(secmap, pool)
            if w is None:
                continue
            out.setdefault((w + pcval) & 0xFFFFFFFF, []).append(base + j)
            break
    return out


def _word(secmap, addr):
    for a, b, d in secmap:
        if a <= addr < b - 4:
            return struct.unpack_from('<I', d, addr - a)[0]
    return None


def refs(ix, addr):
    """Moi cho nap DUNG dia chi `addr`."""
    return sorted(ix.get(addr, []))


def chuoi(ix, addr):
    """Doc chuoi C tai `addr` (dung de doi chieu ket qua)."""
    _e, secs = load()
    for n, a, d in secs:
        if a <= addr < a + len(d):
            end = d.find(b'\0', addr - a)
            return d[addr - a:end].decode('utf-8', 'replace')
    return None


def tim(ten):
    """Tien loi: [(dia chi chuoi, [cho nap])] cho mot chuoi C theo TEN."""
    _e, secs = load()
    from xref import find_cstr
    ix = build()
    return [(a, refs(ix, a)) for a in find_cstr(secs, ten)]


if __name__ == '__main__':
    import sys
    from xref import find_cstr
    _e, secs = load()
    ix = build()
    print('%d dia chi duoc nap bang kieu PIC' % len(ix))
    for arg in sys.argv[1:]:
        # tham so la TEN chuoi thi tra theo ten, la so thi coi la dia chi
        for a in (find_cstr(secs, arg) or [int(arg, 0)]):
            r = refs(ix, a)
            print('%#x  %-24r -> %s'
                  % (a, chuoi(ix, a), ' '.join(hex(x) for x in r) or '(khong co)'))
