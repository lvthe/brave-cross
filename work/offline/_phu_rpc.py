# -*- coding: utf-8 -*-
"""_phu_rpc.py — doi chieu RPC client goi (CallServer) voi handler lop offline.

    python _phu_rpc.py            # bang phu + danh sach thieu
    python _phu_rpc.py --thieu    # chi in danh sach thieu

Quet toan bo sc/ da giai ma (cay.ASSETS) tim
    CallServer(SERVER.X, "G_Module", "FuncName", ...)
roi so voi cac ten duoc dang ky trong offline/sc/offline/**/*.lua
(R:on("Ten"), R:onAll{ Ten = ... }, R:ignore("Ten")).
"""
import argparse
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.dirname(HERE)
sys.path.insert(0, WORK)

import cay  # noqa: E402

CALL = re.compile(r'CallServer\s*\(\s*SERVER\.(\w+)\s*,\s*(?:"([^"]*)"|nil)\s*,\s*"([^"]*)"')
ON = re.compile(r'\bR:on\s*\(\s*"([^"]+)"')
ONALL = re.compile(r'R:onAll\s*\{')
IGNORE = re.compile(r'R:ignore\s*\(')


def quet_goi(assets):
    """[(server, module, func, file, line)]"""
    ra = []
    for dirpath, _, files in os.walk(assets):
        for f in files:
            if not f.endswith('.lua'):
                continue
            p = os.path.join(dirpath, f)
            rel = os.path.relpath(p, assets).replace('\\', '/')
            try:
                txt = open(p, encoding='utf-8', errors='replace').read()
            except OSError:
                continue
            for i, line in enumerate(txt.split('\n'), 1):
                for m in CALL.finditer(line):
                    ra.append((m.group(1), m.group(2), m.group(3), rel, i))
    return ra


def _khoi_ngoac(txt, vi_tri_mo):
    """Doc mot khoi ngoac tu `vi_tri_mo` (ngay SAU dau '(' ) den ngoac dong DUNG CAP.

    Vi sao khong dung regex non-greedy `R:ignore\\s*\\((.*?)\\)`: ban goc viet chu
    thich co ngoac don NGAY TRONG danh sach khoa, vi du

        R:ignore(
            "A",
            -- Client tu luu (ClothingData, SevenDaysGiftData…)
            "B"
        )

    `(.*?)\\)` cat tai dau `)` cua "(ClothingData…)" ⇒ moi khoa SAU do khong duoc
    dem. Bay nay da vap 2 lan (README 31/10) va van con trong ban nay: no lam
    `ClientSetClientCommonData` / `ClientSetGameFuncUnLockData` bi bao THIEU oan du
    da nam trong `R:ignore`.

    Ham nay bo qua CHUOI `"…"`/`'…'` va CHU THICH `-- …` / `--[=*[ … ]=*]` khi dem.
    """
    sau = len(txt)
    i = vi_tri_mo
    sau_cap = 0
    while i < sau:
        c = txt[i]
        if c == '-' and txt.startswith('--', i):
            m = re.compile(r'--\[(=*)\[').match(txt, i)
            if m:
                dong = ']' + '=' * len(m.group(1)) + ']'
                j = txt.find(dong, m.end())
                i = sau if j < 0 else j + len(dong)
            else:
                j = txt.find('\n', i)
                i = sau if j < 0 else j + 1
            continue
        if c == '"' or c == "'":
            j = i + 1
            while j < sau:
                if txt[j] == '\\':
                    j += 2
                    continue
                if txt[j] == c:
                    break
                j += 1
            i = j + 1
            continue
        if c == '(':
            sau_cap += 1
        elif c == ')':
            if sau_cap == 0:
                return txt[vi_tri_mo:i]
            sau_cap -= 1
        i += 1
    return txt[vi_tri_mo:]


def _cac_chuoi(bloc):
    """Cac chuoi `"..."` nam NGOAI chu thich trong mot khoi.

    Khong dung `re.findall('"([^"]+)"')` tran: chu thich trong khoi cung co chuoi
    trong ngoac kep (vi du `-- Client tu luu "client common data" len may chu`),
    va chuoi do bi dem nham thanh mot khoa handler.
    """
    ra = []
    sau = len(bloc)
    i = 0
    while i < sau:
        c = bloc[i]
        if c == '-' and bloc.startswith('--', i):
            m = re.compile(r'--\[(=*)\[').match(bloc, i)
            if m:
                dong = ']' + '=' * len(m.group(1)) + ']'
                j = bloc.find(dong, m.end())
                i = sau if j < 0 else j + len(dong)
            else:
                j = bloc.find('\n', i)
                i = sau if j < 0 else j + 1
            continue
        if c == '"' or c == "'":
            j = i + 1
            buf = []
            while j < sau:
                if bloc[j] == '\\':
                    buf.append(bloc[j + 1] if j + 1 < sau else '')
                    j += 2
                    continue
                if bloc[j] == c:
                    break
                buf.append(bloc[j])
                j += 1
            ra.append(''.join(buf))
            i = j + 1
            continue
        i += 1
    return ra


