"""Tim cho ma tham chieu toi mot dia chi trong libgame.so.

ARM32 nhet hang so vao 'literal pool' ngay trong .text, nen chi can quet tim
tu 4 byte bang dia chi can tim la ra cho dung no.
"""
import struct
import sys
from elftools.elf.elffile import ELFFile

PATH = 'vn/apk/lib/armeabi-v7a/libgame.so'


def load(path=PATH):
    e = ELFFile(open(path, 'rb'))
    secs = []
    for s in e.iter_sections():
        if s.header.sh_type == 'SHT_PROGBITS' and s.header.sh_size:
            secs.append((s.name, s.header.sh_addr, s.data()))
    return e, secs


def find_word(secs, value, only=None):
    """Moi cho chua tu 4 byte == value."""
    need = struct.pack('<I', value)
    out = []
    for name, addr, data in secs:
        if only and name not in only:
            continue
        i = data.find(need)
        while i != -1:
            out.append((name, addr + i))
            i = data.find(need, i + 1)
    return out


def cstr(secs, addr):
    for name, a, d in secs:
        if a <= addr < a + len(d):
            off = addr - a
            end = d.find(b'\0', off)
            return d[off:end].decode('utf-8', 'replace')
    return None


def find_cstr(secs, text):
    """Dia chi cua moi chuoi C bang dung text."""
    need = text.encode() + b'\0'
    out = []
    for name, addr, data in secs:
        i = data.find(need)
        while i != -1:
            if i == 0 or data[i - 1] == 0:
                out.append(addr + i)
            i = data.find(need, i + 1)
    return out


if __name__ == '__main__':
    e, secs = load()
    for t in sys.argv[1:]:
        addrs = find_cstr(secs, t)
        print('chuoi %r -> %s' % (t, [hex(a) for a in addrs]))
        for a in addrs:
            refs = find_word(secs, a)
            print('   %d cho tro toi: %s' % (len(refs),
                  ', '.join('%s:0x%x' % r for r in refs[:8])))
