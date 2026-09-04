--[[
	offline/bootstrap.lua — dựng dữ liệu cho người chơi mới.

	NGUỒN GỐC CỦA TỪNG TÊN. Server thật đã tắt nên không bắt gói được; mọi tên
	bảng và tên trường dưới đây lấy từ chính mã client:

	  * tên bảng   — EventManagerTableName, sc/share/EventManager.lua:1086 (33 bảng)
	  * tên trường — các đăng ký sự kiện dữ liệu
	                 G_EventManager:Reg(obj, fn, EventManagerType.Data, <bảng>, <trường>)
	                 rải khắp codebase, cộng với các trường UserLogic đọc trực tiếp.

	GIÁ TRỊ thì khác: không có cách nào biết server gốc khởi tạo bằng bao nhiêu.
	Các số dưới đây là do ta chọn, đánh dấu bằng ĐẶT. Chúng chỉ cần thoả mãn
	logic client, không cần khớp bản gốc.

	Còn thiếu: 26/33 bảng vẫn rỗng. Cứ chơi rồi đọc offline.log — mỗi lần client
	đòi thứ chưa có, nó hiện ở đó kèm tham số thật.
]]

require("offline.log")
require("offline.store")

OfflineBootstrap = {}

-- ĐẶT: hồ sơ người chơi khởi đầu.
OfflineBootstrap.UID = 100001
OfflineBootstrap.NAME = "Offline"

function OfflineBootstrap:baseInfo()
	local now = os.time()
	return {
		Uid = self.UID,
		UserName = self.NAME,
		DeviceId = "offline-device",

		-- các trường dưới đây đều có mặt trong mã client (xem ghi chú đầu file)
		Level = 1,
		Ex = 0,
		MaxEx = 100,
		Gold = 50000,               -- ĐẶT
		Diamond = 5000,             -- ĐẶT
		Concentrate = 0,
		FatigueValue = 120,         -- ĐẶT: thể lực
		FatigueUpdateTime = now,
		LastLevelUpTime = now,
		LeaderShip = 10,            -- ĐẶT: thống soái
		BarracksLevel = 1,
		ResearchLevel = 1,
		VipLevel = 0,
		AllStar = 0,
		CombatPower = 0,
		UserFightCapacity = 0,
		TournamentScore = 0,
		WorldChampionshipScore = 0,
		GuidState = 0,              -- trạng thái hướng dẫn tân thủ
		GuidId = 0,
	}
end

function OfflineBootstrap:sessionData()
	return {
		Uid = self.UID,
		SessionId = "offline-session",
		LoginTime = os.time(),
		ServerId = 1,
	}
end

--[[ Dựng khối userData đầy đủ.
	Hình dạng phải đúng cái mà ClientGameWorld:initData -> G_DataManager:Init
	mong đợi: một bảng khoá-theo-tên-bảng. Các bảng chưa dùng để rỗng — chính
	CDataManager cũng chấp nhận bảng vắng mặt (GetUserDataWithName sẽ gọi
	initUserDataFromDB, mà bản offline của ta trả về bảng rỗng). ]]
function OfflineBootstrap:newUserData()
	local d = {}
	for _, name in ipairs(OfflineStore.TABLES) do
		d[name] = {}
	end
	d.GameUserBaseInfo = self:baseInfo()
	d.GameUserSessionData = self:sessionData()
	return d
end

--[[ Đảm bảo có dữ liệu: nạp từ file, không có thì tạo mới.
	Trả về true nếu vừa tạo người chơi mới. ]]
function OfflineBootstrap:ensure()
	if OfflineStore:load() then
		-- bổ sung bảng mới nếu bản lưu cũ thiếu (khi ta mở thêm tính năng)
		for _, name in ipairs(OfflineStore.TABLES) do
			if OfflineStore.data[name] == nil then
				OfflineStore.data[name] = {}
				OfflineStore.dirty = true
			end
		end
		return false
	end
	OfflineStore.data = self:newUserData()
	OfflineStore.dirty = true
	OfflineStore:save()
	OfflineLog:info("da tao nguoi choi moi, uid=" .. tostring(self.UID))
	return true
end

return OfflineBootstrap
