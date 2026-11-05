--[[
	offline/nang_cap.lua — ĐỒ THỬ: nâng cấp tài khoản thử rồi mở khoá mọi chức
	năng, để đi kiểm từng panel trên cảnh Main.

	Vì sao phải làm thay máy chủ: mốc mở chức năng do MÁY CHỦ đặt cờ
	`G_UserLogic:SetGameFuncUnLockData(<tên>, true)` vào `GameUserGlobalData`
	(khoá `L_<tên>`, xem `UserLogic:GetCommonData`), rồi client chỉ đọc cờ ấy
	(`CGameFuncOpeningManager:IsFuncOpening`). Bản gốc để chính client đặt cờ
	lúc người chơi đạt cấp (`CGuideEvent:CheckOpenFunc`,
	`user/Guide/CGuideEvent.lua:395`). Offline không có chuỗi sự kiện ấy nên
	phải đặt hộ — ĐÚNG bảng cấp của bản gốc, chép ở `BANG_CAP` dưới đây.

	Cấp/VIP: cấp chỉ là trường `Level` của `GameUserBaseInfo`; VIP là `VipLevel`
	(`VipConfig.VipLevelRechargeList` có 16 mốc ⇒ VIP 0..15). Mốc cao nhất trong
	dữ liệu: chương cần **cấp 88** (`ChapterOpenNeedCharacterLevel`), chức năng
	cao nhất **Lv60** (`CUIWorldWar`), bảng giá/hàng theo cấp tới **90**.

	Chạy MỘT lượt (`TAT = false`), ghi thẳng vào file lưu, rồi khởi động lại
	game cho cảnh Main dựng lại. Xong thì trả `TAT = true`.
]]

require("offline.log")
require("offline.store")

OfflineNangCap = OfflineNangCap or {}

-- ĐÃ CHẠY 28/10 (Lv6 → 90, VIP0 → 15) ⇒ TẮT.
OfflineNangCap.TAT = true
OfflineNangCap.CAP = 90
OfflineNangCap.VIP = 15
OfflineNangCap.CHO_SCENE = 6

-- Bảng cấp mở chức năng — CHÉP từ `CGuideEvent:CheckOpenFunc`
-- (`user/Guide/CGuideEvent.lua:409-431`). Giữ nguyên số, không tự thêm.
local BANG_CAP = {
	CUIArena = 14,
	CUIMysteryShop = 18,
	CUIActivityMode = 22,
	CUITurnplate = 30,
	CUIAchieve = 28,
	CUIDen = 34,
	CUIDestiny = 36,
	CUIGuildControl = 25,
	CUIFriend2 = 20,
	CUILeaderboard = 28,
	HeroFightSoul = 38,
	CUILevelTarget = 19,
	EquipmentRefine = 40,
	CUIMainEvilCastle = 45,
	CUISB = 37,
	CUIQuest = 35,
	CUIContest = 40,
	CUIXingHun = 50,
	CUIWorldWar = 60,
}

OfflineNangCap.DEM = 0
OfflineNangCap.XONG = false

local function tenCanh()
	if g_CSceneManager == nil then return nil end
	local ok, v = pcall(function () return g_CSceneManager:GetCurrentSceneName() end)
	return ok and v or nil
end

local function datCoMoKhoa()
	local soCo = 0
	local ten = {}

	local function dat(k)
		local ok, truoc = pcall(function ()
			local _, v = G_UserLogic:GetGameFuncUnLockData(k)
			return v
		end)
		if ok and truoc ~= true then
			pcall(function () G_UserLogic:SetGameFuncUnLockData(k, true) end)
			soCo = soCo + 1
			ten[#ten + 1] = k
		end
	end

	-- 1) mọi chức năng client có ĐĂNG KÝ (khoá theo giao diện)
	pcall(function ()
		for _, ds in pairs(g_CGameFuncOpeningManager.FuncLockMap) do
			for k in pairs(ds) do
				dat(k)
			end
		end
	end)

	-- 2) bảng cấp + các tên client hỏi nhưng không đăng ký giao diện
	for k in pairs(BANG_CAP) do
		dat(k)
	end

	return soCo, table.concat(ten, ", ")
end

function OfflineNangCap:tick()
	if self.TAT or self.XONG then return end
	if tenCanh() ~= "Main" then return end

	self.DEM = self.DEM + 1
	if self.DEM < self.CHO_SCENE then return end
	self.XONG = true

	local capTruoc, vipTruoc = "?", "?"
	pcall(function ()
		local _, c = G_UserLogic:GetLevel()
		capTruoc = tostring(c)
		local _, v = G_UserLogic:GetUserVipLevel()
		vipTruoc = tostring(v)
	end)

	pcall(function () G_UserLogicDataManager:SetLevel(self.CAP) end)
	pcall(function () G_UserLogicDataManager:SetEx(0) end)
	pcall(function () G_UserLogicDataManager:SetUserVipLevel(self.VIP) end)
	pcall(function () G_UserLogicDataManager:SetRechargeCount(800000) end)

	local soCo, dsTen = datCoMoKhoa()

	OfflineStore:syncFromClient()
	OfflineStore:save()

	OfflineLog:info(string.format(
		"nang cap: Lv %s -> %d, VIP %s -> %d, mo khoa them %d co [%s]",
		capTruoc, self.CAP, vipTruoc, self.VIP, soCo, dsTen))

	-- Dựng lại cảnh Main để nhãn khoá / biểu tượng đổi ngay.
	pcall(function () g_CSceneManager:RepaleceScene("Main") end)
end

function OfflineNangCap:batDau()
	if self.TAT then
		return
	end
	if S_CCSchedule == nil then
		OfflineLog:err("nang_cap: khong thay S_CCSchedule")
		return
	end
	local ok, err = pcall(function () S_CCSchedule:schedule(self, "tick", 1) end)
	if ok then
		OfflineLog:info("nang_cap: da hen gio (1 s/nhip)")
	else
		OfflineLog:err("nang_cap: hen gio loi: " .. tostring(err))
	end
end

return OfflineNangCap
