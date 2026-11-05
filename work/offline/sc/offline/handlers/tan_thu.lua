--[[
	offline/handlers/tan_thu.lua — QUÀ TÂN THỦ / ĐẶC QUYỀN TÂN THỦ (新手特权).

	Ba lệnh `G_NewHandPrivilegeLogic` (api.lua:287/495/496):

	  · `ClientGetUserNewHandPrivilegeInfo()` → callback PHƯƠNG THỨC
	    `OnGetUserNewHandPrivilegeInfo()` trên `g_CUINewHandPrivilege`, `dd_p={}`
	    (KHÔNG đối số). Client đọc dữ liệu qua `GameNewHandPrivilege`
	    (`CUINewHandPrivilegeCommon:getGameNewHandPrivilegeData`, `:279`).
	  · `ClientSendReward()`  → `OnSendReward()` — nút "前往" (CUIPerks).
	  · `ClientSendRewardV2()` → `cb=''` — IM LẶNG, nút "nhận" của CUINewHandPrivilege.

	DỮ LIỆU (hình dạng từ `:279-326`, KHÔNG phải suy đoán):
	  `GameNewHandPrivilege = { TotalRechargeMoneyIn24, LastRewardTime, RewardTimes }`.
	  Client TỰ tính `CurLevel` từ `TotalRechargeMoneyIn24` + config
	  (`configGetLevelInfoByRechargeCount`), `RewardTimesMax` = số NGÀY của bậc ấy
	  (`DayMax`), và `RemainSecond` từ `CreateTime`.

	CẤU HÌNH: `KDBGameNewHandPrivilegeConfig` → cấu trúc
	`{ [DanweiIndex] = { NeedRechargeCount, PrizeList[Day] = {PrizeId, NeedRechargeCount, Day, DanweiIndex} } }`
	(`updateGameNewHandPrivilegeConfig`, `share_configManager.lua:3826-3853`). Ở đây
	dựng lại nếu cache rỗng — bản gốc đăng ký hẳn hàm cập nhật (khác nhà cửa), nhưng
	đọc THẲNG tệp là đường chắc chắn nhất và không thêm phụ thuộc.

	LUẬT (máy chủ gốc đã chết; ba mã lỗi là ĐO ĐƯỢC từ `error.lua:623-627`):
	  · **4301** `NoPrivilege` — `CurLevel == 0` (tổng nạp chưa chạm bậc thấp nhất);
	  · **4302** `NoRewardTimes` — `RewardTimes >= RewardTimesMax`;
	  · **4303** `TodayCanNotGetReward` — đã nhận trong NGÀY (so ngày của `LastRewardTime`).
	[MOI] KHÔNG cổng theo `RemainSecond`: `canGetPrize` của client (`:391-406`) cũng
	không cổng; cổng 24 giờ chỉ dùng để HIỆN ICON (`isIn24Hour`). Thứ tự cổng: có
	privilege → còn lượt → chưa nhận hôm nay.
	Phát thưởng: `PrizeId` của NGÀY KẾ TIẾP (`RewardTimes + 1`) trong bậc hiện tại →
	`PrizeContent` → `G_ChapterLogic:SetDataWithPrizeList`.

	OFFLINE KHÔNG CÓ ĐƯỜNG NẠP TIỀN (nhóm `G_RechargeLogic` chết SDK) ⇒
	`TotalRechargeMoneyIn24` luôn 0 ⇒ `CurLevel == 0` ⇒ mọi lượt nhận trả **4301**.
	Đó là dữ liệu, không phải lỗi handler; bộ thử gieo số để chạy nhánh thành công.
]]

require("offline.log")
require("offline.store")
require("offline.router")

local R = OfflineRouter
local BANG = "GameNewHandPrivilege"
local ERR_NO_PRIVILEGE, ERR_NO_TIMES, ERR_TODAY = 4301, 4302, 4303

local cfgCache = nil

