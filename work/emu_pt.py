"""Do KIEU MAC DINH cua CCProgressTimer trong .xgg bang may ao Android.

    python emu_pt.py --nhanh nen          # canh Main tran (anh nen de doi chieu)
    python emu_pt.py --nhanh <ten>        # mot luot: lim100 | war100 | war30 | hud30
    python emu_pt.py                      # chay het cac luot roi doc lai anh
    python emu_pt.py --so                 # chi doc anh da chup, khong chay may ao

CAU HOI
-------
Ban ghi CCProgressTimer trong .xgg (256 byte) mang: % o +0xF8 (float), mot co
bool o +0xFC, ten anh o 0xEC, va **khong** mang kieu (bar / radial). Lua co ham
doi ten thanh ma (`setType`: ccw=1, cw=0, lr=2, rl=3, bt=4, tb=5), con
`initWithFile` (0x4c8f34) dat byte +0x1a0 = 0. Vay kieu MAC DINH cua mot node
trong .xgg la gi? Khong doan — do bang hinh ve.

PHAN BIET BANG HINH VE
----------------------
Cocos2d ve tien do bang mot da giac:

  * kieu BAR (lr/rl/bt/tb): o 100% da giac phu KIN ca o -> anh chu nhat w x h
  * kieu RADIAL (cw/ccw)   : hinh QUAT quanh diem giua, ban kinh
                             = MIN(w,h)/2 -> o 100% chi ra mot HINH TRON
                             duong kinh MIN(w,h), nam giua o

Nen o 100% cung phan biet duoc, va ti le o cang det thi cang ro: `UI_Load`
730x17, `UI_TimeLimitedHero` 860x14 — bar ra mot dai 860 diem, radial ra mot
cham 14 diem. Chieu cua bar (lr / rl / bt / tb) thi phai ha % xuong: 30% cho ra
dai 30% o mot MEP nao do, do la mep ma kieu bam vao.

CACH DO
-------
Anh `nen` la canh Main tran. Anh `<nhan>` la canh Main + mot bo cuc. Hieu hai
anh ra mat na (`|kenh| > 12`), roi trong CUA SO quanh cho dang le phai co o
tien do (toa do thiet ke tich luy tu goc .xgg, 1:1 voi diem man hinh, goc
duoi-trai — da do o emu_dom):
  * in mat na thu nho (moi ky tu = vai diem) de NHIN ra hinh dang
  * be rong theo TUNG HANG: chu nhat thi moi hang gan bang nhau, quat thi doi
    manh; va hai mep trai/phai cho biet no bam vao mep nao
  * khung bao cac diem DO trong cua so (thanh mau cua o tien do thuong la do)

DA DO DUOC, GHI LAI (2026-09-16)
--------------------------------
* `setVisible(true)` tren node .xgg lam ban dich ARM SIGSEGV (signal 11,
  SEGV_MAPERR, `GLThread`, `eip e840af70` trong `libndk_translation.so`,
  tombstone_10) — cung ho voi `setScale`, `create()`, `getChildrenCount`.
  Vi vay KHONG the bat hien goc bo cuc bang Lua: phai chon bo cuc ma CA CAY
  to tien deu `vis=True` trong .xgg. Do tren ca cay: 304 node tien do, trong do
  **22 node** co toan bo to tien (ke ca goc) hien san.
* `getType()` cung lam chet y nhu vay (do 2026-09-16: in xong
  `KI|nut|ptLoadingGamePercent|userdata` roi SIGSEGV ngay, fault addr
  0x64041ef1, `GLThread`). Nen phep do theo kieu (`--kieu`) khong hoi lai kieu
  bang `getType` ma do bang HINH VE.
* Vao luc nap, `loadLevelFile(file, sc)` co dang ky MOI node co TEN vao `_G`
  (do duoc: `lXingHunDetailDlg`, `lStarSoulMain`, `g_ptWarSoulTBar`, ... la
  userdata trong `_G`), nen node tien do CO TEN thi goi duoc tu Lua.
"""
import argparse
import pathlib
import re
import shutil
import struct
import sys
import time

import emu_tags as E
import emu_dom as D
import xgg

HERE = pathlib.Path(__file__).resolve().parent
ANH = HERE / '_pt'
SUA = ANH / 'sua'

# Moi luot: (file .xgg, ten node tien do trong _G ('' = khong goi), % dat vao
# (0 = khong dat), toa do THIET KE (cx, cy, w, h) cua o de mo cua so do).
#
# Chon bo cuc theo ba dieu kien DO DUOC, khong theo cam giac:
#   1. toan bo to tien (ke ca goc) `vis=True` trong .xgg — neu khong thi khong
#      ve duoc gi (va khong bat hien duoc, xem dau file)
#   2. ban ghi CO anh (o 0xEC khac rong) — khong anh thi khong ve gi ca
#   3. o co dang det (ti le canh lon) hoac CAO, de hinh dang doc ra ro
#
# PHEP DO CHINH khong phai "anh tru anh nen" ma la **100% tru 30%** (xem
# SO_SANH): hieu hai luot ay ra dung vung ma o tien do VE, khong dinh mau nen
# cua bang di kem — bo cuc nao cung keo theo ca mot bang lon, va tren bang do
# thi "khac voi canh Main" khong noi duoc gi ve o tien do.
LUOT = {
    # 178x28 o HUD chinh, anh 'v6/ui_blood_02.png', +0xFC=1
    #
    # Nhieu muc % tren CUNG mot o, de do HAM anh xa % -> be dai thanh, chu
    # khong doan no tuyen tinh: so 30% dau tien cho vung 22 diem tren khung
    # anh 126 diem (17,5%), khong khop 30% cua khung anh lan 30% cua o.
    'hud0': ('conf/UI_Main_ControlPanel_960_640.xgg', 'pMainUIHeroExp', 0.5,
             (281, 555, 178, 28)),
    'hud10': ('conf/UI_Main_ControlPanel_960_640.xgg', 'pMainUIHeroExp', 10,
              (281, 555, 178, 28)),
    # 15 va 20 de chot CHO BANG KHONG cua ham anh xa: mo hinh ti le cho 18,9 va
    # 25,2 diem, mo hinh "cheo" (W+H)*p/100 - H cho 1,1 va 8,4 diem. Khac nhau
    # xa hon sai so do (1-2 diem).
    'hud15': ('conf/UI_Main_ControlPanel_960_640.xgg', 'pMainUIHeroExp', 15,
              (281, 555, 178, 28)),
    'hud20': ('conf/UI_Main_ControlPanel_960_640.xgg', 'pMainUIHeroExp', 20,
              (281, 555, 178, 28)),
    'hud25': ('conf/UI_Main_ControlPanel_960_640.xgg', 'pMainUIHeroExp', 25,
              (281, 555, 178, 28)),
    'hud30': ('conf/UI_Main_ControlPanel_960_640.xgg', 'pMainUIHeroExp', 30,
              (281, 555, 178, 28)),
    'hud50': ('conf/UI_Main_ControlPanel_960_640.xgg', 'pMainUIHeroExp', 50,
              (281, 555, 178, 28)),
    'hud75': ('conf/UI_Main_ControlPanel_960_640.xgg', 'pMainUIHeroExp', 75,
              (281, 555, 178, 28)),
    'hud90': ('conf/UI_Main_ControlPanel_960_640.xgg', 'pMainUIHeroExp', 90,
              (281, 555, 178, 28)),
    'hud100': ('conf/UI_Main_ControlPanel_960_640.xgg', 'pMainUIHeroExp', 0,
               (281, 555, 178, 28)),
    # 71x297 — o CAO, anh 'v6/ui_background499.png', +0xFC=0
    'war0': ('conf/UI_WarSoul_960_640.xgg', 'g_ptWarSoulTBar', 0.5,
             (343.2, 542.2, 71, 297)),
    # war10/war60: cung cau hoi nhu hud15/hud20, nhung cho o CAO (kieu bt).
    #   ti le     : 10% -> 25 diem ; 60% -> 151 diem
    #   cheo doc  : (H+W)*p/100 - W -> 2,6 va 129 diem
    #   cheo ngang: (H+W)*p/100 - W cung the (chieu dai nam theo truc y)
    'war10': ('conf/UI_WarSoul_960_640.xgg', 'g_ptWarSoulTBar', 10,
              (343.2, 542.2, 71, 297)),
    'war60': ('conf/UI_WarSoul_960_640.xgg', 'g_ptWarSoulTBar', 60,
              (343.2, 542.2, 71, 297)),
    'war30': ('conf/UI_WarSoul_960_640.xgg', 'g_ptWarSoulTBar', 30,
              (343.2, 542.2, 71, 297)),
    'war100': ('conf/UI_WarSoul_960_640.xgg', 'g_ptWarSoulTBar', 0,
               (343.2, 542.2, 71, 297)),
}

# Cac phep hieu, moi phep tra loi mot cau khac nhau:
#
#   (<ten>0 , hundred)  -> vung o VE RA = CHINH khung anh cua no (o 0,5% gan
#                          nhu khong ve gi). Khong phu thuoc toa do do trong .xgg.
#   (<ten>0 , <ten>P)   -> vung CHI hien o P% = chinh cai P% ay, do tren khung
#                          anh vua do -> ra ham anh xa % -> be dai, va mep nao
#                          dung yen (mep dung yen la goc thanh).
SO_SANH = tuple([('hud0', 'hud' + str(p))
                 for p in (10, 15, 20, 25, 30, 50, 75, 90, 100)]
                + [('war0', 'war' + str(p)) for p in (10, 30, 60, 100)])

DUNG_CANH = '''
	local function buoc(ten, f)
		print("PT|" .. ten .. "|bat-dau")
		local ok, a = pcall(f)
		print("PT|" .. ten .. "|xong|" .. tostring(ok) .. "|" .. tostring(a))
		return ok, a
	end

	buoc("nap-main", function()
		return loadLevelFile("conf/UI_Main_960_640.xgg")
	end)
	local sc = rawget(_G, "g_MainUIScene")
	print("PT|canh|" .. tostring(sc))
	if sc == nil then
		print("PT|het|khong nap duoc bo cuc Main")
		return
	end
	buoc("replaceScene", function() return S_CCDirector:replaceScene(sc) end)
'''

DAU_DO_NEN = ('\n-- === CHEN DE DO: canh Main tran ===\n'
              'do\n' + DUNG_CANH + '''
	print("PT|san-sang")
end
''')

# `loadLevelFile(file, parent)`: CLevelLoader:LoadFiles goi dung dang hai tham
# so nay (CUIChapterList.lua:156). KHONG goi `setVisible` — no lam chet ban
# dich ARM (do o dau file), nen chi chon bo cuc co san to tien hien.
DAU_DO_BO_CUC = ('\n-- === CHEN DE DO: canh Main + mot bo cuc ===\n'
                 'do\n' + DUNG_CANH + '''
	buoc("nap-bo-cuc", function()
		return loadLevelFile("%(file)s", sc)
	end)

	-- Node tien do co TEN thi bo nap dang ky vao _G (do duoc). In KIỂU chu
	-- khong in gia tri: `tostring` tren userdata goi __tostring, chua do duoc
	-- la co chet khong.
	local ten = "%(ten)s"
	if ten ~= "" then
		local t = rawget(_G, ten)
		print("PT|nut|" .. ten .. "|" .. type(t))
		if t == nil then
			print("PT|thieu-nut|" .. ten)
		elseif %(pct)s > 0 then
			buoc("dat-phan-tram", function() return t:setPercentage(%(pct)s) end)
		end
	end
	print("PT|san-sang")
end
''')

MAN = (1280, 720)

# `setOrange` DOI CAI GI — do bang may ao, ba luot.
#
# Doc ma may da noi duoc CONG THUC. `CCProgressTimer::setOrange` (0x2bd1d0):
#
#     if (*(uint8*)(self + 0x1cc) == 0) return;        -- chua co sprite thi thoi
#     sprite = *(CCSprite**)(*(uint8**)(self + 0x1c8) + 0x1d8)   -- sprite BEN TRONG
#     sprite->setShaderProgram( b ? ten('ShaderPositionTextureColor_Orange')
#                                  : ten('ShaderPositionTextureColor') )
#
# (`setGray`, 0x2bd218, y het nhung ten `..._Gray`; ca hai deu KHONG ghi co `b`
# vao node, khac `CCSprite::setGray` 0x49d6d4 co `strb r1,[r0,#0x23b]`.) Nguon
# manh cua chuong trinh Orange o `.rodata 0x7cd0c1`:
#
#     gl_FragColor = texture2D(u_texture, v_texCoord) * v_fragmentColor;
#     gl_FragColor.r *= 0.9;  gl_FragColor.g *= 2.9;  gl_FragColor.b *= 0.0;
#
# Nhung doc ma KHONG noi duoc chuong trinh MAC DINH cua sprite dang la cai nao.
# Cau hoi do quan trong: sau cho goi nao cung co dang
# `if pt.setOrange then if GetLanguageName()=="en" then setOrange(true) else
# setOrange(false) end end`, nen ban tieng Viet di qua **dung nhanh false** —
# va neu mac dinh DA la 'ShaderPositionTextureColor' thi nhanh ay khong doi mot
# diem anh nao, tuc bo qua no la dung.
#
# Ba luot: khong goi gi / goi setOrange(true) / goi setOrange(false).
#   `tat` phai TRUNG `khong`  -> mac dinh da la chuong trinh ay
#   `bat` phai KHAC, va khac theo dung ba he so 0,9 / 2,9 / 0,0
LUOT_CAM = {
    'cam_khong': ('conf/UI_Main_ControlPanel_960_640.xgg', 'pMainUIHeroExp', ''),
    'cam_bat': ('conf/UI_Main_ControlPanel_960_640.xgg', 'pMainUIHeroExp',
                'setOrange(true)'),
    'cam_tat': ('conf/UI_Main_ControlPanel_960_640.xgg', 'pMainUIHeroExp',
                'setOrange(false)'),
}
# O tien do trong TOA DO THIET KE (goc duoi-trai), suy ra tu khung do duoc tren
# anh: `tat` vs `bat` khac nhau trong (270,139)-(395,159) = 126x21 diem anh, tuc
# thiet ke y = 719-159..719-139 = 560..580, x = 270..395. Truoc do hang so nay la
# (281, 555, 178, 28) — lech 51 diem theo x nen cua so cat mat dau ben phai cua
# thanh (x1=382 < 395), va moi con so doc trong cua so ay la thieu.
CAM_O = (332, 570, 126, 21)

