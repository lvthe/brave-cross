# -*- coding: utf-8 -*-
"""_phan_loai_toancuc.py — phan loai khoa RPC "con thieu" theo BANG CHUNG: khoa nao
con duong goi THAT, khoa nao la ma CHET (nam trong chu thich / ham khong ai goi).

    python -I _phan_loai_toancuc.py                 # 42 khoa objName RONG
    python -I _phan_loai_toancuc.py --nhom G_GuildLogic G_FriendLogic ...
                                                    # moi khoa con thieu cua cac module nay
    python -I _phan_loai_toancuc.py --tat-ca        # tat ca khoa con thieu (theo module)

Vi sao can: `_con_lai.py` chi DEM. Mot khoa "con thieu" co the la:
  * ma dang SONG nhung lop offline chua noi  -> viec that;
  * ham bao quanh KHONG AI GOI               -> chet, nuot lang la dung;
  * nam trong chu thich `--[[ ... ]]` / `--[=====[ ... ]=====]` -> chet han.

Bon quy tac do luong (moi cai da tung cho so SAI neu bo qua):
  1. BO CHU THICH Lua dung CAP (`--[=*[` … `]=*]`). `CUIFriend.lua` mo bang khoi 4 dau `=`
     va dong ca TEP; `CServerRequestLogic.lua:181-198` la ba ham trong `--[[ ... end--]]`.
  2. Dem loi goi theo DUNG LOP/THUC THE: `G_ChapterLogic = ClientChapterLogic:new()` cho
     tap ten hop le; dem tran `:TenHam(` thi `ClientAwardAhieve` "song" chi vi
     `ClientAchieveLogic:AwardAchieve` trung ten.
  3. Callback do ENGINE goi theo ten (`onTouchBegin_*` … dang ky bang `setEnableLuaTouch`)
     khong ai grep thay -> tinh la SONG.
  4. Voi khoa CO MODULE, phai khop CA hai chuoi (`"G_X"` va `"ClientY"`) tren cung dong
     CallServer — cung ten ham co the thuoc nhieu module.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.dirname(HERE)

# DUNG DUNG CAY ma `_phu_rpc` quet (`cay.ASSETS/sc`), khong tu doan duong dan:
# `brave-cross/work/` co HAI ban giai ma khac nhau — `vn/decrypted/assets` (973 tep,
# ban day du) va `decrypted/assets` (952 tep, ban cu/thieu). Quet ban thieu thi bao
# "ham khong ai goi" oan cho nhung cho goi nam trong 21 tep thieu.
sys.path.insert(0, WORK)
import cay as _cay  # noqa: E402
GOC = os.path.normpath(os.path.join(_cay.ASSETS, "sc"))

TEN_TOANCUC = """ClientAgreeFriendApply ClientApplyForFriend ClientAwardAhieve ClientBindingAccount
ClientCancelBuildingUpgrade ClientCancelUpgradeArmy ClientChangeHeroEquipment
ClientChapterHJRQComplete ClientChapterSCSComplete ClientCheckNewEquipment ClientCollectResouce
ClientCompleteUpgradeArmy ClientCompleteUpgradeArmyWithDiomaon ClientCompleteUpgradePotion
ClientDecomposeEquipment ClientDeleteMailWithMailId ClientForgeEquipment ClientGetAllUserData
ClientGetBattleReportsWithDate ClientGetChapterDropData ClientGetPassMissionCountList
ClientGetRecommendedUserList ClientGetSpeechContent ClientGetUserRelation ClientGuestLogin
ClientGuestRegister ClientHeroExpedition ClientNormalLogin ClientNormalRegister
ClientPotionExpedition ClientReachAchieveWithEvent ClientRefuseFriendApply ClientRemoveFriendApply
ClientRemoveFriendRelation ClientReturnHome ClientSaveMailPrizeWithMailId
ClientSearchUserWithUserName ClientSellEquipment ClientSetArenaHero ClientSetMailReadWithMailId
ClientSignIn ClientStartLottery""".split()

RE_ENGINE = re.compile(
    r"^(onTouch|onClick|onMenu|onSelect|onDrag|onItem|onKey|onPress|"
    r"onShow|onHide|onEnter|onExit|onUpdate|siwtch|switch|On[A-Z])")
RE_DINH_NGHIA = re.compile(
    r"\s*(?:local\s+)?function\s+([A-Za-z_]\w*)(?:[.:]([A-Za-z_]\w*))?\s*\(")


# ------------------------------------------------------------------ cay nguon

def bo_chu_thich(dong):
    """Tra ve danh sach dong da bo chu thich (giu nguyen so dong)."""
    ra = []
    trong_khoi = None
    re_mo = re.compile(r"--\[(=*)\[")
    for d in dong:
        if trong_khoi is not None:
            dau = "]" + "=" * trong_khoi + "]"
            j = d.find(dau)
            if j < 0:
                ra.append("")
                continue
            d = " " * (j + len(dau)) + d[j + len(dau):]
            trong_khoi = None
        while True:
            m = re_mo.search(d)
            if not m:
                break
            cap = len(m.group(1))
            dau = "]" + "=" * cap + "]"
            j = d.find(dau, m.end())
            if j < 0:
                d = d[:m.start()]
                trong_khoi = cap
                break
            d = d[:m.start()] + " " * (j + len(dau) - m.start()) + d[j + len(dau):]
        i = d.find("--")
        if i >= 0:
            d = d[:i]
        ra.append(d)
    return ra


def doc_cay():
    for goc, _, tep in os.walk(GOC):
        for t in tep:
            if t.endswith(".lua"):
                p = os.path.join(goc, t)
                try:
                    with open(p, "r", encoding="utf-8", errors="replace") as f:
                        raw = f.read().split("\n")
                except OSError:
                    continue
                yield p, raw, bo_chu_thich(raw)


def ham_bao_quan(dong, i):
    for k in range(i, -1, -1):
        m = RE_DINH_NGHIA.match(dong[k])
        if m:
            return m.group(1), m.group(2) or m.group(1), k
    return None, None, -1


# ------------------------------------------------------------------ phan loai

def phan_loai(ds_khoa, cay, the_hien, chi_muc):
    """ds_khoa: [(module, func)]. Tra ve [(module, func, trang_thai, tong, chi_tiet)]."""
    ket_qua = []
    for module, func in ds_khoa:
        chu_func = '"%s"' % func
        chu_module = ('"%s"' % module) if module else None
        cho_goi = []
        for p, raw, dong in cay:
            for i, d in enumerate(dong):
                if "CallServer" not in d or chu_func not in d:
                    continue
                if chu_module is not None and chu_module not in d:
                    continue
                lop, ham, so = ham_bao_quan(dong, i)
                cho_goi.append((p, i, lop, ham, so))

        if not cho_goi:
            # phan biet: chua tung co dong nao, hay co ma bi chu thich
            co_trong_chu_thich = False
            for p, raw, dong in cay:
                for i, d in enumerate(raw):
                    if chu_func in d and "CallServer" in d:
                        if chu_module is None or chu_module in d:
                            co_trong_chu_thich = True
                            break
                if co_trong_chu_thich:
                    break
            ket_qua.append((module, func,
                            "TRONG-CHU-THICH" if co_trong_chu_thich else "KHONG-GOI",
                            0, "-"))
            continue

        tong = 0
        chi_tiet = []
        for p, i, lop, ham, so in cho_goi:
            if not ham:
                chi_tiet.append("?")
                continue
            if lop:
                ten = {lop} | the_hien.get(lop, set())
                mau = r"\b(?:%s)[.:]%s\s*\(" % (
                    "|".join(re.escape(x) for x in ten), re.escape(ham))
            else:
                mau = r"[.:]%s\s*\(" % re.escape(ham)
            pat = re.compile(mau)
            dem = 0
            for (p2, j, d2) in chi_muc.get(ham, ()):
                if p2 == p and j == so:
                    continue
                if pat.search(d2):
                    dem += 1
            engine = bool(RE_ENGINE.match(ham or ""))
            if engine and dem == 0:
                dem = 1
            tong += dem
            chi_tiet.append("%s.%s x%d%s" % (lop or "-", ham, dem,
                                             " (ENGINE)" if engine else ""))
        ket_qua.append((module, func, "SONG" if tong > 0 else "CHET", tong,
                        ", ".join(chi_tiet)))
    return ket_qua


def in_ket_qua(ket_qua, tieu_de):
    song = [k for k in ket_qua if k[2] == "SONG"]
    chet = [k for k in ket_qua if k[2] == "CHET"]
    chu = [k for k in ket_qua if k[2] == "TRONG-CHU-THICH"]
    khong = [k for k in ket_qua if k[2] == "KHONG-GOI"]

    print("\n########## %s ##########" % tieu_de)
    print("TONG: %d song · %d chet (ham khong ai goi) · %d trong chu thich · %d khong-goi"
          % (len(song), len(chet), len(chu), len(khong)))

    def dong(k, co_ten_module=True):
        m = ("[%s] " % k[0]) if (co_ten_module and k[0]) else ""
        return "  %-52s %-3d %s" % (m + k[1], k[3], k[4])

    print("\n=== SONG (%d) ===" % len(song))
    for k in song:
        print(dong(k))
    print("\n=== CHET — ham bao quanh khong ai goi (%d) ===" % len(chet))
    for k in chet:
        print(dong(k))
    print("\n=== NAM TRONG CHU THICH (%d) ===" % len(chu))
    for k in chu:
        print(dong(k))
    if khong:
        print("\n=== KHONG-CO-LENH-GOI (%d) ===" % len(khong))
        for k in khong:
            print(dong(k))


def nap_the_hien(cay):
    re_the = re.compile(r"\b([A-Za-z_]\w*)\s*=\s*([A-Za-z_]\w*)\s*[.:]\s*new\s*\(")
    the_hien = {}
    for p, raw, dong in cay:
        for d in dong:
            for m in re_the.finditer(d):
                the_hien.setdefault(m.group(2), set()).add(m.group(1))
    return the_hien


def nap_chi_muc(cay):
    chi_muc = {}
    for p, raw, dong in cay:
        for i, d in enumerate(dong):
            for m in re.finditer(r"[.:]([A-Za-z_]\w*)\s*\(", d):
                chi_muc.setdefault(m.group(1), []).append((p, i, d))
    return chi_muc


def khoa_con_thieu():
    """Nap danh sach (module, func) CHUA co handler tu `_phu_rpc`."""
    sys.path.insert(0, HERE)
    import _phu_rpc as P
    import cay as C
    goi = P.quet_goi(C.ASSETS)
    da = {t.split('.')[-1] for t in P.dang_ky()}
    thieu = []
    for _, m, f, _, _ in goi:
        if f not in da and (m, f) not in thieu:
            thieu.append((m, f))
    return thieu


def main(argv):
    cay = list(doc_cay())
    the_hien = nap_the_hien(cay)
    chi_muc = nap_chi_muc(cay)
    print("quet %d tep lua (da bo chu thich) trong %s" % (len(cay), GOC))

    if "--tat-ca" in argv or "--nhom" in argv:
        thieu = khoa_con_thieu()
        if "--nhom" in argv:
            i = argv.index("--nhom")
            nhom = set(argv[i + 1:])
            thieu = [k for k in thieu if k[0] in nhom]
        else:
            nhom = None
        # gom theo module de doc
        theo_module = {}
        for m, f in thieu:
            theo_module.setdefault(m or '(toan cuc)', []).append((m, f))
        tong_song = 0
        for m in sorted(theo_module, key=lambda x: -len(theo_module[x])):
            ds = theo_module[m]
            kq = phan_loai(ds, cay, the_hien, chi_muc)
            in_ket_qua(kq, "%s - %d khoa" % (m, len(ds)))
            tong_song += len([k for k in kq if k[2] == "SONG"])
        print("\n>>>> TONG SO KHOA CON SONG: %d / %d" % (tong_song, len(thieu)))
        return 0

    ds = [("", t) for t in TEN_TOANCUC]
    in_ket_qua(phan_loai(ds, cay, the_hien, chi_muc), "42 khoa objName RONG")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
