"""Đo ngữ nghĩa `Label` (nhãn) bằng máy ảo Android — hỏi thẳng engine bản gốc.

    python emu_nhan.py            # chạy một lượt, in ra các dòng NHAN|

VÌ SAO PHẢI ĐO
--------------
`lua/cocos.lua` (phía Godot) đang thiếu `setDimensions` và `autoFixSize`. Đọc mã
máy (`libgame.so`) đã biết chắc phần LƯU: `setDimensions` -> slot vtable +0x2b0
(hàm 0x4f6750, ghi cặp số nguyên +0x2c4/+0x2c8 và cặp float +0x2bc/+0x2c0 mà
`getDimensions` đọc), còn `getContentSize` (0x2ca6ac -> 0x4f7bfc) bỏ cục lại rồi
trả cặp float +0x5c/+0x60.

Nhưng ĐỌC MÃ KHÔNG TRẢ LỜI ĐƯỢC một câu: sau `setDimensions(w, 0)` + `setString`,
cặp +0x5c/+0x60 là BỀ RỘNG Ô (w) hay là BỀ RỘNG DÒNG DÀI NHẤT của chữ đã xuống
dòng? Hai cách đọc cho hai kết quả khác nhau ở hai chỗ thật:

  * `CUIGuildWar.lua:612-617` đọc `fRuleTextSizeX, fRuleTextSizeY =
    pRuleText:getContentSize()` RỒI dùng lại `fRuleTextSizeX` làm bề rộng ô cho
    đoạn luật kế tiếp. Nếu trả về dòng dài nhất thì mỗi đoạn sau bị bó hẹp hơn
    đoạn trước (thắt dần); nếu trả về bề rộng ô thì đó là điểm bất động.
  * `CUIToolTips.lua:200-220` lấy `nWidth, nHeight` rồi
    `s9ToolTips:setContentSize(nWidth + screenHeight/11, ...)` — tức bề rộng nền
    của khung gợi ý.

Vì vậy phải HỎI CHÍNH ENGINE, đúng cách `emu_tags.py` đã làm với tag: nạp một
bản `game.lua` có chèn đoạn đo, đọc kết quả qua logcat.

LƯỢT 2 — công thức `autoFixSize`. Giải mã `0x2ca5ec..0x2ca66a` cho ra:

    s14 = (float)ôRộng;  if (natW > ôRộng) s14 = ôRộng/natW
    if (natH <= ôCao) s14 = 1.0        <- quirk: bỏ luôn tỉ lệ NGANG
    s15 = (natH > ôCao) and ôCao/natH or 1.0
    scale = min(s14, s15);  setScale(scale)

Còn thiếu đúng một ẩn: `natW`/`natH` (+0x5c/+0x60) là gì sau khi bố cục lại —
và quirk kia có thật không. Lượt 1 đo được `autoFixSize` cho `0,97087377309799`
= 100/103 trong ô 100×40, tức tỉ lệ ngang CÓ bật; nhưng theo mã máy thì nó chỉ
bật khi `natH > ôCao`. Bốn ca ở lượt 2 (chữ một dòng rộng hơn ô, chữ nhiều dòng
cao hơn ô, ô chỉ có bề rộng, ô rộng 0) đo thẳng `getScaleX` sau `autoFixSize`
để chốt.

Cách chèn, cách trả quyền file, cách khởi động — y như `emu_tags.py` (xem
docstring ở đó). Đoạn đo tạo nhãn bằng ĐÚNG đường mã gốc dùng:
`Label:new()` + `createWithTTF(chu, defFontName, co)` (xem
`sc/plot/drama_L_N_01_01.lua:153-156`, `sc/user/Battle/CUISubtitle.lua:310-313`).

Mỗi bước in TRƯỚC khi gọi: bản dịch ARM của máy ảo hay SIGSEGV ở một lời gọi nào
đó, và khi nó chết thì dòng cuối còn lại chính là thủ phạm — nên thứ tự các bước
là thứ tự quan trọng, và mỗi dòng tự đứng một mình.
"""
import argparse
import pathlib
import re
import sys
import time

import emu_tags as E

HERE = pathlib.Path(__file__).resolve().parent
APK_VN = HERE / 'vn' / 'com.cmn.buatanew.apk'

