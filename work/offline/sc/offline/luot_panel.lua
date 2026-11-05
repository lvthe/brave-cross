--[[
	offline/luot_panel.lua — ĐỒ THỬ: mở LẦN LƯỢT mọi lối vào trên cảnh Main,
	mỗi panel 6 nhịp rồi đóng, để biết cái nào mở được / cái nào ném lỗi /
	cái nào thiếu handler (`THIEU` trong `offline.log`).

	Mở bằng ĐÚNG hàm mà nút bấm gọi (`CUIMainBuildingManager:_btnMain*`) — không
	dò toạ độ. Đóng bằng các đường đóng của bản gốc (`g_CUINormalDlg:Close`,
	`g_CUISubDialog:Close`), đúng như watchdog `tu_dong` vẫn làm.

	Tắt: `OfflineLuotPanel.TAT = true` (mặc định TẮT, chỉ bật khi kiểm).
]]

require("offline.log")

OfflineLuotPanel = OfflineLuotPanel or {}

-- ĐÃ CHẠY 28/10 (21/21 panel, 0 THIEU) ⇒ TẮT.
OfflineLuotPanel.TAT = true
OfflineLuotPanel.CHO_SCENE = 6
OfflineLuotPanel.MOI_PANEL = 6

OfflineLuotPanel.DEM = 0
OfflineLuotPanel.I = 0
OfflineLuotPanel.CHO = 0

local function tenCanh()
	if g_CSceneManager == nil then return nil end
	local ok, v = pcall(function () return g_CSceneManager:GetCurrentSceneName() end)
	return ok and v or nil
end

-- {nhãn, hàm mở}
local function danhSach()
	local B = g_CUIMainBuildingManager
	return {
		{ "HopThu", function () B:_btnMailUI() end },
		{ "BXH", function () B:_btnMainLeaderboard() end },
		{ "TMenh", function () B:_btnMainDestiny() end },
		{ "ChienDich", function () B:_btnMainUIAttackActivity() end },
		{ "ShopThanBi", function () B:_btnMainMysteryShop() end },
		{ "MaDong", function () B:_btnMainDen() end },
		{ "LoiDai", function () B:_btnMainArena() end },
		{ "QuanDoan", function () B:_btnGuildUI() end },
		{ "VoHoi", function () B:_btnMainTrials() end },
		{ "ChoDen", function () B:_btnMainStore() end },
		{ "MeRongVien", function () B:_btnBeautyParlor(nil, true) end },
		{ "NghienCuu", function () B:_btnMainResearch(nil, true) end },
		{ "Ruong", function () B:_btnMainLottery() end },
		{ "BinhDoanh", function () B:_btnMainBarrack() end },
		{ "MaThanh", function () B:_btnMainEvilCastle() end },
		{ "BanDo", function () B:_btnMainUIAttack() end },
		{ "DauTruong", function () B:_btnMainContest() end },
		{ "ThuongNhan", function () B:_btnMainTourMerchant() end },
		{ "VanLai", function () B:_btnMainWorldWar() end },
		{ "HopHon", function () g_CUIMainTopTool:onTouchEnd_OnOpenSoulBox(nil, true) end },
		{ "Tui", function () g_CUIMain:onTouchEnd_onBackpackUI(btnBackpackUI, true) end },
	}
end

local function dongHet()
	pcall(function () if g_CUINormalDlg and g_CUINormalDlg.active ~= nil then g_CUINormalDlg:Close() end end)
	pcall(function () if g_CUISubDialog then g_CUISubDialog:Close() end end)
	pcall(function () if g_CUIMultiLayerDialog and g_CUIMultiLayerDialog.active ~= nil then g_CUIMultiLayerDialog:Close() end end)
end

function OfflineLuotPanel:tick()
	if self.TAT or self.XONG then return end
	if tenCanh() ~= "Main" then return end

	self.DEM = self.DEM + 1
	if self.DEM < self.CHO_SCENE then return end

	-- đang mở một panel: đếm đủ nhịp thì đóng rồi sang panel sau
	if self.I > 0 and self.CHO > 0 then
		self.CHO = self.CHO - 1
		if self.CHO == 0 then
			dongHet()
		end
		return
	end

	self.I = self.I + 1
	local ds = danhSach()
	local muc = ds[self.I]
	if muc == nil then
		OfflineLog:info(string.format("luot panel: XONG %d/%d", #ds, #ds))
		self.XONG = true
		return
	end

	local ok, err = pcall(muc[2])
	OfflineLog:info(string.format("panel %02d/%d %s -> %s%s",
		self.I, #ds, muc[1], tostring(ok), ok and "" or ("  LOI: " .. tostring(err))))
	self.CHO = self.MOI_PANEL
end

function OfflineLuotPanel:batDau()
	--[[ 4/11: bật bằng CỜ `luot_panel.flag` cạnh file lưu (không phải sửa mã).
		Cờ tự xoá sau khi bật; `TAT` vẫn là mặc định. ]]
	pcall(function ()
		local p = tostring(OfflineStore:path() or ""):gsub("[^/]*$", "") .. "luot_panel.flag"
		local f = io.open(p, "r")
		if f then
			f:close()
			os.remove(p)
			OfflineLuotPanel.TAT = false
			OfflineLog:info("luot_panel: thay tep co — bat luot quet panel")
		end
	end)
	if self.TAT then
		return
	end
	if S_CCSchedule == nil then
		OfflineLog:err("luot_panel: khong thay S_CCSchedule")
		return
	end
	local ok, err = pcall(function () S_CCSchedule:schedule(self, "tick", 1) end)
	if ok then
		OfflineLog:info("luot_panel: da hen gio (1 s/nhip)")
	else
		OfflineLog:err("luot_panel: hen gio loi: " .. tostring(err))
	end
end

return OfflineLuotPanel
