# -*- coding: utf-8 -*-
"""Sinh dac ta API server (Markdown + JSON) tu ket qua cua extract_api.py."""
import os, re, sys, json, glob, argparse, collections
import extract_api as ex

OUT = 'server-spec'
ASSETS = 'decrypted/assets'
GAME = ''


def detect_game(assets):
    """Ten goi + phien ban, lay tu AndroidManifest da giai o thu muc cha."""
    d = os.path.abspath(assets)
    for _ in range(4):
        d = os.path.dirname(d)
        f = os.path.join(d, 'AndroidManifest.xml')
        if not os.path.exists(f):
            continue
        t = open(f, encoding='utf-8', errors='replace').read(4000)
        pkg = re.search(r'package="([^"]+)"', t)
        if pkg:
            ver = re.search(r'android:versionName="([^"]+)"', t)
            return ('%s %s' % (pkg.group(1), ver.group(1) if ver else '')).strip()
    return os.path.basename(os.path.dirname(os.path.abspath(assets)))


# ------------------------------------------------------------ bang tra cuu
def parse_server_enum():
    txt = ex.read(os.path.join(ASSETS, 'sc/share/Protocol.lua'))
    m = re.search(r'SERVER\s*=\s*\{(.*?)\n\}', txt, re.S)
    out = {}
    if m:
        for name, val in re.findall(r'(\w+)\s*=\s*(\d+)', m.group(1)):
            out[name] = int(val)
    return out


def brace_block(txt, open_pos):
    """Noi dung tu '{' tai open_pos toi '}' cap doi tuong ung."""
    depth = 0
    for i in range(open_pos, len(txt)):
        if txt[i] == '{':
            depth += 1
        elif txt[i] == '}':
            depth -= 1
            if depth == 0:
                return txt[open_pos + 1:i]
    return ''


def parse_error_codes():
    txt = ex.strip_comments(ex.read(os.path.join(ASSETS, 'sc/share/error.lua')))
    groups = collections.OrderedDict()
    # dang 1: ErrorCode.Group = { Name = n, ... }   (dem ngoac, khong dung regex .*?)
    for m in re.finditer(r'ErrorCode\.(\w+)\s*=\s*\{', txt):
        body = brace_block(txt, m.end() - 1)
        for name, val in re.findall(r'(\w+)\s*=\s*(-?\d+)', body):
            groups.setdefault(m.group(1), {})[name] = int(val)
    # dang 2: ErrorCode.Group.Name = n
    for grp, name, val in re.findall(r'ErrorCode\.(\w+)\.(\w+)\s*=\s*(-?\d+)', txt):
        groups.setdefault(grp, {})[name] = int(val)
    # dang 3: ErrorCode.Name = n   (ma o goc)
    for name, val in re.findall(r'ErrorCode\.(\w+)\s*=\s*(-?\d+)\s*$', txt, re.M):
        groups.setdefault('(gốc)', {})[name] = int(val)
    return groups


def index_handlers():
    """Moi ham ten On<X>: ca ham toan cuc lan phuong thuc Obj:On<X>."""
    idx = collections.defaultdict(list)
    for path in ex.lua_files():
        text = ex.read(path)
        lines = ex.strip_comments(text).split('\n')
        rel = os.path.relpath(path, ASSETS).replace('\\', '/')
        for i, full, params, doc in ex.index_functions(lines, text.split('\n')):
            short = re.split(r'[:.]', full)[-1]
            if not re.fullmatch(r'On[A-Z]\w*', short):
                continue
            owner = full[:-(len(short) + 1)] if full != short else ''
            first = params.split(',')[0].strip()
            fields = []
            if first and re.fullmatch(r'[A-Za-z_]\w*', first):
                body = '\n'.join(lines[i:i + 150])
                fields = sorted(set(re.findall(r'\b%s\.(\w+)' % re.escape(first), body)))
            idx[short].append({'obj': owner, 'params': params, 'doc': doc,
                               'fields': fields, 'src': '%s:%d' % (rel, i + 1)})
    return idx