# `%` trong khuôn này phải viết `%%` (đây là khuôn cho phép `%`-format của
# build_overrides). Đoạn dưới KHÔNG dùng string.format cho gọn.
PROBE = '''
-- === CHEN DE DO: ngu nghia nhan (emu_nhan.py sinh ra) ===
do
	-- In TEN buoc TRUOC khi goi: ban dich ARM cua may ao hay SIGSEGV o mot loi
	-- goi native nao do, va pcall KHONG do duoc loi native — nen dong cuoi con
	-- lai chinh la thu pham.
	local function goi(ten, f)
		print("NHAN|goi|" .. ten)
		local ok, a, b = pcall(f)
		local sa = tostring(a):gsub("\\r", "+r"):gsub("\\n", "+n")
		local sb = tostring(b):gsub("\\r", "+r"):gsub("\\n", "+n")
		print("NHAN|xong|" .. ten .. "|" .. tostring(ok) .. "|" .. sa .. "," .. sb)
		return a, b
	end

	print("NHAN|bat-dau")
	-- Nhan that cua ban goc: node trong bo cuc, dung thu ma CUIToolTips.lua /
	-- CUIGuildWar.lua mo ra (chung lay `lRuleTextTemplate:copy()`).
	local oknap = pcall(function() loadLevelFile("conf/Pop_Dialog_UI_960_640.xgg") end)
	print("NHAN|nap|" .. tostring(oknap))
	local n = rawget(_G, "ttfPopDialogContent")
	print("NHAN|node|" .. tostring(n))
	local DAI = "day la mot cau rat dai de do xem nhan tu xuong dong nhu the nao"
		.. " va no dai them mot doan nua cho chac chan vuot 200 diem"

	goi("1-cs-truoc", function() return n:getContentSize() end)
	goi("2-dim-truoc", function() return n:getDimensions() end)
	goi("3-str-truoc", function() return n:getString() end)
	goi("4-scale-truoc", function() return n:getScaleX() end)
	goi("4b-scaleY-truoc", function() return n:getScaleY() end)

	goi("5-setString-dai", function() return n:setString(DAI) end)
	goi("6-cs-sau-setString-dai", function() return n:getContentSize() end)

	goi("7-dim200x0", function() return n:setDimensions(200, 0) end)
	goi("8-cs-sau-dim", function() return n:getContentSize() end)
	goi("9-dimdoc", function() return n:getDimensions() end)

	-- Cung be rong 200 nhung chu NGAN hon 200: phan biet "be rong O" voi
	-- "be rong DONG DAI NHAT".
	goi("10-setString-ngan", function()
		return n:setString("mot cau ngan thoi")
	end)
	goi("11-cs-dim200x0-chu-ngan", function() return n:getContentSize() end)

	-- O co ca chieu cao.
	goi("12-dim200x30", function() return n:setDimensions(200, 30) end)
	goi("13-cs-dim200x30-chu-ngan", function() return n:getContentSize() end)

	-- autoFixSize: chu CAO hon o.
	goi("14-dim100x40", function() return n:setDimensions(100, 40) end)
	goi("15-setString-dai2", function() return n:setString(DAI) end)
	goi("16-cs-truoc-fix", function() return n:getContentSize() end)
	goi("17-fix", function() return n:autoFixSize() end)
	goi("18-cs-sau-fix", function() return n:getContentSize() end)
	goi("19-scale-sau-fix", function() return n:getScaleX() end)
	goi("19b-scaleY-sau-fix", function() return n:getScaleY() end)

	-- autoFixSize khi chu VAN VUA trong o (khong duoc co nho lai).
	goi("20-dim300x200", function() return n:setDimensions(300, 200) end)
	goi("21-setString-ngan2", function() return n:setString("ngan") end)
	goi("22-fix2", function() return n:autoFixSize() end)
	goi("23-scale-sau-fix2", function() return n:getScaleX() end)
	goi("24-cs-sau-fix2", function() return n:getContentSize() end)

	-- "\\r\\n" trong setString.
	goi("25-crlf", function()
		return n:setString("a" .. string.char(13) .. string.char(10) .. "b")
	end)
	goi("26-str-crlf", function() return n:getString() end)
	goi("27-cs-crlf", function() return n:getContentSize() end)

	-- `copy()` — dung o CUIToolTips.lua:207.
	goi("28-copy", function() return n:copy() end)

	-- ================= LUOT 2: CONG THUC autoFixSize =================
	-- Ma may (0x2ca5ec..0x2ca66a) doc ra:
	--     s14 = (float)oRong;  if (natW > oRong) s14 = oRong/natW
	--     if (natH <= oCao) s14 = 1.0        <- quirk: bo luon ti le NGANG
	--     s15 = (natH > oCao) and oCao/natH or 1.0
	--     scale = min(s14, s15);  setScale(scale)
	-- Cau hoi con lai: natW/natH la GI. Bon ca duoi day tra loi.
	local MOT_TU = string.rep("A", 34)      -- mot tu dai, khong co dau cach de ngat

	-- (A) chu MOT DONG rong hon o (natH = mot dong <= oCao): quirk cho 1.0,
	--     con cong thuc "phai le" cho oRong/natW.
	goi("40-dim100x40", function() return n:setDimensions(100, 40) end)
	goi("41-set-mot-tu", function() return n:setString(MOT_TU) end)
	goi("42-cs-mot-tu", function() return n:getContentSize() end)
	goi("43-fix-mot-tu", function() return n:autoFixSize() end)
	goi("44-scale-mot-tu", function() return n:getScaleX() end)

	-- (B) chu NHIEU DONG cao hon o (natH > oCao): ti le DOC co bat khong?
	goi("45-dim400x40", function() return n:setDimensions(400, 40) end)
	goi("46-set-dai3", function() return n:setString(DAI) end)
	goi("47-cs-400x40", function() return n:getContentSize() end)
	goi("48-fix-400x40", function() return n:autoFixSize() end)
	goi("49-scale-400x40", function() return n:getScaleX() end)

	-- (C) o chi co be rong, chu vua: ti le NGANG co bat khong (natW so voi o)?
	goi("50-dim400x0", function() return n:setDimensions(400, 0) end)
	goi("51-cs-400x0", function() return n:getContentSize() end)
	goi("52-fix-400x0", function() return n:autoFixSize() end)
	goi("53-scale-400x0", function() return n:getScaleX() end)

	goi("54-dim100x0", function() return n:setDimensions(100, 0) end)
	goi("55-cs-100x0", function() return n:getContentSize() end)
	goi("56-fix-100x0", function() return n:autoFixSize() end)
	goi("57-scale-100x0", function() return n:getScaleX() end)

	-- (D) o RONG 0: nhan tu co gian theo chu (nhan tu co nhu labEliteName).
	goi("58-dim0x0", function() return n:setDimensions(0, 0) end)
	goi("59-cs-0x0-dai", function() return n:getContentSize() end)
	goi("60-dimdoc-0x0", function() return n:getDimensions() end)
	goi("61-set-ngan3", function() return n:setString("ngan") end)
	goi("62-cs-0x0-ngan", function() return n:getContentSize() end)
	goi("63-fix-0x0", function() return n:autoFixSize() end)
	goi("64-scale-0x0", function() return n:getScaleX() end)

	-- (E) o cao 0 nhung rong 0: chieu cao co thanh chieu cao chu khong.
	goi("65-dim0x40", function() return n:setDimensions(0, 40) end)
	goi("66-set-dai4", function() return n:setString(DAI) end)
	goi("67-cs-0x40", function() return n:getContentSize() end)

	-- Chieu cao DONG theo co chu (de doi chieu cong thuc 1.2 co chu).
	local FONT_TTF = GetStringWithKey("FONT_TTF")
	print("NHAN|font|" .. tostring(FONT_TTF))
	local ten_font = string.sub(FONT_TTF, 4, -1)
	for _, co in ipairs({ 12, 20, 40 }) do
		local l = Label:new()
		local okt = pcall(function() return l:createWithTTF("Ag", ten_font, co) end)
		goi("70-cs-co" .. tostring(co), function() return l:getContentSize() end)
	end

	-- ===== LUOT 3: nhan TAO LUC CHAY thi "o" la gi =====
	-- `createWithTTF` co ghi o (+0x2c4/+0x2c8) khong, hay o la 0 roi be rong
	-- lay theo chu? Cau nay quyet dinh `o_cua` phia Godot phai roi ve dau khi
	-- nhan khong co o .xgg (nhan bo cuc thi do duoc o = chinh o .xgg).
	local l4 = Label:new()
	local ten4 = string.sub(GetStringWithKey("FONT_TTF"), 4, -1)
	goi("80-ttf-dim-truoc", function() return l4:createWithTTF(DAI, ten4, 20) end)
	goi("81-ttf-dimdoc", function() return l4:getDimensions() end)
	goi("82-ttf-cs", function() return l4:getContentSize() end)
	goi("83-ttf-set-ngan", function() return l4:setString("ngan") end)
	goi("84-ttf-cs-sau-set", function() return l4:getContentSize() end)
	goi("85-ttf-dimdoc-sau-set", function() return l4:getDimensions() end)

	-- Co autoFix (+0x21c) co bi setDimensions xoa khong. Neu con thi o 300x200
	-- voi chu NGAN phai ra (300, 200) chu khong phai (44, 24).
	local l5 = Label:new()
	goi("86-fix-roi-doi-o", function()
		l5:createWithTTF(MOT_TU, ten4, 20)
		l5:setDimensions(100, 40)
		l5:autoFixSize()
		l5:setDimensions(300, 200)
		l5:setString("ngan")
		return l5:autoFixSize()
	end)
	goi("87-doi-o-roi-fix-cs", function() return l5:getContentSize() end)
	goi("88-doi-o-roi-fix-scale", function() return l5:getScaleX() end)

	-- ===== LUOT 4: setContentSize tren nhan BO CUC thi getContentSize tra gi =====
	-- `CUIAnniversaryHeaven.lua:277-284`: `setString("")` roi
	-- `setContentSize(0, 0)` de nhan ngay khong chiem cho trong `setLinearLayout`.
	-- Ma may 0x49bdcc chi thay rang setContentSize GHI cap float +0x5c/+0x60 (qua
	-- slot +0xb0), khong dung toi o +0x2c4. Cau hoi: cap vua ghi CO bi lan bo cuc
	-- ghi de khong (tuc setString da bat co "ban" chua, va ghi o co xoa co khong).
	goi("90-nap-lai", function() return loadLevelFile("conf/Pop_Dialog_UI_960_640.xgg") end)
	local l6 = rawget(_G, "ttfPopDialogTitle")
	goi("91-title-dim", function() return l6:getDimensions() end)
	goi("92-title-cs", function() return l6:getContentSize() end)
	goi("93-title-set-rong", function() return l6:setString("") end)
	goi("94-title-set-cs-0", function() return l6:setContentSize(0, 0) end)
	goi("95-title-cs-sau", function() return l6:getContentSize() end)
	goi("96-title-dim-sau", function() return l6:getDimensions() end)
	-- Lan hai: luc nay nhan da "sach" (95 vua bo cuc lai) — cap vua ghi co thang
	-- khong.
	goi("97-title-set-cs-0-lan2", function() return l6:setContentSize(0, 0) end)
	goi("98-title-cs-lan2", function() return l6:getContentSize() end)
	-- Va mot nhan .xgg KHONG bi ai dung toi, de doi chieu: ghi o roi doc lai.
	goi("99-title-set-cs-that", function() return l6:setContentSize(123, 45) end)
	goi("99b-title-cs-that", function() return l6:getContentSize() end)

	print("NHAN|het")
end
'''


