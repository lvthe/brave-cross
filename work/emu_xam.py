"""Do HINH cua `setGray` (lam xam nut / nut bi khoa) bang may ao Android.

    python emu_xam.py --cay                # dum cay node canh Main, tim nut tinh
    python emu_xam.py --duong 1:2:3 --tat  # chay het cac luot do tren nut do
    python emu_xam.py --so                 # chi doc anh da chup, khong dung may ao

VI SAO PHAI DO
--------------
`lua/cocos.lua` moi lam phan TRANG THAI cua `setGray` (ghi co / doc co). Phan
HINH chua lam. Doc ma may (`libgame.so`) thi biet no la mot shader:

    than ham 0x49d6d4 (5 ban sao o 5 lop khac nhau):
        *(uint8*)(self + 0x23b) = b
        self->vfunc_0x158(b ? "ShaderPositionTextureColor_Gray"
                            : "ShaderPositionTextureColor")

    nguon shader xam, .rodata 0x7ccf00, o vi tri 18 trong bang nguon 0x93caec:
        float alpha = texture2D(CC_Texture0, v_texCoord).a;
        float grey  = dot(texture2D(CC_Texture0, v_texCoord).rgb,
                          vec3(0.299, 0.587, 0.114));
        gl_FragColor = vec4(grey, grey, grey, alpha);

Doc ma ra thi `v_fragmentColor` DUOC KHAI BAO NHUNG KHONG DUNG — nghia la khi
bat xam thi mau node va do mo CUA NODE bi bo, chi con anh goc. Do la mot quirks
that, va no doi hoi phai DO chu khong duoc suy doan.

**Da giai xong — nhung KHONG phai bang bo do nay.** Hai duong khac, doc lap:

  * Doc MA: `shaderghep.py --bang` noi duoc ten voi nguon (GRAY = chi so 1,
    nguon manh `N[18] = 0x7ccf00`), va giai thich luon vi sao phep quet con tro
    cho ket qua AM — dia chi chuoi ten duoc dung bang PC-TUONG-DOI
    (`ldr r1,[pc,#imm]` + `add r1, pc`, o hang so chua `dich - pc`), nen trong
    file khong he co 4 byte nao bang dia chi chuoi. Ket luan cu ghi o cho khac
    rang "dia chi duoc dung bang movw/movt" la SUY DOAN, khong phai do.
  * Do DIEM ANH: `bravecross-game/tools/do_xam.gd` (11/11 dat) — no tai hien
    lai dung cong thuc tren trong Godot va do ra tung con so: he so Rec.601
    (0,6000) va loai han Rec.709 (0,6585), mau node bi bo, do mo bi bo, va ca
    mau thua ke tu node CHA cung bi bo.

Bo do nay GIU LAI vi mot ly do khac, va ly do do con nguyen gia tri: no la BAN
GHI nhung gi may ao LAM DUOC va KHONG LAM DUOC, do bang nhieu luot chay that.
Danh sach do con dung cho moi phep do khac ve sau:

  * `node:getChildren()` -> SIGSEGV (fault addr 0x2a51b90). `isVisible()` va
    `CCLayer:getPosition()` cung vay. Nen KHONG the chay `CPublic:SetObjGray`
    tren may ao: ham do di xuong con bang chinh `getChildren`.
  * `scheduleOnce` tra ve mot `CCSchedule` va bao thanh cong nhung KHONG BAO GIO
    chay.
  * Mot loi Lua GIET CA TIEN TRINH, ke ca khi nam trong `pcall` — do lai trong
    luot `thuLoi`: logcat in toi `XAM|co-gi|` roi tat, khong bao gio in
    `XAM|pcall-trong|false`. Nen moi lenh do phai TU KIEM ham co ton tai truoc
    khi goi.
  * Doc truong cua metatable KHONG dung duoc lam phep THU CO MAT voi
    `CDFSpriteRole`: `n.setPosition` doc ra nil (nen mot nhanh bao ve kieu
    `if n.setPosition then` bi bo qua IM LANG) trong khi `n:setPosition(x,y)` /
    `n:getPosition()` / `n:getContentSize()` deu goi duoc that.
  * `CDFSpriteRole` KHONG co `setGray`/`setColor`/`setOpacity`, va
    `getSpriteFromSpriteCatch("UITongYong_ItemLight")` cung tra ve mot
    `CDFSpriteRole` (128x128) — nen khong co doi tuong nao vua chac chan hien
    tren man vua du ham de lam phep do.
  * Node bo cuc trong `_G` la bien LUA (`CPublic:FindUiByPath` doc `_G[ten]` roi
    `getChildByTag`), va quet duoc 120 ten, trong do 30 ten co `setGray`. Nhung
    chung KHONG phai node dang duoc VE: `_G.btnMainStore` la mot `CCSprite`
    (345x171 o 564,175) ma doi cho bang `setPosition(-3000,-3000)` doi dung
    **0 diem anh**, `setColor`/`setGray` cung khong doi gi. Nen muon do tren may
    ao thi truoc het phai tim ra node nao moi la node dang ve — viec do chua
    lam.
  * Vi vay cac phep (a)..(d) duoi day la THIET KE cua bo do, khong phai ket qua
    da do duoc. Phan dinh luong nay da lam o phia Godot.

CAC LUOT DO, VA VI SAO MOI LUOT DEU DUT KHOAT
---------------------------------------------
Goi `a` la do mo cua node, `C` mau goc cua anh, `grey = 0.299Cr+0.587Cg+0.114Cb`,
`bg` la nen, `O` la mau shader tra ra:

  * nen    : khong doi gi                          -> P1 = a*C + (1-a)*bg
  * xam    : setGray(true)                         -> P2 = a*O + (1-a)*bg
  * xam2   : setGray(true), chay LAI y nguyen      -> P2'  (muc nhieu nen)
  * do_xam : setColor(255,0,0) + setGray(true)     -> P3
  * do     : setColor(255,0,0), khong xam          -> P4 = a*Cred + (1-a)*bg
  * mo_xam : setOpacity(128) + setGray(true)       -> P5
  * mo     : setOpacity(128), khong xam            -> P6

  (0) **xam2 so voi xam** dat ra MUC NHIEU NEN. Man Main co phan tu dong
      (hieu ung, chu dong), nen hai lan chay y nguyen van khac nhau chut it.
      Moi phep "giong nhau" duoi day chi duoc coi la dat khi no NAM TRONG muc
      nhieu do — neu khong thi mot phep "giong nhau" co the chi la may man.
  (a) **P3 == P2** (trong muc nhieu). Shader xam khong doc `v_fragmentColor`,
      nen doi mau node khong doi duoc gi. Da kiem ca 28 nguon shader trong
      binary: **chi nguon 18** bo qua `v_fragmentColor`, moi nguon khac deu
      nhan no — nen phep nay loai het cac ung vien con lai, va khong can biet
      anh goc mau gi.
  (b) **P4 != P1**. Doi chung: `setColor` tren node do VAN co tac dung binh
      thuong, tuc phep (a) khong phai "vi setColor khong chay".
  (c) **P5 == P2, va P6 != P1**. Do mo cung bi bo (alpha lay tu ANH, khong tu
      `v_fragmentColor.a`) — chinh cai quirks doc duoc o tren, nay do lai.
  (d) **P2 != P1, va chieu lech dung cong thuc luma.** Do lech mau
      `D = P2 - P1 = a*(grey - C)`: kenh nao cua anh goc LON hon `grey` thi
      TOI di, kenh nao NHO hon thi SANG len. Do la dau vet cua mot phep chieu
      len truc xam, khac han moi shader to mau khac (to mau thi chi day mot
      kenh len, khong keo kenh khac xuong theo tuong quan am).

(0), (a) va (c) khong phu thuoc anh goc. (b) chong lai loi "goi ham khong chay".
(d) la phep dinh luong, chi lam duoc khi biet anh goc — voi node giao dien thi
khong biet, nen (d) o day chi o muc "chieu lech co dung dau khong", va phan
dinh luong Rec.601 phai lam o phia Godot bang anh da biet.

Vi sao KHONG dung armature (`DaQuZhanShi`): no co dong tac, ma dong tac chay
theo thoi gian tu luc khoi dong, nen hai luot chup se o hai tu the khac nhau —
phep "P3 == P2" doi hoi hai anh giong nhau tung diem. Nut giao dien tinh moi
dung. Neu `--cay` khong tim ra nut tinh nao thi phai NOI RA la phep do nay
khong chay duoc, khong duoc thay bang mot phep yeu hon roi goi la da do.

Vi sao phai `adb root` truoc
----------------------------
`adb push` vao `/data/data/<pkg>/files/download` can adbd chay bang root. Khong
co root thi `adb push` that bai IM LANG (`emu_tags.adb` khong kiem ma tra ve), va
may ao van chay ban `game.lua` CU — trieu chung: logcat in ra moc `CHEN|` nhung
KHONG mot dong `XAM|` nao. Da mac dung bay nay mot lan.
"""
import argparse
import pathlib
import re
import sys
import time