def candidates(r):
    """Ten handler co the co, suy ra tu ten ham server.

    Voi API sinh qua bindRpcToEvent ta biet chac ten ham nhan: chinh la
    rspFormat % eventName. Nhung ham do cung do runtime sinh ra nen thuong
    khong co dinh nghia trong ma nguon — nguoi tieu thu that su la listener
    On<eventName> dang ky qua EventManager, nen thu ca hai.
    """
    func_name = r['funcName']
    out = [x for x in (r.get('handlerHint'),
                       'On' + r['eventName'] if r.get('eventName') else None) if x]
    base = func_name
    for pfx in ('Client', 'Req', 'Request'):
        if base.startswith(pfx) and len(base) > len(pfx):
            base = base[len(pfx):]
            break
    out += ['On' + base, 'On' + func_name]
    if func_name.startswith('On'):
        out.insert(0, func_name)
    return list(dict.fromkeys(out))


# ------------------------------------------------------------ gom du lieu
def dedupe(requests):
    """Gop cac call site cung funcName, giu ban co nhieu thong tin nhat."""
    by = collections.OrderedDict()
    for r in requests:
        k = (r['module'], r['funcName'])
        cur = by.get(k)
        score = (len(r['args']), len(r['doc']))
        if cur is None or score > cur['_score']:
            r = dict(r)
            r['_score'] = score
            r['sites'] = (cur['sites'] if cur else [])
            by[k] = r
        else:
            cur['sites'].append(r['src'])
            # ban thua diem van co the la ban duy nhat biet ten handler
            for key in ('bound', 'eventName', 'eventTable', 'handlerHint'):
                if r.get(key) and not cur.get(key):
                    cur[key] = r[key]
        by[k]['sites'] = sorted(set(by[k]['sites'] + [r['src']]))
    return list(by.values())


def feature_of(src):
    """Suy ra nhom chuc nang tu duong dan file goi."""
    p = src.split(':')[0].replace('sc/', '')
    parts = p.split('/')
    return parts[-1].replace('.lua', '')


def arg_sig(args):
    if not args:
        return '()'
    out = []
    for a in args:
        name = re.split(r'[.:\[(]', ex.leaf(a['expr']))[0]
        if not re.fullmatch(r'[A-Za-z_]\w*', name):
            name = a['expr'].strip()
        out.append('%s: %s' % (name, a['type']))
    return '(' + ', '.join(out) + ')'


def esc(s):
    return (s or '').replace('|', '\\|').replace('\n', ' ').strip()


