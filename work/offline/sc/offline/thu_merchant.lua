--[[
	offline/thu_merchant.lua — MỞ PANEL "BỘ THAO" (`CUITourMerchant`) ĐỂ ĐO.

	VÌ SAO: kịch bản hướng dẫn mở panel này (`CGuideScheme.lua:3149`), và panel
	gọi `getLeftStandingTime` MỖI KHUNG HÌNH. Khi bảng `GameUserCloudShop` chưa
	có, bản vá `initUserDataFromDB` cũ để chỗ gọi tự gán lại ⇒ lặp vô hạn, log
	phình +500 KB/phút, game đứng (đo 4/11). Đồ thử này mở panel bằng đúng đường
	của `CUIMainBuildingManager.lua:914` để tái hiện mà không phải chơi hướng dẫn.

	BẬT: tạo `thu_merchant.flag` cạnh file lưu. Tự xoá cờ sau khi mở.
]]

require("offline.log")
require("offline.store")

OfflineThuMerchant = OfflineThuMerchant or {}

local T = OfflineThuMerchant

T.TEP_CO = "thu_merchant.flag"
T.DEM = 0
T.CHO = 8            -- nhịp chờ sau khi vào Main (UI dựng xong)
T.DA_CHAY = false

local function thuMuc() return (OfflineStore:path():gsub("[^/]*$", "")) end
local function coTepCo()
	local ok, fp = pcall(io.open, thuMuc() .. T.TEP_CO, "r")
	if ok and fp then fp:close(); return true end
	return false
end
local function xoaCo() pcall(os.remove, thuMuc() .. T.TEP_CO) end

function T:tick()
	if self.DA_CHAY or not coTepCo() then return end
	if not (Offline and Offline.LAN_VAO_GAME and Offline.LAN_VAO_GAME > 0) then return end
	self.DEM = self.DEM + 1
	if self.DEM < self.CHO then return end
	self.DA_CHAY = true
	local ok, err = pcall(function ()
		g_CUINormalDlg:Show("CUITourMerchant", nil)
	end)
	OfflineLog:info("THU MERCHANT: mo panel Bo Thao -> " .. tostring(ok)
		.. (ok and "" or (" (" .. tostring(err) .. ")")))
	xoaCo()
end

function T:batDau()
	if not coTepCo() then return end
	OfflineLog:info("THU MERCHANT: thay tep co " .. self.TEP_CO)
	if S_CCSchedule == nil then return end
	pcall(function () S_CCSchedule:schedule(self, "tick", 1) end)
end

return OfflineThuMerchant