import emu_tags as E
from emu_dom import dung_de

HERE = pathlib.Path(__file__).resolve().parent
ANH = HERE / '_dom'
NEN = ANH / 'nen.png'

# Nap bo cuc Main roi cho engine VE. Giong `emu_dom.DUNG_CANH`.
DUNG_CANH = '''
	local function buoc(ten, f)
		print("XAM|" .. ten .. "|bat-dau")
		local ok, a = pcall(f)
		local tv
		if type(a) == "table" then tv = "table#" .. tostring(#a)
		else tv = tostring(a) end
		print("XAM|" .. ten .. "|xong|" .. tostring(ok) .. "|" .. tv)
		return ok, a
	end

	buoc("nap-bo-cuc", function()
		return loadLevelFile("conf/UI_Main_960_640.xgg")
	end)
	local sc = rawget(_G, "g_MainUIScene")
	print("XAM|canh|" .. tostring(sc))
	if sc == nil then
		print("XAM|het|khong nap duoc bo cuoc Main")
		return nil
	end
	buoc("replaceScene", function() return S_CCDirector:replaceScene(sc) end)
'''

# Liet ke cac node CO TEN trong _G.
#
# `getChildren` chet duoi ban dich ARM (da do: SIGSEGV trong
# libndk_translation.so, dung cho ma `CPublic:SetObjGray` goi), nen KHONG the
# dum cay. Nhung bo nap bo cuoc dat ten cho tung node thanh bien toan cuc
# (`_G`, theo cach `CPublic:FindUiByPath` doc: `objTemp = _G[strRootUIName]`
# roi moi `getChildByTag`), nen `pairs(_G)` liet ke duoc het node cua bo cuoc
# ma khong can loi goi engine nao.
#
# CHI LIET KE, KHONG GOI PHUONG THUC NAO. Lan dau thu goi `getContentSize` ngay
# trong vong lap nay thi tien trinh chet ngay sau dong dau: `_G` khong chi co
# node ma con co `S_CCDirector`, `S_CCSchedule`…, va goi mot phuong thuc cua
# Node len mot userdata khong phai Node la doc bay vao vung nho khac. pcall
# khong do duoc loi native. Muon kiem tra mot cai ten thi lam o luot rieng.
DAU_DO_TEN = ('\n-- === CHEN DE DO: liet ke node co ten ===\n'
              'do\n' + DUNG_CANH + '''
	if sc == nil then return end
	local dem = 0
	local ud, khac = 0, 0
	for k, v in pairs(_G) do
		local tv = type(v)
		if type(k) == "string" then
			if tv == "userdata" then
				ud = ud + 1
				print("XAM|TEN|" .. k)
			else
				khac = khac + 1
			end
		end
	end
	print("XAM|dem|userdata=" .. tostring(ud) .. "|khac=" .. tostring(khac))
	print("XAM|san-sang")
end
''')