DAU_DO_CAM = ('\n-- === CHEN DE DO: setOrange doi gi ===\n'
              'do\n' + DUNG_CANH + '''
	buoc("nap-bo-cuc", function()
		return loadLevelFile("%(file)s", sc)
	end)
	local ten = "%(ten)s"
	local t = rawget(_G, ten)
	print("PT|nut|" .. ten .. "|" .. type(t))
	if t == nil then
		print("PT|thieu-nut|" .. ten)
	else%(goi_dong)s
	end
	print("PT|san-sang")
end
''')

# Dong goi `setOrange` phai sinh o Python chu khong de trong khuon: khuon cu de
# nguyen `t:%%(goi)s` va khi `goi` rong thi ra `t:` — LOI CU PHAP LUA, va vi Lua
# phan tich ca doan truoc khi chay nen ca doan bi bo, khong mot dong `PT|` lan
# dong `CHEN|` nao duoc in. Do la ly do that cua `cam_khong` (log 2 byte, anh la
# man hinh khac) — khong phai may ao truot nhu da tuong.
def _cam_goi_dong(goi):
    if not goi:
        return ''
    return ('\n\t\tbuoc("goi-%s", function() return t:%s end)' % (goi, goi))

# Do hinh hoc cua CHINH node trong may ao: contentSize / position / percentage /
# scale. Can de biet khung anh do duoc (126x21) co phai contentSize khong, va
# ti le man hinh la bao nhieu — neu khong thi khong doi chieu duoc o +0x98 cua
# ban ghi voi hinh ve.
#
# Moi lenh mot dong co dau rieng: ban dich ARM chet ca tien trinh khi gap lenh
# khong co (da biet voi setVisible/setScale), va pcall KHONG bat duoc SIGSEGV,
# nen dau nao in ra duoc la biet ngay cho chet.
DAU_DO_SO = ('\n-- === CHEN DE DO: so do node ===\n'
             'do\n' + DUNG_CANH + '''
	buoc("nap-bo-cuc", function()
		return loadLevelFile("%(file)s", sc)
	end)
	local ten = "%(ten)s"
	local t = rawget(_G, ten)
	print("SO|nut|" .. ten .. "|" .. type(t))
	if t ~= nil then
		local ok, cs = pcall(function() return t:getContentSize() end)
		print("SO|contentSize|" .. tostring(ok) .. "|" .. type(cs) .. "|"
			.. (type(cs) == "number" and tostring(cs) or "?"))
		if ok and type(cs) == "userdata" then
			local _, w = pcall(function() return cs.width end)
			local _, h = pcall(function() return cs.height end)
			print("SO|wh|" .. tostring(w) .. "|" .. tostring(h))
		end
		local ok2, pos = pcall(function() return t:getPosition() end)
		print("SO|position|" .. tostring(ok2) .. "|" .. type(pos) .. "|"
			.. (type(pos) == "number" and tostring(pos) or "?"))
		if ok2 and type(pos) == "userdata" then
			local _, px = pcall(function() return pos.x end)
			local _, py = pcall(function() return pos.y end)
			print("SO|xy|" .. tostring(px) .. "|" .. tostring(py))
		end
		local ok3, pct = pcall(function() return t:getPercentage() end)
		print("SO|percentage|" .. tostring(ok3) .. "|" .. tostring(pct))
		local ok4, sx = pcall(function() return t:getScaleX() end)
		print("SO|scaleX|" .. tostring(ok4) .. "|" .. tostring(sx))
		local ok5, sy = pcall(function() return t:getScaleY() end)
		print("SO|scaleY|" .. tostring(ok5) .. "|" .. tostring(sy))
	end
	print("SO|san-sang")
end
''')

# Do `sngFixInfoReflash`: luat thi da doc ra tu disassembly (xem ROADMAP), nhung
# tam CON SO (info[+0x18..+0x34]) thi khong nam trong .xgg — ban ghi node lien
# mach, khong co bang an nao chen giua (da do: 33.472 ban ghi, 295 khoang >400
# byte deu la ban ghi cuoi -> section H). Nen so phai lay bang cach CHAY.
#
# Cach do, va vi sao no tra loi duoc: luat cho ba kieu neo moi truc
#   x kieu 1 (trai) : x = info[+0x20] + ax*sx
#   x kieu 2 (giua) : x = (pw-nw)*0.5 + ax + info[+0x30]
#   x kieu 3 (phai) : x = pw - (nw-ax)*sx - info[+0x24]
# Trong do `pw` la ben rong cua CHA (day la lMainBtnLayer). Vay doi ben rong cha
# tu 960 sang 1137,8 thi:
#   kieu 1 -> x KHONG doi            (cong thuc khong chua pw)
#   kieu 2 -> x tang 88,9
#   kieu 3 -> x tang 177,8
# Ba so cach nhau rat xa, nen doc ra ngay tu MOT phep do. Con so hieu chinh
# info[...] tinh duoc sau, tu phuong trinh cua dung kieu do.
#
# Doi ben rong thu hai (1300) de kiem lai: kieu 3 phai tang 340 so voi goc, va
# hieu chinh tinh tu hai phuong trinh phai TRUNG nhau — chi kieu dung moi trung.
#
# Goi `sngFixInfoReflash` o day an toan ve nguyen tac: chinh CSceneManager.lua
# :304-330 goi no cho lMainBtnLayer khi vao canh Main, tuc la no DA chay roi
# ngay luc nap bo cuc — nen no khong lam chet ban dich ARM.
#
# `getChildren` thi KHONG dung: do duoc la no lam ban dich ARM SIGSEGV, ma pcall
# khong bat duoc SIGSEGV. Nen danh sach con phai CHOT SAN theo layout_ref, va
# moi buoc in mot dong truoc khi goi (`buoc`), de biet chet o dau.
TEN_CON = ('lMainToolbarLeft', 'lFriendsChattingNocice', 'lMainToolbarLeftTop',
           'lMainToolbarRightBottom', 's9MainSmallChatting', 'g_levelTarget',
           'spMainUITheme_newYear_0', 'btnHideToolbar', 'btnChatting',
           'lMainToolbarRightButton', 'spMainUITheme_christmas_0',
           'lMainToolbarRightButtonMask', 'lMainToolbarTop',
           'lMainToolbarRightTop', 'lMainToolbarTest', 'lStateWarChatPanel',
           'lShotNode')

DAU_DO_REFLASH = ('\n-- === CHEN DE DO: sngFixInfoReflash ===\n'
                  'do\n' + DUNG_CANH + '''
	buoc("nap-bo-cuc", function()
		return loadLevelFile("conf/UI_Main_ControlPanel_960_640.xgg", sc)
	end)

	local lop = rawget(_G, "lMainBtnLayer")
	print("FI|lop|" .. type(lop))
	if type(lop) ~= "userdata" then
		print("FI|het|khong co lMainBtnLayer trong _G")
		print("PT|san-sang")
		return
	end

	local ten = {%(ten)s}

	-- Mo ta ket qua pcall ma KHONG in gia tri cua userdata: `tostring` tren
	-- userdata di qua `__tostring` cua ban dich, chua do duoc la no co chet
	-- khong. Nen chi in KIEU, va in gia tri voi nhung kieu an toan.
	local function mo_ta(r)
		local s = '|n=' .. #r
		for i = 1, #r do
			local t = type(r[i])
			s = s .. '|' .. i .. ':' .. t
			if t == 'number' or t == 'string' or t == 'boolean' or t == 'nil' then
				s = s .. '=' .. tostring(r[i])
			end
		end
		return s
	end

	local function kich_thuoc(obj)
		local r = {pcall(function() return obj:getContentSize() end)}
		if not r[1] then return 'pcall-loi', 'pcall-loi' end
		-- Duong 1: tra ve HAI SO (co ban dich xuat thang width, height).
		if type(r[2]) == 'number' and type(r[3]) == 'number' then
			return r[2], r[3]
		end
		-- Duong 2: tra ve doi tuong co truong .width/.height.
		if type(r[2]) == 'userdata' or type(r[2]) == 'table' then
			local a = r[2]
			local ok, w = pcall(function() return a.width end)
			if ok and type(w) == 'number' then
				local _, h = pcall(function() return a.height end)
				return w, h
			end
			local ok2, w2 = pcall(function() return a:width() end)
			if ok2 and type(w2) == 'number' then
				local _, h2 = pcall(function() return a:height() end)
				return w2, h2
			end
		end
		return 'khong-doc-duoc', 'khong-doc-duoc'
	end

	local function vi_tri(obj)
		local r = {pcall(function() return obj:getPosition() end)}
		if not r[1] then return 'pcall-loi', 'pcall-loi' end
		if type(r[2]) == 'number' and type(r[3]) == 'number' then
			return r[2], r[3]
		end
		if type(r[2]) == 'userdata' or type(r[2]) == 'table' then
			local p = r[2]
			local ok, x = pcall(function() return p.x end)
			if ok and type(x) == 'number' then
				local _, y = pcall(function() return p.y end)
				return x, y
			end
			local ok2, x2 = pcall(function() return p:getX() end)
			if ok2 and type(x2) == 'number' then
				local _, y2 = pcall(function() return p:getY() end)
				return x2, y2
			end
		end
		return 'khong-doc-duoc', 'khong-doc-duoc'
	end

	-- In kieu tra ve MOT lan. Moi lenh mot pcall RIENG: ban dich ARM chet ca
	-- tien trinh khi gap lenh khong co, va pcall KHONG bat duoc SIGSEGV — nen
	-- dong nao in ra duoc la biet ngay dong sau chet.
	print("FI|kieu|getContentSize" .. mo_ta({pcall(function() return lop:getContentSize() end)}))
	print("FI|kieu|getPosition" .. mo_ta({pcall(function() return lop:getPosition() end)}))

	local function doc(nhan)
		local w, h = kich_thuoc(lop)
		print("FI|" .. nhan .. "|lMainBtnLayer|" .. tostring(w) .. "|" .. tostring(h))
		for i = 1, #ten do
			local t = rawget(_G, ten[i])
			if t == nil then
				print("FI|" .. nhan .. "|" .. ten[i] .. "|thieu")
			else
				local x, y = vi_tri(t)
				local nw, nh = kich_thuoc(t)
				print("FI|" .. nhan .. "|" .. ten[i] .. "|" .. tostring(x) .. "|"
					.. tostring(y) .. "|" .. tostring(nw) .. "|" .. tostring(nh))
			end
		end
	end

	doc("truoc")
	buoc("dat-1137", function() return lop:setContentSize(1137.8, 640) end)
	buoc("reflash-1137", function() return lop:sngFixInfoReflash() end)
	doc("sau1137")
	-- Buoc hai doi CA HAI ben: ben rong 1137,8 -> 1300 (+162,2) va ben cao
	-- 640 -> 800 (+160). Nho vay truc y cung co phuong trinh, va hai ben doi
	-- KHAC nhau nen nghiem cua truc nay khong lan sang truc kia.
	buoc("dat-1300-800", function() return lop:setContentSize(1300, 800) end)
	buoc("reflash-1300-800", function() return lop:sngFixInfoReflash() end)
	doc("sau1300")
	-- Do `getPositionX` o CUOI: neu no lam chet ban dich thi cac phep do tren
	-- da in xong het roi. Day la duong doc vi tri re nhat (tra ve so tran),
	-- nhung chua do duoc la co ton tai trong ban dich khong.
	print("FI|kieu|getPositionX" .. mo_ta({pcall(function() return lop:getPositionX() end)}))
	print("FI|san-sang")
	print("PT|san-sang")
end
''')

