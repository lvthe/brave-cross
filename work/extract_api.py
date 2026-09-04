# -*- coding: utf-8 -*-
"""Trich xuat dac ta API server tu ma nguon Lua client cua game.

Giao thuc (xem sc/system/rpc.lua):
  Client -> Server : CallServer(module, objName, funcName, ...)
                     args duoc cjson.encode thanh mang JSON, dat vao GameActionData.data
  Server -> Client : CallLocal(objName, funcName, data)
                     goi ham toan cuc On<Ten>(tData) cua client
Ca hai chieu deu bat dong bo: request khong tra ve truc tiep, server chu dong
goi nguoc mot RPC khac de tra ket qua.

Co HAI cach ma nguon phat sinh loi goi:
  1. CallServer(...) voi funcName la chuoi -> quet truc tiep duoc.
  2. CUIAssist.bindRpcToEvent(...) -> sinh ham luc chay tu bang su kien,
     ten ham KHONG xuat hien duoi dang chuoi o bat ky dau trong ma nguon.
     Xem resolve_bound() ben duoi; bo qua no la mat 96 API (CN) / 123 (VN).
"""
import os, re, sys, json, glob, argparse, collections

ROOT = 'decrypted/assets/sc'
ASSETS = 'decrypted/assets'
OUT = 'server-spec'


def configure(assets, out=None):
    """Tro bo quet sang mot ban giai ma khac (vi du ban VN)."""
    global ROOT, ASSETS, OUT
    ASSETS = assets.replace(os.sep, '/').rstrip('/')
    ROOT = ASSETS + '/sc'
    if out:
        OUT = out


def read(path):
    """Comment trong codebase tron ca UTF-8 lan GBK, tuy file."""
    raw = open(path, 'rb').read()
    for enc in ('utf-8', 'gbk', 'gb18030'):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            continue
    # 3 file tron encoding trong cung mot file: bo han byte hong,
    # tha mat vai ky tu comment con hon de U+FFFD lot vao dac ta
    return raw.decode('utf-8', 'replace').replace('�', '')


def lua_files():
    return sorted(glob.glob(os.path.join(ROOT, '**', '*.lua'), recursive=True))


def strip_comments(text):
    """Xoa comment Lua, giu nguyen vi tri ky tu va so dong.

    Can thiet vi trong codebase co nhieu loi goi CallServer da bi comment lai
    (vi du CServerResponseLogic.lua:65) — neu khong loc se lot vao dac ta.
    """
    out = list(text)
    i, n = 0, len(text)
    while i < n:
        ch = text[i]
        if ch in '"\'':                                  # chuoi thuong
            q, i = ch, i + 1
            while i < n and text[i] != q:
                i += 2 if text[i] == '\\' else 1
            i += 1
            continue
        if text.startswith('[[', i) or text.startswith('[=', i):   # chuoi dai
            j = text.find(']]', i + 2)
            i = n if j < 0 else j + 2
            continue
        if text.startswith('--', i):
            if text.startswith('--[[', i):               # comment khoi
                j = text.find(']]', i + 4)
                j = n if j < 0 else j + 2
            else:                                        # comment dong
                j = text.find('\n', i)
                j = n if j < 0 else j
            for k in range(i, j):
                if out[k] != '\n':
                    out[k] = ' '
            i = j
            continue
        i += 1
    return ''.join(out)


def split_args(s):
    """Tach danh sach tham so o cap ngoac ngoai cung."""
    out, depth, cur, quote = [], 0, '', None
    for ch in s:
        if quote:
            cur += ch
            if ch == quote:
                quote = None
            continue
        if ch == '"' or ch == "'":
            quote = ch
            cur += ch
            continue
        if ch in '([{':
            depth += 1
        elif ch in ')]}':
            depth -= 1
        if ch == ',' and depth == 0:
            out.append(cur.strip())
            cur = ''
        else:
            cur += ch
    if cur.strip():
        out.append(cur.strip())
    return out


def match_call(text, start):
    """Noi dung trong ngoac cua loi goi, `start` tro toi dau '('."""
    depth, quote = 0, None
    for i in range(start, len(text)):
        ch = text[i]
        if quote:
            if ch == quote:
                quote = None
            continue
        if ch == '"' or ch == "'":
            quote = ch
            continue
        if ch == '(':
            depth += 1
        elif ch == ')':
            depth -= 1
            if depth == 0:
                return text[start + 1:i], i
    return None, start


