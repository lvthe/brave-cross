--[[
	offline/handlers/vo_hon.lua — NÂNG VÕ HỒN (武魂) CỦA TƯỚNG.

	Khoá `G_HeroLogic|ClientUpHeroFightSoul(nHeroID, nMultiple)`
	(`ClientHeroLogic.lua:974-978`), gọi từ `CUIHeroInfoFightSoulUI:doUpgrade` (`:318/:321`).
	Trước lượt này KHÔNG có handler ⇒ bấm là lớp tải quay mãi.

	LUẬT + SỐ ĐỀU LÀ DỮ LIỆU/CÔNG THỨC ĐỌC ĐƯỢC, không phải đoán:

	  · Cấu hình `KDBGameFightSoulConfig` (115 dòng, chỉ số = cấp kế):
	    `CostGold`, `SuccessRate`, `NeedLevel`, `MaterialList`, `MaterialListPlus`,
	    `FightProperty`. Cấp cao nhất nhận ra bằng `CostGold == 0` — chính UI dùng phép thử
	    ấy (`CUIHeroInfoFightSoulUI.lua:1373`, `setMaterialAndGoldUI`).
	  · Vật liệu: `MaterialListPlus[tostring(heroID)]` nếu có, không thì `MaterialList` —
	    đúng hàm `getHeroSoulMaterialList` của UI (`:1394-1406`). Hai trường này có thể còn
	    là CHUỖI JSON tuỳ bản nạp cấu hình, nên giải mã nếu cần.
	  · Số vật liệu = `G_HeroLogic:GetUpgradeSoulCost(base, nMultiple)` (`share_HeroLogic.lua:3627`)
	    — hàm GỐC, tự giảm 25% cho VIP ≥ 8 rồi nhân `nMultiple`. VÀNG thì KHÔNG nhân
	    (`setMaterialAndGoldUI` chỉ `pCost:setString(tNextConf.CostGold)`).
	  · TỈ LỆ THÀNH CÔNG: UI hiện `20 + 10 × nTouchSuccessRateLv` (`:1489`), với
	    `nBasicSuccessRateLv = SuccessRate/10 - 2` (`:1373`). Suy ra **mốc cơ bản đúng bằng
	    `SuccessRate`**, và mỗi bậc kéo thêm +10%. `nMultiple = 1 + (nTouch - nBasic)` (`:1441-1455`)
	    ⇒ **tỉ lệ = SuccessRate + (nMultiple - 1) × 10**, chặn trên 100.

	Trả lời: `ClientHeroLogic:OnUpHeroFightSoul(upResult)` (`:981-1000`) — tham số là một SỐ:
	**1 = thành công · 2 = thất bại · 3 = không đổi** (`CUIHeroInfoFightSoulUI:OnCallBack`
	`:387-420` chọn hoạt ảnh theo đúng ba số này). Hàm ấy tự phát `Hero.OnUpHeroFightSoul`.

	KHÔNG làm hộ phần "không đổi": chỉ trả 3 khi lẽ ra phải đánh mà không đánh được (vd cấp
	tối đa) — nhưng cấp tối đa thì đã chặn từ trước bằng mã 1325.
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineVoHon = OfflineVoHon or {}

local R = OfflineRouter
local TEN_FILE = "vo hon"

local function dongBo()
	pcall(function () OfflineStore:syncFromClient() end)
end

local function thongBao(nMa)
	if nMa == nil or nMa == 0 then return end
	pcall(function ()
		g_CUINotificationCenter:PostNotification(
			CUINotificationEvent.OnServerRequestError, nMa)
	end)
end

local function traLoi(ctx, nKetQua, nMa)
	thongBao(nMa)
	-- Hàm nhận chỉ tắt lớp tải khi ĐƯỢC gọi; gọi luôn để không treo màn hình.
	ctx:call("G_HeroLogic", "OnUpHeroFightSoul", nKetQua)
end

--[[ Giá trị cấu hình có thể là BẢNG hoặc CHUỖI JSON (tuỳ bản nạp) — chấp nhận cả hai. ]]
local function thanhBang(v)
	if type(v) == "table" then return v end
	if type(v) == "string" then
		-- `cjson` có trong game nhưng KHÔNG có trong máy Lua trần của bộ thử; và cả khi có
		-- thì `pcall(cjson.decode, v)` cũng ném TRƯỚC khi vào pcall nếu `cjson` là nil.
		if type(_G.cjson) ~= "table" then return nil end
		local ok, t = pcall(function () return cjson.decode(v) end)
		if ok and type(t) == "table" then return t end
	end
	return nil
end

local function cauHinh()
	local ok, cfg = pcall(function ()
		return G_ConfigManager:GetHeroSoulConfig()
	end)
	if ok and type(cfg) == "table" then return cfg end
	return nil
end

local function vatLieuCua(cfg, nHero)
	local t = thanhBang(cfg.MaterialListPlus)
	if t ~= nil then
		local rieng = t[tostring(nHero)] or t[nHero]
		if type(rieng) == "table" then return rieng end
	end
	return thanhBang(cfg.MaterialList)
end

R:on("G_HeroLogic.ClientUpHeroFightSoul", function (ctx, nHeroID, nMultiple)
	local nHero = tonumber(nHeroID)
	local nBoi = tonumber(nMultiple) or 1
	if nHero == nil or nBoi < 1 then
		OfflineLog:warn(TEN_FILE .. ": tham so sai")
		traLoi(ctx, 3, ErrorCode.ArgError)
		return
	end

	local okT, bT, hero = pcall(function ()
		return G_HeroLogic:GetHeroWithID(nHero)
	end)
	if not okT or bT ~= true or type(hero) ~= "table" then
		OfflineLog:info(string.format("%s: khong co tuong %d", TEN_FILE, nHero))
		traLoi(ctx, 3, ErrorCode.Hero.NotFindHero)
		return
	end

	local nCap = tonumber(hero.FightSoulLevel) or 0
	local cfgAll = cauHinh()
	local cfg = cfgAll and (cfgAll[nCap + 1] or cfgAll[tostring(nCap + 1)])
	if type(cfg) ~= "table" then
		OfflineLog:info(string.format("%s: tuong %d da o cap toi da (%d)", TEN_FILE, nHero, nCap))
		traLoi(ctx, 3, ErrorCode.Hero.UpHeroFightSoulLevelLimit)
		return
	end

	-- `CostGold == 0` = dòng "hết cấp" (chính UI dùng phép thử này).
	local nVang = tonumber(cfg.CostGold) or 0
	if nVang <= 0 then
		OfflineLog:info(string.format("%s: tuong %d het cap (CostGold = 0)", TEN_FILE, nHero))
		traLoi(ctx, 3, ErrorCode.Hero.UpHeroFightSoulLevelLimit)
		return
	end

	local nCanCap = tonumber(cfg.NeedLevel) or 0
	local nCapTuong = tonumber(hero.HeroLevel) or 0
	if nCapTuong < nCanCap then
		OfflineLog:info(string.format("%s: tuong %d cap %d < can %d",
			TEN_FILE, nHero, nCapTuong, nCanCap))
		traLoi(ctx, 3, ErrorCode.Hero.UpHeroFightSoulLevelLimit)
		return
	end

	-- Vật liệu: lấy món ĐẦU trong danh sách, đúng như UI (`tMaterialList[1]`).
	local dsVatLieu = vatLieuCua(cfg, nHero)
	local mot = type(dsVatLieu) == "table" and dsVatLieu[1] or nil
	if type(mot) ~= "table" or tonumber(mot.MaterialID) == nil then
		OfflineLog:err(TEN_FILE .. ": dong cau hinh thieu MaterialList — khong doan")
		traLoi(ctx, 3, ErrorCode.Hero.GetFightSoulConfigFail)
		return
	end
	local idVatLieu = tonumber(mot.MaterialID)
	local nSoGoc = tonumber(mot.Count) or 1

	-- Số cần: hàm GỐC (tự giảm 25% cho VIP ≥ 8 rồi nhân bội).
	local okGia, nCanVatLieu = pcall(function ()
		return G_HeroLogic:GetUpgradeSoulCost(nSoGoc, nBoi)
	end)
	if not okGia or tonumber(nCanVatLieu) == nil then
		OfflineLog:err(TEN_FILE .. ": GetUpgradeSoulCost that bai")
		traLoi(ctx, 3, ErrorCode.UnknowError)
		return
	end
	nCanVatLieu = tonumber(nCanVatLieu)

	-- Đủ vàng?
	local nVangCo = 0
	pcall(function ()
		local _, n = G_UserLogic:GetGold()
		nVangCo = tonumber(n) or 0
	end)
	if nVangCo < nVang then
		OfflineLog:info(string.format("%s: can %d vang, co %d", TEN_FILE, nVang, nVangCo))
		traLoi(ctx, 3, ErrorCode.Common.NotEnoughGold)
		return
	end

	-- Đủ vật liệu?
	local nVatLieuCo = 0
	pcall(function ()
		local _, n = G_ItemLogic:GetItemCount(idVatLieu)
		nVatLieuCo = tonumber(n) or 0
	end)
	if nVatLieuCo < nCanVatLieu then
		OfflineLog:info(string.format("%s: can %d vat lieu %d, co %d",
			TEN_FILE, nCanVatLieu, idVatLieu, nVatLieuCo))
		traLoi(ctx, 3, ErrorCode.Item.NotEnoughItem)
		return
	end

	-- TRỪ: vàng trước, rồi vật liệu. Hỏng bước sau thì hoàn bước trước.
	local okVang, bVang = pcall(function ()
		return G_UserLogic:CostGold(nVang, "ClientUpHeroFightSoul")
	end)
	if not okVang or bVang ~= true then
		traLoi(ctx, 3, ErrorCode.Common.NotEnoughGold)
		return
	end
	local okVl, bVl = pcall(function ()
		return G_ItemDataManager:ReduceItem(idVatLieu, nCanVatLieu, "ClientUpHeroFightSoul")
	end)
	if not okVl or bVl ~= true then
		pcall(function () G_UserLogic:AddGold(nVang, "ClientUpHeroFightSoul.hoan") end)
		OfflineLog:err(TEN_FILE .. ": tru vat lieu that bai — da hoan vang")
		traLoi(ctx, 3, ErrorCode.Item.ReduceItemError)
		return
	end

	-- TỈ LỆ: SuccessRate + (bội - 1) × 10, chặn trên 100 (xem đầu tệp).
	local nTiLe = (tonumber(cfg.SuccessRate) or 100) + (nBoi - 1) * 10
	if nTiLe > 100 then nTiLe = 100 end
	local bThanhCong = math.random(1, 100) <= nTiLe

	if bThanhCong then
		hero.FightSoulLevel = nCap + 1
	end
	dongBo()

	OfflineLog:info(string.format(
		"%s: tuong %d cap %d -> %s (tile %d%%, boi %d, tru %d vang + %d vat lieu %d)",
		TEN_FILE, nHero, nCap, tostring(hero.FightSoulLevel),
		nTiLe, nBoi, nVang, nCanVatLieu, idVatLieu))

	traLoi(ctx, bThanhCong and 1 or 2, 0)
end)

OfflineLog:info("vo hon: da noi 1 khoa (ClientUpHeroFightSoul)")

return true
