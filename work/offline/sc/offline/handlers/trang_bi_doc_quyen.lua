--[[
	offline/handlers/trang_bi_doc_quyen.lua — TRANG BỊ ĐỘC QUYỀN (专属装备):
	ĐÚC (forge) và TINH LUYỆN (purify).

	Hai lệnh client trước lượt này nằm trong lớp chắn `chua_ho_tro.lua` (mã 1):

	  · `G_EquipmentLogic|ClientForgingExclusiveEquip(nHeroID, nEquipPartID)`
	    — `ClientEquipmentLogic.lua:517-522`, nút "đúc độc quyền" của
	    `CUIEquipment_Refine` (`onTouchEnd_OnMakeForgeExclusive` :1713-1760).
	  · `G_EquipmentLogic|ClientPurifyExclusiveEquip(nHeroID, nEquipPartID)`
	    — cùng tệp `:536-541`, nút tinh luyện khi trang bị ĐÃ độc quyền
	    (`EquipRefineType.IsExclusive`).

	DỮ LIỆU THẬT (ship trong game): `KDBGameExclusiveEquipConfig.json`, 5 bảng con —
	`ExclusiveEquipHeroConfig` (22 tướng) · `ExclusiveEquipForgeConfig`
	(`[heroID][part] = {ItemList, PurifyLevel}`) · `ExclusiveEquipPurifyConfig`
	(`[part][cấp] = {NeedConcentrate, AddPrecent}`) · `ExclusiveEquipCommonSkillConfig`
	· `ExclusiveReelSaleConfig`. Config manager đã có hàm đọc sẵn
	(`GetExclusiveEquipHeroConfig/ForgeConfig/PurifyConfig`).

	LUẬT — suy từ ba nguồn ĐỘC LẬP, không phải bịa:

	  1. **UI CHẶN NÚT** (`CUIEquipment_Refine.lua`): đúc cần chất lượng
	     `>= QualityKey.Red + 1` (= 6, `:1619`), đủ nguyên liệu (`:1540-1590`);
	     RIÊNG VŨ KHÍ (part 1) còn phải có **4 món kia đã độc quyền**
	     (`GetCanMakeForgeExclusive` :1877-1923).
	  2. **MÃ LỖI ĐÃ KHAI** (`share/error.lua`): `IsNotExclusive=1111` ·
	     `CanNotPurifyThisPartEquip=1112` · `IsMaxPurifyLevel=1113` ·
	     `NoEnoughPurifyLevel=1114` · `NoGetAllExclusiveEquip=1115` ·
	     `IsExclusive=1116` · `CanNotForgingExclusiveWeapon=1117` ·
	     `NotExclusiveHero=1330` · `Item.NotEnoughItem=1201` · `Item.ReduceItemError=1202`.
	     Mỗi mã đúng một cửa của hai lệnh này.
	  3. **HÀM GHI GỐC**: `EquipmentDataManager:SetEquipIsExclusive` (tự gán
	     `IsExclusive = true` + phát Data event) · `SetEquipRefineLevel` ·
	     `EquipmentLogic:updateEquipData` (tính lại thuộc tính; công thức ở
	     `share_EquipmentPropertyLogic.lua:130-160` dùng `ExclusiveEquipPurifyConfig`
	     theo `[part][RefineLevel]` khi `IsExclusive`).

	TINH LUYỆN: dùng CÙNG cấu trúc với `ClientRefineEquip` đã nối 1/11, nhưng bảng cấu
	hình là `ExclusiveEquipPurifyConfig`; giá đọc `NeedConcentrate` của CẤP KẾ rồi đi qua
	`HeroLogic:GetUpgradeRefineCost` — ĐÚNG hàm UI dùng để HIỂN THỊ giá
	(`CUIEquipment_Refine.lua:520`) — để số hiện và số trừ khớp nhau (VIP10 giảm 20%).

	PHẢN HỒI: lớp tải bật bằng `OnWaitingForRequest` với khoá của lệnh; đóng bằng
	`CUIRPCManager:OnReciveResponse("", "", 0, {})`, rồi phát logic event cho UI:
	  · `OnForgingExclusiveEquip(heroID)` — UI nhận SỐ (`:1772` đọc thẳng `nHeroID`).
	  · `OnPurifyExclusiveEquip(tData)` — UI nhận BẢNG `{HeroID, EquipPartID, RefineLevel}`
	    (`:727-757`).
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineTrangBiDocQuyen = OfflineTrangBiDocQuyen or {}

local R = OfflineRouter
local TEN_FILE = "trang bi doc quyen"

local O_WAPON = 1                 -- HeroEquipPart.Weapon
local O_QUALITY_TOI_THIEU = 6     -- QualityKey.Red (5) + 1

local function dongBo()
	pcall(function () OfflineStore:syncFromClient() end)
end

local function soNguyen(v)
	local n = tonumber(v)
	if n == nil or n ~= n or n < 0 then return nil end
	return math.floor(n)
end

--[[ Đọc bảng con của `KDBGameExclusiveEquipConfig` qua đúng hàm config manager. ]]
local function cauHinh(tenHam)
	local ok, t = pcall(function ()
		return G_ConfigManager[tenHam](G_ConfigManager)
	end)
	if not ok or type(t) ~= "table" then
		return nil
	end
	return t
end

--[[ Khoá cấu hình có thể là SỐ hoặc CHUỖI (bẫy `star_soul_id` 31/10). ]]
local function layKhoa(t, k)
	if type(t) ~= "table" or k == nil then return nil end
	return t[k] or t[tostring(k)]
end

--[[ Cấp cao nhất của một bảng cấu hình đánh theo CẤP.

	`GetExclusiveEquipPurifyConfig` trả khoá **0-based** (`[nLevel-1]`). Toán tử `#`
	của Lua trên bảng không bắt đầu từ 1 là KHÔNG xác định (có thể trả 20 thay vì 21),
	nên đếm khoá bằng `pairs` — cùng quy ước với thuộc tính/UI: khoá = `RefineLevel`. ]]
local function capCaoNhat(t)
	local n = -1
	for k in pairs(t) do
		local kk = tonumber(k)
		if kk ~= nil and kk > n then n = kk end
	end
	return n
end

local function laTuongDocQuyen(nHeroID)
	local ds = cauHinh("GetExclusiveEquipHeroConfig")
	if ds == nil then return nil, "khong doc duoc ExclusiveEquipHeroConfig" end
	for _, v in ipairs(ds) do
		if tonumber(v) == nHeroID then
			return true
		end
	end
	return false
end

local function layDo(nHeroID, nPartID)
	local ok, bRet, tEquip = pcall(function ()
		return G_EquipmentLogic:GetEquipment(nHeroID, nPartID)
	end)
	if ok and bRet == true and type(tEquip) == "table" and (tonumber(tEquip.EquipLevel) or 0) > 0 then
		return tEquip
	end
	return nil
end

--[[ Đếm số món ĐÃ độc quyền trong 4 bộ phận 2..5 (vũ khí = 1). ]]
local function demDocQuyen(nHeroID)
	local n = 0
	for part = 2, 5 do
		local t = layDo(nHeroID, part)
		if t ~= nil and t.IsExclusive == true then
			n = n + 1
		end
	end
	return n
end

local function traLoiLoi(ctx, nMa, strViSao)
	OfflineLog:info(string.format("%s: %s -> ma %d", TEN_FILE, tostring(strViSao), nMa))
	pcall(function ()
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", nMa or 1, {})
	end)
end

local function traLoiXong(ctx)
	pcall(function ()
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 0, {})
	end)
end

-------------------------------------------------------------------------- ĐÚC

R:on("G_EquipmentLogic.ClientForgingExclusiveEquip", function (ctx, nHeroID, nEquipPartID)
	local nHero = soNguyen(nHeroID)
	local nPhan = soNguyen(nEquipPartID)
	if nHero == nil or nPhan == nil then
		traLoiLoi(ctx, ErrorCode.ArgError, "tham so sai")
		return
	end

	-- 1. tướng phải nằm trong danh sách mở độc quyền
	local bLaTuong, strHong = laTuongDocQuyen(nHero)
	if bLaTuong == nil then
		OfflineLog:warn(TEN_FILE .. ": " .. tostring(strHong))
		traLoiLoi(ctx, ErrorCode.Hero.NotExclusiveHero, "thieu cau hinh tuong doc quyen")
		return
	end
	if not bLaTuong then
		traLoiLoi(ctx, ErrorCode.Hero.NotExclusiveHero,
			string.format("tuong %d khong co trong ExclusiveEquipHeroConfig", nHero))
		return
	end

	-- 2. ô đồ phải có
	local tEquip = layDo(nHero, nPhan)
	if tEquip == nil then
		traLoiLoi(ctx, ErrorCode.Equipment.NotEquipmentExist,
			string.format("tuong %d / o %d khong co trang bi", nHero, nPhan))
		return
	end

	-- 3. chưa độc quyền
	if tEquip.IsExclusive == true then
		traLoiLoi(ctx, ErrorCode.Equipment.IsExclusive,
			string.format("tuong %d / o %d da doc quyen", nHero, nPhan))
		return
	end

	local tForge = layKhoa(cauHinh("GetExclusiveEquipForgeConfig"), nHero)
	tForge = layKhoa(tForge, nPhan)
	if type(tForge) ~= "table" or type(tForge.ItemList) ~= "table" then
		OfflineLog:warn(string.format("%s: thieu dong cau hinh duc cho tuong %d / o %d",
			TEN_FILE, nHero, nPhan))
		traLoiLoi(ctx, ErrorCode.Equipment.CanNotForgingExclusiveWeapon, "thieu cau hinh duc")
		return
	end

	-- 4. chất lượng đỏ trở lên (UI `:1619`)
	if (tonumber(tEquip.Quality) or 0) < O_QUALITY_TOI_THIEU then
		traLoiLoi(ctx, ErrorCode.Equipment.CanNotForgingExclusiveWeapon,
			string.format("chat luong %s < %d", tostring(tEquip.Quality), O_QUALITY_TOI_THIEU))
		return
	end

	--[[ 4b. TINH LUYỆN THƯỜNG PHẢI ĐẦY — UI chỉ hiện nút đúc ở trạng thái
		`UpgradeExclusive`, tức `tEquip.RefineLevel >= 5` (`getEquipState`,
		`CUIEquipment_Refine.lua:965`); trạng thái `OpenExclusive` (cấp < 5) chỉ có
		lớp tiến độ, KHÔNG có nút đúc. Số 5 lấy từ chính `EquipRefineConfig[part]`
		để khỏi lệch nếu cấu hình đổi. ]]
	local nCapCan = 5
	pcall(function ()
		local tThuong = G_ConfigManager:GetCommonConfigWithName("EquipRefineConfig")
		local p = layKhoa(tThuong, nPhan)
		if type(p) == "table" and #p > 0 then nCapCan = #p end
	end)
	local nCapHienTai = tonumber(tEquip.RefineLevel) or 0
	if nCapHienTai < nCapCan then
		traLoiLoi(ctx, ErrorCode.Equipment.CanNotForgingExclusiveWeapon,
			string.format("tinh luyen thuong %d/%d chua day", nCapHienTai, nCapCan))
		return
	end

	-- 5. vũ khí cần 4 món kia đã độc quyền (UI :1877-1923 ⇒ mã 1115)
	if nPhan == O_WAPON then
		local nCo = demDocQuyen(nHero)
		if nCo < 4 then
			traLoiLoi(ctx, ErrorCode.Equipment.NoGetAllExclusiveEquip,
				string.format("vu khi can 4 mon kia doc quyen, moi co %d", nCo))
			return
		end
	end

	-- 6. kiểm ĐỦ hết nguyên liệu TRƯỚC khi trừ (nguyên tử)
	local dsTru = {}
	for _, v in ipairs(tForge.ItemList) do
		local nId = tonumber(v.ItemID)
		local nCan = tonumber(v.Count)
		if nId ~= nil and nCan ~= nil and nCan > 0 then
			local ok, _, nCo = pcall(function () return G_ItemLogic:GetItemCount(nId) end)
			local nHienCo = ok and tonumber(nCo) or 0
			if nHienCo < nCan then
				traLoiLoi(ctx, ErrorCode.Item.NotEnoughItem,
					string.format("vat pham %d can %d, co %d", nId, nCan, nHienCo))
				return
			end
			dsTru[#dsTru + 1] = { id = nId, so = nCan }
		end
	end

	-- 7. trừ nguyên liệu; hỏng giữa chừng thì HOÀN LẠI phần đã trừ
	local daTru = {}
	for _, m in ipairs(dsTru) do
		local ok, bRet = pcall(function ()
			return G_ItemDataManager:ReduceItem(m.id, m.so, "ClientForgingExclusiveEquip")
		end)
		if not ok or bRet ~= true then
			for _, lui in ipairs(daTru) do
				pcall(function () G_ItemLogic:AddItem(lui.id, lui.so, "ClientForgingExclusiveEquip.hoan") end)
			end
			traLoiLoi(ctx, ErrorCode.Item.ReduceItemError,
				string.format("tru vat pham %d that bai", m.id))
			return
		end
		daTru[#daTru + 1] = m
	end

	-- 8. đánh dấu độc quyền + tính lại thuộc tính
	local okDat, bDat = pcall(function ()
		return G_EquipmentDataManager:SetEquipIsExclusive(nHero, nPhan)
	end)
	if not okDat or bDat ~= true then
		for _, lui in ipairs(daTru) do
			pcall(function () G_ItemLogic:AddItem(lui.id, lui.so, "ClientForgingExclusiveEquip.hoan") end)
		end
		OfflineLog:err(TEN_FILE .. ": SetEquipIsExclusive that bai")
		traLoiLoi(ctx, 1, "SetEquipIsExclusive that bai")
		return
	end

	pcall(function () G_EquipmentLogic:updateEquipData(tEquip) end)
	dongBo()

	OfflineLog:info(string.format("%s: tuong %d / o %d -> DOC QUYEN (tru %d loai nguyen lieu)",
		TEN_FILE, nHero, nPhan, #daTru))
	traLoiXong(ctx)
	pcall(function ()
		G_EventManager:PostLogicEvent(nHero, "OnForgingExclusiveEquip")
	end)
end)

------------------------------------------------------------------- TINH LUYỆN

R:on("G_EquipmentLogic.ClientPurifyExclusiveEquip", function (ctx, nHeroID, nEquipPartID)
	local nHero = soNguyen(nHeroID)
	local nPhan = soNguyen(nEquipPartID)
	if nHero == nil or nPhan == nil then
		traLoiLoi(ctx, ErrorCode.ArgError, "tham so sai")
		return
	end

	local tEquip = layDo(nHero, nPhan)
	if tEquip == nil then
		traLoiLoi(ctx, ErrorCode.Equipment.NotEquipmentExist,
			string.format("tuong %d / o %d khong co trang bi", nHero, nPhan))
		return
	end

	if tEquip.IsExclusive ~= true then
		traLoiLoi(ctx, ErrorCode.Equipment.IsNotExclusive,
			string.format("tuong %d / o %d chua doc quyen", nHero, nPhan))
		return
	end

	local tPhan = layKhoa(cauHinh("GetExclusiveEquipPurifyConfig"), nPhan)
	if type(tPhan) ~= "table" then
		OfflineLog:warn(string.format("%s: thieu cau hinh tinh luyen cho o %d", TEN_FILE, nPhan))
		traLoiLoi(ctx, ErrorCode.Equipment.CanNotPurifyThisPartEquip, "thieu cau hinh o")
		return
	end

	local nCap = tonumber(tEquip.RefineLevel) or 0
	local nToiDa = capCaoNhat(tPhan)
	if nToiDa < 0 then
		traLoiLoi(ctx, ErrorCode.Equipment.CanNotPurifyThisPartEquip, "cau hinh rong")
		return
	end
	if nCap >= nToiDa then
		traLoiLoi(ctx, ErrorCode.Equipment.IsMaxPurifyLevel,
			string.format("da o cap %d/%d", nCap, nToiDa))
		return
	end

	-- CẤP KẾ = khoá `nCap + 1` — ĐÚNG cách UI đọc (`CUIEquipment_Refine.lua:1129`
	-- lấy `[RefineLevel + 1]` trên chính bảng 0-based này).
	local cfgCap = tPhan[nCap + 1]
	if type(cfgCap) ~= "table" then
		traLoiLoi(ctx, ErrorCode.Equipment.NoEnoughPurifyLevel,
			string.format("thieu dong cau hinh cap %d", nCap + 1))
		return
	end

	local nGia = tonumber(cfgCap.NeedConcentrate) or 0
	-- UI hiển thị giá qua ĐÚNG hàm này (`CUIEquipment_Refine.lua:520`) — trừ cho khớp.
	pcall(function () nGia = tonumber(G_HeroLogic:GetUpgradeRefineCost(nGia)) or nGia end)

	local okTru, bTru = pcall(function ()
		return G_UserLogic:CostConcentrate(nGia, "ClientPurifyExclusiveEquip")
	end)
	if not okTru or bTru ~= true then
		local _, co = pcall(function () return G_UserLogic:GetConcentrate() end)
		traLoiLoi(ctx, ErrorCode.Equipment.NotEnoughConcentrate,
			string.format("can %d tinh hoa, co %s", nGia, tostring(co)))
		return
	end

	local okDat, bDat = pcall(function ()
		return G_EquipmentDataManager:SetEquipRefineLevel(nHero, nPhan, nCap + 1)
	end)
	if not okDat or bDat ~= true then
		pcall(function () G_UserLogic:AddConcentrate(nGia, "ClientPurifyExclusiveEquip.hoan") end)
		OfflineLog:err(TEN_FILE .. ": SetEquipRefineLevel that bai")
		traLoiLoi(ctx, 1, "SetEquipRefineLevel that bai")
		return
	end

	pcall(function () G_EquipmentLogic:updateEquipData(tEquip) end)
	dongBo()

	OfflineLog:info(string.format("%s: tuong %d / o %d len cap %d (tru %d tinh hoa, +%s%%)",
		TEN_FILE, nHero, nPhan, nCap + 1, nGia, tostring(cfgCap.AddPrecent)))
	traLoiXong(ctx)
	pcall(function ()
		G_EventManager:PostLogicEvent(
			{ HeroID = nHero, EquipPartID = nPhan, RefineLevel = nCap + 1 },
			"OnPurifyExclusiveEquip")
	end)
end)

OfflineLog:info("trang bi doc quyen: da noi 2 khoa (duc/tinh luyen)")