HUNGARIAN = [
    (re.compile(r'^(n|dw|i|c)[A-Z]'), 'number'),
    (re.compile(r'^f[A-Z]'), 'float'),
    (re.compile(r'^(sz|str|s)[A-Z]'), 'string'),
    (re.compile(r'^b[A-Z]'), 'boolean'),
    (re.compile(r'^(t|tb|table)[A-Z]'), 'table'),
    (re.compile(r'^p[A-Z]'), 'object'),
    (re.compile(r'^u[A-Z]'), 'number (uid)'),
    (re.compile(r'^(id|Id)$'), 'number'),
]


def leaf(expr):
    """Doan co nghia nhat cua mot duong truy cap truong: self.m.nCount -> nCount.

    Nhieu cho goi day tham so bang bien thanh vien (self.m.args.strStockId);
    lay doan dau se ra 'self' — mat sach ten lan quy uoc Hungarian de doan kieu.
    Chi ap dung cho duong truy cap thuan, khong dung cho bieu thuc co loi goi.
    """
    e = expr.strip()
    return e.rsplit('.', 1)[-1] if re.fullmatch(r'[A-Za-z_][\w.]*', e) else e


def infer_type(expr):
    e = expr.strip()
    if re.fullmatch(r'-?\d+', e):
        return 'number = %s' % e
    if re.fullmatch(r'-?\d*\.\d+', e):
        return 'float = %s' % e
    if re.fullmatch(r'"[^"]*"', e) or re.fullmatch(r"'[^']*'", e):
        return 'string = %s' % e
    if e in ('true', 'false'):
        return 'boolean = %s' % e
    if e == 'nil':
        return 'nil'
    if e.startswith('{'):
        return 'table'
    if e.startswith('os.time'):
        return 'number (timestamp)'
    if e.startswith('cjson.encode'):
        return 'string (JSON)'
    base = re.split(r'[.:\[(]', leaf(e))[0]
    for rx, ty in HUNGARIAN:
        if rx.match(base):
            return ty
    return 'any'


FUNC_DEF = re.compile(r'^\s*(?:local\s+)?function\s+([A-Za-z_][\w.]*)([:.])?([A-Za-z_]\w*)?\s*\(([^)]*)\)')


def doc_above(lines, i):
    """Gom cac dong comment '--' ngay phia tren dinh nghia ham."""
    doc, j = [], i - 1
    while j >= 0:
        raw = lines[j].strip()
        if raw.startswith('--') and not raw.startswith('--[['):
            txt = raw.lstrip('-').strip()
            if txt and set(txt) - set('-=*# '):
                doc.append(txt)
            j -= 1
        elif raw == '':
            j -= 1
            if doc:
                break
        else:
            break
    return ' / '.join(reversed(doc[:3]))


def index_functions(code_lines, doc_lines=None):
    """Quet dinh nghia ham tren ban da xoa comment; doc lay tu ban goc."""
    doc_lines = doc_lines if doc_lines is not None else code_lines
    funcs = []
    for i, ln in enumerate(code_lines):
        m = FUNC_DEF.match(ln)
        if not m:
            continue
        owner, sep, name, params = m.groups()
        full = owner + (sep or '') + (name or '') if name else owner
        funcs.append((i, full, params.strip(), doc_above(doc_lines, i)))
    return funcs


def enclosing(funcs, line_no):
    best = None
    for i, full, params, doc in funcs:
        if i <= line_no:
            best = (full, params, doc)
        else:
            break
    return best or ('(top-level)', '', '')


