--[[
	offline/handlers/than_bi.lua — THẦN BÍ / CỬA HÀNG THẦN BÍ (神秘商店, GodSecret).

	SÁU lệnh `G_GodSecret`, KHÔNG có handler nào trước lượt này:
	  ClientRefresh · ClientFreeRefresh · ClientExchange · ClientGetGlobleScore ·
	  ClientGetRanking · ClientGetGloblePrize
	(khoá thứ bảy `ClientBuyGoods` để nguyên: `share/` KHÔNG có thân hàm mua cho
	`G_GodSecret` — đã khai từ Mốc 33, viết ra là bịa.)

	NGUỒN LUẬT: bản port của máy chủ giả `bc/may_chu/handler/than_bi.lua` (KHÔNG có
	trên máy — `bc/` là cây của bản Axmol, không nằm trong APK), nên luật được
	CHÉP sang đây, chỉ đổi TẦNG LƯU TRỮ: `the_gioi.*` → `G_DataManager` client.
	Mọi hằng số dưới đây là nguyên văn của tệp ấy (bản thân nó lấy từ khối chú
	thích của `share/Activities/GodSecret.lua`):
	  · `RefreshCost = 500` · `RefreshAddScore = 100` · `RefreshExchangeCD = 300` ·
	    `ExchangeListLenth = 3`;
	  · `ExchangeList` và `GloblePrizeList[*].PrizeList` **RỖNG** — đó là DỮ LIỆU
	    GAME, không có ở bất kỳ tệp cấu hình nào của client ⇒ không bịa vật phẩm.
	    Hệ quả ĐO ĐƯỢC: làm mới với nguồn rỗng thì `ExchangeStateList` KHÔNG bị
	    chạm tới (không xoá thành rỗng); `GloblePrizeList` vẫn có MỘT mốc 200 điểm.

	MÃ LỖI (nguyên văn `MA_LOI` của tệp máy chủ giả): 509 thiếu bảng · 4001 hoạt
	động chưa mở · 504 thiếu kim cương · 4020 còn CD miễn phí · 4021 không dựng
	được bàn · 5301 ô đã đổi · 4 tham số hỏng · 1201 thiếu vật · 4022 đã nhận
	thưởng mốc · 4023 thiếu điểm.

	KHÁC BIỆT BẮT BUỘC của offline (ghi rõ): điểm "toàn server" và BXH là của MỘT
	NGƯỜI ⇒ `GetGlobleScore` trả `Score` CỦA MÌNH (đơn vị duy nhất có), `GetRanking`
	trả danh sách RỖNG — cùng lựa chọn "trung thực" đã dùng cho BXH đấu trường.
]]

require("offline.log")
require("offline.store")
require("offline.router")

local R = OfflineRouter

local BANG = "GameGodSecret"
local BANG_TUI = "GameUserItem"
local BANG_HO_SO = "GameUserBaseInfo"
local KIEU_DATA = 1

local V_PROP, V_RES, RT_VANG, RT_KC = 2, 3, 1, 20
local STATE_DOI = 1

local CAU_HINH = {
	ExchangeListLenth = 3,
	ExchangeList = {},
	RefreshExchangeCD = 300,
	RefreshAddScore = 100,
	RefreshCost = 500,
	GloblePrizeList = { { Score = 200, PrizeList = {} } },
}

local daIn = {}
local function inMotLan(khoa, dong)
	if daIn[khoa] then return end
	daIn[khoa] = true
	OfflineLog:warn("than bi: " .. dong)
end

local function motData(bang, duLieu, truong)
	return { EventType = KIEU_DATA, TableName = bang, ChangeData = duLieu, KeyName = truong }
end

-- Mã lỗi: đọc `ErrorCode` thật (client đã nạp `share/error.lua`), rơi về `macDinh`.
local MA_LOI = {
	chuaMo = { nhom = "Activity", ten = "ActivityNotOpen", macDinh = 4001 },
	dangCD = { nhom = "GodSecret", ten = "FreeRefreshInCD", macDinh = 4020 },
	thieuBang = { nhom = "Common", ten = "SetDataErr", macDinh = 509 },
	thieuKimCuong = { nhom = "Common", ten = "NotEnoughDiamond", macDinh = 504 },
	khongDungDuoc = { nhom = "GodSecret", ten = "CreateExchangeListFaild", macDinh = 4021 },
	hasExchange = { nhom = "GodSecret", ten = "HasExchange", macDinh = 5301 },
	thamSoHong = { nhom = "System", ten = "ParamError", macDinh = 4 },
	thieuVat = { nhom = "Item", ten = "NotEnoughItem", macDinh = 1201 },
	vatLa = { nhom = "Common", ten = "SetDataErr", macDinh = 509 },
	daNhan = { nhom = "GodSecret", ten = "HasGetGloblePrize", macDinh = 4022 },
	thieuDiem = { nhom = "GodSecret", ten = "NoEnoughScore", macDinh = 4023 },
}