# Thu `setGray` tren NHIEU nut trong MOT lan chay: in trang thai truoc khi goi,
# roi goi trong pcall va in ket qua. In TRUOC khi goi la co y — neu mot nut lam
# chet tien trinh thi dong cuoi cung con lai chinh la thu pham.
#
# Man hinh cua luot nay bi thay doi (nhieu nut bi lam xam cung luc) nen anh chup
# cua no KHONG dung de do — chi doc dong log.
DAU_DO_THU = ('''\n-- === CHEN DE DO: thu setGray tren nhieu nut ===\n
do
''' + DUNG_CANH + '''
	if sc == nil then return end
	local function goi(ten, f)
		print("XAM|goi|" .. ten .. "|bat-dau")
		local ok, a = pcall(f)
		if type(a) == "table" then a = "table#" .. tostring(#a) end
		print("XAM|goi|" .. ten .. "|xong|" .. tostring(ok) .. "|" .. tostring(a))
		return ok, a
	end
	local ds = {%(ds)s}
	for i = 1, #ds do
		local ten = ds[i]
		local n = rawget(_G, ten)
		print("XAM|thu|" .. i .. "|" .. ten .. "|co=" .. tostring(n))
		if n ~= nil then
			goi(ten .. ".co", function() return n:getContentSize() end)
			goi(ten .. ".vt", function() return n:getPosition() end)
			-- `isVisible` CO Y BO: da do — no lam chet ban dich ARM ngay
			-- (SIGSEGV trong libndk_translation.so), pcall khong do duoc.
			goi(ten .. ".mau", function() return n:getColor() end)
			goi(ten .. ".setGray", function() return n:setGray(true) end)
			goi(ten .. ".isGray", function() return n:isGray() end)
		end
	end
	print("XAM|san-sang")
end
''')

