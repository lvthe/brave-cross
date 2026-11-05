# -*- coding: utf-8 -*-
"""_test_attach.py - kiem tra frida co that su gan duoc vao tien trinh trong guest khong."""
import time

import frida

d = frida.get_device('emulator-5554', timeout=10)
print('device kind:', d.type)
apps = d.enumerate_applications()
print('apps:', len(apps))
procs = d.enumerate_processes()
print('procs:', len(procs))
tgt = [p for p in procs if p.name == 'com.android.systemui']
print('systemui:', [(p.pid, p.name) for p in tgt])
if tgt:
    ses = d.attach(tgt[0].pid)
    msgs = []
    sc = ses.create_script("send('hello from frida')")
    sc.on('message', lambda m, data: msgs.append(m))
    sc.load()
    time.sleep(1)
    print('msg:', msgs)
    sc.unload()
    ses.detach()
print('DONE')
