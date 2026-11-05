--[[
	offline/thu_tinh_nang.lua — ĐỒ THỬ: gọi lần lượt các lệnh vừa nối trong
	`handlers/tinh_nang.lua` (thiên mệnh, trang bị, tướng, đấu trường, thuốc)
	để biết cái nào chạy được, cái nào luật gốc từ chối (và mã lỗi).

	Gọi qua `CallServer` (đúng đường UI dùng) nên đi qua cả router + handler.
	Mã lỗi 0 = chạy; mã khác = luật gốc từ chối vì thiếu nguyên liệu/cấp — đó
	là câu trả lời ĐÚNG, không phải lỗi lớp offline.

	Tắt: `OfflineThuTinhNang.TAT = true` (mặc định TẮT).
]]

require("offline.log")
require("offline.store")

OfflineThuTinhNang = OfflineThuTinhNang or {}

-- ĐÃ CHẠY 28/10 (21 mục) ⇒ TẮT.
OfflineThuTinhNang.TAT = true
OfflineThuTinhNang.CHO_SCENE = 8
OfflineThuTinhNang.DEM = 0
OfflineThuTinhNang.I = 0
OfflineThuTinhNang.CHO = 0
OfflineThuTinhNang.XONG = false

local function tenCanh()
	if g_CSceneManager == nil then return nil end
	local ok, v = pcall(function () return g_CSceneManager:GetCurrentSceneName() end)
	return ok and v or nil
end

local function soDauTien(t)
	local ks = {}
	for k in pairs(t or {}) do ks[#ks + 1] = tonumber(k) or k end
	table.sort(ks, function (a, b) return tostring(a) < tostring(b) end)
	return ks[1]
end

function OfflineThuTinhNang:danhSach()
	local heroMap, itemMap, potionMap, equipMap = {}, {}, {}, {}
	pcall(function ()
		local _, h = G_HeroLogic:GetHeroMap()
		heroMap = h or {}
	end)
	pcall(function ()
		local _, i = G_ItemLogic:GetItemMap()
		itemMap = i or {}
	end)
	pcall(function ()
		local _, p = G_PotionLogic:GetPotionList()
		potionMap = p or {}
	end)

	local heroID = soDauTien(heroMap)
	local potionID = soDauTien(potionMap)

	return {
		{ "ThienMenh.ActiveProgress", function ()
			CallServer(5, "G_DestinyLogic", "ClientActiveProgress")
		end },
		{ "Tuong.TangHeSo (hero " .. tostring(heroID) .. ")", function ()
			CallServer(5, "G_HeroLogic", "ClientUpgradeHeroGrowthFactor", heroID)
		end },
		{ "Tuong.TangPham (hero " .. tostring(heroID) .. ")", function ()
			CallServer(5, "G_HeroLogic", "ClientUpgradeHeroQualityPromotion", heroID)
		end },
		{ "Tuong.DotPha (hero " .. tostring(heroID) .. ")", function ()
			CallServer(5, "G_HeroLogic", "ClientBreakthroughHeroMaxLevel", heroID)
		end },
		{ "TrangBi.CuongHoa (hero " .. tostring(heroID) .. ")", function ()
			CallServer(5, "G_EquipmentLogic", "ClientIntensifyEquipment", heroID, 1)
		end },
		{ "TrangBi.TangPham (hero " .. tostring(heroID) .. ")", function ()
			CallServer(5, "G_EquipmentLogic", "ClientPromoteQualityEquipment", heroID, 1)
		end },
		{ "Thuoc.NangCap (potion " .. tostring(potionID) .. ")", function ()
			CallServer(5, "G_PotionLogic", "ClientUpgradePotion", potionID)
		end },
		{ "DauTruong.MuaDo (o 1)", function ()
			CallServer(5, "G_ArenaLogic", "ClientBuyArenaGoods", 1)
		end },
		{ "ThanhTuu.FreeStrength", function ()
			CallServer(5, "G_AchieveLogic", "ClientUpdateFreeStrengthState")
		end },
		{ "XayDung.NangCap (building 4)", function ()
			CallServer(5, "", "ClientUpgradeBuilding", 4)
		end },
		{ "NhiemVu.NhanThuong (task 1)", function ()
			CallServer(5, "", "ClientAwardDailyTask", 1)
		end },
		{ "Canh.NhanMienPhi", function ()
			CallServer(5, "G_ClothingLogic", "ClientGetCharacterFreeWing")
		end },
		{ "MaDong.LamMoiHang (mien phi)", function ()
			CallServer(5, "G_CavernLogic", "ClientRefreshGoodsList")
		end },
		{ "VongQuay.LamMoi (sinh 12 o)", function ()
			CallServer(5, "G_FortuneWheelLogic", "ClientRefreshFortuneWheelList")
		end },
		{ "VongQuay.QuayThuong", function ()
			CallServer(5, "G_FortuneWheelLogic", "ClientFreeRoll")
		end },
		{ "VongQuay.QuayVip", function ()
			CallServer(5, "G_FortuneWheelLogic", "ClientVipRoll")
		end },
		{ "VongQuayTanThu.DanhSachGiai", function ()
			CallServer(5, "G_FortuneWheelLogic", "ClientGetNewServerDailyWheelPrizeList")
		end },
		{ "VongQuayTanThu.Quay", function ()
			CallServer(5, "G_FortuneWheelLogic", "ClientRunNewServerDailyWheel")
		end },
		{ "NhiemVuNgay.BaoXong (task 1)", function ()
			CallServer(5, "", "ClientComplelteDailyTask", 1)
		end },
		{ "NhiemVuNgay.Nhan (task 1)", function ()
			CallServer(5, "", "ClientAwardDailyTask", 1)
		end },
		{ "MaDong.QuetTatCa (dat tam progress 5)", function ()
			-- ĐỒ THỬ: đẩy tiến độ + tiền để đo đường quét, KHÔNG phải dữ liệu thật.
			pcall(function ()
				G_CavernDataManager:SetCurrentProgress(5)
				G_CavernDataManager:AddCavernCurrency(1000, "thu-nghiem")
			end)
			CallServer(5, "G_CavernLogic", "ClientCavernSweepAll")
		end },
	}
end

function OfflineThuTinhNang:tick()
	if self.TAT or self.XONG then return end
	if tenCanh() ~= "Main" then return end

	self.DEM = self.DEM + 1
	if self.DEM < self.CHO_SCENE then return end

	if self.CHO > 0 then
		self.CHO = self.CHO - 1
		return
	end

	self.I = self.I + 1
	local ds = self:danhSach()
	local muc = ds[self.I]
	if muc == nil then
		OfflineLog:info(string.format("thu tinh nang: XONG %d muc", #ds))
		self.XONG = true
		return
	end

	local ok, err = pcall(muc[2])
	OfflineLog:info(string.format("thu tinh nang %02d: %s -> %s%s",
		self.I, muc[1], tostring(ok), ok and "" or (" LOI: " .. tostring(err))))
	self.CHO = 3
end

function OfflineThuTinhNang:batDau()
	if self.TAT then return end
	if S_CCSchedule == nil then
		OfflineLog:err("thu_tinh_nang: khong thay S_CCSchedule")
		return
	end
	local ok, err = pcall(function () S_CCSchedule:schedule(self, "tick", 1) end)
	if ok then
		OfflineLog:info("thu_tinh_nang: da hen gio (1 s/nhip)")
	else
		OfflineLog:err("thu_tinh_nang: hen gio loi: " .. tostring(err))
	end
end

return OfflineThuTinhNang