# Kiem tra tung node co TEN trong `_G` co nhung phuong thuc nao.
#
# CHI DOC TRUONG CUA METATABLE (`n.setGray`), KHONG GOI PHUONG THUC NAO. Doc
# truong la tra cuu bang, khong dung toi doi tuong C++; con `getPosition` tren
# mot `CCLayer` da do la lam chet ban dich ARM. Nho vay luot nay quet duoc ca
# 120 ten ma khong so chet giua chung.
DAU_DO_COGI = ('\n-- === CHEN DE DO: kiem tra phuong thuc cua node co ten ===\n'
               'do\n' + DUNG_CANH + '''
	if sc == nil then return end
	local function co(n, ten)
		return (n[ten] ~= nil) and "1" or "0"
	end
	local dem = 0
	for k, v in pairs(_G) do
		if type(k) == "string" and type(v) == "userdata" then
			dem = dem + 1
			print("XAM|CO|" .. k
				.. "|setGray=" .. co(v, "setGray")
				.. "|isGray=" .. co(v, "isGray")
				.. "|setColor=" .. co(v, "setColor")
				.. "|setOpacity=" .. co(v, "setOpacity")
				.. "|setString=" .. co(v, "setString")
				.. "|setPosition=" .. co(v, "setPosition")
				.. "|setDisplayFrame=" .. co(v, "setDisplayFrame"))
		end
	end
	print("XAM|dem|" .. tostring(dem))
	print("XAM|san-sang")
end
''')

