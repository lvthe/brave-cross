--[[
	offline/nap_gia_lap.lua — NẠP TIỀN GIẢ LẬP (mở đường cho các hoạt động cần "đã nạp").

	VÌ SAO CẦN: trên Android KHÔNG có lệnh mua nào sống trong Lua —
	`ClientDealPayment` bị CHÚ THÍCH ở cả hai chỗ gọi (`GooglePayManager.lua:273`,
	`CUIRechargeStore.lua:2437`), và AiBei chỉ chạy kênh iOS (`ABPay:isABChannel`).
	Vì thế offline không có cách nào "đã nạp" ⇒ Nạp liên tục + Quà tân thủ luôn từ
	chối (đã khai trong hai handler ấy), còn mua thể lực/kim cương thì thiếu tiền.

	GIẢI PHÁP: một hàm CỘNG NẠP duy nhất `OfflineNap:cong(soTien, soKimCuong)` cập
	nhật ĐÚNG những trường mà các hệ khác đọc — không bịa hệ mới:
	  · `GameUserBaseInfo.Diamond += soKimCuong` qua `G_UserLogic:AddDiamond`;
	  · `GameUserBaseInfo.FirstRechargeTime = now` nếu đang 0 (UI đọc nó);
	  · `GameUserGlobalData.C_RechargeData.FirstRechargeStatus = 1` (`HasFirstRecharge`)
	    — đúng cột mà `RechargeLogic:CheckHasFirstRecharge` đọc;
	  · `GameUserContinuousRecharge`: thêm `{Count=soTien, Time=now}` vào `RechargeList`
	    rồi TÍNH LẠI `RechargeDayList` (tổng từng ngày, theo thứ tự thời gian) — đúng
	    hai trường mà `ContinuousRechargeLogic` đọc;
	  · `GameNewHandPrivilege.TotalRechargeMoneyIn24 += soTien` — đúng trường
	    `CUINewHandPrivilegeCommon` đọc.
	Trường "RechargeCount" (số hiển thị ở cửa hàng nạp, `GetRechargeCount`) cũng cộng
	nếu hồ sơ đang có trường ấy.

	ĐƯỜNG KÍCH HOẠT — `G_UserLogic|ClientGMCommond` (objName RỖNG, cb `OnGMCommond`
	trên `G_GameWorld`, `api.lua:60`): lệnh
	    {"addgold", n}          cộng vàng
	    {"adddiamond", n}       cộng kim cương
	    {"recharge", tien}      GIẢ LẬP nạp `tien` đơn vị (kim cương mặc định = tien)
	    {"recharge", tien, kc}  ... kèm số kim cương cộng
	    {"thethang" [, loai]}   KÍCH HOẠT thẻ tháng (loai = Normal|ShuGuo, mặc định
	                            Normal) — luật `MonthlyCardLogic:GetMonthlyCard`
	    {"cog", n}              cộng điểm CÔNG THÀNH (`COGScore`) để thử shop COG
	Các lệnh khác trả mã **1** + ghi log (bản gốc có nhiều lệnh máy chủ không có ở đây).
	Ngoài ra **`G_RechargeLogic|ClientGetFirstRechargePrize`** được nối luôn — thân
	`RechargeLogic:getFirstRechargePrize` CÓ THẬT trong `share/`, nên sau khi nạp giả
	lập thì quà首充 nhận được thật.

	[MOI] Ba quyết định: (1) mỗi đơn vị "tiền" nạp = 1 đơn vị `Count` của bảng liên tục
	và 1 đơn vị `TotalRechargeMoneyIn24` (cùng thang mà cấu hình hai hệ ấy dùng: 100/198);
	(2) kim cương mặc định = số tiền — KHÔNG đọc bảng sản phẩm vì `GameRechargeConfig`
	chỉ có `FirstRechargePrize`, không có danh mục sản phẩm; (3) không cộng VIP exp.
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineNap = OfflineNap or {}

local function userData()
	local d = G_DataManager and G_DataManager.userData
	return (type(d) == "table") and d or nil
end

local function hoSo()
	local ok, r, b = pcall(function () return G_UserLogic:GetBaseInfo() end)
	if ok then
		if type(b) == "table" then return b end
		if type(r) == "table" then return r end
	end
	return nil
end

local function cungDanhSachNgay(ds)
	local ra = {}
	local ngayCuoi = nil
	for _, m in ipairs(ds) do
		if type(m) == "table" and tonumber(m.Time) and tonumber(m.Count) then
			local d = os.date("*t", tonumber(m.Time))
			local khoa = tostring(d.year) .. "-" .. tostring(d.yday)
			if khoa ~= ngayCuoi then
				ra[#ra + 1] = 0
				ngayCuoi = khoa
			end
			ra[#ra] = ra[#ra] + tonumber(m.Count)
		end
	end
	return ra
end

--- GIẢ LẬP MỘT LƯỢT NẠP. Trả `(ok, lýDo|nil)`.
function OfflineNap:cong(soTien, soKimCuong)
	local tien = tonumber(soTien)
	if tien == nil or tien <= 0 then return false, "so tien khong hop le" end
	local kc = tonumber(soKimCuong)
	if kc == nil then kc = tien end

	local b = hoSo()
	if b == nil then return false, "khong lay duoc ho so" end

	if kc > 0 then
		pcall(function () G_UserLogic:AddDiamond(kc, "GiaLapNap") end)
	end
	if tonumber(b.FirstRechargeTime) == nil or tonumber(b.FirstRechargeTime) == 0 then
		b.FirstRechargeTime = os.time()
	end
	if tonumber(b.RechargeCount) ~= nil then
		b.RechargeCount = (tonumber(b.RechargeCount) or 0) + tien
	end

	-- Trạng thái首充: `RechargeData` nằm trong client common data (`C_RechargeData`).
	pcall(function ()
		-- `GetClientCommonData` trả HAI giá trị `(bResult, value)` — `pcall` cho
		-- cả hai nên biến thứ ba LÀ giá trị; bảng/chuỗi đều xử được.
		local ok, bOK, rd = pcall(function () return G_UserLogic:GetClientCommonData("RechargeData") end)
		if type(rd) == "nil" and type(bOK) == "table" then rd = bOK end
		if type(rd) == "string" then rd = cjson.decode(rd) end
		rd = (type(rd) == "table") and rd or {}
		local cu = tonumber(rd.FirstRechargeStatus) or 0
		if cu < 1 then rd.FirstRechargeStatus = 1 end      -- 1 = HasFirstRecharge
		G_UserLogic:SetClientCommonData("RechargeData", rd, false)
	end)

	local d = userData()
	if d ~= nil then
		-- Nạp liên tục: ghi vào RechargeList rồi TÍNH LẠI RechargeDayList.
		local lt = d.GameUserContinuousRecharge
		if type(lt) ~= "table" then
			lt = { RechargeList = {}, RechargeDayList = {}, PrizeStates = {}, HasGetContinuousPrize = false }
			d.GameUserContinuousRecharge = lt
		end
		lt.RechargeList = lt.RechargeList or {}
		lt.RechargeList[#lt.RechargeList + 1] = { Count = tien, Time = os.time() }
		lt.RechargeDayList = cungDanhSachNgay(lt.RechargeList)

		-- Quà tân thủ: tổng nạp trong 24h.
		local tp = d.GameNewHandPrivilege
		if type(tp) ~= "table" then
			tp = { TotalRechargeMoneyIn24 = 0, LastRewardTime = 0, RewardTimes = 0 }
			d.GameNewHandPrivilege = tp
		end
		tp.TotalRechargeMoneyIn24 = (tonumber(tp.TotalRechargeMoneyIn24) or 0) + tien
	end

	pcall(function () OfflineStore:syncFromClient() end)
	OfflineLog:info(string.format("nap gia lap: +%s tien, +%s kim cuong", tostring(tien), tostring(kc)))
	return true, nil
end

-- ---------------------------------------------------------------- GM command
R_DANG_KY = nil     -- (giữ chỗ cho công cụ đọc tên; không dùng)
local R = OfflineRouter

local function gmTraLoi(ctx, ma)
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "G_GameWorld", "OnGMCommond", ma or 0, {},
		ma or 0)
end

R:on("ClientGMCommond", function (ctx, tList)
	if type(tList) ~= "table" then return gmTraLoi(ctx, 1) end
	local lenh = tostring(tList[1] or "")
	local n = tonumber(tList[2])

	if lenh == "addgold" and n and n > 0 then
		pcall(function () G_UserLogic:AddGold(n, "GM") end)
		pcall(function () OfflineStore:syncFromClient() end)
		OfflineLog:info("GM: addgold " .. tostring(n))
		return gmTraLoi(ctx, 0)
	end
	if lenh == "adddiamond" and n and n > 0 then
		pcall(function () G_UserLogic:AddDiamond(n, "GM") end)
		pcall(function () OfflineStore:syncFromClient() end)
		OfflineLog:info("GM: adddiamond " .. tostring(n))
		return gmTraLoi(ctx, 0)
	end
	if lenh == "recharge" and n and n > 0 then
		local ok = OfflineNap:cong(n, tonumber(tList[3]))
		return gmTraLoi(ctx, ok and 0 or 1)
	end
	--[[ `cog <n>` — cộng điểm CÔNG THÀNH (COGScore). Offline không có trận COG nên
		điểm luôn 0; shop COG (`handlers/cog.lua`) cần điểm để thử mua. Điểm nằm
		trong `GameUserBaseInfo.COGScore`, sửa bằng hàm GỐC `AddCOGScore`. ]]
	if lenh == "cog" and n and n ~= 0 then
		local ok, r = pcall(function () return G_COGDataManager:AddCOGScore(n) end)
		pcall(function () OfflineStore:syncFromClient() end)
		OfflineLog:info("GM: cog " .. tostring(n))
		return gmTraLoi(ctx, (ok and r == true) and 0 or 1)
	end
	--[[ [MOI] Kích hoạt THẺ THÁNG (`thethang [Normal|ShuGuo]`, mặc định Normal).
		Lý do đây là ĐƯỜNG KÍCH HOẠT của lớp offline: bản gốc kích hoạt thẻ từ sự kiện
		`Active.OnGetMonthlyCard` của hệ NẠP TIỀN, mà Android không có lệnh mua sống
		(`ClientDealPayment` bị chú thích) ⇒ offline không có sự kiện ấy. Luật phát
		thưởng vẫn là `MonthlyCardLogic:GetMonthlyCard` của bản gốc (xem
		`handlers/the_thang.lua`). ]]
	if lenh == "thethang" then
		local loai = tostring(tList[2] or "Normal")
		local ok, viSao = false, "chua nap handlers/the_thang.lua"
		if OfflineTheThang and type(OfflineTheThang.kichHoat) == "function" then
			ok, viSao = OfflineTheThang:kichHoat(loai)
		end
		if not ok then
			OfflineLog:warn("GM: thethang " .. loai .. " that bai: " .. tostring(viSao))
		end
		return gmTraLoi(ctx, ok and 0 or 1)
	end

	OfflineLog:warn("GM: lenh chua ho tro -> " .. tostring(lenh))
	return gmTraLoi(ctx, 1)
end)

-- ---------------------------------------------------------------- quà首充
--[[ `RechargeLogic:getFirstRechargePrize` (share, `:20-100`) gọi qua PROXY LỚP CHA.
	Callback: `G_RechargeLogic.OnServerGetFirstRechargePrize(tRetData)` — chính hàm
	ấy dựng `{nClientErrCode, RetData}` rồi phát `OnServerGetFirstRechargePrize`, thứ
	mà `CUIFirstPayGift.lua:67` đăng ký nghe. (Dòng `api.lua:444` khai
	`g_CUIFirstPayGift/OnGetFirstRechargePrize` — hình dạng KHÁC, đo được; chọn cửa
	phương thức vì UI nghe sự kiện do nó phát ra.) ]]
R:on("G_RechargeLogic.ClientGetFirstRechargePrize", function (ctx)
	if _G.G_RechargeLogic == nil or _G.RechargeLogic == nil then
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 1, {})
		return
	end
	local goc = G_RechargeLogic[RechargeLogic]
	local ok, bRet, ma, tRetData = pcall(function ()
		return goc:getFirstRechargePrize()
	end)
	pcall(function () OfflineStore:syncFromClient() end)
	if not ok or bRet ~= true then
		local e = tonumber(ma) or 1
		OfflineLog:info("nap gia lap: nhan qua dau nap bi tu choi, ma " .. tostring(e))
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", e, {})
		return
	end
	OfflineLog:info("nap gia lap: da nhan qua dau nap")
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse",
		"G_RechargeLogic", "OnServerGetFirstRechargePrize", 0, {}, tRetData or {})
end)

OfflineLog:info("nap gia lap: da noi ClientGMCommond (addgold/adddiamond/recharge) + ClientGetFirstRechargePrize")

return true