local function maLoi(m)
	local ok, nhom = pcall(function () return ErrorCode[m.nhom] end)
	if ok and type(nhom) == "table" and type(nhom[m.ten]) == "number" then
		return nhom[m.ten]
	end
	return m.macDinh
end

-- ---------------------------------------------------------------- tầng dữ liệu
local function userData()
	local d = G_DataManager and G_DataManager.userData
	return (type(d) == "table") and d or nil
end

local function bangGod()
	local d = userData()
	if d == nil then return nil end
	local b = d[BANG]
	if type(b) ~= "table" then
		b = { Score = 0, CumulativeScore = 0, NextFreeDrawTime = 0 }
		d[BANG] = b
	end
	return b
end

local function hoSo()
	local ok, r, b = pcall(function () return G_UserLogic:GetBaseInfo() end)
	if ok then
		if type(b) == "table" then return b end
		if type(r) == "table" then return r end
	end
	return nil
end

local function kimCuong() local b = hoSo(); return tonumber(b and b.Diamond) or 0 end
local function vang() local b = hoSo(); return tonumber(b and b.Gold) or 0 end

local function congKimCuong(delta)
	if delta == 0 then return kimCuong() end
	if delta < 0 then
		pcall(function () G_UserLogic:CostDiamond(-delta, "GodSecret") end)
	else
		pcall(function () G_UserLogic:AddDiamond(delta, "GodSecret") end)
	end
	return kimCuong()
end

local function congVang(delta)
	if delta == 0 then return vang() end
	if delta < 0 then
		pcall(function () G_UserLogic:CostGold(-delta, "GodSecret") end)
	else
		pcall(function () G_UserLogic:AddGold(delta, "GodSecret") end)
	end
	return vang()
end

local function soVat(id)
	local ok, bRet, n = pcall(function () return G_ItemLogic:GetItemCount(id) end)
	if not ok then return 0 end
	if type(bRet) == "number" and n == nil then return bRet end
	return tonumber(n) or 0
end

local function datVat(id, soMoi)
	if soMoi >= soVat(id) then
		pcall(function () G_ItemDataManager:AddItem(id, soMoi - soVat(id), "GodSecret") end)
	else
		pcall(function () G_ItemDataManager:ReduceItem(id, soVat(id) - soMoi, "GodSecret") end)
	end
	return { ItemCount = soMoi }
end

local function sync()
	pcall(function () OfflineStore:syncFromClient() end)
end

-- ---------------------------------------------------------------- quay bàn đổi
local function hopLe(dong)
	if type(dong) ~= "table" then return false end
	if type(dong.From) ~= "table" or type(dong.To) ~= "table" then return false end
	if type(dong.From.PrizeResType) ~= "number" or type(dong.From.PrizeResCount) ~= "number" then return false end
	if type(dong.To.PrizeResType) ~= "number" or type(dong.To.PrizeResCount) ~= "number" then return false end
	return true
end

--- Chép nguyên `M.quayDoiThu` của máy chủ giả: Fisher-Yates NGƯỢC, nguồn rỗng
--- KHÔNG phải lỗi (ra bàn rỗng), nguồn có dòng mà không dòng nào dùng được ⇒ 4021.
local function quayDoiThu(cauHinh)
	local nguon = cauHinh.ExchangeList or {}
	local lan = tonumber(cauHinh.ExchangeListLenth) or 0
	local duoc, soBo = {}, 0
	for i = 1, #nguon do
		if hopLe(nguon[i]) then duoc[#duoc + 1] = nguon[i] else soBo = soBo + 1 end
	end
	if #nguon > 0 and #duoc == 0 then return nil, soBo end
	if lan > #duoc then lan = #duoc end
	if lan < 0 then lan = 0 end
	for i = #duoc, 2, -1 do
		local j = math.random(i)
		duoc[i], duoc[j] = duoc[j], duoc[i]
	end
	local ra = {}
	for i = 1, lan do
		local d = duoc[i]
		local f, t = {}, {}
		for k, v in pairs(d.From) do f[k] = v end
		for k, v in pairs(d.To) do t[k] = v end
		ra[i] = { From = f, To = t, ExchangeScore = tonumber(d.ExchangeScore) or 0, ExchangeState = 0 }
	end
	return ra, soBo
end

local function phanLoai(vat)
	if type(vat) ~= "table" then return nil end
	local loai = tonumber(vat.PrizeResType); if loai == nil then return nil end
	local n = tonumber(vat.PrizeResCount); if n == nil or n < 0 then return nil end
	if loai == V_PROP then
		local id = tonumber(vat.PropID); if id == nil then return nil end
		return { kieu = "tui", id = id, so = n }
	end
	if loai == V_RES then
		local ct = tonumber(vat.CurrencyType)
		if ct == RT_VANG then return { kieu = "vang", so = n } end
		if ct == RT_KC then return { kieu = "kimcuong", so = n } end
	end
	return nil
end

local function dangCo(c)
	if c.kieu == "tui" then return soVat(c.id) end
	if c.kieu == "vang" then return vang() end
	return kimCuong()
end

local function ghiVat(c, dau)
	if c.so == 0 then return nil end
	if c.kieu == "tui" then
		local o = datVat(c.id, dangCo(c) + dau * c.so)
		return motData(BANG_TUI, { ItemID = c.id, ItemCount = o.ItemCount }, "ItemCount")
	end
	if c.kieu == "vang" then
		return motData(BANG_HO_SO, { Gold = congVang(dau * c.so) }, "Gold")
	end
	return motData(BANG_HO_SO, { Diamond = congKimCuong(dau * c.so) }, "Diamond")
end

-- ---------------------------------------------------------------- trả lời
local function hong(ctx, ma)
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", ma, {})
end

local function xong(ctx, cb, suKien, gui, ...)
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "G_GodSecret", cb, 0, suKien or {}, gui, ...)
end