# Dum cay con: tag, kich thuoc, vi tri, z, ten lua.
#
# Goi NGAY, khong qua `scheduleOnce`: do duoc la `scheduleOnce(obj, "ten")` tra
# ve mot CCSchedule va khong bao loi, nhung ham hen gio KHONG BAO GIO chay (khong
# mot dong `XAM|dum|bat-dau` nao ra). Con duong da do la chay thang — y nhu
# `emu_dom` van lam: ngay sau `loadLevelFile` + `replaceScene` thi cay da dung
# xong, `getChildByTag`/`addChild` deu chay duoc.
#
# KHONG goi `getChildrenCount` (da do: ban dich ARM chet o loi goi do) va khong
# goi `getDescription` (cung chet). Moi loi goi qua pcall nen lan chay sau biet
# ngay chet o dau.
DAU_DO_CAY = ('\n-- === CHEN DE DO: dum cay node canh Main ===\n'
              'do\n' + DUNG_CANH + '''
	if sc == nil then return end
	local dem = 0
	local function so(f)
		local ok, a = pcall(f)
		if not ok then return "LOI" end
		return tostring(a)
	end
	local function dum(n, ten, sau)
		if sau <= 0 or dem > 300 then return end
		local ok, g = pcall(function() return n:getChildren() end)
		if not ok or g == nil then
			print("XAM|" .. ten .. "|khong lay duoc con")
			return
		end
		local m = 0
		if not pcall(function() m = #g end) then
			print("XAM|" .. ten .. "|khong dem duoc con")
			return
		end
		for i = 1, m do
			local c = g[i]
			local tag = so(function() return c:getTag() end)
			local co = so(function()
				local w, h = c:getContentSize()
				return string.format("%sx%s", tostring(w), tostring(h))
			end)
			local vt = so(function()
				local x, y = c:getPosition()
				return string.format("%s,%s", tostring(x), tostring(y))
			end)
			local z = so(function() return c:getZOrder() end)
			local nm = so(function() return c:getLuaName() end)
			local hien = so(function() return c:isVisible() end)
			dem = dem + 1
			print(string.format(
				"XAM|CAY|%s.%d|tag=%s|co=%s|vt=%s|z=%s|hien=%s|ten=%s",
				ten, i, tag, co, vt, z, hien, nm))
			dum(c, ten .. "." .. i, sau - 1)
		end
	end
	dum(sc, "sc", 3)
	print("XAM|dem|" .. tostring(dem))
	print("XAM|san-sang")
end
''')

# Mot luot do tren MOT nut, chon theo TEN (node cua bo cuoc duoc dat ten thanh
# bien toan cuc — cung loi ma `CPublic:FindUiByPath` dung).
#
# Goi thang (xem chu thich `DAU_DO_TEN`): doi trang thai ngay sau khi dung canh,
# nen khung hinh dau tien da mang trang thai do, va anh chup khong phu thuoc vao
# thoi diem chup. Neu phan nap canh sau do co ghi de mau thi phep doi chung se lo
# ra: luot `xam` se bang luot `nen`.
DAU_DO_LUOT = ('''\n-- === CHEN DE DO: mot luot setGray ===\n
do
''' + DUNG_CANH + '''
	if sc == nil then return end
	local n = nil
%(chuan_bi)s
	if n == nil then return end
	print("XAM|nut|%(nhan)s|" .. tostring(n))
	local okc, w, h = pcall(function() return n:getContentSize() end)
	local okv, x, y = pcall(function() return n:getPosition() end)
	print("XAM|co-vt|" .. tostring(okc) .. "|" .. tostring(w)
		.. "x" .. tostring(h) .. "|" .. tostring(x) .. "," .. tostring(y))
	-- Co nhung phuong thuc nao (doc truong metatable, an toan).
	local cg = (n.setGray ~= nil) and "C" or "-"
	local cc = (n.setColor ~= nil) and "C" or "-"
	local co_ = (n.setOpacity ~= nil) and "C" or "-"
	print("XAM|co-gi|setGray=" .. cg .. "|setColor=" .. cc
		.. "|setOpacity=" .. co_)
	local ok, e = pcall(function() %(lenh)s end)
	print("XAM|doi|" .. tostring(ok) .. "|" .. tostring(e))
	print("XAM|san-sang")
end
''')

# Chuan bi kieu 1: lay node theo TEN trong `_G` (node cua bo cuoc duoc dat ten
# thanh bien toan cuc — cung loi ma `CPublic:FindUiByPath` dung).
CB_TEN = '''
	n = rawget(_G, "%(nut)s")
	if n == nil then
		print("XAM|het|khong co nut ten %(nut)s")
	end
'''

