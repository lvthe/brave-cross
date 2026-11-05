# -*- coding: utf-8 -*-
"""_test_attach2.py <pid> - gan 1 script toi thieu de do xem attach co treo khong."""
import sys
import time

import frida

pid = int(sys.argv[1])
print('attach to', pid, flush=True)
t0 = time.time()
d = frida.get_device('emulator-5554', timeout=10)
ses = d.attach(pid)
print('attached in %.1fs' % (time.time() - t0), flush=True)
msgs = []
sc = ses.create_script("send('hello ' + Process.arch + ' ' + Process.pointerSize)")
sc.on('message', lambda m, data: msgs.append(m))
sc.load()
print('loaded in %.1fs' % (time.time() - t0), flush=True)
time.sleep(1)
print('msgs:', msgs, flush=True)
sc.unload()
ses.detach()
print('DONE', flush=True)
