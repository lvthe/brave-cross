--[[
	offline/handlers/thoi_trang.lua — THỜI TRANG: GHÉP + NHẬN THƯỞNG (ba khoá `G_ClothingLogic`).

	  · `ClientComposeClothing(heroId, clothId)`   → `OnComposeClothing()`
	  · `ClientGetClothingPrize(strIndex)`         → `OnServerGetClothingPrize()`
	  · `ClientSetClothingPrizeUseStatus(strIndex)`→ `OnServerSetClothingPrizeUseStatus()`

	BA NHÓM KHÁC HẲN NHAU, đừng gộp:

	1) **GHÉP THỜI TRANG** — cấu hình THẬT `GameClothingComposeConfig` (3 dòng:
	   `Coat005/006/007`, mỗi dòng `{ItemId, Count=10, PrizeData}`), và đầu ra đi qua
	   đúng đường thưởng gốc `ChapterLogic:SetDataWithPrizeData` (`share_ChapterLogic.lua:
	   4255`, nhánh `PrizeResType.Clothing` `:4399` → `HeroLogic:AddHeroSkin`). Không có
	   hàm ghép riêng trong `share/` ⇒ phần ghép ba bước (kiểm → trừ → phát) là của lớp
	   offline, [GHIM-1]; luật của từng bước thì của bản gốc.
	   Mã lỗi lấy từ nhóm `Clothing` của `spec/server_api.json` (sáu mã, cả sáu dùng được):
	   3301 CanNotGetClothingPrize · 3302 GetConfigFaild · 3305 NotEnoughItemForCompose
	   · 3306 ClothingNotMatchHero.

	2) **NHẬN THƯỞNG THỜI TRANG THEO HOẠT ĐỘNG** — `ClothingLogic:getClothingPrize(strIndex)`
	   (`share_Share_ClothingLogic.lua:163-262`) CÓ THẬT: đòi cửa sổ hoạt động
	   (`ActivityBeginTime/EndTime` so với `FirstEnterGameTime`), đã nạp đủ
	   `GetClothingRechargeCount` (`G_RechargeLogic:GetUserRechargeCount`), chưa nhận,
	   rồi phát `PrizeList`/`WomenPrizeList` theo giới tính. `FirstEnterGameTime` do
	   `offline/bootstrap.lua` seed sẵn ⇒ đường này CHẠY được, và `OfflineNap:cong`
	   (30/10) là đường thoả điều kiện "đã nạp".

	3) **ĐÁNH DẤU ĐÃ MẶC** — `ClothingLogic:setClothingPrizeUseStatus(strIndex)`
	   (`:362-400`) cũng CÓ THẬT; trạng thái nằm ở client common data `ClothingData`
	   (một người chơi ⇒ kho này là đúng chỗ).

	[GHIM-1] Thứ tự cổng của `ClientComposeClothing`: cấu hình → khớp anh hùng →
	         đủ nguyên liệu → trừ → phát. Bản gốc không có hàm để đối chiếu.
]]

require("offline.log")
require("offline.store")
require("offline.router")

local R = OfflineRouter
local TEN_FILE = "thoi trang"

local MA = {
	ARG         = 2,     -- ErrorCode.System.ParamError
	CAN_NOT_GET = 3301,  -- ErrorCode.Clothing.CanNotGetClothingPrize
	NO_CONFIG   = 3302,  -- ErrorCode.Clothing.GetConfigFaild
	NO_ITEM     = 3305,  -- ErrorCode.Clothing.NotEnoughItemForCompose
	NOT_MATCH   = 3306,  -- ErrorCode.Clothing.ClothingNotMatchHero
}

local function loi(ctx, ma, viSao)
	OfflineLog:info(string.format("%s: tu choi, ma %d (%s)",
		TEN_FILE, tonumber(ma) or 1, tostring(viSao)))
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", tonumber(ma) or 1, {})
end

local function dongBo()
	pcall(function () OfflineStore:syncFromClient() end)
end

--[[ Gọi hàm của LỚP CHA trên `G_ClothingLogic` (`ClientClothingLogic = class(ClothingLogic)`).
	Ba hàm `Client*` chỉ gửi request; thân luật nằm ở `ClothingLogic`. ]]
local function goiCha(ten, ...)
	local o = _G.G_ClothingLogic
	local c = _G.ClothingLogic
	if type(o) ~= "table" or type(c) ~= "table" then return nil end
	local self = o[c] or o
	local fn = self[ten]
	if type(fn) ~= "function" then return nil end
	local args = { n = select("#", ...), ... }
	local ok, a1, a2 = xpcall(function ()
		return fn(self, unpack(args, 1, args.n))
	end, function (e)
		return tostring(e) .. (debug and debug.traceback and ("\n" .. tostring(debug.traceback())) or "")
	end)
	if not ok then
		OfflineLog:err(TEN_FILE .. ": " .. ten .. " nem loi: " .. tostring(a1))
		return nil
	end
	return a1, a2
end

------------------------------------------------------------------- GHÉP THỜI TRANG
--[[ [GHIM-1] Cổng: mã trang phục → cấu hình (`GameClothingComposeConfig`) → khớp anh
	hùng (`PrizeData.UserProperty.HeroID`) → đủ `ItemId × Count` → trừ → phát qua
	`SetDataWithPrizeData` (nhánh Clothing của bản gốc). ]]