# Chuan bi kieu 2: tu dung mot armature roi gan vao canh — duong DUY NHAT da do
# la CO VE (emu_dom da do bang cach nay: hieu ung `UITongYong_ItemLight` va
# tuong `DaQuZhanShi` deu hien ra trong anh chup).
#
# `%(chay)s` = co goi `_Lua_playAnimation("Play")` hay khong. KHONG goi thi
# tuong dung o tu the nghi — tinh, nen hai lan chup giong nhau tung diem, va
# phep "P3 == P2" moi kiem duoc. CO goi thi dong tac chay theo thoi gian tu luc
# khoi dong, hai lan chup se lech nhau, va moi phep so chi con la thong ke.
CB_TUONG = '''
	local okE, e = pcall(function() return getSpriteFromSpriteCatch("%(tuong)s") end)
	print("XAM|dung-tuong|ok=" .. tostring(okE) .. "|" .. tostring(e))
	if okE and e ~= nil then
		n = e
		pcall(function() return n:setPosition(%(x)s, %(y)s) end)
		%(chay)s
		pcall(function() return sc:addChild(n, 60000, 60000) end)
		print("XAM|gan-xong")
	end
'''

# MOI LENH PHAI TU KIEM TRA PHUONG THUC CO TON TAI KHONG.
#
# Do duoc: mot loi Lua (goi phuong thuc khong co) lam CHET TIEN TRINH du no nam
# trong `pcall` - pcall bat duoc loi Lua, nhung tien trinh van chet ngay sau do.
# Trieu chung giong het "ban dich ARM khong chay duoc lenh nay", nen neu khong
# tu kiem tra thi se ket luan sai ve ENGINE trong khi loi la cua DAU DO.
# `n.setGray` (doc truong cua metatable) thi an toan, tra ve nil.
LENH = {
    'nen':    'local x = 1',
    'xam':    'if n.setGray then n:setGray(true) else print("XAM|thieu|setGray") end',
    'xam2':   'if n.setGray then n:setGray(true) else print("XAM|thieu|setGray") end',
    'do_xam': 'if n.setColor then n:setColor(255, 0, 0) end '
              'if n.setGray then n:setGray(true) else print("XAM|thieu|setGray") end',
    'do':     'if n.setColor then n:setColor(255, 0, 0) else print("XAM|thieu|setColor") end',
    'mo_xam': 'if n.setOpacity then n:setOpacity(128) end '
              'if n.setGray then n:setGray(true) else print("XAM|thieu|setGray") end',
    'mo':     'if n.setOpacity then n:setOpacity(128) else print("XAM|thieu|setOpacity") end',
    # Doi chung ve VI TRI: `setPosition` la loi goi da do la chay duoc, va day
    # la node o giua man hinh. Neu doi cho ma man hinh KHONG doi thi ket luan
    # khong phai "setGray khong co tac dung" ma la "`_G[ten]` khong phai node
    # dang duoc ve" — mot ket luan khac han, va phai noi dung cai nao.
    'doi_cho': 'if n.setPosition then n:setPosition(-3000, -3000) end',
    # Doi chung ve chinh cai `pcall`: mot loi Lua CO lam chet tien trinh khong?
    # Lan dau (goi phuong thuc tren nil) tien trinh chet ngay sau `pcall`, nhung
    # do la suy doan tu mot lan chay. Phep nay tach doi hai kha nang:
    #   - in ra `pcall-trong|false` roi moi chet  -> loi Lua KHONG chet; thu
    #     lam chet la thu khac (in thong bao loi chu?)
    #   - chet TRUOC khi in duoc dong nao    -> ban than loi Lua lam chet
    # Ket qua nay quyet dinh moi dau do sau nay phai tu kiem tra phuong thuc
    # truoc khi goi, hay co the dung pcall thoai mai.
    'thuLoi': ('local o = pcall(function() error("thu mot loi Lua") end) '
               'print("XAM|pcall-trong|" .. tostring(o)) '
               'error("thu mot loi Lua that su")'),
}
THU_TU = ['nen', 'xam', 'xam2', 'do_xam', 'do', 'mo_xam', 'mo']

# Cac nut dem ra thu: truoc het la sprite trang tri (la, co anh, mau manh, tinh),
# sau do moi den nut bam (la NODE CHUA, ban than no khong ve gi — `CUIGame.lua`
# phai tu xuong tung con moi lam xam duoc, xem :3968-3992).
THU_NUT = ['spMainUITheme_halloween_1', 'spMainUITheme_halloween_5',
           'spMainUITheme_halloween_77', 'UI2ZhouNianZhuangShi_Guang1',
           'mainThemeDarkBg', 'btnMainStore', 'btnMainUIAttack',
           'lMainUIThemeBase', 'gb10_1']


