# -*- coding: utf-8 -*-
"""_tim_port_duoc.py — tim khoa con thieu CO THE PORT bang than ham goc trong `share/`.

    python -I _tim_port_duoc.py

Y tuong (da dung mot lan 28/10, xem README §25): khoa RPC `Client<Ten>` ma may chu
xu ly bang `XLogic:ten` thi ten ham THUONG chi khac chu C dau. Neu `share/` con
nguyen than ham do thi chi viec noi day, khong phai viet lai luat.

Quet:
  * danh sach khoá CÒN THIẾU (từ `_phu_rpc`, đã bỏ chú thích đúng — xem `_khoi_ngoac`)
  * mọi `function <Lop>[.:]<ten>(` trong `share/`
  * so khớp KHÔNG phân biệt hoa/thường sau khi bỏ tiền tố `Client` và hậu tố `Req`

In ra, mỗi ứng viên: khoá client · hàm share tìm được · tệp:dòng · CÓ ĐỘT BIẾN hay
chỉ ĐỌC (đoán bằng sự có mặt của các lời gọi ghi: Set/Add/Cost/Reduce/Receive/Save/
Delete/Remove/Update...). Chỉ là GỢI Ý để đọc tiếp, không phải kết luận.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import _phu_rpc as P  # noqa: E402
import cay  # noqa: E402

RE_HAM = re.compile(r"^\s*function\s+([A-Za-z_]\w*)[.:]([A-Za-z_]\w*)\s*\(", re.M)
RE_GHI = re.compile(r"\b(Set|Add|Cost|Reduce|Receive|Save|Delete|Remove|Update|"
                    r"Buy|Sell|Upgrade|Use|Exchange|Claim|Award|Modify)")


def ten_goc(func):
    t = func
    for p in ("Client", "Req"):
        if t.startswith(p):
            t = t[len(p):]
    for s in ("Req", "Request"):
        if t.endswith(s):
            t = t[:-len(s)]
    return t.lower()


def main():
    goi = P.quet_goi(cay.ASSETS)
    da = {t.split('.')[-1] for t in P.dang_ky()}
    thieu = sorted({(m, f) for _, m, f, _, _ in goi if f not in da})

    # hàm share: ten thuong -> [(lop, ten, tep, dong, co_ghi)]
    share = {}
    goc = os.path.join(cay.ASSETS, "sc", "share")
    for dirpath, _, files in os.walk(goc):
        for fn in files:
            if not fn.endswith(".lua"):
                continue
            p = os.path.join(dirpath, fn)
            txt = open(p, encoding="utf-8", errors="replace").read()
            for m in RE_HAM.finditer(txt):
                lop, ten = m.group(1), m.group(2)
                # thân hàm: từ đây tới 'function' kế tiếp
                nxt = txt.find("\nfunction ", m.end())
                than = txt[m.end(): nxt if nxt > 0 else len(txt)]
                share.setdefault(ten.lower(), []).append(
                    (lop, ten, os.path.relpath(p, cay.ASSETS), txt.count("\n", 0, m.start()) + 1,
                     bool(RE_GHI.search(than))))

    print("khoa con thieu: %d" % len(thieu))
    print("\n=== UNG VIEN PORT (ten ham share trung sau khi bo Client/Req) ===")
    n = 0
    for m, f in thieu:
        khoa = ten_goc(f)
        ds = share.get(khoa)
        if not ds:
            continue
        n += 1
        print("  %-42s [%s]" % (f, m or "(toan cuc)"))
        for lop, ten, tep, dong, co_ghi in ds[:3]:
            print("      %-44s %s:%d  %s" % ("%s:%s" % (lop, ten), tep, dong,
                                             "GHI" if co_ghi else "doc"))
    print("\nTONG UNG VIEN: %d khoa" % n)
    return 0


if __name__ == "__main__":
    sys.exit(main())
