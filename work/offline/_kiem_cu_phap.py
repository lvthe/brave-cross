# -*- coding: utf-8 -*-
"""_kiem_cu_phap.py — kiểm CÚ PHÁP mọi tệp Lua của lớp offline bằng chính
`lua51.dll` của BraveCross (không chạy game, không cần máy).

    python _kiem_cu_phap.py

Vì sao cần thành tệp: 30/10 một ĐỊNH DANH CÓ DẤU (`tongNạp`) làm LuaJIT trên máy
báo `')' expected near char(225)` và **cả lớp offline chết ngay lúc nạp** — triệu
chứng duy nhất trên logcat là tiến trình thoát (`onSystemExit`), trông y như
"game tự đóng". Chạy lệnh này TRƯỚC khi push thì lỗi hiện ngay tại đây.
"""
import ctypes
import glob
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SC = os.path.join(HERE, 'deploy', 'plain', 'sc', 'offline')
DLL = os.path.abspath(os.path.join(HERE, '..', '..', '..', 'bravecross-ax',
                                   'build', 'bin', 'BraveCross', 'lua51.dll'))


def main():
    if not os.path.exists(DLL):
        print('KHONG thay lua51.dll: %s' % DLL)
        return 1
    L = ctypes.CDLL(DLL)
    L.luaL_newstate.restype = ctypes.c_void_p
    L.luaL_loadfile.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
    L.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
    L.lua_tolstring.restype = ctypes.c_char_p
    L.lua_close.argtypes = [ctypes.c_void_p]

    files = [os.path.join(SC, 'init.lua')] + sorted(glob.glob(os.path.join(SC, 'handlers', '*.lua')))
    files += sorted(glob.glob(os.path.join(SC, '*.lua')))
    files = sorted(set(os.path.abspath(p) for p in files))
    bad = 0
    for p in files:
        st = L.luaL_newstate()
        rc = L.luaL_loadfile(st, p.encode())
        if rc != 0:
            bad += 1
            n = ctypes.c_size_t()
            msg = L.lua_tolstring(st, -1, ctypes.byref(n)).decode('utf-8', 'replace')
            print('LOI %s\n    %s' % (os.path.relpath(p, SC), msg))
        L.lua_close(st)
    print('kiem %d tep, loi %d' % (len(files), bad))
    return 0 if bad == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