def chay(probe, nhan, cho=20):
    """Mot lan khoi dong game: day cay ghi de, chay, chup man hinh, doc logcat."""
    sc_dir = dung_de(probe, HERE / '_dom')
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
    xa = '/sdcard/' + nhan + '.png'
    E.adb('shell', 'screencap', '-p', xa)
    dich = ANH / (nhan + '.png')
    E.adb('pull', xa, str(dich))
    E.adb('shell', 'rm', '-f', xa)
    txt = E.adb('logcat', '-d').stdout
    dong = re.findall(r'(?:XAM|DOM|CHEN)\|[^\n\r]*', txt)
    return (dich if dich.exists() else None), dong


def _anh(p):
    from PIL import Image
    return Image.open(p).convert('RGB')


def so_hai(pa, pb, nguong=12):
    """So hai anh diem-anh-diem: so diem khac, ti le, hop bao, mau trung binh."""
    A, B = _anh(pa), _anh(pb)
    if A.size != B.size:
        return dict(loi='khac kich thuoc %s vs %s' % (A.size, B.size))
    da, db = A.tobytes(), B.tobytes()
    n = len(da) // 3
    khac = 0
    x0, y0, x1, y1 = 10 ** 9, 10 ** 9, -1, -1
    w = A.size[0]
    ta = [0, 0, 0]
    tb = [0, 0, 0]
    lech = [0.0, 0.0, 0.0]
    for i in range(n):
        o = i * 3
        a0, a1, a2 = da[o], da[o + 1], da[o + 2]
        b0, b1, b2 = db[o], db[o + 1], db[o + 2]
        ta[0] += a0; ta[1] += a1; ta[2] += a2
        tb[0] += b0; tb[1] += b1; tb[2] += b2
        lech[0] += b0 - a0; lech[1] += b1 - a1; lech[2] += b2 - a2
        if abs(a0 - b0) > nguong or abs(a1 - b1) > nguong or abs(a2 - b2) > nguong:
            khac += 1
            x, y = i % w, i // w
            if x < x0: x0 = x
            if x > x1: x1 = x
            if y < y0: y0 = y
            if y > y1: y1 = y
    return dict(
        khac=khac, ti_le=khac / float(n),
        hop=None if x1 < 0 else (x0, y0, x1, y1),
        tb_a=tuple(v / n for v in ta), tb_b=tuple(v / n for v in tb),
        lech=tuple(v / n for v in lech),
    )


def in_so(pa, pb, nhan):
    r = so_hai(pa, pb)
    if 'loi' in r:
        print('  %-22s %s' % (nhan, r['loi']))
        return r
    hop = '' if r['hop'] is None else '%dx%d @%d,%d' % (
        r['hop'][2] - r['hop'][0] + 1, r['hop'][3] - r['hop'][1] + 1,
        r['hop'][0], r['hop'][1])
    print('  %-22s khac %7d diem (%5.2f%%) hop %-18s lech TB %+6.2f %+6.2f %+6.2f'
          % (nhan, r['khac'], r['ti_le'] * 100, hop, r['lech'][0],
             r['lech'][1], r['lech'][2]))
    return r