# CONG KICH HOAT. Phep do reflash tren lMainBtnLayer da ra duoc cong thuc hai
# truc, nhung ca 17 node do deu co kieu X khac 0. Ca kho con 2.302 node
# (6,9%) co kieu X = 0 ma kieu Y khac 0 — chung co duoc doi cho theo truc Y
# khong, hay bi chan? Doc ma dich thi thay mot phep kiem `+0x1C != 0` (tuc la
# kieu X, o ban sao luc chay), va neu do la cong THI 2.302 node kia dung yen.
# Khong doan: doi kich thuoc cha cua dung nhung node do roi doc lai.
#
# Chon node co DICH khac 0 (o +0x48 / +0x54) de khong the lan voi "cha to ra
# thi con cung to ra": bon nut dieu huong cua UI_Equipment co dich 15 va 20
# diem, va g_UpgradeQualityActionBeginLayer co dich 49.
#
# Do luon cot +0x54 (dich cua kieu Y 2), thu ma lMainBtnLayer khong co mau nao
# vi moi dich cua no deu bang 0: ca kho chi co DUNG MOT node kieu Y 2 ma dich
# khac 0 — lUIHuangJinRuQinBattleLeftTime (kieu X 3, kieu Y 2, dich 25 va 55).
# Node do co kieu X khac 0 nen phep doc nay doc lap voi cau hoi cong.
#
# Va do luon kieu Y 2 / Y 1 voi ANCHOR khac 0,5 de biet `s` nam trong hay
# ngoai ngoac: bon nut dieu huong co scale 0,8 (nen phan biet duoc), con
# g_UpgradeQualityActionBeginLayer co anchor (0,0).
DAU_DO_CONG = ('\n-- === CHEN DE DO: cong kich hoat + cot dich ===\n'
               'do\n' + DUNG_CANH + '''
	local function kich_thuoc(obj)
		local r = {pcall(function() return obj:getContentSize() end)}
		if not r[1] then return 'pcall-loi', 'pcall-loi' end
		if type(r[2]) == 'number' and type(r[3]) == 'number' then
			return r[2], r[3]
		end
		if type(r[2]) == 'userdata' or type(r[2]) == 'table' then
			local a = r[2]
			local ok, w = pcall(function() return a.width end)
			if ok and type(w) == 'number' then
				local _, h = pcall(function() return a.height end)
				return w, h
			end
		end
		return 'khong-doc-duoc', 'khong-doc-duoc'
	end

	local function vi_tri(obj)
		local r = {pcall(function() return obj:getPosition() end)}
		if not r[1] then return 'pcall-loi', 'pcall-loi' end
		if type(r[2]) == 'number' and type(r[3]) == 'number' then
			return r[2], r[3]
		end
		return 'khong-doc-duoc', 'khong-doc-duoc'
	end

	-- So muc o dau dong de doc ra duoc: 7 muc, moi muc co "truoc" va "sau",
	-- nen chi co nhan khong thi muc sau de len muc truoc.
	local function doc(k, ten_cha, con, nhan)
		local lop = rawget(_G, ten_cha)
		if type(lop) ~= "userdata" then
			print("FI|cong|" .. k .. "|" .. nhan .. "|" .. ten_cha .. "|thieu-lop")
			return
		end
		local pw, ph = kich_thuoc(lop)
		print("FI|cong|" .. k .. "|" .. nhan .. "|" .. ten_cha .. "|"
			.. tostring(pw) .. "|" .. tostring(ph))
		for i = 1, #con do
			local t = rawget(_G, con[i])
			if t == nil then
				print("FI|cong|" .. k .. "|" .. nhan .. "|" .. con[i] .. "|thieu")
			else
				local x, y = vi_tri(t)
				local cw, ch = kich_thuoc(t)
				print("FI|cong|" .. k .. "|" .. nhan .. "|" .. con[i] .. "|"
					.. tostring(x) .. "|" .. tostring(y) .. "|"
					.. tostring(cw) .. "|" .. tostring(ch))
			end
		end
	end

	-- Moi muc: {file, lop cha, ben rong moi, ben cao moi, {con...}}
	--
	-- HAI muc Game_UI_Control_Panel da BO: `loadLevelFile` tren file do khong
	-- chay xong trong may ao (do hai lan: dung ngay sau dong
	-- `nap-lUIHuangJinRuQin|bat-dau`, khong co dong `xong`, khong co tombstone).
	-- Phan "node goc cua file" — thu ma hai muc do dinh do — da duoc phep do
	-- `--o54` phu, va o do khong can file Game_UI.
	local muc = {
		{"conf/UI_Equipment_960_640.xgg", "lEquipmentForgeUI", 410, 640,
			{"btnEquipForgeUINavigation2", "btnEquipForgeUINavigation3"}},
		{"conf/UI_Equipment_960_640.xgg", "lEquipUpgradeQualityCompoundUI", 410, 640,
			{"btnEquipUpgradeQualityCompoundNavigation2",
			 "btnEquipUpgradeQualityCompoundNavigation3"}},
		{"conf/UI_Equipment_960_640.xgg", "lEquipUpgradeQualityMainUI", 410, 640,
			{"g_UpgradeQualityActionBeginLayer"}},
		{"conf/UI_Equipment_960_640.xgg", "nodeEquipmentUI_CritIntensifyLevel", 40, 80,
			{"nodeEquipmentUI_CritIntensifyLevel_1"}},
		{"conf/UI_Hero_960_640.xgg", "spDlgUpgradeHeroStarSkill", 764, 250,
			{"spDlgUpgradeHeroStarInfoUpIcon5"}},
	}
	for k = 1, #muc do
		local m = muc[k]
		buoc("nap-" .. m[2], function() return loadLevelFile(m[1], sc) end)
		doc(k, m[2], m[5], "truoc")
		buoc("dat-" .. m[2], function()
			local lop = rawget(_G, m[2])
			return lop:setContentSize(m[3], m[4])
		end)
		buoc("reflash-" .. m[2], function()
			local lop = rawget(_G, m[2])
			return lop:sngFixInfoReflash()
		end)
		doc(k, m[2], m[5], "sau")
	end
	print("FI|san-sang")
	print("PT|san-sang")
end
''')

# DAU CUA COT +0x54 (dich cua kieu Y 2).
#
# Ca kho co 117 node kieu Y 2 ma dich khac 0, nhung **116 node trong so do la
# node goc cua mot file** — cha cua chung la mot node khong ten, va ban ghi cua
# no ghi 0x0 (CCLayer khong luu ben; luc chay no lay ben cua man). Chi DUNG MOT
# node vua kieu Y 2 vua co dich khac 0 vua co cha CO TEN:
# lUIHuangJinRuQinBattleLeftTime (UI_..._HuangJinRuQin), ma file do nap khong
# xong trong may ao (do roi: dung sau dong `nap-lUIHuangJinRuQin|bat-dau`).
#
# Nen do bang duong khac: node goc cua UI_Hero la lHeroInfoUI (960x570, anchor
# (0,0), kieu (2,2), dich 54 = -25). Doc vi tri cua no NGAY LUC NAP, roi doi
# ben cua CHINH CANH (`sc`) va reflash — nhu vay ben cua cha la so MINH dat,
# khong phai suy doan. Cong thuc cho y = (ph - h)/2 + ay + 54, nen:
#   neu +54: y = (ph - 570)/2 + 0 - 25
#   neu -54: y = (ph - 570)/2 + 0 + 25
# Hai gia thuyet lech nhau dung 50 diem, va ph do duoc ngay trong phep do.
#
# Doc ca `lStarSoulMain` (UI_StarSoul, kieu (2,2), dich 54 = -25) lam mau thu
# hai: cung dich, khac ben, nen doi chieu duoc voi nhau.
DAU_DO_O54 = ('\n-- === CHEN DE DO: dau cua cot +0x54 ===\n'
              'do\n' + DUNG_CANH + '''
	local function kich_thuoc(obj)
		local r = {pcall(function() return obj:getContentSize() end)}
		if not r[1] then return 'pcall-loi', 'pcall-loi' end
		if type(r[2]) == 'number' and type(r[3]) == 'number' then
			return r[2], r[3]
		end
		return 'khong-doc-duoc', 'khong-doc-duoc'
	end

	local function vi_tri(obj)
		local r = {pcall(function() return obj:getPosition() end)}
		if not r[1] then return 'pcall-loi', 'pcall-loi' end
		if type(r[2]) == 'number' and type(r[3]) == 'number' then
			return r[2], r[3]
		end
		return 'khong-doc-duoc', 'khong-doc-duoc'
	end

	local function doc(ten, nhan)
		local t = rawget(_G, ten)
		if t == nil then
			print("FI|o54|" .. nhan .. "|" .. ten .. "|thieu")
			return
		end
		local x, y = vi_tri(t)
		local w, h = kich_thuoc(t)
		local sw, sh = kich_thuoc(sc)
		print("FI|o54|" .. nhan .. "|" .. ten .. "|" .. tostring(x) .. "|"
			.. tostring(y) .. "|" .. tostring(w) .. "|" .. tostring(h) .. "|"
			.. tostring(sw) .. "|" .. tostring(sh))
	end

	-- Doi ben cua chinh CANH: `sc` la node cha cua lop goc, nen day la cho dat
	-- ben cha bang mot so MINH biet truoc.
	buoc("nap-hero", function()
		return loadLevelFile("conf/UI_Hero_960_640.xgg", sc)
	end)
	doc("lHeroInfoUI", "hero-luc-nap")
	local buoc_sc = {960, 640, 960, 800, 1137.8, 768}
	for k = 1, #buoc_sc, 2 do
		local w, h = buoc_sc[k], buoc_sc[k + 1]
		buoc("dat-canh-" .. w .. "x" .. h, function() return sc:setContentSize(w, h) end)
		buoc("reflash-canh-" .. w .. "x" .. h, function() return sc:sngFixInfoReflash() end)
		doc("lHeroInfoUI", "hero-at-" .. w .. "x" .. h)
	end

	buoc("nap-starsoul", function()
		return loadLevelFile("conf/UI_StarSoul_960_640.xgg", sc)
	end)
	doc("lStarSoulMain", "starsoul")

	-- Mau co dich 54 DUONG: lQQCoinsGift (840x570, anchor (0,0), kieu (2,2),
	-- 54 = +25). Ba mau tren deu co 54 = -25, nen chung khong phan biet duoc
	-- "cong so co dau" voi "tru gia tri tuyet doi" — hai gia thuyet do chi lech
	-- nhau khi 54 duong. O ben canh 960x640: cong -> 35 + 25 = 60, tru -> 10.
	buoc("nap-qqcoins", function()
		return loadLevelFile("conf/UI_QQCoinsGift_960_640.xgg", sc)
	end)
	for _, wh in ipairs({{960, 640}, {960, 800}}) do
		buoc("dat-canh-q-" .. wh[1] .. "x" .. wh[2], function()
			return sc:setContentSize(wh[1], wh[2])
		end)
		buoc("reflash-canh-q-" .. wh[1] .. "x" .. wh[2], function()
			return sc:sngFixInfoReflash()
		end)
		doc("lQQCoinsGift", "qq-at-" .. wh[1] .. "x" .. wh[2])
	end

	print("FI|san-sang")
	print("PT|san-sang")
end
''')


# KIEU 0 NGHIA LA GI: "de yen" hay "dat lai ve so trong ban ghi"?
# Hai cach doc nay khong phan biet duoc bang phep do reflash thong thuong: luc
# nap, node kieu 0 dang o dung so trong ban ghi, nen dat lai hay de yen deu ra
# cung mot ket qua. Nhung doi voi ban port thi khac han nhau — neu la "dat lai"
# thi moi lan reflash se keo moi node kieu 0 ve cho thiet ke, de len ca nhung
# cho ma ma game da tu doi (action, keo tha).
#
# Nen phep do phai DAY node kieu 0 ra mot cho khac han TRUOC, roi moi reflash:
#   * o lai -777     -> kieu 0 la "de yen"
#   * ve lai 171     -> kieu 0 la "dat lai theo ban ghi"
#
# Do ca mot node kieu X = 1 (btnEquipForgeUINavigation1, dich X 25) lam chung:
# no PHAI nhay theo cong thuc, neu khong thi phep do khong chung minh duoc gi.
#
# Trong danh sach con co `g_EquipForgeUIEffectSmaillIconBg` — node CHAU (con cua
# btnEquipForgeUINavigation1, kieu (2,2), dich X 20). No tra loi mot cau hoi
# nua: reflash co di xuong cac doi chau khong? Cung meo day-di-roi-xem: neu no
# ve lai cho cong thuc (tinh theo ben cua cha no, 79x79 khong doi) thi co di
# xuong; neu van o -777 thi reflash chi dat con TRUC TIEP.
DAU_DO_KIEU0 = ('\n-- === CHEN DE DO: kieu 0 la de yen hay dat lai ===\n'
                'do\n' + DUNG_CANH + '''
	local function kich_thuoc(obj)
		local r = {pcall(function() return obj:getContentSize() end)}
		if not r[1] then return 'pcall-loi', 'pcall-loi' end
		if type(r[2]) == 'number' and type(r[3]) == 'number' then
			return r[2], r[3]
		end
		return 'khong-doc-duoc', 'khong-doc-duoc'
	end

	local function vi_tri(obj)
		local r = {pcall(function() return obj:getPosition() end)}
		if not r[1] then return 'pcall-loi', 'pcall-loi' end
		if type(r[2]) == 'number' and type(r[3]) == 'number' then
			return r[2], r[3]
		end
		return 'khong-doc-duoc', 'khong-doc-duoc'
	end

	local ten = {"btnEquipForgeUINavigation1", "btnEquipForgeUINavigation2",
	             "btnEquipForgeUINavigation3",
	             "g_EquipForgeUIEffectSmaillIconBg"}
	local function doc(nhan)
		local lop = rawget(_G, "lEquipmentForgeUI")
		local pw, ph = kich_thuoc(lop)
		print("FI|k0|" .. nhan .. "|lEquipmentForgeUI|" .. tostring(pw) .. "|" .. tostring(ph))
		for i = 1, #ten do
			local t = rawget(_G, ten[i])
			if t == nil then
				print("FI|k0|" .. nhan .. "|" .. ten[i] .. "|thieu")
			else
				local x, y = vi_tri(t)
				local w, h = kich_thuoc(t)
				print("FI|k0|" .. nhan .. "|" .. ten[i] .. "|" .. tostring(x) .. "|"
					.. tostring(y) .. "|" .. tostring(w) .. "|" .. tostring(h))
			end
		end
	end

	buoc("nap-0", function()
		return loadLevelFile("conf/UI_Equipment_960_640.xgg", sc)
	end)
	doc("truoc")
	-- Day di bang setPosition: neu lenh nay khong co trong ban dich thi dong
	-- `0-day` in ra dung so cu, va ca phep do vo nghia — nhin la biet ngay.
	buoc("day-di", function()
		for i = 1, #ten do
			local t = rawget(_G, ten[i])
			if t ~= nil then t:setPosition(-777, -888) end
		end
	end)
	doc("day")
	buoc("dat-0", function()
		return rawget(_G, "lEquipmentForgeUI"):setContentSize(700, 800)
	end)
	buoc("reflash-0", function()
		return rawget(_G, "lEquipmentForgeUI"):sngFixInfoReflash()
	end)
	doc("sau")
	print("FI|san-sang")
	print("PT|san-sang")
end
''')


