--[[
	offline/qua_ngay.lua — "VIỆC MÁY CHỦ LÀM MỖI NGÀY" cho lớp offline.

	Máy chủ gốc có một nhịp chạy lúc sang ngày: đặt lại lượt (điểm kim thủ), mở ngày
	kế của quà đăng nhập, … Ở bản client không có một dòng nào làm việc ấy (đo bằng
	grep: `MidasTouchLogic:ResetDaily` 0 chỗ gọi, `SevenDaysGiftLogic:SetDailyLogin`
	0 chỗ gọi). Không làm thay thì các hệ cộng dồn vĩnh viễn: quà 7 ngày đứng ở ngày 1
	mãi mãi, điểm kim thủ chạm trần một lần là khoá luôn.

	Nên tệp này là NHỊP THAY MÁY CHỦ — [MOI], không phải luật chơi. Mọi con số vẫn do
	mã gốc + cấu hình gốc quyết định; ở đây chỉ chọn "khi nào gọi".

	MỐC NGÀY: 5 giờ, đúng `DialyRefreshHour` của bản gốc (`share_gameWorld.lua:29-37`;
	`handlers/nhiem_vu_ngay.lua` dùng cùng mốc). Trước 5 giờ vẫn tính là ngày hôm trước.

	NƠI GỌI: sự kiện `OnEnterGame` của client — KHÔNG gọi trong `Offline:start()`, vì
	lúc ấy `OfflineBootstrap:ensure()` (nơi nạp dữ liệu người chơi) chưa chạy; nó chỉ
	chạy khi handler `ClientEnterGame` tới (`handlers/login.lua:144`). Cùng lý do và
	cùng cách với `offline/luc_chien.lua`.
]]

require("offline.log")
require("offline.store")

OfflineQuaNgay = OfflineQuaNgay or {}

OfflineQuaNgay.MOC_GIO = 5
OfflineQuaNgay.KHOA = "OfflineQuaNgayDay"   -- -> GameUserGlobalData.C_OfflineQuaNgayDay

local function dongBo()
	pcall(function () OfflineStore:syncFromClient() end)
end

--[[ Khoá ngày theo mốc 5 giờ: 20261101. ]]
local function homNay()
	local now = os.time()
	local t = os.date("*t", now)
	if t.hour < OfflineQuaNgay.MOC_GIO then
		now = now - 86400
	end
	local d = os.date("*t", now)
	return d.year * 10000 + d.month * 100 + d.day
end

local function docKhoa()
	if type(_G.G_UserLogic) ~= "table" then return nil end
	local ok, v = pcall(function ()
		local _, x = G_UserLogic:GetClientCommonData(OfflineQuaNgay.KHOA)
		return x
	end)
	if ok then return tonumber(v) end
	return nil
end

--[[ Chạy các việc ngày nếu đã sang ngày mới. Trả true nếu VỪA chạy. ]]
function OfflineQuaNgay:kiem_ngay()
	local key = homNay()
	local cu = docKhoa()
	if cu == key then
		return false
	end

	-- Mỗi việc bọc riêng: một hệ hỏng không được kéo theo hệ kia, và khoá ngày chỉ
	-- được ghi SAU khi cả hai đã có cơ hội chạy.
	local daChay = {}
	for _, ten in ipairs({ "OfflineQua7Ngay", "OfflineKimThu" }) do
		local m = _G[ten]
		if type(m) == "table" and type(m.kiem_ngay) == "function" then
			local ok, err = pcall(function () m:kiem_ngay() end)
			if not ok then
				OfflineLog:err(string.format("qua ngay: %s loi: %s", ten, tostring(err)))
			else
				daChay[#daChay + 1] = ten
			end
		else
			OfflineLog:warn("qua ngay: khong thay " .. ten .. " — bo qua")
		end
	end

	if type(_G.G_UserLogic) == "table" then
		pcall(function ()
			G_UserLogic:SetClientCommonData(OfflineQuaNgay.KHOA, key)
		end)
	end
	dongBo()

	OfflineLog:info(string.format("qua ngay: sang ngay moi (khoa cu %s -> %s), da chay: %s",
		tostring(cu), tostring(key), table.concat(daChay, ", ")))
	return true
end

function OfflineQuaNgay:OnEnterGame(nErrCode)
	if nErrCode ~= nil and nErrCode ~= 0 then
		OfflineLog:warn("qua ngay: EnterGame loi " .. tostring(nErrCode) .. " — bo qua")
		return nil
	end
	return self:kiem_ngay()
end

--[[ Nối vào sự kiện `OnEnterGame` — cùng cơ chế `OfflineLucChien:noi_su_kien`. ]]
function OfflineQuaNgay:noi_su_kien()
	if not G_EventManager then
		OfflineLog:err("qua ngay: khong co G_EventManager — khong noi duoc su kien")
		return false
	end
	G_EventManager:Reg(self, self.OnEnterGame, EventManagerType.Logic,
		EventManagerLogicEvent.OnEnterGame)
	return true
end

return OfflineQuaNgay
