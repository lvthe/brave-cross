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

--[[ Phiên bản định dạng FILE LƯU.

	Tăng số này khi Ý NGHĨA của một bảng trong file đổi theo cách không suy ra
	được từ chính nội dung file. Đã có đúng một lần như vậy: bản build TRƯỚC khi
	có `TU_DUNG` nhét `{}` vào những bảng mà client phải tự dựng hình dạng, nên
	file lưu ghi ra một bảng trông y như bảng thật nhưng thiếu hết trường —
	`CUIInfiniteLevelMain.lua:619` chết vì nó. `{}` KHÔNG phân biệt được với một
	bảng thật sự rỗng, nên không "vá tại chỗ" được: chỉ có bỏ bảng đi để
	`GetUserEndlessChapterData` thấy `nil` rồi tự gọi hàm dựng của chính nó.

	Khoá phiên bản nằm TRONG file nhưng KHÔNG nằm trong `OfflineStore.data`:
	`load` bóc nó ra ngoài, `save` đặt tạm rồi gỡ ngay. Phải thế vì `all()` đưa
	NGUYÊN `self.data` cho `G_DataManager:Init` — để lọt vào là client thấy một
	bảng lạ tên `__phien_ban`. ]]
OfflineStore.PHIEN_BAN = 1
OfflineStore.KHOA_PHIEN_BAN = "__phien_ban"
OfflineStore.phien_ban = nil     -- đọc từ file; nil = file không có (bản cũ)

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
	-- Bốn bảng dưới đây client hỏi tới bằng CHUỖI chứ không qua
	-- `EventManagerTableName`, nên lọt lưới khi lập danh sách này. Tìm ra bằng
	-- cách quét mọi `GetUserDataWithName("...")` trong 973 file rồi trừ đi
	-- danh sách trên — còn đúng bốn cái.
	--
	-- Thiếu chúng KHÔNG báo gì: `GetUserDataWithName` rơi xuống
	-- `initUserDataFromDB` (share_CDataManager.lua:225) và trả mã lỗi, rồi
	-- người gọi `goto Exit0` lặng lẽ. Ví dụ `ClientGuildLogic:GetGuildData`
	-- thoát ngay ở đó, nên `CUIGuildControl:onInit` không chạy tiếp.
	"GameUserGuildData",     -- share_GuildLogic.ModuleName, GuildStoreLogic
	"GameUserCloudShop",
	"GameUserStateWar",
	"GameUserRankTitle",
	-- Cũng hỏi bằng chuỗi: `EndlessChapterLogic.ModuleName`
	-- (share/EndlessChapterLogic.lua:23). Có trong `TABLES` là để
	-- `syncFromClient` LƯU được nó — xem `TU_DUNG` ngay dưới, nó là trường hợp
	-- đặc biệt chứ không phải mâu thuẫn.
	"GameUserEndlessChapter",
}

--[[ Bảng mà client TỰ DỰNG hình dạng, nhưng CHỈ khi bảng là NIL.

	Với các bảng này phải để chúng VẮNG MẶT trong khối userData lúc khởi động,
	và `initUserDataFromDB` phải trả NIL chứ không phải {}. Trả {} thì client
	tưởng đã có dữ liệu, bỏ qua hàm dựng của chính nó, rồi màn hình đọc trường
	nil và vỡ.

	Đây là định nghĩa DUY NHẤT — `offline/init.lua` và `offline/bootstrap.lua`
	đều đọc lại chỗ này, để ba nơi không lệch nhau.

	Lưu ý một bảng vẫn có thể nằm trong `TABLES`: `TABLES` quyết định cái gì
	được LƯU, `TU_DUNG` quyết định cái gì KHÔNG được tự sinh ra lúc khởi động.
	Hai việc khác nhau, và `GameUserEndlessChapter` cần cả hai. ]]
OfflineStore.TU_DUNG = {
	-- CavernDataManager:GetUserCavern kiểm `== nil` rồi gọi CraeteUserCavern()
	-- (share/CavernDataManager.lua:42). Trả {} thì CUICavern.lua:971 đọc
	-- `CurrentProgress` nil và vỡ.
	GameUserCavern = true,
	-- EndlessChapterLogic:GetUserEndlessChapterData kiểm `== nil` rồi gọi
	-- craeteUserEndlessChapter() (share/EndlessChapterLogic.lua:127). Trả {} thì
	-- ChallengesCount / PayChallengesCount / ResetCount / BestProsees /
	-- InspireCount ở lại nil, và CUIInfiniteLevelMain.lua:619 với
	-- CUIInfiniteLevelFirstPassRewards.lua:211 vỡ vì làm số học trên nil.
	--
	-- Bảng này KHÔNG có mục `<bảng>Reset` trong cấu hình và không lớp nào khai
	-- `InitData()`, nên hàm dựng của client là đường DUY NHẤT có hình dạng gốc.
	GameUserEndlessChapter = true,
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
	-- Bóc khoá phiên bản RA NGOÀI `self.data` (xem OfflineStore.KHOA_PHIEN_BAN).
	self.phien_ban = tonumber(decoded[self.KHOA_PHIEN_BAN])
	decoded[self.KHOA_PHIEN_BAN] = nil
	self:nangCap()
	OfflineLog:info(string.format("da nap file luu (%d bang)", self:count()))
	return true
end

--[[ Nâng file lưu cũ lên định dạng hiện tại.

	Lệch phiên bản thì chỉ có MỘT việc: bỏ các bảng thuộc `TU_DUNG`. Bản build
	cũ nhét `{}` vào đó, và `{}` là dữ liệu HỎNG mà không suy ra được trường nào
	còn thiếu — đoán danh sách trường là bịa. Bỏ đi thì lần đọc sau client thấy
	`nil` và tự dựng lại bằng chính hàm dựng của nó, tức về đúng định nghĩa gốc.

	Mất tiến trình trong các bảng đó là chấp nhận được: tiến trình ấy vốn đã
	không dùng được, vì mọi màn đọc nó đều vỡ.

	Idempotent: chạy lại khi chưa kịp lưu cũng không bỏ thêm gì (lần hai các
	bảng đã vắng mặt trong bộ nhớ). ]]
function OfflineStore:nangCap()
	local nCu = self.phien_ban
	if nCu == self.PHIEN_BAN then
		return 0
	end
	local n = 0
	for ten in pairs(self.TU_DUNG) do
		if self.data[ten] ~= nil then
			self.data[ten] = nil
			n = n + 1
		end
	end
	self.phien_ban = self.PHIEN_BAN
	self.dirty = true
	OfflineLog:warn(string.format(
		"file luu dinh dang cu (%s) -> %d: bo %d bang thuoc TU_DUNG"
		.. " de client tu dung lai", tostring(nCu), self.PHIEN_BAN, n))
	return n
end

function OfflineStore:save()
	if not self.data then
		return false
	end
	-- Đặt tạm khoá phiên bản rồi GỠ NGAY, để `self.data` luôn sạch (xem
	-- OfflineStore.KHOA_PHIEN_BAN). Gỡ TRƯỚC khi xét `ok` để đường lỗi cũng sạch.
	self.data[self.KHOA_PHIEN_BAN] = self.PHIEN_BAN
	local ok, raw = pcall(cjson.encode, self.data)
	self.data[self.KHOA_PHIEN_BAN] = nil
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
	self.phien_ban = self.PHIEN_BAN
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
	self.phien_ban = nil
	self.dirty = false
	os.remove(self:path())
	OfflineLog:info("da xoa file luu")
end

return OfflineStore