# KIEU 2 VA KIEU 3, VA BA COT DICH CON LAI (o44, o4C, o50) — do co GIÃN.
#
# Bon phep do truoc da chot: kieu 0 de yen, khong co cong kich hoat, +0x54 la
# phep cong co dau, va ham de quy xuong chau. Nhung chung moi chot o40 (kieu X
# 1), o48 (kieu Y 1), o54 (kieu Y 2), va deu o scale = 1 hoac chi mot truc co
# scale. Bon cho con ho:
#
#   * o44 (kieu X 3) va o4C (kieu Y 3): **chua do lan nao**. Ca kho co 65 node
#     kieu X 3 va 104 node kieu Y 3 co cot do khac 0, nhung phai chon node CO
#     TEN va co CHA CO TEN thi moi dat lai ben cha bang Lua duoc.
#   * o50 (kieu X 2): chi 3 node co ca ten lan cha co ten.
#   * Kich thuoc trong cong thuc la kich thuoc DA co gian: moi do duoc tren
#     truc X (nav1: 25 + 39,5*0,8 = 56,6). Truc Y thi phep do `--kieu0` doc ra
#     753,4 nhung chinh vi_tri_theo_cong_thuc cu tinh ra 737,6 — lech dung
#     h - h*scale = 15,8. Nen phai do lai truc Y o scale khac 1.
#
# Cach do: KHONG doi ben canh, ma doi ben cua CHINH LOP CHA. Do la ben ma cong
# thuc thuc su doc, nen biet truoc so roi van kiem duoc cong thuc. Doi ca ben
# rong lan ben cao de hai truc co phuong trinh rieng.
#
# Sau moi lan doi ben thi reflash tu CANH (`sc`), khong reflash lop cha: lop cha
# cung la mot node co kieu rieng, reflash no thi no tu doi cho theo cha no nua,
# va phep do that kho doc hon.
DAU_DO_KIEU23 = ('\n-- === CHEN DE DO: kieu 2, kieu 3, va cot dich con lai ===\n'
                 'do\n' + DUNG_CANH + '''
	local function kich_thuoc(obj)
		local r = {pcall(function() return obj:getContentSize() end)}
		if not r[1] then return 'pcall-loi', 'pcall-loi' end
		if type(r[2]) == 'number' and type(r[3]) == 'number' then
			return r[2], r[3]
		end
		return 'khong-doc-duoc', 'khong-doc-duoc'
	end

	local function vi_tri(obj)
		local r = {pcall(function() return obj:getPosition() end)}
		if not r[1] then return 'pcall-loi', 'pcall-loi' end
		if type(r[2]) == 'number' and type(r[3]) == 'number' then
			return r[2], r[3]
		end
		return 'khong-doc-duoc', 'khong-doc-duoc'
	end

	local function doc(k, ten_cha, con, nhan)
		local lop = rawget(_G, ten_cha)
		if type(lop) ~= "userdata" then
			print("FI|k23|" .. k .. "|" .. nhan .. "|" .. ten_cha .. "|thieu-lop")
			return
		end
		local pw, ph = kich_thuoc(lop)
		print("FI|k23|" .. k .. "|" .. nhan .. "|" .. ten_cha .. "|"
			.. tostring(pw) .. "|" .. tostring(ph))
		for i = 1, #con do
			local t = rawget(_G, con[i])
			if t == nil then
				print("FI|k23|" .. k .. "|" .. nhan .. "|" .. con[i] .. "|thieu")
			else
				local x, y = vi_tri(t)
				local cw, ch = kich_thuoc(t)
				print("FI|k23|" .. k .. "|" .. nhan .. "|" .. con[i] .. "|"
					.. tostring(x) .. "|" .. tostring(y) .. "|"
					.. tostring(cw) .. "|" .. tostring(ch))
			end
		end
	end

	-- {file, lop cha, ben rong moi, ben cao moi, {con...}}
	--
	-- Sau so la so cua ban ghi .xgg, doc bang `work/fix_info.py --in`, ghi lai
	-- day de doc gia thiet TRUOC khi do (thu tu k=(kieu X, kieu Y)):
	--   lEquipmentUI 880x570 -> 1000x700
	--     btnHeroEquipUIToRight (k=(3,2), scale -1,1, 56x83, o44=28)
	--   lEquipUpgradeQualityMainUI 410x550 -> 500x650
	--     g_UpgradeQualityActionMaterialItem (k=(2,0), scale 0,8, 79x79)
	--     g_UpgradeQualityActionBeginLayer (k=(0,1), 40x40, o48=49)
	--   g_UpgradeQualityActionBeginLayer 40x40 -> 60x90
	--     g_UpgradeQualityActionItemIcon (k=(1,3), scale 0,8, 79x79)
	--   lNormalLoginUI 960x640 -> 1100x760
	--     snsQuickEnter (k=(2,3), 152x79, o4C=20, o50=-152)
	--   g_LoginUIScene 960x640 -> 1100x760
	--     btnLoginOpenProtocol (k=(3,2), 245x75, o44=20, o4C=100)
	--     ttfLoginUISceneVer (k=(3,1), 300x30, o44=20, o48=15)
	--   lLoginServerListUI 960x640 -> 1100x760
	--     g_ServerNodesLayer (k=(0,3), 540x448, o4C=50)
	--
	-- HAI muc CUOI tra loi mot cau hoi rieng: kieu 2 co nhan kich thuoc DA co
	-- gian khong? Voi neo 0,5 thi khong phan biet duoc — (pw-w*sx)/2 + w*sx/2 =
	-- pw/2, y het nhu khi khong nhan. Nen phai tim node neo KHAC 0,5 VA scale
	-- khac 1; ca kho chi co DUNG HAI node nhu vay co ten va cha co ten:
	--   lHeroInfoUIDetails (UI_Hero, k=(1,2), neo (0,0), scale 0,98, 404x550,
	--     cha lHeroInfoUILeft 420x570). Y kieu 2: co gian -> (570-539)/2 =
	--     15,5 ; khong gian -> (570-550)/2 = 10.
	--   lCUICOGMap (UI_COG, k=(2,2), neo (0,0), scale 0,8, 2850x2235, cha
	--     lCOGUI 960x640). X co gian -> (960-2280)/2 = -660 ; khong gian ->
	--     -945. Y co gian -> -574 ; khong gian -> -797,5.
	local muc = {
		{"conf/UI_Equipment_960_640.xgg", "lEquipmentUI", 1000, 700,
			{"btnHeroEquipUIToRight"}},
		{"conf/UI_Equipment_960_640.xgg", "lEquipUpgradeQualityMainUI", 500, 650,
			{"g_UpgradeQualityActionMaterialItem",
			 "g_UpgradeQualityActionBeginLayer"}},
		{"conf/UI_Equipment_960_640.xgg", "g_UpgradeQualityActionBeginLayer", 60, 90,
			{"g_UpgradeQualityActionItemIcon"}},
		-- File dang nhap co the khong nap xong (nhu Game_UI_Control_Panel); ba
		-- muc duoi day nam CUOI nen ba muc tren van do duoc nguyen ven.
		{"conf/UI_AccountLogin_960_640.xgg", "lNormalLoginUI", 1100, 760,
			{"snsQuickEnter"}},
		{"conf/UI_AccountLogin_960_640.xgg", "g_LoginUIScene", 1100, 760,
			{"btnLoginOpenProtocol", "ttfLoginUISceneVer"}},
		{"conf/UI_AccountLogin_960_640.xgg", "lLoginServerListUI", 1100, 760,
			{"g_ServerNodesLayer"}},
		{"conf/UI_Hero_960_640.xgg", "lHeroInfoUILeft", 520, 700,
			{"lHeroInfoUIDetails"}},
		{"conf/UI_COG_960_640.xgg", "lCOGUI", 1100, 760, {"lCUICOGMap"}},
	}
	for k = 1, #muc do
		local m = muc[k]
		buoc("nap-" .. k, function() return loadLevelFile(m[1], sc) end)
		doc(k, m[2], m[5], "truoc")
		buoc("dat-" .. k, function()
			local lop = rawget(_G, m[2])
			return lop:setContentSize(m[3], m[4])
		end)
		buoc("reflash-" .. k, function() return sc:sngFixInfoReflash() end)
		doc(k, m[2], m[5], "sau")
	end
	print("FI|san-sang")
	print("PT|san-sang")
end
''')


# So do thiet ke cua con lMainBtnLayer, lay tu layout_ref (khong sua tay): dung
# de tinh xem reflash da doi cho nao va doi bao nhieu.
BO_CUC_CON = {
    'lMainToolbarLeft': (0.0, 240.0, 80.0, 250.0),
    'lFriendsChattingNocice': (295.0, 120.0, 370.0, 120.0),
    'lMainToolbarLeftTop': (0.0, 110.0, 150.0, 530.0),
    'lMainToolbarRightBottom': (820.0, 15.0, 130.0, 250.0),
    's9MainSmallChatting': (200.0, 45.0, 400.0, 90.0),
    'g_levelTarget': (780.0, 150.0, 180.0, 290.0),
    'spMainUITheme_newYear_0': (459.0, 602.167, 0.0, 0.0),
    'btnHideToolbar': (65.0, 64.0, 98.0, 98.0),
    'btnChatting': (27.0, 58.0, 58.0, 77.0),
    'lMainToolbarRightButton': (902.15, 386.4, 110.0, 560.0),
    'spMainUITheme_christmas_0': (459.0, 602.167, 0.0, 0.0),
    'lMainToolbarRightButtonMask': (-203.0, -64.0, 1366.0, 768.0),
    'lMainToolbarTop': (0.0, 0.0, 960.0, 640.0),
    'lMainToolbarRightTop': (280.0, 504.0, 480.0, 80.0),
    'lMainToolbarTest': (7.762, 15.0, 600.0, 100.0),
    'lStateWarChatPanel': (160.0, 90.0, 320.0, 180.0),
    'lShotNode': (439.298, 353.735, 40.0, 40.0),
}


