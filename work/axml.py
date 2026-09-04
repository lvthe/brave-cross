# -*- coding: utf-8 -*-
"""Bo giai ma AndroidManifest.xml (Android binary XML) thuan Python."""
import struct, sys

RES_STRING_POOL = 0x0001
RES_XML_START_NS = 0x0100
RES_XML_END_NS = 0x0101
RES_XML_START_ELEM = 0x0102
RES_XML_END_ELEM = 0x0103
RES_XML_CDATA = 0x0104
RES_XML_RESOURCE_MAP = 0x0180


def read_string_pool(buf, off):
    _, hdr_size, size = struct.unpack_from('<HHI', buf, off)
    n_str, n_style, flags, str_start, style_start = struct.unpack_from('<5I', buf, off + 8)
    utf8 = bool(flags & (1 << 8))
    offsets = struct.unpack_from('<%dI' % n_str, buf, off + hdr_size)
    base = off + str_start
    out = []
    for o in offsets:
        p = base + o
        if utf8:
            n = buf[p]
            p += 2 if n & 0x80 else 1          # bo qua do dai ky tu
            n = buf[p]
            if n & 0x80:
                n = ((n & 0x7F) << 8) | buf[p + 1]; p += 2
            else:
                p += 1
            out.append(buf[p:p + n].decode('utf-8', 'replace'))
        else:
            n = struct.unpack_from('<H', buf, p)[0]; p += 2
            if n & 0x8000:
                n = ((n & 0x7FFF) << 16) | struct.unpack_from('<H', buf, p)[0]; p += 2
            out.append(buf[p:p + n * 2].decode('utf-16-le', 'replace'))
    return out, off + size


def fmt_value(vtype, data, strings):
    if vtype == 0x03: return strings[data] if data < len(strings) else '@str/%d' % data
    if vtype == 0x10: return str(struct.unpack('<i', struct.pack('<I', data))[0])
    if vtype == 0x12: return 'true' if data else 'false'
    if vtype == 0x04: return str(struct.unpack('<f', struct.pack('<I', data))[0])
    if vtype == 0x01: return '@%08X' % data
    if vtype == 0x02: return '?%08X' % data
    if vtype in (0x1C, 0x1D): return '#%08X' % data
    if vtype == 0x11: return '0x%08X' % data
    return '0x%08X' % data


def decode(path):
    buf = open(path, 'rb').read()
    magic, hdr, total = struct.unpack_from('<HHI', buf, 0)
    strings, off = [], 8
    lines, indent, ns = [], 0, {}
    while off < min(total, len(buf)):
        ctype, hdr_size, size = struct.unpack_from('<HHI', buf, off)
        if size == 0: break
        if ctype == RES_STRING_POOL:
            strings, _ = read_string_pool(buf, off)
        elif ctype == RES_XML_START_NS:
            pfx, uri = struct.unpack_from('<II', buf, off + hdr_size)
            ns[strings[uri]] = strings[pfx]
        elif ctype == RES_XML_START_ELEM:
            nsi, namei = struct.unpack_from('<iI', buf, off + hdr_size)
            a_start, a_size, a_count = struct.unpack_from('<HHH', buf, off + hdr_size + 8)
            name = strings[namei]
            attrs = []
            for i in range(a_count):
                p = off + hdr_size + a_start - 20 + 20 + i * a_size
                a_ns, a_name, a_raw = struct.unpack_from('<iii', buf, p)
                v_type = buf[p + 15]
                v_data = struct.unpack_from('<I', buf, p + 16)[0]
                key = strings[a_name]
                if a_ns >= 0:
                    key = '%s:%s' % (ns.get(strings[a_ns], 'ns'), key)
                val = strings[a_raw] if a_raw >= 0 else fmt_value(v_type, v_data, strings)
                attrs.append('%s="%s"' % (key, val.replace('&', '&amp;').replace('"', '&quot;')))
            pad = '    ' * indent
            if attrs:
                lines.append('%s<%s' % (pad, name))
                for a in attrs:
                    lines.append('%s    %s' % (pad, a))
                lines.append('%s>' % pad)
            else:
                lines.append('%s<%s>' % (pad, name))
            indent += 1
        elif ctype == RES_XML_END_ELEM:
            indent -= 1
            nsi, namei = struct.unpack_from('<iI', buf, off + hdr_size)
            lines.append('%s</%s>' % ('    ' * indent, strings[namei]))
        off += size
    return '<?xml version="1.0" encoding="utf-8"?>\n' + '\n'.join(lines)


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    print(decode(sys.argv[1]))
