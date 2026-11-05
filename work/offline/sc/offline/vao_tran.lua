--[[
	offline/vao_tran.lua — tự vào MỘT TRẬN sau khi đăng nhập xong, để gắn
	trace Frida mà không phải chạm màn hình.

	Vì sao cần: máy ảo ARM này chậm, mỗi phép `screencap`/`tap` đều đắt, và
	`system_server` đã hai lần bị watchdog giết giữa lượt (xem
	GHI-CHU-TRACE-2026-10-23.md). Đường bấm UI để vào ải là chỗ dễ vỡ nhất.

	Hai đường có sẵn trong CHÍNH mã gốc (không phải đồ tôi bịa):

	  * `g_CUIGame:Test()`   (sc/user/Battle/CUIGame.lua:157) — tự dựng 10 đội
	    `tArmys[1..10]`, rồi `RepaleceScene("Battle", nil, tChapterInfo, nil, {})`
	    với `ChapterKey = "L_N_01_01"`. KHÔNG cần dữ liệu máy chủ.
	  * `QuickArena()`        (sc/game_arena.lua:124) — đường đấu trường, cần
	    `g_CArena` và đội hình của người chơi (lớp offline phải trả đội hình).

	Mặc định dùng `Test` vì nó khép kín. Đổi bằng `OfflineVaoTran.LOAI = "arena"`.

	Tắt: `OfflineVaoTran.TAT = true` trước khi nạp, hoặc bỏ hai dòng cuối
	`offline/init.lua`.
]]

require("offline.log")

OfflineVaoTran = OfflineVaoTran or {}

OfflineVaoTran.TAT = true     -- TẠM TẮT: đường Test() làm sập libhoudini (xem GHI-CHU)
OfflineVaoTran.LOAI = "test"   -- "test" | "arena"
OfflineVaoTran.CHO_SCENE = 8   -- giây chờ cho cảnh Main dựng xong
OfflineVaoTran.DEM = 0
OfflineVaoTran.DA_VAO = false

local function tenCanh()
	if g_CSceneManager == nil then return nil end
	local ok, v = pcall(function () return g_CSceneManager:GetCurrentSceneName() end)
	return ok and v or nil
end

local function dangNhapXong()
	if OfflineTuDong ~= nil then
		return (OfflineTuDong.BUOC or 0) >= 2
	end
	-- Không nạp tu_dong (ví dụ đường LDPlayer: hook Kull SDK đã tự đăng nhập):
	-- coi như xong khi RPC manager đã có uid.
	local ok, uid = pcall(function () return g_CUIGameRPCManager:GetUid() end)
	return ok and uid ~= nil
end

local function vaoTest()
	if g_CUIGame == nil or type(g_CUIGame.Test) ~= "function" then
		return false, "khong thay g_CUIGame:Test"
	end
	g_CUIGame:Test()
	return true
end

-- Bản sao của QuickArena (sc/game_arena.lua:124-140) — tệp ấy là tệp thử của
-- bản gốc, tự gọi QuickArena() ngay khi nạp nên KHÔNG nạp nó vào game thật.
local function vaoArena()
	if g_CUIGame == nil or g_CSceneManager == nil then
		return false, "thieu g_CUIGame/g_CSceneManager"
	end
	g_CUIGame.bQuickResult = true
	g_CUIGame.fnInitCallBack = function (obj, ...)
		if g_CArena ~= nil then
			pcall(function () g_CArena:sngSetNoDraw(true) end)
		end
		local t = {}
		t.ChapterType = 9999
		t.ChapterScenes = 9
		t.MainChapter = 1
		t.SubChapter = 6
		t.ChapterGameTime = 10000
		t.ChapterKey = "L_XSGK"
		g_CUIGame.test = true
		g_CUIGame:StartBattle(nil, t)
	end
	g_CSceneManager:RepaleceScene("Battle", nil, { ChapterType = 9999, ChapterScenes = 9 })
	return true
end

function OfflineVaoTran:tick()
	if self.TAT or self.DA_VAO then return end
	if not dangNhapXong() then return end

	local canh = tenCanh()
	if canh ~= "Main" then return end

	self.DEM = self.DEM + 1
	if self.DEM < self.CHO_SCENE then return end

	self.DA_VAO = true
	local ham = (self.LOAI == "arena") and vaoArena or vaoTest
	local ok, why = pcall(ham)
	if ok then
		OfflineLog:info("vao_tran: da goi " .. tostring(self.LOAI) .. " -> " .. tostring(why))
	else
		OfflineLog:err("vao_tran: goi " .. tostring(self.LOAI) .. " loi: " .. tostring(why))
	end
end

function OfflineVaoTran:batDau()
	if self.TAT then
		OfflineLog:info("vao_tran: TAT, khong tu vao tran")
		return
	end
	if S_CCSchedule == nil then
		OfflineLog:err("vao_tran: khong thay S_CCSchedule")
		return
	end
	local ok, err = pcall(function () S_CCSchedule:schedule(self, "tick", 1) end)
	if ok then
		OfflineLog:info("vao_tran: da hen gio tu vao tran (" .. tostring(self.LOAI) .. ", 1 s)")
	else
		OfflineLog:err("vao_tran: hen gio loi: " .. tostring(err))
	end
end

return OfflineVaoTran
