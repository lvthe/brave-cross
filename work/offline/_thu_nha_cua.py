# -*- coding: utf-8 -*-
"""_thu_nha_cua.py — chạy THẬT một tệp Lua của lớp offline trong máy Lua trần
(lua51.dll của BraveCross) với API client GIẢ, để kiểm LUẬT mà không mở game và
KHÔNG đụng bản lưu trên máy.

    python _thu_nha_cua.py                      # mặc định: _thu_nha_cua.lua (NHÀ CỬA)
    python _thu_nha_cua.py _thu_mua_luot.lua    # bộ thử khác, cùng khung

Mã Lua nằm ở `_thu_nha_cua.lua` (đọc + thay `__SC__`), không nhúng vào Python —
nhúng thì mọi dấu `%` và `\\n` của Lua phải thoát, đã mắc một lượt.

KHÔNG thử ở đây (đã khai trong tệp mã): UI vẽ nhà, số dư của bản lưu thật, mở
khoá quân/thuốc/tướng khi hoàn thành ([MOI-6] cố ý bỏ), đường mạng.
"""
import ctypes
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SC = os.path.join(HERE, 'deploy', 'plain', 'sc')
LUA_FILE = os.path.join(HERE, sys.argv[1] if len(sys.argv) > 1 else '_thu_nha_cua.lua')
DLL = os.path.abspath(os.path.join(HERE, '..', '..', '..', 'bravecross-ax',
                                   'build', 'bin', 'BraveCross', 'lua51.dll'))


def main():
    if not os.path.exists(DLL):
        print('KHONG thay lua51.dll: %s' % DLL)
        return 1
    with open(LUA_FILE, encoding='utf-8') as f:
        src = f.read().replace('__SC__', SC.replace('\\', '/'))

    L = ctypes.CDLL(DLL)
    L.luaL_newstate.restype = ctypes.c_void_p
    L.luaL_openlibs.argtypes = [ctypes.c_void_p]
    L.luaL_loadstring.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
    L.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
    L.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
    L.lua_tolstring.restype = ctypes.c_char_p
    L.lua_close.argtypes = [ctypes.c_void_p]

    st = L.luaL_newstate()
    L.luaL_openlibs(st)
    if L.luaL_loadstring(st, src.encode('utf-8')) != 0:
        n = ctypes.c_size_t()
        print('LOI nap:', L.lua_tolstring(st, -1, ctypes.byref(n)).decode('utf-8', 'replace').encode('ascii','backslashreplace').decode('ascii'))
        return 1
    rc = L.lua_pcall(st, 0, 0, 0)
    if rc != 0:
        n = ctypes.c_size_t()
        print('LOI chay:', L.lua_tolstring(st, -1, ctypes.byref(n)).decode('utf-8', 'replace').encode('ascii','backslashreplace').decode('ascii'))
    L.lua_close(st)
    return rc


if __name__ == '__main__':
    sys.exit(main())