# ------------------------------------------------- RPC dung ten dung luc chay
#
#   CUIAssist.bindRpcToEvent(self, "G_ActivityStock", EventManagerLogicEvent.Stock,
#                            "Client%s", "OnClient%s")
#
# sinh ra luc chay, cho MOI khoa k trong bang su kien (sc/user/UI/CUIAssist.lua:335):
#   self[reqFmt % k] = function(...) CallServer(GAME_LOGIC, serverObj, reqFmt % k, ...) end
#   self[rspFmt % k] = function(...) ... end        -- server goi nguoc vao day
#
# Ten ham that su chi ton tai sau khi string.format chay, nen luot quet CallServer
# o tren chi thay mot loi goi voi funcName la bien. Phai no bang tay tu bang su kien.
BIND_RE = re.compile(
    r'bindRpcToEvent\(\s*\w+\s*,\s*"([^"]+)"\s*,\s*EventManagerLogicEvent\.([\w.]+)\s*,'
    r'\s*"([^"]+)"\s*,\s*"([^"]+)"')

DEF_RE = re.compile(r'EventManagerLogicEventDef\s*\(')


def parse_event_defs(text, code):
    """Bang su kien khai bao qua EventManagerLogicEventDef("A"[,"B"], { "Key", ... }).

    Tra ve {'A.B': [(key, doc)]}. Do dai loi goi do tren ban da xoa comment
    (comment tieng Trung co the chua ngoac/nhay lam lech bo dem ngoac), con doc
    lay tu ban goc: comment cuoi dong la mo ta duy nhat co cho tung API nhom nay.
    strip_comments giu nguyen vi tri ky tu nen hai ban danh chi so trung nhau.
    """
    out = collections.OrderedDict()
    for m in DEF_RE.finditer(code):
        inner_code, end = match_call(code, m.end() - 1)
        if inner_code is None:
            continue
        inner_raw = text[m.end():end]
        b = inner_code.find('{')
        path = re.findall(r'"(\w+)"', inner_code[:b] if b >= 0 else '')
        if b < 0 or not path:
            continue
        keys = []
        for lc, lr in zip(inner_code[b + 1:].split('\n'), inner_raw[b + 1:].split('\n')):
            k = re.search(r'"(\w+)"', lc)
            if not k:
                continue
            after = lr[k.end():]
            keys.append((k.group(1), after.split('--', 1)[1].strip() if '--' in after else ''))
        out.setdefault('.'.join(path), []).extend(keys)
    return out


def index_method_calls(files, names):
    """Tim noi client goi cac phuong thuc do bindRpcToEvent sinh ra.

    Ten ham chi lo dien o dau goi (G_ActivityStock:ClientBuyStock(nId, nCount)),
    nen day la cho duy nhat suy duoc chu ky tham so that. Sap xep theo do dai
    giam dan de ClientGetPack khong khop nham vao ClientGetPackDetail.
    """
    if not names:
        return {}
    rx = re.compile(r'[:.](%s)\s*\(' %
                    '|'.join(sorted((re.escape(n) for n in names), key=len, reverse=True)))
    best = {}
    for f in files:
        code = f['code']
        for m in rx.finditer(code):
            name = m.group(1)
            inner, _ = match_call(code, m.end() - 1)
            if inner is None:
                continue
            args = [{'expr': a, 'type': infer_type(a)} for a in split_args(inner)]
            line = code.count('\n', 0, m.start())
            owner, params, _doc = enclosing(f['funcs'], line)
            cur = best.get(name)
            if cur is None or len(args) > len(cur[0]):
                best[name] = (args, owner, params, '%s:%d' % (f['rel'], line + 1))
    return best


def resolve_bound(files):
    """No moi loi goi bindRpcToEvent thanh danh sach API cu the."""
    em = next((f for f in files if f['rel'].endswith('sc/share/EventManager.lua')), None)
    if em is None:
        return []
    defs = parse_event_defs(em['text'], em['code'])

    wanted = collections.OrderedDict()
    for f in files:
        for m in BIND_RE.finditer(f['code']):
            obj, path, reqfmt, rspfmt = m.groups()
            line = f['code'].count('\n', 0, m.start()) + 1
            for key, doc in defs.get(path, []):
                # Def co the khai bao trung (StateWar khai bao 2 lan): giu ban dau
                wanted.setdefault(reqfmt.replace('%s', key),
                                  (f['rel'], line, obj, path, key, doc,
                                   rspfmt.replace('%s', key)))

    calls = index_method_calls(files, wanted)
    out = []
    for name, (rel, line, obj, path, key, doc, rsp) in wanted.items():
        args, caller, params, site = calls.get(name, ([], '', '', None))
        out.append({
            'module': 'GAME_LOGIC',              # _addRpcFunc co dinh SERVER.GAME_LOGIC
            'objName': obj,
            'funcName': name,
            'args': args,
            'caller': caller or '%s (bindRpcToEvent)' % obj,
            'callerParams': params,
            'doc': doc,
            'src': '%s:%d' % (rel, line),
            'bound': True,
            'eventName': key,
            'eventTable': path,
            'handlerHint': rsp,
            'callSite': site,
        })
    return sorted(out, key=lambda r: r['funcName'])


