--[[
	offline/thu_vong_quay.lua — TỰ KIỂM `ClientPlayLottery` SAU KHI VÁ LỖI 3/11.

	LỖI ĐÃ ĐO ĐƯỢC (trong game, `chan_doan`): bấm "Miễn phí" ở rương **Hoàng Kim**
	→ client gửi `ClientPlayLottery(5)` (`LOTTERY_TYPE.DIAMOND_FREE`) → handler cũ
	chỉ biết 1/2/3/4/6, log `loai la 5` rồi **IM LẶNG** → lớp "đang tải" không tắt
	→ `CUIManager:131` chặn mọi cú bấm ⇒ màn hình đứng.

	Đồ thử này gọi THẲNG handler (không qua UI) và hỏi ba điều:
	  1. loại 5 có được TRẢ LỜI không (callback `OnServerLotteryFinish`, mode = 5);
	  2. `LastFreeDiamondTime` có được đặt (hồi chiêu của lượt miễn phí kim cương);
	  3. loại LẠ (99) có được trả lỗi thay vì im lặng không.

	BẬT: `vongquay_test.flag` cạnh file lưu; chạy MỘT lần sau khi vào Main.
	Đồ thử này TIÊU một lượt quay miễn phí kim cương — chỉ dùng tài khoản thử.
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineThuVongQuay = OfflineThuVongQuay or {}

local T = OfflineThuVongQuay

T.TEP_CO = "vongquay_test.flag"
T.DEM = 0
T.DA_CHAY = false
T.CHO = 6

local function thuMuc() return (OfflineStore:path():gsub("[^/]*$", "")) end
local function coTepCo()
	local ok, fp = pcall(io.open, thuMuc() .. T.TEP_CO, "r")
	if ok and fp then fp:close(); return true end
	return false
end
local function xoaCo() pcall(os.remove, thuMuc() .. T.TEP_CO) end

local function ctxGia()
	local c = { calls = {} }
	function c:call(obj, f, ...)
		self.calls[#self.calls + 1] = { obj = obj, f = f, args = { ... } }
		return true
	end
	return c
end

local function goi(nType)
	local fn = OfflineRouter:getFor("G_LotteryLogic", "ClientPlayLottery")
	if fn == nil then
		OfflineLog:err("THU VONG QUAY: khong co handler ClientPlayLottery")
		return nil
	end
	local c = ctxGia()
	local ok, e = pcall(fn, c, nType, false)
	if not ok then
		OfflineLog:err("THU VONG QUAY(loai " .. tostring(nType) .. "): handler nem — " .. tostring(e))
		return nil
	end
	return c
end

function T:tick()
	if self.DA_CHAY then return end
	if not coTepCo() then return end
	if not (Offline and Offline.LAN_VAO_GAME and Offline.LAN_VAO_GAME > 0) then return end
	self.DEM = self.DEM + 1
	if self.DEM < self.CHO then return end
	self.DA_CHAY = true

	-- Mốc hồi chiêu TRƯỚC lượt quay (để chứng minh nó ĐỔI).
	local truoc = nil
	pcall(function ()
		local _, t = G_LotteryLogicDataManager:GetUserLotteryData()
		truoc = t and tonumber(t.LastFreeDiamondTime) or nil
	end)

	-- 1. Loại 5 = DIAMOND_FREE phải được TRẢ LỜI.
	local c5 = goi(5)
	if c5 == nil then return xoaCo() end
	local x = c5.calls[#c5.calls]
	if x ~= nil and x.f == "OnServerLotteryFinish" then
		OfflineLog:info(string.format(
			"THU VONG QUAY: OK loai 5 -> OnServerLotteryFinish(mode=%s, tResult=%s, bTest=%s)",
			tostring(x.args[1]), type(x.args[2]), tostring(x.args[3])))
	elseif x ~= nil and x.f == "OnReciveResponse" then
		OfflineLog:err("THU VONG QUAY: HONG loai 5 bi tu choi ma " .. tostring(x.args[3]))
	else
		OfflineLog:err("THU VONG QUAY: HONG loai 5 KHONG duoc tra loi")
	end

	-- 2. Hồi chiêu phải được đặt.
	local sau = nil
	pcall(function ()
		local _, t = G_LotteryLogicDataManager:GetUserLotteryData()
		sau = t and tonumber(t.LastFreeDiamondTime) or nil
	end)
	OfflineLog:info(string.format("THU VONG QUAY: LastFreeDiamondTime %s -> %s",
		tostring(truoc), tostring(sau)))

	-- 3. Loại LẠ phải trả LỖI (không im lặng).
	local c99 = goi(99)
	if c99 ~= nil then
		local y = c99.calls[#c99.calls]
		if y ~= nil and y.f == "OnReciveResponse" and tonumber(y.args[3]) ~= 0 then
			OfflineLog:info("THU VONG QUAY: OK loai 99 -> tra loi ma " .. tostring(y.args[3]))
		else
			OfflineLog:err("THU VONG QUAY: HONG loai 99 khong tra loi / khong co ma")
		end
	end

	OfflineStore:syncFromClient()
	OfflineLog:info("THU VONG QUAY: KET THUC")
	xoaCo()
end

function T:batDau()
	if not coTepCo() then return end
	OfflineLog:info("THU VONG QUAY: thay tep co " .. self.TEP_CO)
	if S_CCSchedule == nil then return end
	pcall(function () S_CCSchedule:schedule(self, "tick", 1) end)
end

return OfflineThuVongQuay