def so(tien='xam-'):
    print('anh trong %s (tien to %r):' % (ANH, tien))
    for t in THU_TU:
        p = ANH / ('%s%s.png' % (tien, t))
        print('  %-8s %s' % (t, 'co' if p.exists() else 'THIEU'))
    print('\nso tung cap (nguong 12/kenh):')
    co = {t: ANH / ('%s%s.png' % (tien, t)) for t in THU_TU}
    if not all(p.exists() for p in co.values()):
        print('  thieu anh, bo qua')
        return
    in_so(co['nen'], co['xam'], 'xam vs nen')
    in_so(co['xam'], co['xam2'], 'xam2 vs xam  [NHIEU]')
    in_so(co['xam'], co['do_xam'], 'do_xam vs xam  (a)')
    in_so(co['nen'], co['do'], 'do vs nen      (b)')
    in_so(co['xam'], co['mo_xam'], 'mo_xam vs xam  (c)')
    in_so(co['nen'], co['mo'], 'mo vs nen      (b)')


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--cay', action='store_true', help='dum cay node canh Main')
    ap.add_argument('--ten', action='store_true',
                    help='liet ke node co ten trong _G')
    ap.add_argument('--thu', default=None,
                    help='thu setGray tren cac ten nay (phay ngan cach)')
    ap.add_argument('--co-gi', action='store_true',
                    help='in ra moi node co ten co nhung phuong thuc nao')
    ap.add_argument('--nut', default='btnMainStore',
                    help='ten node se do (bien toan cuc cua bo cuoc)')
    ap.add_argument('--tuong', default='',
                    help='thay vi lay node co ten, tu dung armature nay')
    ap.add_argument('--chay-dong-tac', action='store_true',
                    help='goi _Lua_playAnimation("Play") tren armature')
    ap.add_argument('--luot', default='', help='chi chay mot luot')
    ap.add_argument('--tat', action='store_true', help='chay het cac luot')
    ap.add_argument('--so', action='store_true', help='chi doc anh da chup')
    ap.add_argument('--so-tien-to', default='xam-',
                    help='tien to ten anh khi doc lai (mac dinh xam-)')
    a = ap.parse_args()
    ANH.mkdir(exist_ok=True)
    if a.so:
        so(a.so_tien_to)
        return
    if not (a.cay or a.ten or a.thu is not None or a.co_gi or a.luot or a.tat):
        ap.print_help()
        return

    ds = [l for l in E.adb('devices').stdout.splitlines()
          if l.strip().endswith('device')]
    if not ds:
        raise SystemExit('khong thay may ao nao — bat emulator truoc')
    print('may ao:', ', '.join(l.split()[0] for l in ds))

    if a.cay:
        _, dong = chay(DAU_DO_CAY, 'cay', 18)
        for l in dong:
            if l.startswith('XAM|CAY|') or 'bat-dau' not in l:
                print(' ', l)
        return

    if a.ten:
        _, dong = chay(DAU_DO_TEN, 'ten', 18)
        for l in dong:
            if l.startswith('XAM|TEN|') or 'bat-dau' not in l:
                print(' ', l)
        return

    if a.co_gi:
        _, dong = chay(DAU_DO_COGI, 'cogi', 18)
        for l in dong:
            if l.startswith('XAM|CO|') or 'bat-dau' not in l:
                print(' ', l)
        return

    if a.thu is not None:
        ds = [x for x in a.thu.split(',') if x] or THU_NUT
        probe = DAU_DO_THU % {'ds': ', '.join('"%s"' % x for x in ds)}
        _, dong = chay(probe, 'thu', 18)
        for l in dong:
            if l.startswith('XAM|thu') or 'bat-dau' not in l:
                print(' ', l)
        return

    if a.luot:
        ds_luot = [a.luot]
    elif a.tat:
        ds_luot = THU_TU
    else:
        ap.print_help()
        return
    for ten in ds_luot:
        if ten not in LENH:
            raise SystemExit('khong biet luot %r' % ten)
        if a.tuong:
            chuan_bi = CB_TUONG % {
                'tuong': a.tuong, 'x': 480, 'y': 500,
                'chay': ('pcall(function() return n:_Lua_playAnimation("Play") end)'
                         if a.chay_dong_tac else
                         'print("XAM|khong-chay-dong-tac")')}
            nhan = a.tuong
        else:
            chuan_bi = CB_TEN % {'nut': a.nut}
            nhan = a.nut
        probe = DAU_DO_LUOT % {'chuan_bi': chuan_bi, 'nhan': nhan,
                               'lenh': LENH[ten]}
        nhan_file = ('t-%s-%s' % (a.tuong, ten)) if a.tuong else ('xam-' + ten)
        _, dong = chay(probe, nhan_file, 20)
        print('--- %s (%s) ---' % (ten, nhan))
        for l in dong:
            print(' ', l)


if __name__ == '__main__':
    main()