def doc_reflash(dong):
    """Doc ket qua phep do reflash: ra KIEU NEO va so hieu chinh tung truc.

    Chuan doi chieu la so THIET KE trong layout_ref, khong phai mot con so nao
    cua phep do. Ba muc do la ba ben cua lop cha:
        truoc      pw=960    ph=640    (= lop cha luc nap, chua reflash)
        sau1137    pw=1137,8 ph=640
        sau1300    pw=1300   ph=800

    Doi ben rong them d thi x cua mot node neo:
        kieu 1 (trai)  : doi 0
        kieu 2 (giua)  : doi d/2
        kieu 3 (phai)  : doi d
    Ba gia tri cach nhau du xa de doc ra, va ben cao cua lop cha o muc thu ba
    cung doi — nen truc y co phuong trinh rieng.
    """
    o = {'truoc': {}, 'sau1137': {}, 'sau1300': {}}
    for d in dong:
        p = d.split('|')
        if len(p) < 4 or p[0] != 'FI':
            continue
        nhan = p[1]
        if nhan == 'kieu':
            print('  %s' % d)
            continue
        if nhan not in o:
            continue
        if p[2] == 'lMainBtnLayer':
            if len(p) >= 5:
                try:
                    o[nhan]['LOP'] = (float(p[3]), float(p[4]))
                except ValueError:
                    pass
            continue
        if p[2] == 'thieu' or len(p) < 7:
            print('  %-28s THIEU trong _G' % p[2])
            continue
        try:
            o[nhan][p[2]] = (float(p[3]), float(p[4]), float(p[5]), float(p[6]))
        except ValueError:
            pass

    for nhan in ('truoc', 'sau1137', 'sau1300'):
        if 'LOP' in o[nhan]:
            print('  lop cha %-9s contentSize = %.3f x %.3f'
                  % (nhan, o[nhan]['LOP'][0], o[nhan]['LOP'][1]))

    if not o['truoc'] or 'LOP' not in o['truoc'] or 'LOP' not in o['sau1137']:
        print('khong doc duoc dong FI| nao co so')
        return
    dw = o['sau1137']['LOP'][0] - o['truoc']['LOP'][0]
    dh = o['sau1137']['LOP'][1] - o['truoc']['LOP'][1]
    print('  ben lop cha doi: rong %+.3f, cao %+.3f' % (dw, dh))
    print()
    print('%-28s %9s %9s %9s %9s | %7s %7s %s' %
          ('node', 'tk.x', 'tk.y', 'x@960', 'x@1137', 'dx', 'dy', 'kieu x'))
    for ten, (tx, ty, tw, th) in BO_CUC_CON.items():
        t = o['truoc'].get(ten)
        s = o['sau1137'].get(ten)
        if t is None or s is None:
            print('%-28s khong co trong log' % ten)
            continue
        dx = s[0] - t[0]
        dy = s[1] - t[1]
        # Kieu neo doc ra tu ty so dx/dw — khong phu thuoc so hieu chinh.
        if abs(dx) < 0.75:
            kx = '1 trai'
        elif abs(dx - dw / 2) < 0.75:
            kx = '2 giua'
        elif abs(dx - dw) < 0.75:
            kx = '3 phai'
        else:
            kx = '? (%.3f)' % dx
        # Doi chieu lai: truoc reflash co dung bang thiet ke khong?
        lech = 'lech tk %+.3f,%+.3f' % (t[0] - tx, t[1] - ty)
        print('%-28s %9.3f %9.3f %9.3f %9.3f | %+7.3f %+7.3f %-9s %s'
              % (ten, tx, ty, t[0], s[0], dx, dy, kx, lech))


# Cong thuc da do duoc (xem ROADMAP.md): tinh vi tri ma ban goc dat cho mot
# node, theo kich thuoc cha. `ph`/`pw` la ben cua CHA; w,h la contentSize cua
# node; ax, ay la anchorPointInPoints (anchor nhan contentSize).
def vi_tri_theo_cong_thuc(fix, pw, ph, w, h, ax, ay, sx, sy):
    """Vi tri ban goc se dat node vao. None = truc do de yen.

    KIEU 2 KHAC KIEU 1 VA KIEU 3 O CHO CO GIAN. Do duoc, khong suy:
    kieu 1 va kieu 3 dung hop DA CO GIAN (ws = w*sx, hs = h*sy), con kieu 2
    dung hop CHUA co gian. Hai mau chot dieu do:
      * lCUICOGMap (UI_COG, k=(2,2), neo (0,0), scale 0,8, 2850x2235, cha
        lCOGUI): do duoc x = -875 khi cha rong 1100. Chua gian:
        (1100-2850)/2 = -875 dung; da gian: (1100-2280)/2 = -590 sai 285 diem.
        Truc Y cung vay: -737,5 so voi -514. Bon diem du lieu (hai ben cha,
        hai truc) deu khong co gian.
      * g_UpgradeQualityActionMaterialItem (UI_Equipment, k=(2,0), neo (0,5;0,5),
        scale 0,8, 79x79, cha lEquipUpgradeQualityMainUI rong 500): do duoc
        x = 250. Hop chua gian: (500-79)/2 + 39,5 = 250 dung. Hop da gian:
        (500-63,2)/2 + 31,6 = 242,1 sai 7,9 diem. Nen so hang neo cua kieu 2
        cung khong nhan scale.
    Kieu 1 va 3 thi nguoc lai, do tren btnEquipForgeUINavigation1 (k=(1,1),
    scale 0,8): x = 25 + 39,5*0,8 = 56,6 (chua gian thi ra 64,5) va
    y = 800 - (63,2 - 31,6) - 15 = 753,4 (chua gian thi ra 745,5); tren
    btnHeroEquipUIToRight (k=(3,2), scale x = -1) thi mep phai ra dung 880
    (chua gian thi ra 824).
    """
    mx, my, o40, o44, o48, o4C, o50, o54 = fix
    ws, hs = w * sx, h * sy
    axs, ays = ax * sx, ay * sy
    X = {0: None, 1: o40 + axs,
         2: (pw - w) * 0.5 + ax + o50,
         3: pw - (ws - axs) - o44}[mx]
    Y = {0: None, 1: ph - (hs - ays) - o48,
         2: (ph - h) * 0.5 + ay + o54,
         3: o4C + ays}[my]
    return X, Y


def doc_cam():
    """Doc ba luot `setOrange` — xem `LUOT_CAM` de biet cau hoi.

    Cau hoi that: sau cho goi nao cung co dang `if pt.setOrange then if
    GetLanguageName()=="en" then setOrange(true) else setOrange(false) end end`,
    nen ban tieng Viet di qua DUNG nhanh false. Neu `tat` trung `khong` tung diem
    anh thi chuong trinh mac dinh DA la 'ShaderPositionTextureColor', va bo qua
    setOrange(false) khong sai gi.

    Phai kiem TUNG LUOT co chay that khong truoc khi so: mot luot chet giua duong
    van sinh ra mot file .png, va dem so mot luot hong voi mot luot chay duoc thi
    ra ket luan nguoc han. Da bi mot lan: `cam_khong` khong chay, no dung o man
    hinh khac (khac 921.587/921.600 diem anh), va ham nay in ra "bo qua la SAI".
    """
    from PIL import Image
    ten = ('cam_khong', 'cam_bat', 'cam_tat')
    duong = [ANH / (n + '.png') for n in ten]
    log = [ANH / (n + '.log') for n in ten]
    for d in duong + log:
        if not d.exists():
            print('  thieu %s — chay --cam truoc' % d)
            return

    # 1. Cong kiem: tung luot phai chay het. `PT|nut|<ten>|userdata` = node co
    #    that; `PT|san-sang` = ca kich ban di het (khong chet giua duong).
    for n, l in zip(ten, log):
        dong = l.read_text(encoding='utf-8', errors='replace').splitlines()
        nut = [x for x in dong if x.startswith('PT|nut|')]
        if not nut or 'thieu-nut' in ' '.join(dong):
            print('  LUOT %-10s KHONG CHAY DUOC: %s' % (n, nut[0] if nut else 'khong co dong PT|nut|'))
            print('  => mot luot hong thi moi so sanh ben duoi vo nghia — KHONG KET LUAN')
            return
        if 'PT|san-sang' not in dong:
            print('  LUOT %-10s KHONG CHAY DUOC: thieu PT|san-sang (chet giua duong); %s'
                  % (n, nut[0]))
            print('  => mot luot hong thi moi so sanh ben duoi vo nghia — KHONG KET LUAN')
            return
    print('  ba luot deu chay het:')
    for n, l in zip(ten, log):
        print('    %-10s %s' % (n, [x for x in l.read_text(encoding='utf-8',
              errors='replace').splitlines() if x.startswith('PT|nut|')][0]))

    im = [Image.open(d).convert('RGB') for d in duong]
    if len({i.size for i in im}) != 1:
        print('  ba anh khac co — khong so duoc')
        return
    px = [i.load() for i in im]
    W, H = im[0].size

    def dem(a, b, x0, y0, x1, y1, nguong=0):
        n, dmax = 0, 0
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                ca, cb = px[a][x, y], px[b][x, y]
                d = max(abs(ca[k] - cb[k]) for k in range(3))
                if d > nguong:
                    n += 1
                dmax = max(dmax, d)
        return n, dmax

    # 2. Khung thanh tien do: do bang chinh anh chu khong tin hang so tay. Roi
    #    doi chieu voi `cua_so(CAM_O)` — day la phep kiem doc lap cho cong thuc
    #    lat truc cua `cua_so` (toa do thiet ke goc duoi-trai -> diem anh).
    xs = []; ys = []
    for y in range(H):
        for x in range(W):
            if max(abs(px[2][x, y][k] - px[1][x, y][k]) for k in range(3)) > 12:
                xs.append(x); ys.append(y)
    if not xs:
        print('  `tat` va `bat` khong khac nhau o dau — khong ket luan duoc')
        return
    x0, y0 = max(0, min(xs) - 4), max(0, min(ys) - 4)
    x1, y1 = min(W - 1, max(xs) + 4), min(H - 1, max(ys) + 4)
    ly = cua_so(CAM_O[0], CAM_O[1], CAM_O[2], CAM_O[3], them=4)
    print('  khung do tu anh   : (%d,%d)-(%d,%d) = %dx%d'
          % (x0, y0, x1, y1, x1 - x0 + 1, y1 - y0 + 1))
    print('  cua_so(CAM_O) doi chieu: (%d,%d)-(%d,%d)  %s'
          % (ly[0], ly[1], ly[2], ly[3],
             'khop (<=2 diem anh)' if max(abs(a - b) for a, b in zip(ly, (x0, y0, x1, y1))) <= 2
             else 'LECH — xem lai CAM_O'))
    tong = (x1 - x0 + 1) * (y1 - y0 + 1)

    # 3. Ngoai khung do ba anh phai TRUNG NHAU. Lech o ngoai = mot luot dung o
    #    man hinh khac, va ca phep do vo nghia.
    n_ngoai = 0
    for y in range(H):
        for x in range(W):
            if x0 <= x <= x1 and y0 <= y <= y1:
                continue
            if max(abs(px[0][x, y][k] - px[2][x, y][k]) for k in range(3)) > 12:
                n_ngoai += 1
    print('  ngoai khung: `khong` vs `tat` khac %d diem anh' % n_ngoai)
    if n_ngoai:
        print('  => mot luot dung o man hinh khac — KHONG KET LUAN')
        return

    for a, b in ((0, 2), (0, 1), (2, 1)):
        n, dmax = dem(a, b, x0, y0, x1, y1)
        print('  trong khung: %-10s vs %-10s : %6d diem khac (lech toi %d)'
              % (ten[a], ten[b], n, dmax))
    print('  khung = %d diem anh' % tong)

    # 4. Tra loi cau hoi cua cong: setOrange(false) co doi gi khong.
    n, dmax = dem(0, 2, x0, y0, x1, y1, nguong=0)
    if n == 0:
        print('  => setOrange(false) KHONG doi mot diem anh nao: chuong trinh mac')
        print('     dinh DA la ShaderPositionTextureColor. Bo qua no la dung.')
    else:
        print('  => setOrange(false) CO doi hinh (%d diem, lech toi %d) — mac dinh'
              % (n, dmax))
        print('     KHONG phai chuong trinh ay, va bo qua no la SAI.')

    # 5. Luot `bat`: kiem chuong trinh Orange.
    #
    # Phep tron mac dinh la GL_ONE / GL_ONE_MINUS_SRC_ALPHA, nen diem man hinh
    # = S + D*(1-a), voi S la rgb TRUOC khi nhan he so va D la nen. Shader chi
    # nhan S, nen  delta = S*(T-1)  tung kenh. Do la ly do cong thuc
    # `clamp(diem_cu * T)` — doan thang tren DIEM MAN HINH — la SAI: no bo qua so
    # hang nen D*(1-a). Mot lan do truoc do dung cong thuc sai ay nen chi ra
    # 1.167/2.486 diem "khop", va con so do khong noi gi ve shader ca.
    #
    # Cach kiem dung khong can biet D: S suy ra duoc tu chinh delta —
    #     S_r = -delta_r/0,1    S_g = delta_g/1,9    S_b = -delta_b
    # nen co ba phep kiem khong the qua:
    #   (a) DAU: T=(0,9 2,9 0,0) buoc delta_r<=0, delta_g>=0, delta_b<=0.
    #       Bat ky chuong trinh nao khac dau — hoac co so hang nen cu~ng doi —
    #       deu sinh diem sai.
    #   (b) S phai la mot MAU HOP LE: 0<=S<=255. He so sai lam S vuot bien.
    #   (c) S phai la MOT mau: ba kenh suy tu BA he so khac nhau phai ra cung mot
    #       mau do. Thanh mau do thi S_g ~ S_b, va S_r/S_b phai on dinh.
    # He so lay tu `.rodata 0x7cd0c1` (nguon shader doc ra tu file game), KHONG
    # lay tu anh: anh chi duoc phep BAC BO, khong duoc phep thanh bang so.
    HE = (0.9, 2.9, 0.0)
    doi = sai_dau = vuot = 0
    Sr = []; Sg = []; Sb = []; ti_le = []; mo = 0
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            cu, moi = px[2][x, y], px[1][x, y]
            d = [moi[k] - cu[k] for k in range(3)]
            if d == [0, 0, 0]:
                continue
            doi += 1
            if d[0] > 0 or d[1] < 0 or d[2] > 0:
                sai_dau += 1
            sr, sg, sb = -10.0 * d[0], d[1] / 1.9, -1.0 * d[2]
            if not (0 <= sr <= 255 and 0 <= sg <= 255 and 0 <= sb <= 255):
                vuot += 1
                continue
            Sr.append(sr); Sg.append(sg); Sb.append(sb)
            if d[2]:
                ti_le.append(float(d[1]) / d[2])
            if max(abs(moi[k] - round(cu[k] * HE[k])) for k in range(3)) <= 1:
                mo += 1
    print('  luot "bat": %d/%d diem anh doi trong khung' % (doi, tong))
    print('    (a) sai dau (phai: r<=0, g>=0, b<=0)     : %d' % sai_dau)
    print('    (b) S ra ngoai [0,255]                    : %d' % vuot)
    if not Sr:
        print('    (c) khong suy duoc S — khong ket luan')
        return
    import statistics as st
    print('    (c) S suy tu ba he so: r=%6.1f  g=%5.1f  b=%5.1f  (trung vi, n=%d)'
          % (st.median(Sr), st.median(Sg), st.median(Sb), len(Sr)))
    print('        delta_g/delta_b trung vi %+0.3f  (S_g/S_b = %+0.3f, thanh mau do'
          % (st.median(ti_le), -st.median(ti_le) / 1.9))
    print('        thi S_g ~ S_b, tuc ti so nay phai ~ -1,9)')
    print('    tham chieu: %d diem thoa "diem moi = diem cu * T" (thanh mo hoan'
          % mo)
    print('      toan) — so nay KHONG dung de ket luan, chi de biet do mo cua thanh')


