# -*- coding: utf-8 -*-
"""_test_bundle.py <pid> <script> - do xem load() bundle co treo khong."""
import json
import os
import sys
import time

import frida

pid = int(sys.argv[1])
tep = sys.argv[2]
src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), tep), encoding='utf-8').read()
t0 = time.time()
d = frida.get_device('emulator-5554', timeout=10)
ses = d.attach(pid)
print('attached %.1fs' % (time.time() - t0), flush=True)
msgs = []
sc = ses.create_script(src)
print('create_script %.1fs' % (time.time() - t0), flush=True)
sc.on('message', lambda m, data: (msgs.append(m), print('MSG', json.dumps(m)[:300], flush=True)))
sc.load()
print('loaded %.1fs, msgs=%d' % (time.time() - t0, len(msgs)), flush=True)
time.sleep(3)
print('sau 3s: msgs=%d' % len(msgs), flush=True)
for m in msgs:
    print('  ', json.dumps(m, ensure_ascii=False)[:300], flush=True)
sc.unload()
ses.detach()
print('DONE', flush=True)