--- `[DanweiIndex] = {NeedRechargeCount, PrizeList[Day] = {PrizeId, ...}}` — dựng từ
--- tệp cấu hình nếu cache của client rỗng (xem đầu tệp).
local function bangCauHinh()
	if cfgCache ~= nil then return cfgCache end
	local CM = G_ConfigManager
	if type(CM) ~= "table" then return nil end
	local ten = CM.configCacheName and CM.configCacheName.GameNewHandPrivilegeConfig
	if ten then
		local ok, c = pcall(function () return CM:GetConfigWithNameArg(ten) end)
		if ok and type(c) == "table" and next(c) ~= nil then
			cfgCache = c
			return cfgCache
		end
	end
	local okRows, rows = pcall(function () return CM:GetConfigTableWithName("KDBGameNewHandPrivilegeConfig") end)
	if not okRows or type(rows) ~= "table" then return nil end
	local ra = {}
	for _, r in ipairs(rows) do
		local k = tostring(r.DanweiIndex)
		ra[k] = ra[k] or { NeedRechargeCount = r.NeedRechargeCount, PrizeList = {} }
		ra[k].PrizeList[tostring(r.Day)] = r
	end
	cfgCache = ra
	return cfgCache
end

--- Bậc khớp với `TotalRechargeMoneyIn24` (cao nhất mà ngưỡng ≤ tổng) + số ngày của
--- bậc ấy (`DayMax` = số mục `PrizeList`). Trả `(bậc, tênKhoá, sốNgày)`.
local function bacCua(tongNap)
	local c = bangCauHinh()
	if c == nil then return 0, nil, 0 end
	local tot, ten, soNgay = nil, nil, 0
	for k, v in pairs(c) do
		if type(v) == "table" and tonumber(v.NeedRechargeCount) ~= nil
			and tongNap >= tonumber(v.NeedRechargeCount) then
			if tot == nil or tonumber(v.NeedRechargeCount) >= tot then
				tot, ten = tonumber(v.NeedRechargeCount), k
			end
		end
	end
	if ten ~= nil then
		for _ in pairs(c[ten].PrizeList or {}) do soNgay = soNgay + 1 end
		-- Bậc xếp theo thứ tự NeedRechargeCount tăng; "số ngày" = DayMax.
	end
	return tot or 0, ten, soNgay
end

local function userData()
	local d = G_DataManager and G_DataManager.userData
	return (type(d) == "table") and d or nil
end

local function bang()
	local d = userData()
	if d == nil then return nil end
	local t = d[BANG]
	if type(t) ~= "table" then t = {}; d[BANG] = t end
	if tonumber(t.TotalRechargeMoneyIn24) == nil then t.TotalRechargeMoneyIn24 = 0 end
	if tonumber(t.LastRewardTime) == nil then t.LastRewardTime = 0 end
	if tonumber(t.RewardTimes) == nil then t.RewardTimes = 0 end
	return t
end

local function cungNgay(a, b)
	if a <= 0 or b <= 0 then return false end
	local x, y = os.date("*t", a), os.date("*t", b)
	return x.year == y.year and x.month == y.month and x.day == y.day
end

local function motData(duLieu)
	return { EventType = 1, TableName = BANG, ChangeData = duLieu, KeyName = "RewardTimes" }
end

local function dongBo()
	pcall(function () OfflineStore:syncFromClient() end)
end

local function hong(ctx, ma)
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", tonumber(ma) or 1, {})
end

--[[ VÁ MỘT LỖI CỦA CHÍNH CLIENT (đo được trong game 31/10).

	`CUINewHandPrivilege:__initGetHud` (`CUINewHandPrivilege.lua:369-374`) kiểm
	`sngLNewHandPrivilege ~= nil` cho DÒNG ĐẦU, rồi DÒNG NGAY SAU vẫn gọi
	`self:__getRootNode()` — mà hàm ấy (`:126-127`) đọc thẳng
	`sngLNewHandPrivilege:getChildByStringTag("root")`. Khi node C++ chưa dựng
	(lúc vào Main, ngay sau khi lớp offline trả `ClientGetUserNewHandPrivilegeInfo`)
	thì nổ `attempt to index global 'sngLNewHandPrivilege' (a nil value)`, và lỗi
	ấy CẮT NGANG `OnReciveResponse` — các mục sự kiện phía sau trong CÙNG gói
	không bao giờ chạy.

	Bọc `__getRootNode` của THỰC THỂ để trả `nil` khi node vắng — chính
	`__initGetHud` đã có `if pRootNode == nil then break end` ngay dưới, tức đây
	là hành vi nó MUỐN có. ]]
