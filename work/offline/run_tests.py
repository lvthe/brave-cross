# -*- coding: utf-8 -*-
"""Chay bo test cua lop offline tren PC (khong can may Android).

Dung lupa (Lua nhung trong Python) lam thong dich vien, cong voi test/mock.lua
gia lap phan moi truong game ma lop offline cham toi.

    pip install lupa
    python run_tests.py
"""
import os, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))

# Lua 5.1: game chay LuaJIT. `lupa.LuaRuntime` tron lay ban moi nhat (5.5) —
# sai doi, va co may Windows chan han file lua55 ("Application Control").
try:
    import lupa.lua51 as lupa
except ImportError:
    try:
        import lupa
    except ImportError:
        sys.exit('thieu lupa: pip install lupa')


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    os.chdir(HERE)
    save_dir = tempfile.mkdtemp(prefix='offline_test_').replace('\\', '/') + '/'

    L = lupa.LuaRuntime(unpack_returned_tuples=True)
    L.execute('package.path = "./sc/?.lua;./?.lua;" .. package.path')
    L.globals().MOCK_DIR = save_dir
    try:
        L.execute('require("test.mock"); Mock.dir = MOCK_DIR; dofile("test/run.lua")')
    except lupa.LuaError as e:
        # run.lua ket thuc bang os.exit, lupa nem ra o day
        msg = str(e)
        if 'exit' not in msg.lower():
            print('LOI:', msg)
            return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
