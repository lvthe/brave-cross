--[[
	offline/thu_cau_rpc.lua — TỰ KIỂM CẦU RPC (`offline/noi_server.lua`) TRONG GAME.

	Gọi qua ĐÚNG đường của client (`CallServer`) để đi qua `OfflineNet:dispatch` và cầu:
	    CallServer(5, "G_LotteryLogic", "ClientGetLotteryData")     -- đọc
	    CallServer(5, "G_LotteryLogic", "ClientPlayLottery", 5, false) -- DIAMOND_FREE

	Bằng chứng nằm ở HAI nhật ký:
	  · client `offline.log`: `noi_server: gui …` + `noi_server: … -> err=… cb="…"`
	  · server `[rpc] uid=… G_LotteryLogic|… -> tay err=…`
	và ở file lưu: `GameUserLottery.LastFreeDiamondTime` phải > 0 sau lượt miễn phí
	(server đặt mốc + gửi mục Data; client áp rồi cầu đồng bộ lại).

	BẬT: `cau_rpc_test.flag` cạnh file lưu; chạy MỘT lần sau khi vào Main.
	Đồ thử TIÊU một lượt quay miễn phí kim cương — chỉ dùng tài khoản thử.
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineThuCauRpc = OfflineThuCauRpc or {}

local T = OfflineThuCauRpc

T.TEP_CO = "cau_rpc_test.flag"
-- Cờ THỨ HAI (tuỳ chọn): chỉ chạy khi cờ này CÓ MẶT. Dùng để căn thời điểm (vd tắt
-- server SAU khi đăng nhập rồi mới cho đồ thử chạy — kiểm đường lùi về offline).
T.TEP_CHO = "cau_rpc_go.flag"
T.DEM = 0
T.CHO = 6
T.BUOC = 0
T.DA_CHAY = false

local function thuMuc() return (OfflineStore:path():gsub("[^/]*$", "")) end
local function coTepCo()
	local ok, fp = pcall(io.open, thuMuc() .. T.TEP_CO, "r")
	if ok and fp then fp:close(); return true end
	return false
end
local function xoaCo() pcall(os.remove, thuMuc() .. T.TEP_CO) end

local function moc()
	local v = nil
	pcall(function ()
		local _, t = G_LotteryLogicDataManager:GetUserLotteryData()
		v = t and tonumber(t.LastFreeDiamondTime) or nil
	end)
	return v
end

local function coTepCho()
	local ok, fp = pcall(io.open, thuMuc() .. T.TEP_CHO, "r")
	if ok and fp then fp:close(); return true end
	return false
end

function T:tick()
	if self.DA_CHAY then return end
	if not coTepCo() then return end
	if not coTepCho() then return end
	if not (Offline and Offline.LAN_VAO_GAME and Offline.LAN_VAO_GAME > 0) then return end
	self.DEM = self.DEM + 1
	if self.DEM < self.CHO then return end

	if self.BUOC == 0 then
		self.BUOC = 1
		self.DEM = 0
		OfflineLog:info(string.format("THU CAU RPC: LastFreeDiamondTime truoc = %s", tostring(moc())))
		OfflineLog:info("THU CAU RPC: CallServer(5, G_LotteryLogic, ClientGetLotteryData)")
		pcall(function () CallServer(5, "G_LotteryLogic", "ClientGetLotteryData") end)
		return
	end

	if self.BUOC == 1 then
		if self.DEM < 3 then return end
		self.BUOC = 2
		self.DEM = 0
		OfflineLog:info("THU CAU RPC: CallServer(5, G_LotteryLogic, ClientPlayLottery, 5, false)")
		pcall(function () CallServer(5, "G_LotteryLogic", "ClientPlayLottery", 5, false) end)
		return
	end

	if self.BUOC == 2 then
		if self.DEM < 4 then return end
		-- Lượt MIỄN PHÍ ĐỒNG (loại 1) — chắc chắn còn (file lưu: FreeCount 5).
		self.BUOC = 3
		self.DEM = 0
		OfflineLog:info("THU CAU RPC: CallServer(5, G_LotteryLogic, ClientPlayLottery, 1, false)")
		pcall(function () CallServer(5, "G_LotteryLogic", "ClientPlayLottery", 1, false) end)
		return
	end

	if self.BUOC == 3 then
		if self.DEM < 4 then return end
		self.BUOC = 4
		self.DEM = 0
		-- NHÓM 2: VÒNG QUAY MAY MẮN — làm mới bánh rồi quay MIỄN PHÍ.
		OfflineLog:info("THU CAU RPC: CallServer(5, G_FortuneWheelLogic, ClientRefreshFortuneWheelList)")
		pcall(function () CallServer(5, "G_FortuneWheelLogic", "ClientRefreshFortuneWheelList") end)
		return
	end

	if self.BUOC == 4 then
		if self.DEM < 4 then return end
		self.BUOC = 5
		self.DEM = 0
		local soO = -1
		pcall(function ()
			local _, t = G_FortuneWheelLogic:GetUserFortuneWheel()
			soO = (t and type(t.FreeWheelList) == "table") and #t.FreeWheelList or -1
		end)
		OfflineLog:info("THU CAU RPC: banh sau lam moi = " .. tostring(soO) .. " o")
		OfflineLog:info("THU CAU RPC: CallServer(5, G_FortuneWheelLogic, ClientFreeRoll)")
		pcall(function () CallServer(5, "G_FortuneWheelLogic", "ClientFreeRoll") end)
		return
	end

	if self.BUOC == 5 then
		if self.DEM < 4 then return end
		self.BUOC = 6
		self.DEM = 0
		-- NHÓM 3 (theo KHOÁ): quà 7 ngày · điểm kim thủ · thiên mệnh.
		OfflineLog:info("THU CAU RPC: CallServer(5, G_SevenDaysGiftLogic, ClientSevenDaysGift, 1)")
		pcall(function () CallServer(5, "G_SevenDaysGiftLogic", "ClientSevenDaysGift", 1) end)
		return
	end

	if self.BUOC == 6 then
		if self.DEM < 4 then return end
		self.BUOC = 7
		self.DEM = 0
		OfflineLog:info("THU CAU RPC: CallServer(5, G_MidasTouchLogic, ClientRunMidasTouchWithCount, 1)")
		pcall(function () CallServer(5, "G_MidasTouchLogic", "ClientRunMidasTouchWithCount", 1) end)
		return
	end

	if self.BUOC == 7 then
		if self.DEM < 4 then return end
		self.BUOC = 8
		self.DEM = 0
		OfflineLog:info("THU CAU RPC: CallServer(5, G_DestinyLogic, ClientActiveProgress)")
		pcall(function () CallServer(5, "G_DestinyLogic", "ClientActiveProgress") end)
		return
	end

	if self.BUOC == 8 then
		if self.DEM < 4 then return end
		self.BUOC = 9
		self.DEM = 0
		OfflineLog:info("THU CAU RPC: CallServer(5, G_FormationLogic, ClientUpgrade, jichu)")
		pcall(function () CallServer(5, "G_FormationLogic", "ClientUpgrade", "jichu") end)
		return
	end

	if self.BUOC == 9 then
		if self.DEM < 4 then return end
		self.BUOC = 10
		self.DEM = 0
		OfflineLog:info("THU CAU RPC: CallServer(5, G_FormationLogic, ClientSelectAdvancedFormation, heyi)")
		pcall(function () CallServer(5, "G_FormationLogic", "ClientSelectAdvancedFormation", "heyi") end)
		return
	end

	if self.BUOC == 10 then
		if self.DEM < 4 then return end
		self.BUOC = 11
		self.DEM = 0
		OfflineLog:info("THU CAU RPC: CallServer(5, G_HeroPracticeLogic, ClientPracticeHero, 25, 1)")
		pcall(function () CallServer(5, "G_HeroPracticeLogic", "ClientPracticeHero", 25, "1") end)
		return
	end

	if self.BUOC == 11 then
		if self.DEM < 4 then return end
		self.BUOC = 12
		self.DEM = 0
		OfflineLog:info("THU CAU RPC: CallServer(5, G_HeroPracticeLogic, ClientGetPracticePrize, 1)")
		pcall(function () CallServer(5, "G_HeroPracticeLogic", "ClientGetPracticePrize", "1") end)
		return
	end

	if self.BUOC == 12 then
		if self.DEM < 4 then return end
		self.BUOC = 13
		self.DEM = 0
		OfflineLog:info("THU CAU RPC: CallServer(5, G_HeroPracticeLogic, ClientGetPracticeInfo)")
		pcall(function () CallServer(5, "G_HeroPracticeLogic", "ClientGetPracticeInfo") end)
		return
	end

	if self.BUOC == 13 then
		if self.DEM < 4 then return end
		self.BUOC = 14
		self.DEM = 0
		OfflineLog:info("THU CAU RPC: CallServer(5, G_MonthlyCardLogic, ClientGetReward)")
		pcall(function () CallServer(5, "G_MonthlyCardLogic", "ClientGetReward", "Normal") end)
		return
	end

	if self.BUOC == 14 then
		if self.DEM < 4 then return end
		self.BUOC = 15
		self.DEM = 0
		OfflineLog:info("THU CAU RPC: CallServer(5, G_SubtitleLogic, ClientSetUserCopySubtitle)")
		pcall(function () CallServer(5, "G_SubtitleLogic", "ClientSetUserCopySubtitle", "L_N_01_03", "cau thu tu cau RPC", 0, "") end)
		return
	end

	if self.BUOC == 15 then
		if self.DEM < 4 then return end
		self.BUOC = 16
		self.DEM = 0
		OfflineLog:info("THU CAU RPC: CallServer(5, G_SubtitleLogic, ClientGetCopySubtitle)")
		pcall(function () CallServer(5, "G_SubtitleLogic", "ClientGetCopySubtitle", "L_N_01_03") end)
		return
	end

	if self.BUOC == 16 then
		if self.DEM < 4 then return end
		self.BUOC = 17
		self.DEM = 0
		OfflineLog:info("THU CAU RPC: CallServer(5, G_RedeemCodeLogic, ClientUseRedeemCode)")
		pcall(function () CallServer(5, "G_RedeemCodeLogic", "ClientUseRedeemCode", "TEST123") end)
		return
	end

	if self.BUOC == 17 then
		if self.DEM < 4 then return end
		self.BUOC = 18
		self.DEM = 0
		OfflineLog:info("THU CAU RPC: CallServer(5, G_EquipmentLogic, ClientSynthesisEquipment)")
		pcall(function () CallServer(5, "G_EquipmentLogic", "ClientSynthesisEquipment", 25, 1) end)
		return
	end

	if self.BUOC == 18 then
		if self.DEM < 4 then return end
		self.BUOC = 19
		self.DEM = 0
		OfflineLog:info("THU CAU RPC: CallServer(5, G_EquipmentLogic, ClientAutoIntensifyEquipment)")
		pcall(function () CallServer(5, "G_EquipmentLogic", "ClientAutoIntensifyEquipment", 25, 1) end)
		return
	end

	if self.BUOC == 19 then
		if self.DEM < 4 then return end
		self.BUOC = 20
		self.DEM = 0
		OfflineLog:info("THU CAU RPC: CallServer(5, G_MailLogic, ClientGetMailList)")
		pcall(function () CallServer(5, "G_MailLogic", "ClientGetMailList") end)
		return
	end

	if self.BUOC == 20 then
		if self.DEM < 4 then return end
		self.BUOC = 21
		self.DEM = 0
		OfflineLog:info("THU CAU RPC: CallServer(5, G_AchieveLogic, ClientReachAchieve)")
		pcall(function () CallServer(5, "G_AchieveLogic", "ClientReachAchieve", 1) end)
		return
	end

	if self.BUOC == 21 then
		if self.DEM < 4 then return end
		self.BUOC = 22
		self.DEM = 0
		OfflineLog:info("THU CAU RPC: CallServer(5, G_PotionLogic, ClientBuyPotion)")
		pcall(function () CallServer(5, "G_PotionLogic", "ClientBuyPotion", 1) end)
		return
	end

	if self.BUOC == 22 then
		if self.DEM < 4 then return end
		self.BUOC = 23
		self.DEM = 0
		OfflineLog:info("THU CAU RPC: CallServer(5, G_CavernLogic, ClientRevive)")
		pcall(function () CallServer(5, "G_CavernLogic", "ClientRevive") end)
		return
	end

	if self.BUOC == 23 then
		if self.DEM < 4 then return end
		self.BUOC = 24
		self.DEM = 0
		OfflineLog:info("THU CAU RPC: CallServer(5, G_CavernLogic, ClientResetCavern)")
		pcall(function () CallServer(5, "G_CavernLogic", "ClientResetCavern") end)
		return
	end

	if self.BUOC == 24 then
		if self.DEM < 4 then return end
		self.BUOC = 25
		self.DEM = 0
		OfflineLog:info("THU CAU RPC: CallServer(5, G_RankLogic, ClientGetLevelRank)")
		pcall(function () CallServer(5, "G_RankLogic", "ClientGetLevelRank") end)
		return
	end

	if self.BUOC == 25 then
		if self.DEM < 4 then return end
		self.BUOC = 26
		self.DEM = 0
		OfflineLog:info("THU CAU RPC: CallServer(5, G_RankLogic, ClientGet5HeroPowerRank)")
		pcall(function () CallServer(5, "G_RankLogic", "ClientGet5HeroPowerRank") end)
		return
	end

	if self.BUOC == 26 then
		if self.DEM < 4 then return end
		self.DA_CHAY = true
		local daQuay = nil
		pcall(function ()
			local _, t = G_FortuneWheelLogic:GetUserFortuneWheel()
			daQuay = t and t.HasRollFreeWheelCount
		end)
		OfflineLog:info("THU CAU RPC: HasRollFreeWheelCount = " .. tostring(daQuay))
		OfflineLog:info(string.format(
			"THU CAU RPC: LastFreeDiamondTime sau = %s (dem gui/nhan/hong = %s/%s/%s)",
			tostring(moc()),
			tostring(OfflineNoiServer and OfflineNoiServer.demGui or "?"),
			tostring(OfflineNoiServer and OfflineNoiServer.demNhan or "?"),
			tostring(OfflineNoiServer and OfflineNoiServer.demHong or "?")))
		OfflineLog:info("THU CAU RPC: KET THUC")
		xoaCo()
		return
	end
end

function T:batDau()
	if not coTepCo() then return end
	OfflineLog:info("THU CAU RPC: thay tep co " .. self.TEP_CO)
	if S_CCSchedule == nil then return end
	pcall(function () S_CCSchedule:schedule(self, "tick", 1) end)
end

return OfflineThuCauRpc
