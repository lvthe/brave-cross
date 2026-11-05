--[[
	offline/handlers/mua_luot_ai.lua — MUA LƯỢT ĐÁNH LẠI ẢI (花费钻石购买战斗次数重置).

	Lệnh: `G_ChapterLogic.ClientBuyChapterBattleResetCount(strChapterKey)`
	(`ClientChapterLogic.lua:435`), gọi từ HAI nút trong popup chi tiết ải
	(`CUIChapterInfo.lua:2253` và `:2399`). Callback trả lời là PHƯƠNG THỨC trên
	`G_ChapterLogic`: `OnServerBuyChapterBattleResetCount(strChapterKey)` (`:454`)
	⇒ UI `CUIChapterInfo:OnBuyChapterBattleResetCount` gọi `refreshUI()`.

	LUẬT LÀ MÃ GỐC CÒN SỐNG, không phải ta viết:
	`ChapterLogic:costDiamondToResetBattleCount` (`share_ChapterLogic.lua:1106-1175`):
	  · phải có bản ghi ải (`GetBattleReportsData`) — thiếu ⇒ hỏng;
	  · giá = `getBattleResetCountAndCostDiamond` (:1060-1095): bảng cấu hình
	    `ResetBossChapterCountList` trong `GameUserGlobalConfig`, chỉ số
	    `BattleResetCount + 1` (quá cuối bảng thì lấy mục CUỐI);
	  · trần = `GetMaxBattleCount()` = `G_UserLogic:GetVipConfig("ResetBossChapterCountList")`
	    — đã `BattleResetCount >= trần` thì từ chối;
	  · trả kim cương (`G_UserLogic:CostDiamond`), rồi `BattleResetCount + 1`,
	    `PassMissionCount = 0`, `SaveBattleReportsWithData`.
	Thân ấy **KHÔNG trả mã lỗi** — chỉ `bResult` (false/true). Vì vậy khi hỏng
	handler trả **1** (`ErrorCode.UnknowError`), và KHAI RÕ đây là chỗ port thêm
	mã, không phải bản gốc.

	VÌ SAO GỌI QUA PROXY LỚP CHA: `G_ChapterLogic` là thể hiện của
	`ClientChapterLogic = class(ChapterLogic)`; hàm này chỉ định nghĩa ở LỚP CHA,
	nhưng gọi qua proxy `o[ChapterLogic]` là lối đã dùng ở `handlers/tinh_nang.lua`
	để không bao giờ trúng bản client (bản client của các hàm CÙNG TÊN chỉ gửi
	request ⇒ đệ quy).
]]

require("offline.log")
require("offline.store")
require("offline.router")

local R = OfflineRouter

local function lopCha(obj)
	local ten = obj:match("^G_(.+)$")
	if not ten then return nil end
	local c = _G[ten]
	return (type(c) == "table") and c or nil
end

--[[ Gọi một hàm của LỚP CHA trên thể hiện `obj`. Trả `ok, bResult` như bản gốc. ]]
local function goiLopCha(obj, ten, ...)
	local o = _G[obj]
	if type(o) ~= "table" then return false, false end
	local c = lopCha(obj)
	local self = (c and o[c]) or o
	local fn = self and self[ten]
	if type(fn) ~= "function" then return false, false end
	local args = { n = select("#", ...), ... }
	local ok, bRet = xpcall(function ()
		return fn(self, unpack(args, 1, args.n))
	end, function (e)
		return tostring(e) .. (debug and debug.traceback and ("\n" .. tostring(debug.traceback())) or "")
	end)
	return ok, bRet
end

R:on("G_ChapterLogic.ClientBuyChapterBattleResetCount", function (ctx, strChapterKey)
	if type(strChapterKey) ~= "string" or strChapterKey == "" then
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 1, {})
		return
	end

	local ok, bRet = goiLopCha("G_ChapterLogic", "costDiamondToResetBattleCount", strChapterKey)
	pcall(function () OfflineStore:syncFromClient() end)

	if not ok or bRet ~= true then
		OfflineLog:info(string.format("mua luot ai %s: luat goc tu choi (ok=%s, ret=%s) -> 1",
			tostring(strChapterKey), tostring(ok), tostring(bRet)))
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 1, {})
		return
	end

	OfflineLog:info("mua luot ai " .. tostring(strChapterKey) .. ": da mua (+1 luot, da tru kim cuong)")
	-- Callback PHƯƠNG THỨC trên G_ChapterLogic, tham số `key` đi qua `...`.
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse",
		"G_ChapterLogic", "OnServerBuyChapterBattleResetCount", 0, {}, strChapterKey)
end)

--[[ `ClientBuyChapterSweepCount(nSweepCount)` — MUA LƯỢT QUÉT (mỗi lượt 1 kim cương).

	Lệnh `ClientChapterLogic.lua:395`; callback PHƯƠNG THỨC
	`OnServerBuyChapterSweepCount(nSweepCount)` (`:409`, đọc ĐÚNG MỘT số và phát
	`OnServerBuyChapterSweepCount` cho UI).

	VÌ SAO KHÔNG GỌI `changeDiamondToSweepCount` (bản gốc còn sống, `:1206-1235`):
	nó tiêu kim cương rồi gọi **`ReduceSweepCount`** — tức **TRỪ** số lượt vừa mua.
	Đó là một chỗ ĐẢO NGHĨA của bản gốc (tài liệu `handlers/chapter.lua:443-458` đo
	cùng kết luận: `SweepCount` là số lượt MUA được, `ReduceSweepCount` từ chối ngay
	lượt quét đầu vì nó trừ thay vì trả). Nên ở đây làm đúng NGHĨA TÊN + đúng GIÁ
	của hàm ấy:
	  · giá = **1 kim cương/lượt** (`nNeedDiamond = 1 * nSweepCount`, `:1211`);
	  · cộng lượt bằng `SetSweepCount(hiện có + n)` — hàm CÓ THẬT (`:1298`);
	  · trả `1702 NoEnoughResource` khi thiếu kim cương, `4 ParamError` khi tham số hỏng.
	[GHIM] chiều cộng là quyết định của ta (bản gốc đảo chiều); giá và API là của gốc.
]]
R:on("G_ChapterLogic.ClientBuyChapterSweepCount", function (ctx, nSweepCount)
	local n = tonumber(nSweepCount)
	if n == nil or n ~= math.floor(n) or n < 1 or n > 1000 then
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 4, {})
		return
	end
	local okB, base = pcall(function () local _, b = G_UserLogic:GetBaseInfo(); return b end)
	if not okB or type(base) ~= "table" then
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 1704, {})
		return
	end
	if (tonumber(base.Diamond) or 0) < n then
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 1702, {})
		return
	end
	local okC = pcall(function () G_UserLogic:CostDiamond(n, "buySweepCount") end)
	if not okC then
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 1702, {})
		return
	end
	local cu = 0
	pcall(function ()
		local _, c = G_ChapterDataManager:GetSweepCount()
		cu = tonumber(c) or 0
	end)
	pcall(function () G_ChapterDataManager:SetSweepCount(cu + n) end)
	pcall(function () OfflineStore:syncFromClient() end)
	OfflineLog:info(string.format("mua luot quet: +%d luot (gia %d kim cuong)", n, n))
	ctx:call("G_ChapterLogic", "OnServerBuyChapterSweepCount", n)
end)

return true