def dang_ky():
    """Ten cac handler da dang ky trong lop offline."""
    out = set()
    for dirpath, _, files in os.walk(os.path.join(HERE, 'sc', 'offline')):
        for f in files:
            if not f.endswith('.lua'):
                continue
            txt = open(os.path.join(dirpath, f), encoding='utf-8', errors='replace').read()
            out.update(ON.findall(txt))
            # onAll{ Ten = ... } hoặc onAll({ ... }) — lay khoa o dau dong
            for bloc in re.findall(r'R:onAll\s*\(?\s*\{(.*?)\n\s*\}', txt, re.S):
                for m in re.finditer(r'^\s*(\w+)\s*=\s*function', bloc, re.M):
                    out.add(m.group(1))
            # `R:ignore(` — doc khoi ngoac DUNG CAP (xem _khoi_ngoac), roi lay chuoi
            # NGOAI chu thich (xem _cac_chuoi)
            for m in re.finditer(r'R:ignore\s*\(', txt):
                for k in _cac_chuoi(_khoi_ngoac(txt, m.end())):
                    out.add(k)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--assets', default=cay.ASSETS)
    ap.add_argument('--thieu', action='store_true')
    ap.add_argument('--la', action='store_true',
                    help='liet ke handler khong khop lenh client nao (nghi go sai ten)')
    a = ap.parse_args()

    goi = quet_goi(a.assets)
    da = dang_ky()

    # Ten tran (khong tien to obj) de doi chieu voi client; ten co obj
    # ("G_X.Func") giu lai de kiem "la" — xem duoi.
    da_tran = {ten.split('.')[-1] for ten in da}
    cap = {(module, func) for _, module, func, _, _ in goi}

    theo_ten = {}
    for server, module, func, rel, line in goi:
        theo_ten.setdefault(func, []).append((server, module, rel, line))

    if getattr(a, 'la', False):
        #[[ Handler dang ky ma KHONG khop bo ba (obj, func) nao cua client,
        #   cung khong khop ten tran — nghi go sai ten. Ten co obj chi khop
        #   khi client that su goi (obj do, func do). ]]
        la = []
        for ten in sorted(da):
            if '.' in ten:
                obj, func = ten.rsplit('.', 1)
                if (obj, func) not in cap:
                    la.append(ten)
            elif ten not in theo_ten:
                la.append(ten)
        #[[ Vài tên KHÔNG có trong Lua vì phía C++ gửi (libgame tự gọi qua
        #   CallServer của engine), hoặc client gọi bằng tên khác. Không phải
        #   lỗi chính tả — chỉ là công cụ quét Lua không thấy. ]]
        NGOAI_LE = {
            'Heartbeat': 'C++ gửi (CUILoginRPCManager chỉ khai báo)',
            'ClientReportClientInfo': 'C++ gửi, không có trong Lua',
            'ClientStatistics': 'C++ gửi, không có trong Lua',
            'ClientStateWarBeginTime': 'client gọi qua G_StateWarLogic, khai báo ngoài Lua',
            # `G_PkProtocol` dựng bằng bindRpcToEvent ("Client%s"/"OnClient%s",
            # ClientHeroPKLogic.lua:4) nên lời gọi là `G_PkProtocol:ClientGetData`,
            # KHÔNG phải CallServer — bộ quét không thấy.
            'ClientGetData': 'G_PkProtocol:ClientGetData (bindRpcToEvent), không phải CallServer',
        }
        la = [t for t in la if t.split('.')[-1] not in NGOAI_LE]
        if la:
            print('Handler KHONG khop lenh nao cua client (%d):' % len(la))
            for ten in la:
                print('  ' + ten)
        else:
            print('Moi handler deu khop mot lenh client.')
        return 0

    thieu = {k: v for k, v in theo_ten.items() if k not in da_tran}
    print('Tong so ham server client goi : %d' % len(theo_ten))
    print('Da co handler trong lop offline: %d' % len(da_tran & set(theo_ten)))
    print('THIEU                          : %d' % len(thieu))

    if not a.thieu:
        print('\n=== da co ===')
        for k in sorted(da_tran & set(theo_ten)):
            print('  %-46s %s' % (k, theo_ten[k][0][1] or '(toan cuc)'))

    print('\n=== THIEU (theo server/module) ===')
    for k in sorted(thieu):
        noi = thieu[k][0]
        print('  %-46s %-9s %-34s %s:%d'
              % (k, noi[0], noi[1] or '(toan cuc)', noi[2], noi[3]))


if __name__ == '__main__':
    main()