def doc_cong(dong):
    """Doc phep do CONG KICH HOAT va cot dich chua do duoc.

    Cau hoi 1 — cong: node co kieu X = 0 ma kieu Y khac 0 thi truc Y co duoc
    dat lai khong? Cha cua chung bi lam cho cao them 90 (hoac 160) diem, nen
    neu dat lai thi y doi dung bang chenh lech ben cao; neu bi chan thi y dung
    yen. Bon nut dieu huong va g_UpgradeQualityActionBeginLayer deu co dich
    khac 0, nen "cha to ra thi con to ra" khong the giai thich mot phep doi cho
    nao.

    Cau hoi 2 — dau cua cot dich +0x48 (kieu Y 1) va +0x54 (kieu Y 2): doc vi
    tri luc CHUA doi ben cha roi doi chieu voi cong thuc. Hieu so khong tra loi
    duoc cau nay vi dich la hang so, no triet tieu khi tru.
    """
    o = {}
    for l in dong:
        p = l.split('|')
        if len(p) < 6 or p[0] != 'FI' or p[1] != 'cong':
            continue
        k, nhan, ten = p[2], p[3], p[4]
        try:
            so = tuple(float(v) for v in p[5:])
        except ValueError:
            so = None
        o.setdefault((k, nhan), {})[ten] = so
    if not o:
        print('khong doc duoc dong FI|cong| nao')
        return

    # Doi chieu voi ban ghi .xgg: lay so that tu chinh file, khong chep tay.
    import os
    import xgg as _xgg
    CONF = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                        'vn', 'decrypted', 'assets', 'conf')
    ghi = {}
    for f in ('UI_Equipment_960_640.xgg', 'UI_Hero_960_640.xgg',
              'Game_UI_Control_Panel_960_640.xgg'):
        try:
            x = _xgg.load(os.path.join(CONF, f))
        except Exception:
            continue
        nds, G, offs = x.nodes(), x.offsets['G'], x.node_offsets()
        cha_cua = {}
        for r in x.tree():
            pila = [(r, None)]
            while pila:
                nd, cha = pila.pop()
                cha_cua[id(nd)] = cha
                for c in nd.get('children', []):
                    pila.append((c, nd))
        for i, nd in enumerate(nds):
            t = nd.get('name')
            if not t or t in ghi:
                continue
            a = G + offs[i]
            # THU TU COT: +0x38 la kieu Y, +0x3C moi la kieu X. Doc bang <8i tu
            # +0x38 thi phan tu DAU la kieu Y — dat lai dung thu tu (mx, my)
            # cho khop ten goi trong ROADMAP va trong vi_tri_theo_cong_thuc.
            # (Da doc nham cho nay mot lan: bang kieu hien ra (my, mx).)
            fix = struct.unpack_from('<8i', x.data, a + 0x38)
            fix = (fix[1], fix[0]) + fix[2:]
            sx, sy = struct.unpack_from('<2f', x.data, a + 0x84)
            fx, fy = struct.unpack_from('<2f', x.data, a + 0x90)
            w, h = struct.unpack_from('<2f', x.data, a + 0x98)
            cha = cha_cua.get(id(nd))
            ghi[t] = (fix, w, h, fx * w, fy * h, sx, sy,
                      cha.get('name') if cha else None)

    for k in sorted(o, key=lambda z: (int(z[0]), z[1])):
        if k[1] != 'truoc':
            continue
        # Cha: dong co 2 so. Con: dong co 4 so.
        cha = [t for t, v in o[k].items() if v is not None and len(v) == 2]
        if not cha:
            continue
        ten_cha = cha[0]
        print('  --- muc %s: %s ---' % (k[0], ten_cha))
        for nhan in ('truoc', 'sau'):
            pb = o.get((k[0], nhan))
            if not pb or pb.get(ten_cha) is None:
                continue
            pwid, phei = pb[ten_cha][0], pb[ten_cha][1]
            print('    cha %-38s %g x %g' % (nhan, pwid, phei))
            for ten, vt in sorted(pb.items()):
                if ten == ten_cha:
                    continue
                g = ghi.get(ten)
                if vt is None or len(vt) < 2:
                    print('      %-44s %s' % (ten, vt))
                    continue
                if g is None:
                    print('      %-44s x=%-9.3f y=%-9.3f (khong co trong .xgg)'
                          % (ten, vt[0], vt[1]))
                    continue
                fix, w, h, ax, ay, sx, sy, _ = g
                X, Y = vi_tri_theo_cong_thuc(fix, pwid, phei, w, h, ax, ay, sx, sy)
                kx = ('giu nguyen' if fix[0] == 0 else '%.3f' % X)
                ky = ('giu nguyen' if fix[1] == 0 else '%.3f' % Y)
                print('      %-44s x=%-9.3f y=%-9.3f | kieu=(%d,%d) dich=(%d,%d,%d,%d,%d,%d)'
                      % (ten, vt[0], vt[1], fix[0], fix[1],
                         fix[2], fix[3], fix[4], fix[5], fix[6], fix[7]))
                print('      %-44s cong thuc: x=%s y=%s' % ('', kx, ky))
        t = o[(k[0], 'truoc')]
        s = o.get((k[0], 'sau'), {})
        for ten in sorted(s):
            if ten == ten_cha or t.get(ten) is None or s[ten] is None \
                    or len(t[ten]) < 2 or len(s[ten]) < 2:
                continue
            print('      %-44s doi: dx=%+.3f dy=%+.3f'
                  % (ten, s[ten][0] - t[ten][0], s[ten][1] - t[ten][1]))


# Do node KHONG CO TEN: phai sua mot BAN SAO cua .xgg truoc khi nap.
#
# Vi sao phai sua file: `loadLevelFile` chi dang ky node CO TEN vao `_G` (da do),
# ma 49 thanh mau kieu 3 va 12 o tron kieu 0 deu khong co ten. Sua HAI thu,
# ca hai deu KHONG doi hinh ve (nen phep do van la phep do tren ban goc):
#
#   * TEN: tro cap (off,len) cua ten (+0x68) sang chinh chuoi TEN ANH cua no
#     (+0xEC, hoac +0xE4 — xem chu thich o doc_lai). Chuoi co san trong file,
#     nen khong phai dung lai file va khong lech offset nao.
#   * HIEN: chuoi to tien `vis=1` moi ve duoc, ma `setVisible` tu Lua lam ban
#     dich ARM SIGSEGV (do o dau file) — nen byte hien/an (+0xA1) phai sua
#     trong file. Day la BAN SAO trong _pt/sua, khong dung vao du lieu goc.
def ban_sao(nguon, doi_ten=(), hien=()):
    """Ghi ban sao .xgg co sua ten/hien-an. Tra ve duong dan ban sao.

    doi_ten: (w, h, x_tuyet_doi, y_tuyet_doi, ten_to_tien) — khop theo kich
             thuoc, vi tri tuyet doi VA ten mot to tien. Ba dieu kien la can
             thiet: `s9Blood_1` 360x15 co **40** ban o dung cung mot cho, moi
             ban thuoc mot lop `lUI*` khac nhau, nen kich thuoc voi vi tri
             khong du phan biet.
    hien:    (ten, x, y) — bat `+0xA1 = 1`; x/y bo qua duoc khi ten la duy nhat.
    """
    x = xgg.load(str(nguon))
    data = bytearray(x.data)
    offs, G, H = x.node_offsets(), x.offsets['G'], x.offsets['H']
    ns = x.nodes()
    order = {id(nd): i for i, nd in enumerate(ns)}
    vt, cha = {}, {}

    def walk(nd, ax, ay, to_tien):
        vt[id(nd)] = (ax + nd['x'], ay + nd['y'])
        cha[id(nd)] = to_tien
        for c in nd['children']:
            walk(c, ax + nd['x'], ay + nd['y'],
                 to_tien + ((nd['name'],) if nd['name'] else ()))

    for r in x.tree():
        walk(r, 0, 0, ())

    sua = 0
    for nd in ns:
        i = order[id(nd)]
        a = G + offs[i]
        xx, yy = vt[id(nd)]
        for (ten, *o_) in hien:
            if nd['name'] != ten:
                continue
            if len(o_) == 2 and (abs(xx - o_[0]) > 0.5 or abs(yy - o_[1]) > 0.5):
                continue
            data[a + 0xA1] = 1
            sua += 1
            print('  bat hien  %-24s tai (%.0f,%.0f) vis 0 -> 1' % (ten, xx, yy))
        for (w, h, x_, y_, to_tien, *rest) in doi_ten:
            if (abs(nd['w'] - w) < 0.5 and abs(nd['h'] - h) < 0.5
                    and abs(xx - x_) < 0.5 and abs(yy - y_) < 0.5
                    and to_tien in cha[id(nd)]):
                # O nao dang giu ten anh: +0xEC neu o +0xF0 (do dai) khac 0,
                # khong thi +0xE4. Do tren ca 325 ban ghi: 323 o +0xEC, 1 o
                # +0xE4 (o tien do cua man hinh cho), 1 khong co anh.
                #
                # `rest` = (offset trong ban ghi cua chinh node, do lech) khi
                # hai node dinh doi ten DUNG CHUNG mot chuoi ten anh (hai thanh
                # cua lContestFight cung 'v6/ui_blood_44.png'): dat cung ten thi
                # `_G` chi giu mot cai, mat luon doi chung. Khi do lay chuoi o
                # cho khac — chu cua mot nhan ('#...'), thu khong bao gio trung
                # ten node nao.
                if rest:
                    o, l = struct.unpack_from('<2I', data, a + rest[0])
                else:
                    src = 0xEC if struct.unpack_from('<I', data, a + 0xF0)[0] else 0xE4
                    o, l = struct.unpack_from('<2I', data, a + src)
                ten = data[H + o:H + o + l].decode('utf-8')
                struct.pack_into('<2I', data, a + 0x68, o, l)
                sua += 1
                print('  doi ten   %-24s %5.0fx%-4.0f tai (%.0f,%.0f) -> %r'
                      % (nd['cls'], w, h, xx, yy, ten))
    if not sua:
        raise SystemExit('khong sua duoc gi — kiem lai dieu kien khop')
    SUA.mkdir(parents=True, exist_ok=True)
    dich = SUA / pathlib.Path(nguon).name
    dich.write_bytes(bytes(data))
    print('  ban sao:', dich)
    return dich


# Dau do cho ban sao: in ca duong tim kiem (de biet dat file o dau) va doc lai
# phan tram sau khi dat — doc lai duoc nghia la `_G` giu dung node ta nham.
DAU_DO_SUA = ('\n-- === CHEN DE DO: ban sao .xgg ===\n'
              'do\n' + DUNG_CANH + '''
	do
		local ok, t = pcall(function() return sngUtil:getSearchPaths() end)
		print("SU|duong|" .. tostring(ok) .. "|" .. tostring(type(t)))
		if type(t) == "table" then
			for i = 1, #t do print("SU|duong|" .. i .. "|" .. tostring(t[i])) end
		end
	end
	buoc("nap", function()
		return loadLevelFile("%(file)s", sc)
	end)
	local ten = "%(ten)s"
	local t = rawget(_G, ten)
	print("SU|nut|" .. ten .. "|" .. type(t))
	if type(t) == "userdata" then
		if %(pct)s > 0 then
			buoc("dat-phan-tram", function() return t:setPercentage(%(pct)s) end)
		end
		local ok, p = pcall(function() return t:getPercentage() end)
		print("SU|phan-tram|" .. tostring(ok) .. "|" .. tostring(p))
	end
	print("SU|san-sang")
end
''')