-- ---------------------------------------------------------------- sáu khoá
R:on("G_GodSecret.ClientRefresh", function (ctx)
	local b = bangGod()
	if b == nil then return hong(ctx, maLoi(MA_LOI.thieuBang)) end
	local bayGio = os.time()
	local conLai = math.max(0, (tonumber(b.NextFreeDrawTime) or 0) - bayGio)
	local gia = conLai > 0 and CAU_HINH.RefreshCost or 0
	if gia > 0 and kimCuong() < gia then return hong(ctx, maLoi(MA_LOI.thieuKimCuong)) end

	local moi, soBo = quayDoiThu(CAU_HINH)
	if moi == nil then return hong(ctx, maLoi(MA_LOI.khongDungDuoc)) end
	if soBo and soBo > 0 then
		inMotLan("than_bi.bo", string.format("%d dong nguon doi thuong khong dung duoc — da BO", soBo))
	end

	local suKien = {}
	if gia > 0 then suKien[#suKien + 1] = motData(BANG_HO_SO, { Diamond = congKimCuong(-gia) }, "Diamond") end
	b.Score = (tonumber(b.Score) or 0) + CAU_HINH.RefreshAddScore
	b.CumulativeScore = (tonumber(b.CumulativeScore) or 0) + CAU_HINH.RefreshAddScore
	b.NextFreeDrawTime = bayGio + CAU_HINH.RefreshExchangeCD
	local doi = { Score = b.Score, CumulativeScore = b.CumulativeScore, NextFreeDrawTime = b.NextFreeDrawTime }
	if #moi > 0 then b.ExchangeStateList = moi; doi.ExchangeStateList = moi end
	suKien[#suKien + 1] = motData(BANG, doi, "NextFreeDrawTime")
	sync()
	OfflineLog:info(string.format("than bi: lam moi bang kim cuong (gia %d), diem %d", gia, b.Score))
	xong(ctx, "OnRefresh", suKien, { err = 0 })
end)

R:on("G_GodSecret.ClientFreeRefresh", function (ctx)
	local b = bangGod()
	if b == nil then return hong(ctx, maLoi(MA_LOI.thieuBang)) end
	local bayGio = os.time()
	if (tonumber(b.NextFreeDrawTime) or 0) - bayGio > 0 then return hong(ctx, maLoi(MA_LOI.dangCD)) end

	local moi, soBo = quayDoiThu(CAU_HINH)
	if moi == nil then return hong(ctx, maLoi(MA_LOI.khongDungDuoc)) end
	if soBo and soBo > 0 then
		inMotLan("than_bi.bo.free", string.format("%d dong nguon doi thuong khong dung duoc — da BO", soBo))
	end
	local suKien = {}
	b.Score = (tonumber(b.Score) or 0) + CAU_HINH.RefreshAddScore
	b.CumulativeScore = (tonumber(b.CumulativeScore) or 0) + CAU_HINH.RefreshAddScore
	b.NextFreeDrawTime = bayGio + CAU_HINH.RefreshExchangeCD
	local doi = { Score = b.Score, CumulativeScore = b.CumulativeScore, NextFreeDrawTime = b.NextFreeDrawTime }
	if #moi > 0 then b.ExchangeStateList = moi; doi.ExchangeStateList = moi end
	suKien[#suKien + 1] = motData(BANG, doi, "NextFreeDrawTime")
	sync()
	OfflineLog:info("than bi: lam moi MIEN PHI, diem " .. tostring(b.Score))
	xong(ctx, "OnFreeRefresh", suKien, 0)
end)

R:on("G_GodSecret.ClientExchange", function (ctx, nIndex)
	local b = bangGod()
	if b == nil then return hong(ctx, maLoi(MA_LOI.thieuBang)) end
	local i = tonumber(nIndex)
	if i == nil or i ~= math.floor(i) or i < 1 then return hong(ctx, maLoi(MA_LOI.thamSoHong)) end
	local ban = b.ExchangeStateList
	if type(ban) ~= "table" or #ban == 0 then return hong(ctx, maLoi(MA_LOI.khongDungDuoc)) end
	local dong = ban[i]
	if type(dong) ~= "table" then return hong(ctx, maLoi(MA_LOI.thamSoHong)) end
	if tonumber(dong.ExchangeState) == STATE_DOI then return hong(ctx, maLoi(MA_LOI.hasExchange)) end

	local cFrom, cTo = phanLoai(dong.From), phanLoai(dong.To)
	if cFrom == nil or cTo == nil then return hong(ctx, maLoi(MA_LOI.vatLa)) end
	if dangCo(cFrom) < cFrom.so then return hong(ctx, maLoi(MA_LOI.thieuVat)) end

	local suKien = {}
	local m1 = ghiVat(cFrom, -1); if m1 ~= nil then suKien[#suKien + 1] = m1 end
	local m2 = ghiVat(cTo, 1); if m2 ~= nil then suKien[#suKien + 1] = m2 end
	dong.ExchangeState = STATE_DOI
	local diem = tonumber(dong.ExchangeScore) or 0
	b.Score = (tonumber(b.Score) or 0) + diem
	b.CumulativeScore = (tonumber(b.CumulativeScore) or 0) + diem
	suKien[#suKien + 1] = motData(BANG,
		{ Score = b.Score, CumulativeScore = b.CumulativeScore, ExchangeStateList = ban }, "ExchangeStateList")
	sync()
	OfflineLog:info(string.format("than bi: doi o %d, diem %d", i, b.Score))
	xong(ctx, "OnExchange", suKien, i)
end)

R:on("G_GodSecret.ClientGetGlobleScore", function (ctx)
	local b = bangGod()
	if b == nil then return hong(ctx, maLoi(MA_LOI.thieuBang)) end
	-- Offline một người: "điểm toàn server" = điểm CỦA MÌNH (`Score`, không phải
	-- `CumulativeScore` — hai trường hai nghĩa, đọc nhầm là lỗi im lặng).
	xong(ctx, "OnGetGlobleScore", {}, tonumber(b.Score) or 0)
end)

R:on("G_GodSecret.ClientGetRanking", function (ctx)
	-- Một người chơi ⇒ bảng RỖNG là sự thật (cùng lựa chọn với BXH đấu trường).
	xong(ctx, "OnGetRanking", {}, {})
end)

R:on("G_GodSecret.ClientGetGloblePrize", function (ctx, nIndex)
	local b = bangGod()
	if b == nil then return hong(ctx, maLoi(MA_LOI.thieuBang)) end
	local ds = CAU_HINH.GloblePrizeList or {}
	local i = tonumber(nIndex) or 1
	local moc = ds[i]
	if type(moc) ~= "table" then return hong(ctx, maLoi(MA_LOI.khongDungDuoc)) end
	b.GloblePrizeGet = b.GloblePrizeGet or {}
	if b.GloblePrizeGet[tostring(i)] == true then return hong(ctx, maLoi(MA_LOI.daNhan)) end
	if (tonumber(b.Score) or 0) < (tonumber(moc.Score) or 0) then return hong(ctx, maLoi(MA_LOI.thieuDiem)) end

	-- `PrizeList` RỖNG là dữ liệu game chưa có ⇒ 509 (khác 4021: bảng mốc CÓ).
	local prize = moc.PrizeList or {}
	if #prize == 0 then return hong(ctx, maLoi(MA_LOI.vatLa)) end
	local suKien = {}
	for _, p in ipairs(prize) do
		local c = phanLoai(p)
		if c ~= nil then
			local m = ghiVat(c, 1)
			if m ~= nil then suKien[#suKien + 1] = m end
		end
	end
	b.GloblePrizeGet[tostring(i)] = true
	suKien[#suKien + 1] = motData(BANG, { GloblePrizeGet = b.GloblePrizeGet }, "GloblePrizeGet")
	sync()
	xong(ctx, "OnGetGloblePrize", suKien, i)
end)

OfflineLog:info("than bi: da noi 6 khoa (Refresh/FreeRefresh/Exchange/GetGlobleScore/GetRanking/GetGloblePrize)")

return true
