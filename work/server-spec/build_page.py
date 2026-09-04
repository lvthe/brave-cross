# -*- coding: utf-8 -*-
"""Nhung page_data.json vao page_template.html -> rpc-reference.html

  python build_page.py                # ban CN (ngay canh script)
  python build_page.py ../server-spec-vn
"""
import io, os, sys, json

HERE = os.path.dirname(os.path.abspath(__file__))
out_dir = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else HERE

tpl = io.open(os.path.join(HERE, 'page_template.html'), encoding='utf-8').read()
data = io.open(os.path.join(out_dir, 'page_data.json'), encoding='utf-8').read()
json.loads(data)                       # kiem tra JSON hop le truoc khi nhung
assert '__DATA__' in tpl, 'thieu cho danh dau __DATA__'
# '<\/' la escape hop le trong JSON, tranh </script> ket thuc the som
out = tpl.replace('__DATA__', data.replace('</', r'<\/'))
dst = os.path.join(out_dir, 'rpc-reference.html')
io.open(dst, 'w', encoding='utf-8').write(out)
print(os.path.relpath(dst), ':', len(out.encode('utf-8')) // 1024, 'KB')
