--[[
	offline/handlers/binh_chung.lua — Doanh Trại: mở khoá / nâng cấp / đội hình.

	Vì sao cần: kịch bản hướng dẫn tân thủ dừng ở bước "Mở cung binh!"
	(`CUIBarracksArmyInfo`), gọi `G_ArmyLogic:CallUnlockArmy` — đo 27/10:
	`THIEU G_ArmyLogic.ClientUnlockArmy args=[3]`, nên hướng dẫn kẹt và mọi
	cú bấm sau đó không đi tiếp.

	LUẬT LÀ CỦA BẢN GỐC, đủ cả năm hàm trong `share/ArmyLogic.lua`:
	  UnlockArmy (:409)     — kiểm đã khoá/được mở/đủ Binh Hồn, đặt IsLocked,
	                          trừ Binh Hồn, tự thêm vào đội hình 1 nếu còn chỗ
	  UpgradeArmy (:283)
	  IntoLineup (:585) / OutOffLineup (:707)
	  SetLastLineup        — client gọi cục bộ trước rồi mới báo "máy chủ"

	Client kế thừa nguyên vẹn (`ClientArmyLogic = class(ArmyLogic)`), nên ở đây
	chỉ GỌI rồi trả đúng hàm nhận của client:
	  OnUnlockArmy(nArmyId) / OnUpgradeArmy(nArmyId) / OnIntoLineup / OnOutOffLineup
	(`user/Logical/ClientArmyLogic.lua:20-106`), mỗi hàm phát logic event
	`Army.On*` cho UI.

	`CallUnlockArmy`/`CallUpgradeArmy`/`CallIntoLineup` phát
	`OnWaitingForRequest` (hiện lớp "đang tải"), nên phải trả thêm đường phản
	hồi chung `CUIRPCManager:OnReciveResponse` để tắt nó — xem
	`handlers/mysterious.lua:15`.
]]

require("offline.log")
require("offline.store")
require("offline.router")

local R = OfflineRouter

--[[ Trả lời chung: tắt lớp "đang tải" rồi gọi hàm nhận của client.
	nErrCode 0 = OK. `eventList` rỗng vì dữ liệu đã được hàm luật ghi thẳng
	vào các DataManager của client. ]]
local function traLoi(ctx, strHam, nErrCode, ...)
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", nErrCode or 0, {})
	ctx:call("G_ArmyLogic", strHam, ...)
end

local function ma_loi(nErrCode)
	return tonumber(nErrCode) or 1
end

--[[ Bảo đảm dòng dữ liệu của BINH CHỦNG đã được `updateArmyData` tính lại trước khi
	xét. `ArmyLogic:UnlockArmy` đòi `tArmy.CanBeUnlock == true`, mà trường ấy do
	`updateArmyData` (:186-193) đặt — dựa trên `FrontArmy`/`FrontArmyLevel` của
	TIỀN BINH. Dữ liệu nạp từ file lưu (bản JSON của lớp offline) có thể chưa
	qua bước ấy, khi đó `CanBeUnlock` là nil và luật gốc từ chối
	"NoEnoughSoulToUnlockArmy"/"ArmyCanNotUnlock" dù người chơi đủ điều kiện.
	Gọi lại đúng hàm của bản gốc, không tự tính. ]]
