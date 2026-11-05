--[[
	offline/handlers/nhiem_vu_ngay.lua — DANH SÁCH NHIỆM VỤ NGÀY: sinh, đặt lại
	theo ngày, và nhận "báo hoàn thành" từ client.

	VÌ SAO PHẢI TỰ SINH: `GameUserDailyTask` trong file lưu là **bảng rỗng** —
	không ai tạo danh sách. `KDBGameDailyTaskConfig.json` chỉ có 8 dòng
	`{TaskId 1..8, Name (午餐/晚宴/关卡/精英关卡/强化/嗑药/活动副本/斗兽者), Award}`;
	**không có điều kiện hoàn thành** và `share/share_dailyTask.lua` chỉ có
	`checkTask1` (luôn đúng). Điều kiện của 7 nhiệm vụ kia nằm ở mã máy chủ.

	⇒ Ba thứ dưới đây là QUYẾT ĐỊNH CỦA LỚP OFFLINE (chủ dự án yêu cầu), KHÔNG
	phải dữ liệu gốc — ghi rõ để sau này không nhầm:
	  1. Danh sách = **đủ 8 nhiệm vụ** trong cấu hình, mỗi nhiệm vụ
	     `{TaskId, State = Doing, AchieveType = TaskId}` (AchieveType gốc do máy
	     chủ gán; ở đây lấy bằng TaskId để UI có khoá hiển thị).
	  2. **Đặt lại theo ngày**: sang ngày mới (mốc 5 giờ, như `DialyRefreshHour`)
	     thì mọi nhiệm vụ về `Doing`; nhiệm vụ đã nhận (`Award`) cũng mở lại.
	  3. **Hoàn thành**: nhận lệnh `ClientComplelteDailyTask(taskId)` của client
	     và đặt `Done` (tin client — trong chế độ offline client chính là game
	     thật, máy chủ gốc cũng chỉ ghi nhận yêu cầu này).

	Nhận thưởng đã có ở `handlers/achieve.lua` (`ClientAwardDailyTask`, cổng
	`State == Done`).
]]

require("offline.log")
require("offline.store")
require("offline.router")

local R = OfflineRouter

OfflineNhiemVuNgay = OfflineNhiemVuNgay or {}

local MOC_GIO = 5          -- DialyRefreshHour của bản gốc

local function homNay()
	local now = os.time()
	local t = os.date("*t", now)
	if t.hour < MOC_GIO then
		now = now - 86400
	end
	local d = os.date("*t", now)
	return d.year * 10000 + d.month * 100 + d.day
end

local function cauHinh()
	local ok, v = pcall(function ()
		return G_ConfigManager:GetDailyTaskConfigWithId(1)
	end)
	-- Chỉ cần biết bảng cấu hình có tồn tại; danh sách thật đọc qua config manager.
	return ok and v ~= nil
end

--[[ Chỉ có hàm tra TỪNG dòng (`GetDailyTaskConfigWithId`), nên dò id 1..50.
	ĐO 28/10: cấu hình có đúng 8 dòng (TaskId 1..8). ]]
local function danhSachCauHinh()
	local ds = {}
	for id = 1, 50 do
		local ok, v = pcall(function ()
			return G_ConfigManager:GetDailyTaskConfigWithId(id)
		end)
		if ok and v ~= nil then
			ds[#ds + 1] = id
		end
	end
	return ds
end

local function damBaoDanhSach()
	if not cauHinh() then
		return 0, "thieu KDBGameDailyTaskConfig"
	end

	local idList = danhSachCauHinh()
	if #idList == 0 then
		return 0, "khong doc duoc danh sach TaskId"
	end

	local ds, soMoi = nil, 0
	local okLay, bang = pcall(function ()
		return G_DataManager:getDailyTaskList()
	end)
	if not okLay or type(bang) ~= "table" then
		return 0, "khong lay duoc GameUserDailyTask"
	end
	ds = bang

	local daCo = {}
	for _, t in ipairs(ds) do
		if type(t) == "table" then
			daCo[tonumber(t.TaskId)] = t
		end
	end

	for _, id in ipairs(idList) do
		local t = daCo[id]
		if t == nil then
			ds[#ds + 1] = { TaskId = id, AchieveType = id, State = AchieveState.Doing }
			soMoi = soMoi + 1
		elseif tonumber(t.AchieveType) == nil then
			t.AchieveType = id
		end
	end

	-- Đặt lại theo ngày
	local g = nil
	pcall(function ()
		local _, x = G_UserLogic:GetUserGlobalData()
		g = x
	end)
	local homNayS = homNay()
	if g ~= nil and tonumber(g.DailyTaskDay) ~= homNayS then
		for _, t in ipairs(ds) do
			if type(t) == "table" then
				t.State = AchieveState.Doing
			end
		end
		g.DailyTaskDay = homNayS
		soMoi = soMoi + 1000      -- đánh dấu "có đặt lại"
	end

	pcall(function () OfflineStore:syncFromClient() end)
	return #ds, soMoi
end

-- Sinh danh sách ngay khi vào cảnh Main (hàm gọi từ đồ thử hoặc init).
function OfflineNhiemVuNgay:damBao()
	local n, soMoi = damBaoDanhSach()
	if n == nil then
		OfflineLog:warn("nhiem vu ngay: " .. tostring(soMoi))
		return false
	end
	OfflineLog:info(string.format("nhiem vu ngay: %d nhiem vu (moi/dat lai: %s)",
		n, tostring(soMoi)))
	return true
end

--[[ Sinh danh sách + đặt lại theo ngày NGAY khi cảnh Main dựng xong (một lần
	mỗi phiên). Đây là việc "máy chủ" chứ không phải đồ thử, nên luôn bật. ]]
local CHO_MAIN = 6
local demCho = 0

function OfflineNhiemVuNgay:tick()
	if self.XONG then return end
	local canh = nil
	pcall(function () canh = g_CSceneManager:GetCurrentSceneName() end)
	if canh ~= "Main" then return end
	demCho = demCho + 1
	if demCho < CHO_MAIN then return end
	self.XONG = true
	self:damBao()
end

function OfflineNhiemVuNgay:batDau()
	if S_CCSchedule == nil then return end
	pcall(function () S_CCSchedule:schedule(self, "tick", 1) end)
end

--[[ Client báo "nhiệm vụ đã xong". Máy chủ thật cũng chỉ đánh dấu rồi trả OK. ]]
R:on("ClientComplelteDailyTask", function(ctx, taskId)
	local nErr = 0
	local t = nil
	pcall(function ()
		t = G_DataManager:getDailyTaskWithId(taskId)
	end)
	if type(t) ~= "table" then
		nErr = 1
	else
		t.State = AchieveState.Done
		OfflineStore:syncFromClient()
		OfflineLog:info("nhiem vu ngay " .. tostring(taskId) .. ": danh dau hoan thanh")
	end
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", nErr, {})
end)

OfflineNhiemVuNgay:batDau()

return true
