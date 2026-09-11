"""Bang tham chieu cheo cua libgame.so: moi dia chi PIC duoc mot doan ma tinh ra.

Dich ca .text mot lan (5,5 MB, ~30 giay) roi bat dung cap lenh:

    ldr rX, [pc, #imm]    ; W = literal
    ...                   ; vai lenh
    add rX, pc            ; tai A -> rX = W + A + 4

Chi nhan khi CUNG thanh ghi va 'add' nam trong vai lenh sau 'ldr'. Cach dan
mat hon (quet moi tu 4 byte roi suy nguoc) cho ra rat nhieu duong tinh gia:
trong 5,5 MB co vo so lenh 'add rX, pc' nen cai nao cung khop duoc mot target.

Ket qua nho vao picmap.pkl, lan sau nap lai ngay.
"""
import os
import pickle
import struct
import capstone
from armdis import TEXT

BASE, DATA = TEXT
CACHE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'picmap.pkl')
_md = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)


def _word(off):
    if 0 <= off <= len(DATA) - 4:
        return struct.unpack_from('<I', DATA, off)[0]
    return None


def build():
    """{dia chi duoc tro toi: [dia chi lenh add-pc]}"""
    out = {}
    pending = {}          # thanh ghi -> (W, dia chi ldr)
    a = BASE
    end = BASE + len(DATA)
    while a < end:
        n = 0
        for i in _md.disasm(DATA[a - BASE:], a):
            n += 1
            a = i.address + i.size
            op = i.op_str
            if i.mnemonic.startswith('ldr') and ', [pc, #' in op:
                reg, rest = op.split(',', 1)
                imm = rest.split('#')[1].rstrip(']')
                imm = int(imm, 16) if 'x' in imm else int(imm)
                w = _word((((i.address + 4) & ~3) + imm) - BASE)
                if w is not None:
                    pending[reg.strip()] = (w, i.address)
            elif i.mnemonic == 'add' and op.endswith(', pc'):
                reg = op.split(',')[0].strip()
                hit = pending.pop(reg, None)
                if hit is not None and i.address - hit[1] <= 24:
                    tgt = (hit[0] + i.address + 4) & 0xffffffff
                    out.setdefault(tgt, []).append(i.address)
            elif i.mnemonic in ('b', 'bl', 'blx', 'bx', 'pop', 'push'):
                pending.clear()
            if n > 400000:
                break
        if n == 0:
            a += 2
            pending.clear()
    return out


def load_map():
    if os.path.exists(CACHE):
        with open(CACHE, 'rb') as f:
            return pickle.load(f)
    m = build()
    with open(CACHE, 'wb') as f:
        pickle.dump(m, f)
    return m


if __name__ == '__main__':
    m = load_map()
    print('%d dia chi duoc tro toi tu ma PIC' % len(m))
