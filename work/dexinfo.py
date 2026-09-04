# -*- coding: utf-8 -*-
"""Doc classes.dex: dem method co / khong co bytecode.

Dung de phan biet mot dex that voi mot dex vo (stub cua packer):
packer thuong giu nguyen khai bao class/method nhung xoa than method
(code_off = 0), roi khoi phuc trong RAM luc chay.
"""
import struct, sys, collections


def uleb128(d, p):
    r = s = 0
    while True:
        b = d[p]; p += 1
        r |= (b & 0x7F) << s
        if not b & 0x80:
            return r, p
        s += 7


def analyse(path):
    d = open(path, 'rb').read()
    (file_size, header_size, endian, link_size, link_off, map_off,
     string_ids_size, string_ids_off, type_ids_size, type_ids_off,
     proto_ids_size, proto_ids_off, field_ids_size, field_ids_off,
     method_ids_size, method_ids_off, class_defs_size, class_defs_off,
     data_size, data_off) = struct.unpack_from('<20I', d, 32)

    # bang chuoi -> ten type, de biet class nao thuoc package nao
    def string_at(idx):
        off = struct.unpack_from('<I', d, string_ids_off + idx * 4)[0]
        n, p = uleb128(d, off)
        return d[p:p + n].decode('utf-8', 'replace')

    def type_name(idx):
        return string_at(struct.unpack_from('<I', d, type_ids_off + idx * 4)[0])

    stat = collections.Counter()
    pkg_empty = collections.Counter()
    pkg_total = collections.Counter()
    no_data = []

    for i in range(class_defs_size):
        cls_idx, access, superclass, interfaces, source, annots, class_data_off, statics = \
            struct.unpack_from('<8I', d, class_defs_off + i * 32)
        name = type_name(cls_idx)
        pkg = '/'.join(name.lstrip('L').rstrip(';').split('/')[:3])
        stat['classes'] += 1
        if class_data_off == 0:
            stat['classes_no_data'] += 1
            no_data.append(name)
            pkg_total[pkg] += 0
            continue

        p = class_data_off
        n_sf, p = uleb128(d, p)
        n_if, p = uleb128(d, p)
        n_dm, p = uleb128(d, p)
        n_vm, p = uleb128(d, p)
        for _ in range(n_sf):
            _, p = uleb128(d, p); _, p = uleb128(d, p)
        for _ in range(n_if):
            _, p = uleb128(d, p); _, p = uleb128(d, p)
        for _ in range(n_dm + n_vm):
            _, p = uleb128(d, p)          # method_idx_diff
            acc, p = uleb128(d, p)        # access_flags
            code_off, p = uleb128(d, p)
            abstract_or_native = acc & 0x0400 or acc & 0x0100
            stat['methods'] += 1
            pkg_total[pkg] += 1
            if code_off == 0:
                stat['methods_no_code'] += 1
                if not abstract_or_native:
                    stat['methods_stripped'] += 1   # dang le phai co than ma khong co
                    pkg_empty[pkg] += 1
            else:
                stat['methods_with_code'] += 1

    return {
        'path': path, 'size': len(d),
        'counts': dict(stat),
        'string_ids': string_ids_size, 'class_defs': class_defs_size,
        'method_ids': method_ids_size,
        'top_stripped_pkgs': pkg_empty.most_common(10),
        'classes_no_data_sample': no_data[:8],
        'sample_classes': [type_name(struct.unpack_from('<I', d, class_defs_off + i * 32)[0])
                           for i in range(0, min(class_defs_size, 60), 6)],
    }


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    for p in sys.argv[1:]:
        r = analyse(p)
        print('=' * 68)
        print(r['path'], '|', r['size'] // 1024, 'KB')
        c = r['counts']
        print('  classes           %6d  (khong co class_data: %d)' % (r['class_defs'], c.get('classes_no_data', 0)))
        print('  methods           %6d' % c.get('methods', 0))
        print('    co bytecode     %6d' % c.get('methods_with_code', 0))
        print('    khong bytecode  %6d  (trong do bi xoa than: %d)'
              % (c.get('methods_no_code', 0), c.get('methods_stripped', 0)))
        tot = c.get('methods', 1)
        print('  ty le bi xoa than %5.1f%%' % (100.0 * c.get('methods_stripped', 0) / tot))
        if r['top_stripped_pkgs']:
            print('  package bi xoa nhieu nhat:')
            for pkg, n in r['top_stripped_pkgs']:
                print('     %-42s %d' % (pkg, n))
        print('  mau ten class:', ', '.join(r['sample_classes'][:6]))
