--[[
	offline/handlers/tinh_luyen_trang_bi.lua — TINH LUYỆN TRANG BỊ / 装备熔炼 (refine).

	Khoá `G_EquipmentLogic|ClientRefineEquip(nHeroID, nEquipPartID)`
	(`ClientEquipmentLogic.lua:60-68`, nút "Tinh luyện" của `CUIEquipment_Refine`).
	Trước lượt này KHÔNG có handler nào ⇒ bấm là lớp "đang tải" quay mãi.

	KHÔNG có thân hàm máy chủ trong `share/`, NHƯNG luật suy ra được CHẮC CHẮN từ ba
	nguồn ĐỘC LẬP — không phải đoán:

	  1. **MÃ LỖI ĐÃ KHAI SẴN** (`share/error.lua:82-83`): `NotEnoughConcentrate = 1109`,
	     `MaxRefineLevelCantRefine = 1110` — đúng hai cửa của một lệnh tinh luyện, cạnh
	     `NotEquipmentExist = 1106`. Mã không được khai cho việc gì khác.
	  2. **CẤU HÌNH THẬT** `EquipRefineConfig`: `[EquipPartID][cấp] = {NeedConcentrate,
	     AddPrecent}` (5 mốc mỗi bộ phận: 30/40 → 80/60 → …).
	  3. **UI ĐỌC ĐÚNG MỐC ẤY**: `CUIEquipment_Refine.lua:373` lấy
	     `tEquipRefineConfig[tEquip.EquipPartID][tEquip.RefineLevel + 1]` để hiện giá và
	     `%` của CẤP KẾ; `:447-451` cùng đường. Công thức thuộc tính cũng đã có trong
	     `share/share_EquipmentPropertyLogic.lua:147-160`: `RefineLevel` cộng
	     `AddPrecent%` vào thuộc tính chính — nên chỉ cần TĂNG CẤP là thuộc tính tự đúng.

	⇒ LUẬT: lấy cấp kế trong cấu hình → thiếu cấu hình/cao nhất thì 1110 → trừ
	`NeedConcentrate` bằng `G_UserLogic:CostConcentrate` (hàm gốc, tự chặn âm) → thiếu thì
	1109 → `SetEquipRefineLevel(cấp+1)` → `updateEquipData` (tính lại thuộc tính + giá cấp
	kế) → trả lời.

	Trả lời: `ClientEquipmentLogic:OnRefineEquip()` (`:76-87`) KHÔNG đối số — nó tự tắt
	lớp tải và phát `OnRefineEquip` cho UI vẽ lại. Lỗi thì phát thêm
	`OnServerRequestError` (đường chuẩn của `onActionError`).
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineTinhLuyen = OfflineTinhLuyen or {}

local R = OfflineRouter
local TEN_FILE = "tinh luyen trang bi"

local function dongBo()
	pcall(function () OfflineStore:syncFromClient() end)
end

--[[ Bảng cấu hình của MỘT bộ phận. Config manager có thể đánh lại khoá thành chuỗi
	(bẫy `star_soul_id` 31/10), nên thử cả hai. ]]
local function cauHinhPhan(nPartID)
	local ok, m = pcall(function ()
		return G_ConfigManager:GetCommonConfigWithName("EquipRefineConfig")
	end)
	if not ok or type(m) ~= "table" then
		return nil
	end
	local p = m[nPartID] or m[tostring(nPartID)]
	if type(p) ~= "table" then
		return nil
	end
	return p
end

local function thongBao(nMa)
	if nMa == nil or nMa == 0 then return end
	pcall(function ()
		g_CUINotificationCenter:PostNotification(
			CUINotificationEvent.OnServerRequestError, nMa)
	end)
end

--[[ Trả lời: hàm nhận KHÔNG đối số, nó tự tắt lớp tải. ]]
local function traLoi(ctx, nMa)
	thongBao(nMa)
	ctx:call("G_EquipmentLogic", "OnRefineEquip")
end

R:on("G_EquipmentLogic.ClientRefineEquip", function (ctx, nHeroID, nEquipPartID)
	local nHero, nPhan = tonumber(nHeroID), tonumber(nEquipPartID)
	if nHero == nil or nPhan == nil then
		OfflineLog:warn(TEN_FILE .. ": tham so sai")
		traLoi(ctx, ErrorCode.ArgError)
		return
	end

	local equip = nil
	do
		local ok, bRet, e = pcall(function ()
			return G_EquipmentLogic:GetEquipment(nHero, nPhan)
		end)
		if not ok or bRet ~= true or type(e) ~= "table" then
			OfflineLog:info(string.format("%s: khong co trang bi hero %d / o %d", TEN_FILE, nHero, nPhan))
			traLoi(ctx, ErrorCode.Equipment.NotFindEquipment)
			return
		end
		equip = e
	end

	local nCap = tonumber(equip.RefineLevel) or 0
	local phan = cauHinhPhan(equip.EquipPartID or nPhan)
	local nToiDa = type(phan) == "table" and #phan or 0
	if nToiDa <= 0 or nCap >= nToiDa then
		OfflineLog:info(string.format("%s: hero %d / o %d da o cap %d/%d",
			TEN_FILE, nHero, nPhan, nCap, nToiDa))
		traLoi(ctx, ErrorCode.Equipment.MaxRefineLevelCantRefine)
		return
	end

	local cfg = phan[nCap + 1]
	local nGia = tonumber(cfg and cfg.NeedConcentrate)
	if nGia == nil then
		OfflineLog:warn(string.format("%s: thieu dong cau hinh cap %d", TEN_FILE, nCap + 1))
		traLoi(ctx, ErrorCode.Equipment.MaxRefineLevelCantRefine)
		return
	end

	-- TRỪ BẰNG HÀM GỐC: nó tự chặn khi `Concentrate - nGia < 0`.
	local okTru, bTru = pcall(function ()
		return G_UserLogic:CostConcentrate(nGia, "ClientRefineEquip")
	end)
	if not okTru or bTru ~= true then
		local _, co = pcall(function () return G_UserLogic:GetConcentrate() end)
		OfflineLog:info(string.format("%s: khong du tinh hoa (can %d, co %s)",
			TEN_FILE, nGia, tostring(co)))
		traLoi(ctx, ErrorCode.Equipment.NotEnoughConcentrate)
		return
	end

	local okDat, bDat = pcall(function ()
		return G_EquipmentDataManager:SetEquipRefineLevel(nHero, nPhan, nCap + 1)
	end)
	if not okDat or bDat ~= true then
		OfflineLog:err(TEN_FILE .. ": SetEquipRefineLevel that bai")
		-- Trả lại tinh hoa đã trừ để không nuốt của người chơi.
		pcall(function () G_UserLogic:AddConcentrate(nGia, "ClientRefineEquip.hoan") end)
		traLoi(ctx, ErrorCode.Equipment.SetEquipIntensifyLevel)
		return
	end

	pcall(function () G_EquipmentLogic:updateEquipData(equip) end)
	dongBo()

	OfflineLog:info(string.format("%s: hero %d / o %d len cap %d (tru %d tinh hoa, +%s%%)",
		TEN_FILE, nHero, nPhan, nCap + 1, nGia, tostring(cfg.AddPrecent)))
	traLoi(ctx, 0)
end)

OfflineLog:info("tinh luyen trang bi: da noi 1 khoa (ClientRefineEquip)")

return true