# ------------------------------------------------------------ xuat Markdown
def build():
    requests, responses, dynamic = ex.collect()
    reqs = dedupe(requests)
    servers = parse_server_enum()
    errors = parse_error_codes()
    handlers = index_handlers()

    matched = 0
    for r in reqs:
        r['handler'] = None
        for c in candidates(r):
            if c in handlers:
                r['handler'] = {'name': c, 'defs': handlers[c]}
                matched += 1
                break

    by_module = collections.OrderedDict()
    for r in sorted(reqs, key=lambda x: (x['module'], feature_of(x['src']), x['funcName'])):
        by_module.setdefault(r['module'], []).append(r)

    L = []
    A = L.append
    A('# Đặc tả API server — Búa Tạ (`%s`)' % GAME)
    A('')
    A('Trích tự động từ %d file Lua client đã giải mã. Mọi số liệu dưới đây đến từ '
      'chính mã nguồn, không suy đoán.' % len(ex.lua_files()))
    A('')
    A('| | |')
    A('|---|---|')
    nbound = len([r for r in reqs if r.get('bound')])
    A('| Hàm server được client gọi | **%d** (%d chỗ gọi) |' % (len(reqs), len(requests)))
    A('| — khai báo trực tiếp `CallServer("Tên", …)` | %d |' % (len(reqs) - nbound))
    A('| — sinh lúc chạy qua `bindRpcToEvent` ⟳ | %d |' % nbound)
    A('| Trong đó dò được handler trả về | %d |' % matched)
    A('| Callback được API ở §3 dùng tới | %d |' % len(set(
        r['handler']['name'] for r in reqs if r['handler'])))
    A('| Tổng hàm `On*` có trong client | %d |' % len(handlers))
    A('| Tên hàm dựng động (phải đọc tay) | %d |' % len(dynamic))
    A('')

    # -------- giao thuc
    A('## 1. Giao thức')
    A('')
    A('Vận chuyển: TCP, envelope **protobuf**, payload **JSON thuần** (`cjson`). '
      'Định nghĩa gốc ở `conf/kGameRequestData.proto`.')
    A('')
    A('```protobuf')
    A('message GameActionData {')
    A('  optional int32  module   = 1;  // nhóm server, xem bảng §2')
    A('  optional string funcName = 2;  // TÊN HÀM server sẽ gọi')
    A('  optional int64  uid      = 3;')
    A('  optional string sessionId= 4;')
    A('  optional string data     = 5;  // mảng JSON chứa tham số')
    A('  optional uint32 connId   = 6;')
    A('  optional uint64 IP       = 7;')
    A('  optional string objName  = 8;  // đối tượng chứa hàm ("" = hàm toàn cục)')
    A('  optional uint64 serialID = 9;  // id giao dịch, dùng để khớp req/resp')
    A('  optional uint32 serverID = 10;')
    A('}')
    A('```')
    A('')
    A('**Mô hình bất đồng bộ.** Client gọi xong không chờ kết quả. Server xử lý rồi '
      '*chủ động phát một RPC ngược lại* để trả kết quả — xem `sc/system/rpc.lua:5-8`.')
    A('')
    A('Định tuyến hai chiều đều theo tên:')
    A('')
    A('```lua')
    A('-- client -> server (rpc.lua:155)')
    A('CallServer(nModule, strObjName, strFunction, ...)')
    A('  --> data = cjson.encode({...})            -- mảng JSON các tham số')
    A('')
    A('-- server -> client (rpc.lua:39, 84)')
    A('CallLocal(szObjName, szFunName, szData)')
    A('  --> obj = _G[szObjName];  func = obj and obj[szFunName] or _G[szFunName]')
    A('  --> func(obj, unpack(cjson.decode(szData)))')
    A('```')
    A('')
    A('Server phải triển khai đúng tên hàm ở §3 và gọi ngược đúng tên handler ở §4. '
      'Payload trả về theo quy ước `{ err = <mã lỗi>, data = <nội dung> }` — '
      'mọi handler đều kiểm tra `tData.err ~= 0` trước tiên.')
    A('')

    # -------- module
    A('## 2. Các server con')
    A('')
    A('`SERVER` định nghĩa tại `sc/share/Protocol.lua`. Cột cuối là số API client thực sự gọi.')
    A('')
    A('| id | hằng số | số API dùng |')
    A('|---:|---|---:|')
    for name, val in sorted(servers.items(), key=lambda x: x[1]):
        if name == 'SERVER_MAX':
            continue
        n = len(by_module.get(name, []))
        A('| %d | `SERVER.%s` | %s |' % (val, name, n or '—'))
    A('')
    undefined = [m for m in by_module if m not in servers]
    if undefined:
        A('> **Lưu ý.** %s được client tham chiếu nhưng **không có trong enum `SERVER`** '
          '— tức là `nil` lúc chạy, nên `CallServer` rơi vào nhánh mặc định và đẩy qua '
          'game gateway. Đây là API cũ còn sót: %s.' % (
              ', '.join('`SERVER.%s`' % m for m in undefined),
              ', '.join('`%s`' % r['funcName'] for m in undefined for r in by_module[m])))
        A('')

    # -------- API
    A('## 3. API client → server')
    A('')
    A('Hàm đánh dấu **⟳** không có tên dưới dạng chuỗi ở bất kỳ đâu trong mã nguồn: '
      '`CUIAssist.bindRpcToEvent` sinh chúng lúc chạy bằng `string.format(reqFormat, eventName)` '
      'từ bảng sự kiện trong `sc/share/EventManager.lua` (xem `sc/user/UI/CUIAssist.lua:335`). '
      'Cột *Nguồn* của chúng trỏ tới chỗ `bindRpcToEvent`, còn tham số lấy từ nơi gọi thật.')
    A('')
    A('Chữ ký tham số suy ra từ quy ước Hungarian của chính codebase '
      '(`n`/`dw` = số, `sz`/`str` = chuỗi, `t` = bảng, `b` = boolean). '
      'Cột *Mô tả* là comment gốc (tiếng Trung) của hàm client bọc lời gọi.')
    A('')
    for mod, items in by_module.items():
        A('### 3.%d `SERVER.%s` — %d API' % (list(by_module).index(mod) + 1, mod, len(items)))
        A('')
        cur_feat = None
        for r in items:
            feat = feature_of(r['src'])
            if feat != cur_feat:
                cur_feat = feat
                A('')
                A('#### %s' % feat)
                A('')
                A('| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |')
                A('|---|---|---|---|---|')
            obj = ('`%s`.' % r['objName']) if r['objName'] else ''
            h = r['handler']['name'] if r['handler'] else '—'
            A('| %s**`%s`**%s | `%s` | `%s` | %s | `%s` |' % (
                obj, r['funcName'], ' ⟳' if r.get('bound') else '',
                esc(arg_sig(r['args'])), h, esc(r['doc'])[:90], r['src']))
        A('')

    # -------- handler
    A('## 4. Callback server → client')
    A('')
    A('Server gọi ngược các hàm này. Cột *Trường đọc* là các khoá client thực sự '
      'truy cập trên tham số — chính là hình dạng tối thiểu của payload trả về.')
    A('')
    A('| Handler | Đối tượng | Tham số | Trường đọc từ payload | Nguồn |')
    A('|---|---|---|---|---|')
    used = {r['handler']['name'] for r in reqs if r['handler']}
    for name in sorted(used):
        for d in handlers[name][:1]:
            A('| **`%s`** | %s | `%s` | %s | `%s` |' % (
                name, ('`%s`' % d['obj']) if d['obj'] else '*(toàn cục)*',
                esc(d['params']) or '—',
                ', '.join('`%s`' % f for f in d['fields'][:12]) or '—', d['src']))
    A('')

    # -------- loi
    A('## 5. Mã lỗi (`sc/share/error.lua`)')
    A('')
    A('Trường `err` của mọi payload trả về.')
    A('')
    for grp, codes in errors.items():
        if not codes:
            continue
        A('<details><summary><code>ErrorCode.%s</code> — %d mã</summary>' % (grp, len(codes)))
        A('')
        A('| mã | tên |')
        A('|---:|---|')
        for name, val in sorted(codes.items(), key=lambda x: x[1]):
            A('| %d | `%s` |' % (val, name))
        A('')
        A('</details>')
        A('')

    # -------- dynamic
    if dynamic:
        A('## 6. Lời gọi có tên hàm dựng động')
        A('')
        A('Những chỗ này `funcName` là biến, phải đọc tay để biết tập tên đầy đủ.')
        A('')
        A('| Biểu thức | Module | Hàm client | Nguồn |')
        A('|---|---|---|---|')
        for d in dynamic:
            A('| `%s` | %s | `%s` | `%s` |' % (esc(d['funcName']), d['module'], d['caller'], d['src']))
        A('')

    # -------- luat dung chung
    A('## 7. Luật chơi dùng chung với server (`sc/share/`)')
    A('')
    A('%d file logic client và server dùng chung — đây là phần quy tắc nghiệp vụ '
      'server phải tái hiện. Cột *hằng số* đếm các hằng số cấu hình khai báo trong `ctor`.' %
      len(glob.glob(os.path.join(ASSETS, 'sc/share/**/*.lua'), recursive=True)))
    A('')
    A('| File | dòng | hằng số | mô tả đầu file |')
    A('|---|---:|---:|---|')
    for p in sorted(glob.glob(os.path.join(ASSETS, 'sc/share/**/*.lua'), recursive=True)):
        t = ex.read(p)
        lines = t.split('\n')
        consts = len(re.findall(r'self\.\w+\s*=\s*[-\d]', t))
        head = ''
        for ln in lines[:12]:
            s = ln.strip()
            if s.startswith('--') and len(s) > 3 and set(s) - set('-= '):
                head = s.lstrip('-').strip()
                break
        A('| `%s` | %d | %d | %s |' % (
            os.path.relpath(p, ASSETS).replace('\\', '/'), len(lines), consts, esc(head)[:70]))
    A('')

    os.makedirs(OUT, exist_ok=True)
    md = '\n'.join(L)
    open(os.path.join(OUT, 'SERVER_API.md'), 'w', encoding='utf-8').write(md)

    for r in reqs:
        r.pop('_score', None)
    json.dump({
        'game': GAME,
        'protocol': {'envelope': 'protobuf GameActionData', 'payload': 'JSON array (cjson)',
                     'async': True, 'response_shape': {'err': 'int', 'data': 'any'}},
        'servers': servers,
        'requests': reqs,
        'handlers': {k: v for k, v in handlers.items() if k in used},
        'errorCodes': errors,
        'dynamic': dynamic,
    }, open(os.path.join(OUT, 'server_api.json'), 'w', encoding='utf-8'),
        ensure_ascii=False, indent=1)

    # du lieu cho trang tra cuu: mot ban det, ten khoa ngan cho nhe file
    rows = []
    for r in sorted(reqs, key=lambda x: (x['module'], x['funcName'])):
        h = r['handler']
        d0 = h['defs'][0] if h and h['defs'] else None
        rows.append({
            'm': r['module'], 'f': r['funcName'], 'o': r['objName'],
            'a': [[re.split(r'[.:\[(]', ex.leaf(a['expr']))[0] or a['expr'].strip(), a['type']]
                  for a in r['args']],
            'h': h['name'] if h else '',
            'ho': d0['obj'] if d0 else '',
            'hs': d0['src'] if d0 else '',
            'hf': d0['fields'][:12] if d0 else [],
            'd': r['doc'], 's': r['src'], 'n': len(r['sites']) or 1,
            'b': 1 if r.get('bound') else 0,
        })
    json.dump({'game': GAME, 'lua': len(ex.lua_files()), 'rows': rows,
               'servers': servers, 'errors': errors, 'dynamic': dynamic},
              open(os.path.join(OUT, 'page_data.json'), 'w', encoding='utf-8'),
              ensure_ascii=False, separators=(',', ':'))

    print('SERVER_API.md : %d dong, %d KB' % (len(L), len(md.encode('utf-8')) // 1024))
    print('APIs %d (bound %d) | handler khop %d | callback %d | ma loi %d nhom'
          % (len(reqs), nbound, matched, len(used), len(errors)))


def main():
    global ASSETS, OUT, GAME
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--assets', default=ASSETS,
                    help='thu muc assets da giai ma (mac dinh: %(default)s)')
    ap.add_argument('--out', default=OUT, help='thu muc ket qua (mac dinh: %(default)s)')
    ap.add_argument('--game', default=None, help='ghi de ten/phien ban ghi trong dac ta')
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')
    ex.configure(a.assets)
    ASSETS, OUT = ex.ASSETS, a.out
    GAME = a.game or detect_game(ASSETS)
    print('assets    :', ASSETS, '->', OUT, '|', GAME)
    build()


if __name__ == '__main__':
    main()
