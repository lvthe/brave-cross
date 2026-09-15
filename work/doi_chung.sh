#!/bin/sh
# DOI CHUNG cho phep quay neo: cung ma, cung tran 16 luot, cung trang thai dau
# vao. Khac nhau DUY NHAT la tham so `xoay`.
#   A. --khong-xoay : tat han quay                   -> tags_cay.khongxoay.json
#   B. quay TRAI DEU: buoc nhay len(names)/LUOT_MAX  -> tags_cay.traideu.json
#
# VI SAO CHI 6 MAN: do tren tags_cay.json thi CHI 6 man con neo chua toi duoc,
# va ca 6 deu co tap neo toi duoc la mot TIEN TO lien mach tu vi tri 1
# (UI_Hero 84/168, UI_Main_ControlPanel 21/75, UI_Destiny 7/42,
#  UI_ArmyGroup_Campsite_Info 9/22, UI_Mail 1/7, UI_Friends 28/33).
# Ca 6 deu KHONG co DOTREO (ten khong co trong _G) va KHONG co DOCUT
# (getChildren tra nil) — nen khong con cach giai thich nao khac ngoai
# "di het luot ma chua toi". Chay tren dung 6 man do thi moi cham dung cho
# gia thuyet, va ton ~20 phut/nhanh thay vi ~55.
#
# CA HAI NHANH THUA HUONG CUNG mot `bo` cua tags_cay.json (bo qua 6 man nay roi
# do lai tu dau) — do la dieu kien de phep so sanh chi khac mot bien.
#
# GIU LAI script nay, dung xoa: bang ba nhanh o README muc "Quay neo" va phan
# noi ve tran do chi co nghia khi doc lai duoc CA PHEP DO. Chay lai khi nghi ngo
# ket qua cu — ton ~40 phut cho ca hai nhanh.
#
# Sau khi hai nhanh xong:
#   python gop_nhanh.py --ghi        # so ba nhanh, roi gop vao tags_cay.json
#   python layout.py --all --out <bravecross-game>/layout_ref   # ve ban NGUYEN
#   python emu_join.py --ghi         # roi moi ghep lai (README buoc 2b)
#   python ../bravecross-game/tools/check.py                    # 24 bo xanh
# Phai dung lai layout_ref truoc khi ghep: ghep chong len ban da ghep thi du
# lieu cu nam lai, va kiem_tag.py bao dong truoc/sau de thay cho do.
set -e
cd /c/Project/game/brave-cross/work
T=/c/Users/lvthe/AppData/Local/Temp
KHOA="$T/doi_chung.lock"

# Chan chay hai ban cung luc: dung cai bay vua mat 25 phut may ao —
# hai tien trinh cung day game.lua len cung mot may ao va cung ghi mot file
# ket qua, nen so do duoc la tron lan cua hai luot va khong kiem chung duoc.
if [ -e "$KHOA" ]; then
    echo "DANG CHAY ROI ($KHOA). Dung lai truoc da."
    exit 1
fi
echo "$$ $(date +%H:%M:%S)" > "$KHOA"
trap 'rm -f "$KHOA"' EXIT INT TERM

MAN="UI_ArmyGroup_Campsite_Info_960_640.xgg,UI_Destiny_960_640.xgg,UI_Friends_960_640.xgg,UI_Hero_960_640.xgg,UI_Mail_960_640.xgg,UI_Main_ControlPanel_960_640.xgg"

# $1 = nhan (cung la ten file log), $2 = file json ra, phan con lai la co them.
chay() {
    nhan="$1"; ten="$2"; shift 2
    echo "=== bat dau $nhan $(date +%H:%M:%S)"
    PYTHONIOENCODING=utf-8 python - "$ten" <<'PY'
import json, os, pathlib, sys
ten = sys.argv[1]
MAN = ('UI_ArmyGroup_Campsite_Info_960_640.xgg', 'UI_Destiny_960_640.xgg',
       'UI_Friends_960_640.xgg', 'UI_Hero_960_640.xgg',
       'UI_Mail_960_640.xgg', 'UI_Main_ControlPanel_960_640.xgg')
doc = json.loads(pathlib.Path('tags_cay.json').read_text('utf-8'))
out = {}
for khoa in ('cay', 'xong', 'lan', 'bo', 'treo', 'cut', 'loaded', 'nodes'):
    out[khoa] = {k: v for k, v in doc.get(khoa, {}).items() if k not in MAN}
pathlib.Path(ten).write_text(json.dumps(out, ensure_ascii=False, indent=1),
                             encoding='utf-8')
print('da xoa 6 man khoi ban sao -> %s' % ten)
PY
    # Log de ngay canh file json cua nhanh, khong de Temp: no la bang chung tho
    # cho tung man (so node, so luot, trang thai) cua con so trong README.
    PYTHONIOENCODING=utf-8 python -u emu_tags.py --cay --out "$ten" \
        --chi "$MAN" "$@" > "$nhan.log" 2>&1
    echo "=== xong $nhan $(date +%H:%M:%S)"
    grep -E "^\[|^xong:|^man di tron" "$nhan.log" || true
}

rm -f tags_cay.khongxoay.json
chay khongxoay tags_cay.khongxoay.json --khong-xoay
chay traideu   tags_cay.traideu.json

echo "=== HET DOI CHUNG $(date +%H:%M:%S)"
echo THOAT