# ── Do HINH DANG cua tung KIEU (cw / ccw / lr / rl / bt / tb) ─────────────
#
# Doi KIEU tren CHINH hai node ma LUOT da do duoc la CO HIEN va CO VE, chu
# khong tim node khac: moi luot chi khac nhau dung mot bien, nen hieu hai anh
# la hieu chinh cai kieu.
#
# Da thu duong khac va no KHONG chay: `ptLoadingGamePercent` cua UI_LoadingGame
# (node tien do DUY NHAT vua VUONG vua to — 81x81, kieu 0, ca cay to tien
# vis=1, ten co trong _G) nap vao canh Main roi dat kieu/phan tram: CA 14 luot
# deu KHONG khac gi luot 0,5%. Nap bo cuc do vao canh Main thi no nam DUOI giao
# dien cua Main, nen khong nhin thay — do la ly do, khong phai no khong ve.
#
# `setType` cua ban goc nhan CHUOI chu khong phai so — doc duoc tu chinh ma
# goc: CUIDownload.lua:65,67 goi
#     S_CCCallFunc:create(ptLoadingGamePercent, "setType", "cw")
#     S_CCCallFunc:create(ptLoadingGamePercent, "setType", "ccw")
#
# Moi luot: (file, ten node trong _G, kieu, %). Khung anh cua hai node nay da
# do duoc o LUOT (hud 126x21, war 54x251) nen khong do lai.
KIEU = ('cw', 'ccw', 'lr', 'rl', 'bt', 'tb')

_HUD = ('conf/UI_Main_ControlPanel_960_640.xgg', 'pMainUIHeroExp')
_WAR = ('conf/UI_WarSoul_960_640.xgg', 'g_ptWarSoulTBar')

LUOT_KIEU = {}
for _k in ('cw', 'ccw', 'lr', 'rl', 'bt', 'tb'):
    LUOT_KIEU['war_%s_25' % _k] = _WAR + (_k, 25)
# Vong tren o CAO 71x297: duong kinh quat se lo ra ngay (71 theo o, hay 213
# theo anh 102x324) — va 71 diem thi doc duoc CHIEU quay.
for _p in (50, 75):
    LUOT_KIEU['war_cw_%d' % _p] = _WAR + ('cw', _p)
# Vong tren o NGANG 178x28 va 28 diem: neu quat lay theo ANH (362x14) thi
# duong kinh la 188 chu khong phai 28 — khac nhau qua xa de nham.
LUOT_KIEU['hud_cw_25'] = _HUD + ('cw', 25)
# rl / tb tren o NGANG 178x28: mep nao dung yen doc ra ro nhat o o det.
LUOT_KIEU['hud_rl_25'] = _HUD + ('rl', 25)
LUOT_KIEU['hud_tb_25'] = _HUD + ('tb', 25)

DAU_DO_KIEU = ('\n-- === CHEN DE DO: hinh dang theo kieu ===\n'
               'do\n' + DUNG_CANH + '''
	buoc("nap-bo-cuc", function()
		return loadLevelFile("%(file)s", sc)
	end)
	local t = rawget(_G, "%(ten)s")
	print("KI|nut|%(ten)s|" .. type(t))
	if type(t) == "userdata" then
		-- KHONG goi getType(): do duoc la no lam ban dich ARM SIGSEGV ngay
		-- (fault addr 0x64041ef1, GLThread) — cung ho voi setVisible /
		-- setScale / create / getChildrenCount. Kieu dat duoc thi do bang
		-- HINH VE, khong bang getType.
		buoc("dat-kieu", function() return t:setType("%(kieu)s") end)
		buoc("dat-phan-tram", function() return t:setPercentage(%(pct)s) end)
		local ok3, p = pcall(function() return t:getPercentage() end)
		print("KI|phan-tram|" .. tostring(ok3) .. "|" .. tostring(p))
	end
	print("KI|san-sang")
	print("PT|san-sang")
end
''')


def chup(ten):
    xa = '/sdcard/' + ten
    E.adb('shell', 'screencap', '-p', xa)
    dich = ANH / ten
    E.adb('pull', xa, str(dich))
    E.adb('shell', 'rm', '-f', xa)
    return dich if dich.exists() else None


def chay(probe, nhan, cho, them=()):
    """Đẩy bản đè, khởi động game, chờ rồi chụp (giống emu_dom.chay).

    `them`: cap (duong trong sc/, file nguon) — de dat BAN SAO .xgg vao cay de.
    Cay de chi co `sc/` va `download/` chi chua `sc/`, nen phai in ra duong tim
    kiem moi biet `conf/` nam o dau (xem `SU|duong|` o dau do ban sao).
    """
    sc_dir = D.dung_de(probe, ANH)
    for duong, nguon in them:
        d = sc_dir / duong
        d.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(nguon, d)
        print('  dat', duong, '<-', nguon)
    E.adb('shell', 'am', 'force-stop', E.PKG)
    for _ in range(20):
        if not E.adb('shell', 'pidof', E.PKG).stdout.strip():
            break
        time.sleep(0.5)
    E.adb('shell', 'mkdir', '-p', E.REMOTE)
    E.adb('push', str(sc_dir), E.REMOTE + '/')
    E.cap_quyen()
    E.adb('logcat', '-b', 'all', '-c')
    E.adb('shell', 'am', 'start', '-n', '%s/%s' % (E.PKG, E.ACT))
    time.sleep(cho)
    a = chup(nhan + '.png')
    txt = E.adb('logcat', '-d').stdout
    dong = re.findall(r'(?:PT|SO|DOM|CHEN|SU|DD|KI|FI)\|[^\n\r]*', txt)
    # Ghi lai dong do ra file: phep do fix-info chi co gia tri neu doi chieu lai
    # duoc voi mot chuong trinh KHAC (work/fix_info.py --kiem doc lai chinh
    # file nay). Khong ghi thi con so chi nam trong hoi thoai, mai khong ai
    # kiem lai duoc.
    ANH.mkdir(exist_ok=True)
    (ANH / (nhan + '.log')).write_text('\n'.join(dong) + '\n', encoding='utf-8')
    # Chay het thi dong cuoi la `PT|san-sang`. Thieu dong do = tien trinh da
    # chet giua duong (pcall KHONG bat duoc SIGSEGV — da biet), nen in luon
    # logcat tho de biet chet o dau va chet kieu gi.
    if 'PT|san-sang' not in ' '.join(dong):
        print('   !! dau do khong chay het — logcat tho:')
        for l in txt.splitlines()[-12:]:
            print('    |', l)
    return a, dong


def cua_so(cx, cy, w, h, them=40):
    """Cua so tren ANH MAN HINH quanh o tien do (toa do thiet ke, goc duoi-trai)."""
    x0 = int(cx - w / 2 - them)
    x1 = int(cx + w / 2 + them)
    y0 = int(MAN[1] - (cy + h / 2) - them)
    y1 = int(MAN[1] - (cy - h / 2) + them)
    return (max(0, x0), max(0, y0), min(MAN[0] - 1, x1), min(MAN[1] - 1, y1))


def mat_na(a, b, hop, nguong=12):
    from PIL import Image
    ia = Image.open(a).convert('RGB')
    ib = Image.open(b).convert('RGB')
    if ia.size != ib.size:
        return None
    pa, pb = ia.load(), ib.load()
    x0, y0, x1, y1 = hop
    m = {}
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            ca, cb = pa[x, y], pb[x, y]
            if max(abs(ca[k] - cb[k]) for k in range(3)) > nguong:
                m[(x, y)] = True
    return m


def in_hinh(m, hop, thu=2):
    x0, y0, x1, y1 = hop
    for y in range(y0, y1 + 1, thu):
        dong = ''
        for x in range(x0, x1 + 1, thu):
            dong += '#' if m.get((x, y)) else '.'
        print('   ', dong)


def be_rong(m, hop, buoc=4):
    x0, y0, x1, y1 = hop
    for y in range(y0, y1 + 1, buoc):
        xs = [x for x in range(x0, x1 + 1) if m.get((x, y))]
        if xs:
            print('     y=%4d  rong=%5d  trai=%5d  phai=%5d' % (y, len(xs), min(xs), max(xs)))


def do_trong_vung(duong, hop):
    """Khung bao cac diem DO trong cua so (thanh tien do thuong mau do)."""
    from PIL import Image
    im = Image.open(duong).convert('RGB')
    px = im.load()
    x0, y0, x1, y1 = hop
    a = [x1, y1, x0, y0]
    n = 0
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            r, g, b = px[x, y]
            if r > g + 20 and r > b + 20:
                a[0], a[1] = min(a[0], x), min(a[1], y)
                a[2], a[3] = max(a[2], x), max(a[3], y)
                n += 1
    if n == 0:
        return None
    return (a[0], a[1], a[2], a[3], n, a[2] - a[0] + 1, a[3] - a[1] + 1)


def toan_man(a_, b_):
    """Hieu hai luot 100% / 30% tren TOAN MAN HINH.

    Khong can biet truoc o tien do nam o dau: hai luot dung cung mot bo cuc,
    chi khac moi `setPercentage`, nen vung khac chinh la vung o ay VE RA.
    (Neu con chi tiet nao khac nua — hieu ung nhap nhay theo thoi gian — thi
    no hien ra day thanh vung thu hai, va do la dieu phai thay.)
    """
    from PIL import Image
    da, db = ANH / (a_ + '.png'), ANH / (b_ + '.png')
    ia = Image.open(da).convert('RGB')
    ib = Image.open(db).convert('RGB')
    pa, pb = ia.load(), ib.load()
    w, h = ia.size
    m = {}
    x0, y0, x1, y1 = w, h, -1, -1
    for y in range(h):
        for x in range(w):
            ca, cb = pa[x, y], pb[x, y]
            if max(abs(ca[k] - cb[k]) for k in range(3)) > 12:
                m[(x, y)] = True
                x0, y0 = min(x0, x), min(y0, y)
                x1, y1 = max(x1, x), max(y1, y)
    return m, (x0, y0, x1, y1) if m else None


def in_toan_man(m, hop, thu=4):
    x0, y0, x1, y1 = hop
    print('    khung bao %d,%d .. %d,%d  (%dx%d)'
          % (x0, y0, x1, y1, x1 - x0 + 1, y1 - y0 + 1))
    for y in range(y0, y1 + 1, thu):
        dong = ''
        for x in range(x0, x1 + 1, thu):
            dong += '#' if m.get((x, y)) else '.'
        print('    y=%4d %s' % (y, dong))


def doc_lai():
    # Khung anh cua o = hieu (0,5% , 100%). Moi phep hieu khac doc theo khung do.
    khung = {}
    print('--- khung anh cua o (hieu 0,5%% voi 100%%) ---')
    for ten in ('hud', 'war'):
        a_, b_ = ten + '0', ten + '100'
        if not (ANH / (a_ + '.png')).exists() or not (ANH / (b_ + '.png')).exists():
            print('  %-4s thieu anh' % ten)
            continue
        m, hop = toan_man(a_, b_)
        khung[ten] = hop
        print('  %-4s khung %s  %d diem  (%dx%d)'
              % (ten, hop, len(m), hop[2] - hop[0] + 1, hop[3] - hop[1] + 1))
    print()
    print('--- be dai thanh theo tung muc %%, do tren khung anh ay ---')
    for a_, b_ in SO_SANH:
        ten = a_[:-1]
        fa, pa = LUOT[a_][0], LUOT[a_][2]
        pb = LUOT[b_][2]
        if a_ == b_ or (a_.endswith('0') and b_ == ten + '100'):
            continue          # chinh la phep do khung anh, in o tren roi
        if not (ANH / (a_ + '.png')).exists() or not (ANH / (b_ + '.png')).exists():
            print('  %-8s thieu anh' % b_)
            continue
        m, hop = toan_man(a_, b_)
        g = khung.get(ten)
        if not m or g is None:
            print('  %-8s khong thay gi (%d diem)' % (b_, len(m)))
            continue
        rong = g[2] - g[0] + 1
        cao = g[3] - g[1] + 1
        # O NGANG (kieu lr) thi be dai la be NGANG cua vung; o CAO (kieu bt) thi
        # la chieu CAO. Do ca hai, va doi chieu voi hai mo hinh:
        #   ti le  : W * p/100
        #   cheo   : (W + H) * p/100 - H   (mo hinh khop so do cua o HUD)
        dai = rong if ten == 'hud' else cao     # canh DAI cua khung anh
        goc_ = cao if ten == 'hud' else rong    # canh KIA cua khung anh
        do_dai = hop[2] - hop[0] + 1 if ten == 'hud' else hop[3] - hop[1] + 1
        ti_le = dai * pb / 100.0
        cheo = max(0.0, (dai + goc_) * pb / 100.0 - goc_)
        print('  p=%-5g vung %d,%d..%d,%d  %3dx%-3d | cach mep trai %+4d  '
              'rong %3d=%.1f%% khung | duoi %+4d len %+4d'
              % (pb, hop[0], hop[1], hop[2], hop[3],
                 hop[2] - hop[0] + 1, hop[3] - hop[1] + 1,
                 hop[0] - g[0], hop[2] - hop[0] + 1, 100.0 * (hop[2] - hop[0] + 1) / rong,
                 hop[1] - g[1], g[3] - hop[3]))
        print('          be dai do = %d diem | ti le doi %5.1f | cheo doi %5.1f'
              % (do_dai, ti_le, cheo))
    return


