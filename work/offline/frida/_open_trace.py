# -*- coding: utf-8 -*-
"""_open_trace.py - spawn game + in ra cac file sc/ ma game mo."""
import json
import os
import sys
import time

import frida

HERE = os.path.dirname(os.path.abspath(__file__))
PKG = 'com.cmn.buatanew'
src = open(os.path.join(HERE, '_open_trace.js'), encoding='utf-8').read()

seen = []


def on_message(m, data):
    if m.get('type') == 'send':
        p = m['payload']
        if p.get('api') == 'info':
            print('   ', p['path'], flush=True)
            return
        line = '%s  %s' % (p['api'], p['path'])
        if line not in seen:
            seen.append(line)
            print(line, flush=True)
    else:
        print('MSG', json.dumps(m)[:300], flush=True)


d = frida.get_device('emulator-5554', timeout=10)
pid = d.spawn([PKG])
print('spawn', pid, flush=True)
ses = d.attach(pid)
sc = ses.create_script(src)
sc.on('message', on_message)
sc.load()
d.resume(pid)
time.sleep(int(sys.argv[1]) if len(sys.argv) > 1 else 25)
print('--- tong %d duong dan ---' % len(seen), flush=True)
sc.unload()
ses.detach()
