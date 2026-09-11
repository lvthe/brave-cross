"""Dich nguoc mot doan libgame.so (Thumb-2)."""
import capstone
from xref import load

_e, SECS = load()
TEXT = next((a, d) for n, a, d in SECS if n == '.text')

md = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
md.detail = True


def code(addr, n=0x200):
    base, data = TEXT
    off = addr - base
    return data[off:off + n]


def dis(addr, n=0x200):
    for i in md.disasm(code(addr, n), addr):
        yield i


def show(addr, n=0x200):
    for i in dis(addr, n):
        print('0x%06x  %-10s %s' % (i.address, i.mnemonic, i.op_str))