local function vaNodeTanThu()
	local o = _G.g_CUINewHandPrivilege
	if type(o) ~= "table" or o.__DA_VA then return end
	local goc = o.__getRootNode
	if type(goc) ~= "function" then return end
	o.__getRootNode = function (self)
		if _G.sngLNewHandPrivilege == nil then return nil end
		return goc(self)
	end
	o.__DA_VA = true
	OfflineLog:info("tan thu: da va __getRootNode (node chua dung thi tra nil)")
end

R:on("G_NewHandPrivilegeLogic.ClientGetUserNewHandPrivilegeInfo", function (ctx)
	vaNodeTanThu()
	local b = bang()
	if b == nil then return hong(ctx, 1) end
	-- Gửi NGUYÊN bản ghi để `getGameNewHandPrivilegeData` (:279) có dữ liệu; client
	-- tự tính CurLevel/RewardTimesMax/RemainSecond từ config + CreateTime.
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse",
		"g_CUINewHandPrivilege", "OnGetUserNewHandPrivilegeInfo", 0, { motData(b) })
end)

--- Phần chung của HAI lệnh nhận thưởng. Trả bảng `{ok=bool, ma=, suKien=}`.
local function nhanThuong(b)
	local _, ten, soNgay = bacCua(tonumber(b.TotalRechargeMoneyIn24) or 0)
	if ten == nil or soNgay == 0 then return { ma = ERR_NO_PRIVILEGE } end
	if (tonumber(b.RewardTimes) or 0) >= soNgay then return { ma = ERR_NO_TIMES } end
	if cungNgay(tonumber(b.LastRewardTime) or 0, os.time()) then return { ma = ERR_TODAY } end

	local c = bangCauHinh()
	local ngay = (tonumber(b.RewardTimes) or 0) + 1
	local dongNgay = c and c[ten] and c[ten].PrizeList and c[ten].PrizeList[tostring(ngay)]
	if type(dongNgay) ~= "table" then return { ma = 1 } end

	local okP, prize = pcall(function () return G_ConfigManager:GetPrizeConfigWithID(dongNgay.PrizeId) end)
	if not okP or type(prize) ~= "table" or type(prize.PrizeContent) ~= "table" then
		return { ma = 1 }
	end
	local okSet = pcall(function ()
		G_ChapterLogic:SetDataWithPrizeList(prize.PrizeContent, nil, "NewHandPrivilege")
	end)
	if not okSet then return { ma = 1 } end

	b.RewardTimes = ngay
	b.LastRewardTime = os.time()
	dongBo()
	OfflineLog:info(string.format("tan thu: nhan thuong ngay %d (bac %s)", ngay, ten))
	return { ok = true, suKien = { motData(b) } }
end

R:on("G_NewHandPrivilegeLogic.ClientSendReward", function (ctx)
	local b = bang()
	if b == nil then return hong(ctx, 1) end
	local kq = nhanThuong(b)
	if not kq.ok then return hong(ctx, kq.ma) end
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse",
		"g_CUINewHandPrivilege", "OnSendReward", 0, kq.suKien)
end)

R:on("G_NewHandPrivilegeLogic.ClientSendRewardV2", function (ctx)
	local b = bang()
	if b == nil then return hong(ctx, 1) end
	local kq = nhanThuong(b)
	if not kq.ok then return hong(ctx, kq.ma) end
	-- `api.lua:495` khai `cb=''` ⇒ IM LẶNG; `eventList` vẫn tới TRƯỚC nhánh callback.
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 0, kq.suKien)
end)

OfflineLog:info("tan thu: da noi 3 khoa (GetUserNewHandPrivilegeInfo / SendReward / SendRewardV2)")

return true