def doc_nhan():
    txt = E.adb('logcat', '-d').stdout
    return [l for l in re.findall(r'NHAN\|[^\n\r]*', txt)]


def chay(han=180, cai=False):
    if not E.thiet_bi():
        raise SystemExit('khong thay may ao nao — bat emulator truoc')
    if cai:
        print('cai APK %s' % APK_VN)
        r = E.adb('install', '-r', '-d', str(APK_VN))
        print(r.stdout.strip()[-400:], r.stderr.strip()[-400:])
    sc_dir = E.build_overrides([('UI_Main_960_640.xgg', [])], HERE / '_emu',
                               PROBE, token='nhan')
    E.adb('shell', 'am', 'force-stop', E.PKG)
    for _ in range(20):
        if not E.adb('shell', 'pidof', E.PKG).stdout.strip():
            break
        time.sleep(0.5)
    E.adb('push', str(sc_dir / 'game.lua'), E.REMOTE + '/sc/game.lua')
    E.cap_quyen()
    E.adb('logcat', '-b', 'all', '-c')
    E.adb('shell', 'am', 'start', '-n', '%s/%s' % (E.PKG, E.ACT))
    cho = 0
    while cho < han:
        time.sleep(3)
        cho += 3
        lines = doc_nhan()
        if len(lines) >= 2 and lines[-1].startswith('NHAN|het'):
            return lines + ['(xong sau %ds)' % cho]
        if not E.adb('shell', 'pidof', E.PKG).stdout.strip() and cho >= 15:
            return doc_nhan() + ['(game chet sau %ds)' % cho]
    return doc_nhan() + ['(het gio %ds)' % han]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--cai', action='store_true', help='cai lai APK truoc khi chay')
    ap.add_argument('--han', type=int, default=180)
    a = ap.parse_args()
    for l in chay(a.han, a.cai):
        print(l)
    return 0


if __name__ == '__main__':
    sys.exit(main())