local function capNhatBinhChung(nArmyId)
	if G_ArmyLogic == nil or G_ArmyLogic.GetArmy == nil
			or G_ArmyLogic.updateArmyData == nil then
		return
	end
	local ok, bRecode, tArmy = pcall(function ()
		return G_ArmyLogic:GetArmy(nArmyId)
	end)
	if not (ok and bRecode == true and type(tArmy) == "table") then
		return
	end
	--[[ Dòng dữ liệu nạp từ file lưu có thể THIẾU các trường mà
		`updateArmyData` (:120-196) sinh ra: `CanBeUnlock`, `FrontArmy`,
		`ResourceForUnlock`, `ResourceForUpgrade`, `BaseInfo`… Thiếu cái nào cũng
		làm luật gốc hoặc UI vỡ — đo 27/10: mở khoá xong, UI đọc
		`tArmy.ResourceForUpgrade` (dòng `IsEnoughResourceUpgadeArmy`, :523) và
		nổ "attempt to compare nil with number". Tính lại TRƯỚC và cả SAU khi
		mở khoá (sau thì nhánh `if army.IsLocked` không chạy, nên nó điền được
		các trường của bậc kế). ]]
	if tArmy.CanBeUnlock == nil or tArmy.ResourceForUpgrade == nil
			or tArmy.BaseInfo == nil then
		local okU = pcall(function () G_ArmyLogic:updateArmyData(tArmy) end)
		OfflineLog:info("binh chung " .. tostring(nArmyId)
			.. ": tinh lai du lieu -> " .. tostring(okU))
	end
end

R:on("ClientUnlockArmy", function(ctx, nArmyId)
	local bOk = false
	if G_ArmyLogic ~= nil and G_ArmyLogic.UnlockArmy ~= nil then
		capNhatBinhChung(nArmyId)
		bOk = G_ArmyLogic:UnlockArmy(nArmyId)
	end
	OfflineLog:info(string.format("mo khoa binh chung %s -> %s",
		tostring(nArmyId), tostring(bOk)))
	if bOk == true then
		capNhatBinhChung(nArmyId)   -- điền nốt trường của bậc 1 cho UI
		OfflineStore:syncFromClient()
		traLoi(ctx, "OnUnlockArmy", 0, nArmyId)
	else
		-- Luật gốc chỉ trả true/false (mã lỗi chỉ in log). Không phát
		-- `OnUnlockArmy` để UI không hiện popup "đã mở"; chỉ tắt lớp đang tải.
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 1, {})
	end
end)

R:on("ClientUpgradeArmy", function(ctx, nArmyId)
	local bOk, bCanUpgrade, nErr = false, false, 0
	if G_ArmyLogic ~= nil and G_ArmyLogic.UpgradeArmy ~= nil then
		capNhatBinhChung(nArmyId)
		bOk, bCanUpgrade, nErr = G_ArmyLogic:UpgradeArmy(nArmyId)
	end
	OfflineLog:info(string.format("nang cap binh chung %s -> %s (duoc: %s, ma %s)",
		tostring(nArmyId), tostring(bOk), tostring(bCanUpgrade), tostring(nErr)))
	if bOk == true and bCanUpgrade == true then
		OfflineStore:syncFromClient()
		traLoi(ctx, "OnUpgradeArmy", 0, nArmyId)
	else
		traLoi(ctx, "OnUpgradeArmy", ma_loi(nErr), nArmyId)
	end
end)

R:on("ClientIntoLineup", function(ctx, nIndex, nArmyId)
	local bOk, nErr = false, 0
	if G_ArmyLogic ~= nil and G_ArmyLogic.IntoLineup ~= nil then
		bOk, nErr = G_ArmyLogic:IntoLineup(nIndex, nArmyId)
	end
	if bOk == true then
		OfflineStore:syncFromClient()
	end
	traLoi(ctx, "OnIntoLineup", ma_loi(bOk and 0 or nErr),
		{ nIndex = nIndex, nArmyId = nArmyId })
end)

R:on("ClientOutOffLineup", function(ctx, nIndex, nArmyId)
	local bOk, nErr = false, 0
	if G_ArmyLogic ~= nil and G_ArmyLogic.OutOffLineup ~= nil then
		bOk, nErr = G_ArmyLogic:OutOffLineup(nIndex, nArmyId)
	end
	if bOk == true then
		OfflineStore:syncFromClient()
	end
	traLoi(ctx, "OnOutOffLineup", ma_loi(bOk and 0 or nErr),
		{ nIndex = nIndex, nArmyId = nArmyId })
end)

-- `ClientSetLastArmyLineup` đã có handler ở `handlers/chapter.lua:285` —
-- KHÔNG đăng ký lại (router cảnh báo trùng, và bản ở chapter.lua mới là
-- bản chạy từ trước tới nay).

return true