# ------------------------------------------------------------------ quet chinh
def load_files():
    """Doc va tien xu ly mot lan; ca hai luot quet dung chung ket qua nay."""
    out = []
    for path in lua_files():
        text = read(path)
        code = strip_comments(text)
        code_lines = code.split('\n')
        out.append({
            'rel': os.path.relpath(path, ASSETS).replace('\\', '/'),
            'text': text, 'code': code,
            'lines': text.split('\n'), 'code_lines': code_lines,
            'funcs': index_functions(code_lines, text.split('\n')),
        })
    return out


def collect():
    files = load_files()
    requests, responses, dynamic = [], [], []
    for f in files:
        if f['rel'].endswith('sc/system/rpc.lua'):
            continue                          # chinh tang van chuyen, khong phai API
        text, code, code_lines, funcs = f['text'], f['code'], f['code_lines'], f['funcs']

        for m in re.finditer(r'\bCallServer\s*\(', code):
            inner, _ = match_call(code, m.end() - 1)
            if inner is None:
                continue
            args = split_args(inner)
            if len(args) < 3:
                continue
            line_no = text.count('\n', 0, m.start())
            owner, params, doc = enclosing(funcs, line_no)
            fn = args[2]
            entry = {
                'module': args[0].replace('SERVER.', ''),
                'objName': args[1].strip('"\''),
                'funcName': fn.strip('"\''),
                'args': [{'expr': a, 'type': infer_type(a)} for a in args[3:]],
                'caller': owner,
                'callerParams': params,
                'doc': doc,
                'src': '%s:%d' % (f['rel'], line_no + 1),
            }
            literal = re.fullmatch(r'"\w+"|\'\w+\'', fn) is not None
            (requests if literal else dynamic).append(entry)

        for i, full, params, doc in funcs:
            if re.fullmatch(r'On[A-Z]\w*', full):
                first = params.split(',')[0].strip()
                fields = []
                if first:
                    body = '\n'.join(code_lines[i:i + 150])
                    fields = sorted(set(re.findall(r'\b%s\.(\w+)' % re.escape(first), body)))
                responses.append({
                    'funcName': full,
                    'params': params,
                    'fields': fields,
                    'doc': doc,
                    'src': '%s:%d' % (f['rel'], i + 1),
                })

    requests += resolve_bound(files)
    return requests, responses, dynamic


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--assets', default=ASSETS,
                    help='thu muc assets da giai ma (mac dinh: %(default)s)')
    ap.add_argument('--out', default=OUT, help='thu muc ket qua (mac dinh: %(default)s)')
    a = ap.parse_args()
    configure(a.assets, a.out)

    sys.stdout.reconfigure(encoding='utf-8')
    requests, responses, dynamic = collect()
    os.makedirs(OUT, exist_ok=True)
    json.dump({'requests': requests, 'responses': responses, 'dynamic': dynamic},
              open(os.path.join(OUT, 'server_api.json'), 'w', encoding='utf-8'),
              ensure_ascii=False, indent=1)
    bound = [r for r in requests if r.get('bound')]
    print('assets    :', ASSETS, '->', OUT)
    print('requests  :', len(requests), 'call sites,', len({r['funcName'] for r in requests}), 'unique')
    print('  literal :', len(requests) - len(bound))
    print('  bound   :', len(bound), '(bindRpcToEvent, ten dung luc chay)')
    print('responses :', len(responses), 'defs,', len({r['funcName'] for r in responses}), 'unique')
    print('dynamic   :', len(dynamic), '(con lai chua giai duoc)')
    print('modules   :', dict(collections.Counter(r['module'] for r in requests)))


if __name__ == '__main__':
    main()
