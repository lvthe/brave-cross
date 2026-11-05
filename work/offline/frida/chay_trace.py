# -*- coding: utf-8 -*-
"""chay_trace.py — gan frida/trace_danh.js vao tien trinh dang chay va ghi ket qua ra tep.

Dung CLI frida khong co tren may nay (chi co frida-python), nen driver nay thay no:

    python -I chay_trace.py --attach                 # gan vao tien trinh dang chay
    python -I chay_trace.py --attach --giay 300       # tu thoat sau 300 giay
    python -I chay_trace.py --spawn                    # tat roi mo lai game (hook tu dau)

Ket qua: moi dong `send()` cua script in ra man hinh va ghi vao `trace_danh.out.jsonl`.
`console.log` cua script ghi vao cung tep voi tien to `[console]`.
"""
import argparse
import json
import os
import sys
import time

import frida

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, 'trace_danh.js')
OUT = os.path.join(HERE, 'trace_danh.out.jsonl')
PKG = 'com.cmn.buatanew'


def tep():
    return open(OUT, 'a', encoding='utf-8')


def on_message(message, data):
    f = tep()
    try:
        if message.get('type') == 'send':
            d = message.get('payload')
            f.write(json.dumps(d, ensure_ascii=False) + '\n')
            f.flush()
            print(json.dumps(d, ensure_ascii=False))
        elif message.get('type') == 'error':
            f.write('[error] ' + json.dumps(message, ensure_ascii=False) + '\n')
            f.flush()
            print('[error] ' + json.dumps(message, ensure_ascii=False))
        else:
            f.write('[msg] ' + json.dumps(message, ensure_ascii=False) + '\n')
            f.flush()
    finally:
        f.close()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--attach', action='store_true')
    ap.add_argument('--spawn', action='store_true')
    ap.add_argument('--giay', type=int, default=0, help='0 = chay toi khi Ctrl-C')
    ap.add_argument('--pid', type=int, default=0)
    ap.add_argument('--tep', default='', help='script Frida khac (mac dinh trace_danh.js)')
    a = ap.parse_args()

    dev = frida.get_device('emulator-5554', timeout=10)
    path = os.path.join(HERE, a.tep) if a.tep else SCRIPT
    src = open(path, encoding='utf-8').read()

    if a.spawn:
        pid = dev.spawn([PKG])
        print('[driver] spawn pid=%d' % pid)
        ses = dev.attach(pid)
        sc = ses.create_script(src)
        sc.on('message', on_message)
        sc.load()
        dev.resume(pid)
    elif a.pid:
        ses = dev.attach(a.pid)
        sc = ses.create_script(src)
        sc.on('message', on_message)
        sc.load()
    else:
        ses = dev.attach(PKG)
        sc = ses.create_script(src)
        sc.on('message', on_message)
        sc.load()

    # console.log cua script Frida khong tu ve day; on_message chi bat send()/error.
    print('[driver] da gan, dang ghi vao %s' % OUT)

    t0 = time.time()
    try:
        while True:
            time.sleep(1)
            if a.giay and (time.time() - t0) > a.giay:
                print('[driver] het gio, thoat')
                break
    except KeyboardInterrupt:
        print('[driver] Ctrl-C')
    finally:
        try:
            sc.unload()
        except Exception:
            pass
        ses.detach()


if __name__ == '__main__':
    sys.exit(main())
