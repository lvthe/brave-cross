--[[
	offline/store.lua — kho dữ liệu người chơi, thay cho database của server.

	Trong bản gốc, server giữ dữ liệu người chơi trong 33 bảng `GameUser*` và
	client nhận nguyên khối đó lúc vào game (ClientGameWorld:initData ->
	G_DataManager:Init). Xem sc/share/share_CDataManager.lua: client đã mang sẵn
	toàn bộ tầng đọc/ghi của server, chỉ có mỗi hàm chạm database là bị rút ruột:

		function CDataManager:initUserDataFromDB(strModuleName)
			return 0, nil      -- <- bản server nạp từ DB ở đây
		end

	Module này chính là cái database đó, chạy tại chỗ và lưu ra một file JSON.
]]

require("offline.log")

OfflineStore = {}

OfflineStore.FILE = "offline_save.json"
OfflineStore.data = nil          -- toàn bộ userData, khoá là tên bảng
OfflineStore.dirty = false

-- 33 bảng dữ liệu người chơi. Danh sách chuẩn lấy nguyên từ
-- EventManagerTableName, sc/share/EventManager.lua:1086 — đây là bảng tra
-- của chính game, không phải suy đoán.
OfflineStore.TABLES = {
	"GameUserBaseInfo", "GameUserSessionData", "GameUserArmyType",
	"GameUserHero", "GameUserEquipment", "GameUserItem",
	"GameUserPotion", "GameUserMail", "GameUserGoods",
	"GameUserDailyTask", "GameUserGlobalData", "GameUserBattleReports",
	"GameUserLottery", "GameLotteryPlayerRecord", "GameUserAchieve",
	"GameUserJob", "GameUserArenaRank", "GameUserMainChapterStatus",
	"GameUserSkill", "GameCityDefendMission", "GameWeeklyFun",
	"GameLoginReward", "GameGodSecret", "GameChampionWelfare",
	"GameMagicWeapon", "GameUserFormation", "GameUserEpicChapter",
	"GameUserStarSoul", "GameScoreCompetitivePlay", "GameNewHandPrivilege",
	"GamePet", "GameGuildTechnology", "GameAnniversary",
}

function OfflineStore:path()
	if LGG_GetSetFilePath then
		return LGG_GetSetFilePath() .. self.FILE
	end
	return self.FILE
end

--------------------------------------------------------------------- nạp / lưu

function OfflineStore:load()
	local fp = io.open(self:path(), "r")
	if not fp then
		OfflineLog:info("chua co file luu, se tao nguoi choi moi")
		return false
	end
	local raw = fp:read("*a")
	fp:close()
	if not raw or raw == "" then
		return false
	end
	local ok, decoded = pcall(cjson.decode, raw)
	if not ok or type(decoded) ~= "table" then
		OfflineLog:err("file luu hong, bo qua: " .. tostring(decoded))
		return false
	end
	self.data = decoded
	OfflineLog:info(string.format("da nap file luu (%d bang)", self:count()))
	return true
end

function OfflineStore:save()
	if not self.data then
		return false
	end
	local ok, raw = pcall(cjson.encode, self.data)
	if not ok then
		OfflineLog:err("khong encode duoc du lieu: " .. tostring(raw))
		return false
	end
	local fp = io.open(self:path(), "w")
	if not fp then
		OfflineLog:err("khong mo duoc file luu de ghi: " .. self:path())
		return false
	end
	fp:write(raw)
	fp:close()
	self.dirty = false
	return true
end

-- Lưu nếu có thay đổi. Gọi định kỳ từ offline/net.lua chứ không lưu sau mỗi
-- thao tác: encode cả khối userData không rẻ.
function OfflineStore:flush()
	if self.dirty then
		return self:save()
	end
	return true
end

function OfflineStore:count()
	local n = 0
	for _ in pairs(self.data or {}) do n = n + 1 end
	return n
end

------------------------------------------------------------------- truy cập

function OfflineStore:table(strName)
	if not self.data then
		return nil
	end
	if self.data[strName] == nil then
		self.data[strName] = {}
	end
	return self.data[strName]
end

function OfflineStore:get(strTable, strField)
	local t = self:table(strTable)
	if not t then return nil end
	if strField == nil then return t end
	return t[strField]
end

function OfflineStore:set(strTable, strField, value)
	local t = self:table(strTable)
	if not t then return false end
	t[strField] = value
	self.dirty = true
	return true
end

-- Cộng dồn một trường số (vàng, kim cương, kinh nghiệm...).
function OfflineStore:add(strTable, strField, nDelta)
	local cur = tonumber(self:get(strTable, strField)) or 0
	self:set(strTable, strField, cur + (tonumber(nDelta) or 0))
	return cur + (tonumber(nDelta) or 0)
end

function OfflineStore:uid()
	return self:get("GameUserBaseInfo", "Uid") or 1
end

-- Toàn bộ khối dữ liệu, đúng hình dạng mà G_DataManager:Init mong đợi.
function OfflineStore:all()
	return self.data
end

local function chepSau(v)
	if type(v) ~= "table" then
		return v
	end
	local t = {}
	for k, x in pairs(v) do
		t[k] = chepSau(x)
	end
	return t
end

--[[ Chép dữ liệu người chơi của CLIENT về kho.

	Vì sao lấy từ client: bản gốc chạy CÙNG luật (sc/share) ở cả hai đầu.
	Client tự áp thay đổi rồi mới báo server — ví dụ CallSetLastArmyLineup
	gọi G_ArmyLogic:SetLastArmyLineup tại chỗ rồi mới CallServer
	(ClientArmyLogic.lua:120-122) — còn server chạy lại luật đó trên bản của
	nó. Ở đây server chạy trong chính máy ảo Lua của client, trên chính bảng
	G_DataManager.userData, nên sau khi luật chạy xong thì bảng đó LÀ trạng
	thái đúng; việc của kho chỉ là giữ lại một bản.

	Chép SÂU: dùng chung bảng thì mọi thay đổi tạm của giao diện sau đó cũng
	lọt vào kho mà không qua handler nào. ]]
function OfflineStore:syncFromClient()
	local dm = rawget(_G, "G_DataManager")
	local u = dm and dm.userData
	if type(u) ~= "table" or not self.data then
		OfflineLog:err("syncFromClient: chua co G_DataManager.userData")
		return false
	end
	for _, name in ipairs(self.TABLES) do
		if u[name] ~= nil then
			self.data[name] = chepSau(u[name])
		end
	end
	self.dirty = true
	return true
end

function OfflineStore:reset()
	self.data = nil
	self.dirty = false
	os.remove(self:path())
	OfflineLog:info("da xoa file luu")
end

return OfflineStore
