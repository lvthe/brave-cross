--[[
	offline/handlers/the_thang.lua — THẺ THÁNG / 月卡.

	Khoá `G_MonthlyCardLogic|ClientGetReward(sCardType)` (`ClientActivitiesLogic.lua:369`,
	hai nút "Nhận" của `CUIMonthCard` / `CUIActivityMonthCard`). Trước lượt này KHÔNG
	có handler nào ⇒ bấm "Nhận" là lớp tải quay mãi.

	LUẬT LÀ MÃ GỐC CÒN SỐNG: `MonthlyCardLogic:GetReward` (`share/Activities/
	MonthlyCardLogic.lua:157-240`), gọi qua PROXY LỚP CHA. Nó tự:
	  · đòi `MonthlyCardLeftCount<loại> > 0` (còn ngày thẻ);
	  · đòi CHƯA nhận hôm nay (`IsGetMonthlyCardReward<loại>`);
	  · chọn `VipReward` khi VIP ≥ `VipLevel` (cấu hình = 6), ngược lại `DailyReward`;
	  · phát qua `G_PrizeLogic:ReceivePrizeWithID` (tự đẩy `OnReceivePrize` cho UI);
	  · đặt cờ đã nhận + giảm 1 ngày;
	  · phát `Active.OnGetMonthlyCardReward` — chính sự kiện `CUIMonthCard:
	    OnGetMonthlyCardReward` đăng ký nghe.
	Hai trường trạng thái nằm ở `GameUserGlobalData` qua `Set/GetUserGlobalData`
	(góp ý của `getLeftKeyWithType`/`IsGetRewardKeyWithType`, `:266-271`) — KHÔNG phải
	client common data.

	KÍCH HOẠT THẺ KHÔNG CÓ KHOÁ CLIENT: `GetMonthlyCard(sCardType)` (`:32`) chạy từ
	sự kiện `Active.OnGetMonthlyCard` của hệ NẠP TIỀN, mà hệ ấy chỉ có `OfflineNap`
	giả lập (không bắn sự kiện đó). Vì thế `OfflineTheThang:kichHoat(loai)` gọi THẲNG
	luật gốc — hàm ấy phát `FirstReward` + cộng 30 ngày. Đường vào là lệnh GM
	`thethang [Normal|ShuGuo]` trong `offline/nap_gia_lap.lua` (cùng chỗ với
	`addgold`/`recharge`). [MOI] đây là ĐƯỜNG KÍCH HOẠT của lớp offline; luật thưởng
	là của bản gốc.

	Mã lỗi: `GetReward` chỉ trả `bResult` (không mã) ⇒ mọi thất bại quy về **1**
	(`ErrorCode.UnknowError`), đúng như `bravecross-server/src/handlers/the_thang.ts`
	(Mốc 45) đã chọn.
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineTheThang = OfflineTheThang or {}

local R = OfflineRouter
local TEN_FILE = "the thang"
local LOAI_HOP_LE = { Normal = true, ShuGuo = true }

local function goiCha(ten, ...)
	local o = _G.G_MonthlyCardLogic
	local c = _G.MonthlyCardLogic
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

local function dongBo()
	pcall(function () OfflineStore:syncFromClient() end)
end

--[[ Kích hoạt thẻ tháng: `MonthlyCardLogic:GetMonthlyCard(loai)` — luật GỐC.
	Phát thưởng lần đầu + cộng `MonthCardCount` (=30) ngày. Trả `(ok, lyDo|nil)`. ]]
function OfflineTheThang:kichHoat(loai)
	loai = tostring(loai or "Normal")
	if not LOAI_HOP_LE[loai] then
		return false, "loai the khong hop le (Normal|ShuGuo)"
	end
	if type(_G.G_MonthlyCardLogic) ~= "table" or type(_G.MonthlyCardLogic) ~= "table" then
		return false, "chua co G_MonthlyCardLogic"
	end
	local bRet = goiCha("GetMonthlyCard", loai)
	dongBo()
	if bRet ~= true then
		OfflineLog:info(TEN_FILE .. ": kich hoat " .. loai .. " that bai (cau hinh?)")
		return false, "luat goc tu choi"
	end
	OfflineLog:info(TEN_FILE .. ": da kich hoat the " .. loai .. " (+30 ngay, da phat thuong dau)")
	return true, nil
end

-------------------------------------------------------------- nhận thưởng hằng ngày
R:on("G_MonthlyCardLogic.ClientGetReward", function (ctx, sCardType)
	if type(sCardType) ~= "string" or sCardType == "" then
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 1, {})
		return
	end

	local bRet = goiCha("GetReward", sCardType)
	dongBo()

	if bRet ~= true then
		-- Bốn cửa gộp về 1 (luật gốc không có mã): chưa có thẻ / nhận rồi / thiếu
		-- cấu hình / phát thưởng hỏng. Ghi log để biết cửa nào.
		local coThe = false
		pcall(function ()
			local _, n = G_MonthlyCardLogic:GetMonthlyCardLeftCount(sCardType)
			coThe = (tonumber(n) or 0) > 0
		end)
		OfflineLog:info(string.format("%s: nhan %s bi tu choi (con ngay = %s)",
			TEN_FILE, sCardType, tostring(coThe)))
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 1, {})
		return
	end

	-- Luật gốc đã tự phát `Active.OnGetMonthlyCardReward`; ở đây chỉ cần tắt lớp
	-- "đang tải" mà `CallGetReward` đã bật (`PostLogicEvent("ClientGetReward",
	-- OnWaitingForRequest)`).
	OfflineLog:info(TEN_FILE .. ": da nhan thuong the " .. sCardType)
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 0, {})
end)

OfflineLog:info("the thang: da noi 1 khoa (ClientGetReward) + OfflineTheThang:kichHoat")

return true