R:on("G_ClothingLogic.ClientComposeClothing", function (ctx, heroId, clothId)
	local nHero = tonumber(heroId)
	if type(clothId) ~= "string" or clothId == "" or nHero == nil then
		return loi(ctx, MA.ARG, "ComposeClothing(tham so)")
	end

	local cfg = nil
	pcall(function ()
		cfg = G_ConfigManager:GetCommonConfigWithName("GameClothingComposeConfig", clothId)
	end)
	if type(cfg) ~= "table" then
		return loi(ctx, MA.NO_CONFIG, "ComposeClothing(cau hinh " .. clothId .. ")")
	end

	-- PrizeData là bảng THẬT trong cấu hình (xgg-json đã giải), UserProperty là CHUỖI JSON.
	local prize = cfg.PrizeData
	if type(prize) ~= "table" then
		return loi(ctx, MA.NO_CONFIG, "ComposeClothing(PrizeData)")
	end
	local thuoc = nil
	if type(prize.UserProperty) == "string" then
		pcall(function () thuoc = cjson.decode(prize.UserProperty) end)
	end
	if type(thuoc) == "table" and tonumber(thuoc.HeroID) ~= nil
		and tonumber(thuoc.HeroID) ~= nHero then
		return loi(ctx, MA.NOT_MATCH, string.format("ComposeClothing(hero %d vs %s)",
			nHero, tostring(thuoc.HeroID)))
	end

	local nCan = tonumber(cfg.Count) or 0
	if nCan > 0 then
		local co = 0
		pcall(function ()
			local _, n = G_ItemLogic:GetItemCount(cfg.ItemId)
			co = tonumber(n) or 0
		end)
		if co < nCan then
			return loi(ctx, MA.NO_ITEM, string.format("ComposeClothing(item %s: %d/%d)",
				tostring(cfg.ItemId), co, nCan))
		end
		local okTru, r = pcall(function ()
			return G_ItemDataManager:ReduceItem(cfg.ItemId, nCan, "ComposeClothing")
		end)
		if not okTru or r ~= true then
			return loi(ctx, MA.NO_ITEM, "ComposeClothing(ReduceItem)")
		end
	end

	local okPhat, daPhat = pcall(function ()
		return G_ChapterLogic:SetDataWithPrizeData(prize, 1, "ComposeClothing")
	end)
	if not okPhat or daPhat ~= true then
		return loi(ctx, MA.CAN_NOT_GET, "ComposeClothing(SetDataWithPrizeData)")
	end

	dongBo()
	OfflineLog:info(string.format("%s: da ghep %s cho hero %d", TEN_FILE, clothId, nHero))
	ctx:call("G_ClothingLogic", "OnComposeClothing")
end)

-------------------------------------------------------- NHẬN THƯỞNG THEO HOẠT ĐỘNG
--[[ Luật GỐC `ClothingLogic:getClothingPrize` trả `(bResult, nErrCode)`.
	Callback PHƯƠNG THỨC `OnServerGetClothingPrize()` là hàm client tự dựng gói rồi
	phát sự kiện "OnServerGetClothingPrize" — chỗ UI `CUICharacterDressGet.lua:107`
	đăng ký nghe. ]]
R:on("G_ClothingLogic.ClientGetClothingPrize", function (ctx, strIndex)
	if type(strIndex) ~= "string" and type(strIndex) ~= "number" then
		return loi(ctx, MA.ARG, "GetClothingPrize(tham so)")
	end

	local bRet, ma = goiCha("getClothingPrize", strIndex)
	dongBo()

	if bRet ~= true then
		-- Cửa thường nhất: chưa đủ số tiền đã nạp của hoạt động, hoặc ngoài cửa sổ.
		return loi(ctx, tonumber(ma) or MA.CAN_NOT_GET, "GetClothingPrize(" .. tostring(strIndex) .. ")")
	end
	OfflineLog:info(TEN_FILE .. ": da nhan thuong thoi trang " .. tostring(strIndex))
	ctx:call("G_ClothingLogic", "OnServerGetClothingPrize")
end)

------------------------------------------------------------------- ĐÁNH DẤU ĐÃ MẶC
R:on("G_ClothingLogic.ClientSetClothingPrizeUseStatus", function (ctx, strIndex)
	if type(strIndex) ~= "string" and type(strIndex) ~= "number" then
		return loi(ctx, MA.ARG, "SetClothingPrizeUseStatus(tham so)")
	end

	local bRet = goiCha("setClothingPrizeUseStatus", strIndex)
	dongBo()

	if bRet ~= true then
		return loi(ctx, MA.CAN_NOT_GET, "SetClothingPrizeUseStatus(" .. tostring(strIndex) .. ")")
	end
	OfflineLog:info(TEN_FILE .. ": da danh dau da mac " .. tostring(strIndex))
	ctx:call("G_ClothingLogic", "OnServerSetClothingPrizeUseStatus")
end)

OfflineLog:info("thoi trang: da noi 3 khoa (ComposeClothing / GetClothingPrize / SetClothingPrizeUseStatus)")

return true