def doc_lai_cu():
    hop_o = {}
    print('--- khung anh cua tung o: hieu 0,5%% voi 100%% ---')
    for a_, b_ in SO_SANH:
        if a_[-2:] != '00' or b_[-2:] != '00':
            continue
        m, hop = toan_man(a_, b_)
        hop_o[a_[:-2]] = hop
        print('  %-4s khung %s  %d diem' % (a_[:-2], hop, len(m)))
    print()
    for a_, b_ in SO_SANH:
        fa = LUOT[a_][0]
        print('=== %s tru %s   %s' % (a_, b_, fa))
        if not (ANH / (a_ + '.png')).exists() or not (ANH / (b_ + '.png')).exists():
            print('    thieu anh')
            continue
        m, hop = toan_man(a_, b_)
        print('    %d diem khac tren toan man hinh, khung %s' % (len(m), hop))
        if len(m) < 50:
            print('    -> khong thay gi: hoac o khong ve, hoac setPercentage khong chay')
            continue
        in_toan_man(m, hop, thu=4)
        goc = hop_o.get(a_[:-2])
        if goc and a_[-2:] != '00':
            # mep nao dung yen, mep nao lui — do bang so chu khong bang mat
            print('    doi chieu khung anh %s:' % (goc,))
            d_trai = hop[0] - goc[0]
            d_phai = goc[2] - hop[2]
            d_tren = hop[1] - goc[1]
            d_duoi = goc[3] - hop[3]
            print('      lech mep: trai %+d, phai %+d, tren %+d, duoi %+d'
                  % (d_trai, d_phai, d_tren, d_duoi))
            rong = goc[2] - goc[0] + 1
            cao = goc[3] - goc[1] + 1
            print('      be ngang khung %d -> vung doi %d = %.1f%% be ngang'
                  % (rong, hop[2] - hop[0] + 1,
                     100.0 * (hop[2] - hop[0] + 1) / rong))
            print('      chieu cao khung %d -> vung doi %d = %.1f%% chieu cao'
                  % (cao, hop[3] - hop[1] + 1,
                     100.0 * (hop[3] - hop[1] + 1) / cao))
    nen = ANH / 'nen.png'
    if not nen.exists():
        print('(chua co anh nen — chay --nhanh nen neu can doi chieu voi canh Main)')
        return
    print()
    for c_ in sorted({x for p in SO_SANH for x in p}):
        f, ten, pct, o = LUOT[c_]
        d = ANH / (c_ + '.png')
        if not d.exists():
            continue
        hop = cua_so(*o, them=6)
        m = mat_na(nen, d, hop)
        dr = do_trong_vung(d, hop)
        print('=== %-8s khac anh nen: %6d diem trong cua so; diem DO: %s'
              % (c_, len(m), dr))


def doc_kieu():
    """Doc lai cac anh cua phep do theo KIEU: in hinh dang tung luot.

    Moi luot duoc hieu voi luot 0,5% cua CHINH node ay (`hud0` / `war0`) —
    luc 0,5% moi kieu gan nhu khong ve gi, nen vung khac la vung kieu do VE RA,
    khong dinh gi khac cua bo cuc.
    """
    for ten in sorted(LUOT_KIEU):
        node_ten = LUOT_KIEU[ten][1]
        kieu, p = LUOT_KIEU[ten][2], LUOT_KIEU[ten][3]
        nen_k = 'hud0' if node_ten.startswith('pMain') else 'war0'
        if not (ANH / (ten + '.png')).exists():
            print('=== %-12s thieu anh' % ten)
            continue
        m, hop = toan_man(nen_k, ten)
        if not m:
            print('=== %-12s khong thay gi khac luot 0,5%%' % ten)
            continue
        rong = hop[2] - hop[0] + 1
        cao = hop[3] - hop[1] + 1
        print('=== %-12s kieu=%-3s p=%-3g khung %d,%d..%d,%d  %dx%d  %d diem'
              % (ten, kieu, p, hop[0], hop[1], hop[2], hop[3], rong, cao, len(m)))
        # In 1:1 (o chi vai chuc diem), roi be rong tung hang: hinh QUAT thi be
        # rong doi manh dan theo hang, thanh NGANG thi moi hang bang nhau.
        for y in range(hop[1], hop[3] + 1):
            dong = ''
            for x in range(hop[0], hop[2] + 1):
                dong += '#' if m.get((x, y)) else '.'
            print('      %s' % dong)
        print('      be rong theo hang (moi 4 hang):')
        for y in range(hop[1], hop[3] + 1, 4):
            xs = [x for x in range(hop[0], hop[2] + 1) if m.get((x, y))]
            if xs:
                print('        y=%4d rong=%3d trai=%4d phai=%4d'
                      % (y, len(xs), min(xs), max(xs)))


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--nhanh', default='', help='nen | ' + ' | '.join(LUOT))
    ap.add_argument('--so', action='store_true', help='chi doc anh da chup')
    ap.add_argument('--do', action='store_true',
                    help='do contentSize/position/percentage/scale cua node')
    ap.add_argument('--kieu', action='store_true',
                    help='do hinh dang cua tung kieu tren node da biet la hien')
    ap.add_argument('--kieu-so', action='store_true',
                    help='chi doc lai anh cua phep do theo kieu')
    ap.add_argument('--reflash', action='store_true',
                    help='do sngFixInfoReflash tren lMainBtnLayer (kieu neo + so)')
    ap.add_argument('--cong', action='store_true',
                    help='do cong kich hoat (kieu X = 0) va cot dich +0x48 / +0x54')
    ap.add_argument('--o54', action='store_true',
                    help='do dau cua cot dich +0x54 (kieu Y 2) tren lop goc')
    ap.add_argument('--cam', action='store_true',
                    help='setOrange doi gi: khong / bat / tat, roi so ba anh')
    ap.add_argument('--kieu0', action='store_true',
                    help='do kieu 0 la "de yen" hay "dat lai theo ban ghi"')
    ap.add_argument('--kieu23', action='store_true',
                    help='do kieu 2, kieu 3 va cac cot dich o44/o4C/o50, co gian')
    a = ap.parse_args()
    ANH.mkdir(exist_ok=True)

    if a.so:
        doc_lai()
        return

    ds = [l for l in E.adb('devices').stdout.splitlines()
          if l.strip().endswith('device')]
    if not ds:
        raise SystemExit('khong thay may ao nao — bat emulator truoc')
    print('may ao:', ', '.join(l.split()[0] for l in ds))

    if a.do:
        for nhan, ten_khoa in (('so_hud', 'hud0'), ('so_war', 'war0')):
            f, ten, _, _ = LUOT[ten_khoa]
            probe = DAU_DO_SO % {'file': f, 'ten': ten}
            print('---', nhan, f, ten)
            _, dong = chay(probe, nhan, 18)
            for l in dong[:40]:
                print(' ', l)
        return

    if a.kieu_so:
        doc_kieu()
        return

    if a.reflash:
        probe = DAU_DO_REFLASH % {'ten': ', '.join("'%s'" % t for t in TEN_CON)}
        anh, dong = chay(probe, 'reflash', 20)
        print('--- reflash ---')
        for l in dong:
            if l.startswith(('FI|', 'PT|')):
                print(' ', l)
        print()
        doc_reflash(dong)
        return

    if a.cong:
        anh, dong = chay(DAU_DO_CONG, "cong", 55)
        print('--- cong kich hoat + cot dich ---')
        for l in dong:
            if l.startswith('FI|cong|') or l.startswith('PT|'):
                print(' ', l)
        print()
        doc_cong(dong)
        return

    if a.cam:
        for nhan in sorted(LUOT_CAM):
            f, ten, goi = LUOT_CAM[nhan]
            probe = DAU_DO_CAM % {'file': f, 'ten': ten, 'goi_dong': _cam_goi_dong(goi)}
            # Chay lai mot lan neu luot khong di het: mot luot hong thi
            # `doc_cam` phai bo ket luan, nen thu lai re hon la mat ca ba luot.
            for lan in (1, 2):
                anh, dong = chay(probe, nhan, 45)
                if 'PT|san-sang' in ' '.join(dong):
                    break
                if lan == 1:
                    print('--- %s: luot 1 khong chay het, chay lai ---' % nhan)
            print('--- %s (%s) ---' % (nhan, goi or 'khong goi gi'))
            for l in dong:
                if l.startswith(('PT|nut|', 'PT|goi-', 'PT|thieu-nut', 'PT|canh')):
                    print(' ', l)
            print('  anh:', anh)
        print()
        doc_cam()
        return

    if a.kieu0:
        anh, dong = chay(DAU_DO_KIEU0, 'kieu0', 25)
        print('--- kieu 0: de yen hay dat lai ---')
        for l in dong:
            if l.startswith('FI|k0|') or l.startswith('PT|'):
                print(' ', l)
        # Du kien: btnEquipForgeUINavigation1 kieu (1,1) dich X 25, Y 15,
        # 79x79 scale 0,8 -> x = 25 + 39,5*0,8 = 56,6 ; y = 800 - 31,6 - 15.
        # btnEquipForgeUINavigation2 kieu (0,1) dich Y 15 -> x = 171 neu kieu 0
        # la "dat lai theo ban ghi", = -777 neu la "de yen".
        print()
        for l in dong:
            q = l.split('|')
            if len(q) >= 8 and q[0] == 'FI' and q[1] == 'k0' and q[3] != 'lEquipmentForgeUI':
                print('  %-9s %-30s x=%-10s y=%-10s' % (q[2], q[3], q[4], q[5]))
        return

    if a.kieu23:
        anh, dong = chay(DAU_DO_KIEU23, 'kieu23', 55)
        print('--- kieu 2, kieu 3, cot dich o44/o4C/o50 ---')
        for l in dong:
            if l.startswith(('FI|k23|', 'PT|')):
                print(' ', l)
        print()
        # Doi chieu bang `python fix_info.py --kiem` — cho nay chi in ra de mat
        # nguoi doc thay so tho, khong tu ket luan.
        for l in dong:
            q = l.split('|')
            # Dong cha co 7 truong (ten + ben rong + ben cao), dong con co 9
            # (them x, y truoc ben).
            if len(q) == 9 and q[0] == 'FI' and q[1] == 'k23':
                print('  muc %-3s %-6s %-34s x=%-11s y=%-11s %sx%s'
                      % (q[2], q[3], q[4], q[5], q[6], q[7], q[8]))
        return

    if a.o54:
        anh, dong = chay(DAU_DO_O54, 'o54', 30)
        print('--- dau cot +0x54 ---')
        for l in dong:
            if l.startswith('FI|o54|') or l.startswith('PT|'):
                print(' ', l)
        print()
        # lHeroInfoUI: 960x570, anchor (0,0), kieu (2,2), 54 = -25.
        # Cong thuc y = (ph - 570)/2 + 0 + 54. Hai gia thuyet lech nhau 50 diem.
        for l in dong:
            p = l.split('|')
            if len(p) >= 10 and p[0] == 'FI' and p[1] == 'o54'                     and p[3] in ('lHeroInfoUI', 'lStarSoulMain', 'lQQCoinsGift'):
                try:
                    x, y = float(p[4]), float(p[5])
                    w, h = float(p[6]), float(p[7])
                    pw, ph = float(p[8]), float(p[9])
                except ValueError:
                    continue
                print('  %-18s %-14s do duoc (%8.3f, %8.3f)  node %gx%g  '
                      'ben canh %gx%g | (pw-w)/2=%8.3f (ph-h)/2=%8.3f  '
                      'x-thua=%+.3f y-thua=%+.3f'
                      % (p[2], p[3], x, y, w, h, pw, ph,
                         (pw - w) / 2.0, (ph - h) / 2.0,
                         x - (pw - w) / 2.0, y - (ph - h) / 2.0))
        return

    if a.kieu:
        for nhan in sorted(LUOT_KIEU):
            f, ten_node, k, pct = LUOT_KIEU[nhan]
            probe = DAU_DO_KIEU % {'file': f, 'ten': ten_node,
                                   'kieu': k, 'pct': pct}
            anh, dong = chay(probe, nhan, 20)
            print('--- %-12s kieu=%-3s pct=%g ---' % (nhan, k, pct))
            for l in dong:
                if l.startswith(('KI|', 'PT|nut', 'PT|canh')):
                    print(' ', l)
        print()
        doc_kieu()
        return

    luot = [('nen', DAU_DO_NEN, 16)]
    for nhan, (f, ten, pct, o) in LUOT.items():
        luot.append((nhan, DAU_DO_BO_CUC % {'file': f, 'ten': ten, 'pct': pct}, 20))
    if a.nhanh:
        luot = [x for x in luot if x[0] == a.nhanh]
        if not luot:
            raise SystemExit('khong co luot nao ten %r' % a.nhanh)

    for nhan, probe, cho in luot:
        anh, dong = chay(probe, nhan, cho)
        print('--- %s ---' % nhan)
        for l in dong[:40]:
            print(' ', l)
        print('  anh:', anh)

    if not a.nhanh:
        print()
        doc_lai()


if __name__ == '__main__':
    main()
