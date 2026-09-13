--[[
	offline/bootstrap.lua — dựng dữ liệu cho người chơi mới.

	NGUỒN GỐC CỦA TỪNG TÊN. Server thật đã tắt nên không bắt gói được; mọi tên
	bảng và tên trường dưới đây lấy từ chính mã client:

	  * tên bảng   — EventManagerTableName, sc/share/EventManager.lua:1086 (33 bảng)
	  * tên trường — các đăng ký sự kiện dữ liệu
	                 G_EventManager:Reg(obj, fn, EventManagerType.Data, <bảng>, <trường>)
	                 rải khắp codebase, cộng với các trường UserLogic đọc trực tiếp.

	GIÁ TRỊ lấy từ CHÍNH BẢNG CẤU HÌNH của bản gốc. KDBGameCommonConfig có mục
	"<bảng>Reset" cho 10/33 bảng — giá trị server gốc dùng để đặt lại một bảng
	người chơi. Mã server dùng chung (sc/share/) làm đúng như vậy:

	    LotteryLogic:Reset (LotteryLogic.lua:24)
	        G_DataManager:SetUserDataWithName("GameUserLottery",
	            G_ConfigManager:GetCommonConfigWithName("GameUserLotteryReset"))
	    UserLogic:Reset (UserLogic.lua:2194)
	        CopyTabWithSameFiled(<GameUserBaseInfoReset>, baseInfo)

	Mười bảng đó: BaseInfo, GlobalData, ArmyType, Hero, Equipment, Potion,
	Lottery, ArenaRank, BattleReports, Achieve. Người chơi mới ra tay với tướng
	25 và bộ 6 món của nó, 50.000 vàng, 0 kim cương, thống soái 6, thể lực 120.
	Bản trước ở đây TỰ ĐẶT kim cương 5.000 và thống soái 10 — bản gốc ghi 0 và 6.

	(GameUserSkill trong cùng bảng cấu hình KHÔNG phải giá trị khởi tạo: đó là
	định nghĩa kỹ năng, UserLogic.lua:1984 và bốn màn đọc nó như vậy.)

	Chỉ còn ĐẶT những gì server CẤP cho từng tài khoản chứ không nằm trong cấu
	hình: Uid, UserName, DeviceId và bảng phiên. 23 bảng không có mục Reset thì
	để rỗng — không biết server gốc khởi tạo chúng thế nào, và không bịa.
]]

require("offline.log")
require("offline.store")

OfflineBootstrap = {}

-- ĐẶT: danh tính — server gốc cấp cho từng tài khoản, không có trong cấu hình.
OfflineBootstrap.UID = 100001
OfflineBootstrap.NAME = "Offline"

local function chep(v)
	if type(v) ~= "table" then
		return v
	end
	local t = {}
	for k, x in pairs(v) do
		t[k] = chep(x)
	end
	return t
end

--[[ Giá trị khởi tạo của bản gốc cho một bảng, hoặc nil nếu bản gốc không có.

	Phải CHÉP: cấu hình là bảng dùng chung trong bộ nhớ đệm của ConfigManager.
	Không chép thì người chơi tiêu vàng là tiêu luôn vào cấu hình, và lần tạo
	người chơi sau ra số sai. ]]
function OfflineBootstrap:resetOf(strTable)
	if not (G_ConfigManager and G_ConfigManager.GetCommonConfigWithName) then
		return nil
	end
	local ok, t = pcall(G_ConfigManager.GetCommonConfigWithName, G_ConfigManager,
		strTable .. "Reset")
	if ok and type(t) == "table" then
		return chep(t)
	end
	return nil
end

function OfflineBootstrap:baseInfo()
	local t = self:resetOf("GameUserBaseInfo")
	if t == nil then
		OfflineLog:err("khong co GameUserBaseInfoReset — bang cau hinh chua nap?")
		t = {}
	end
	-- Danh tính: server CẤP, không có trong cấu hình. Tên trường lấy từ chỗ
	-- client đọc: tên nhân vật là CharacterName (UserLogicDataManager.lua:209,
	-- sáu file đọc nó) — bản trước ghi 'UserName', trường KHÔNG file nào đọc,
	-- nên GetCharacterName trả lỗi và CUILogin:OnServerEnterGame dừng ở
	-- CUILogin2.lua:3594, không bao giờ tới cảnh chính.
	t.Uid = self.UID                 -- ĐẶT
	t.CharacterName = self.NAME      -- ĐẶT
	t.DeviceId = "offline-device"    -- ĐẶT
	t.CreateTime = os.time()         -- ĐẶT: lúc tạo nhân vật (CUIMainTopTool đọc)
	-- Giới tính nhân vật chính: bản gốc cho người chơi CHỌN lúc tạo, offline
	-- không có bước đó nên ĐẶT. HeroLogic:GetHeroSpriteName trả "PlayerM" khi
	-- Gender bật, "PlayerW" khi tắt -> chữ thứ 7 của tên armature (M/W), quyết
	-- định hình nhân vật chính trên sân. Để FALSE = nữ, khop nhan vat chinh
	-- (co gai) cua ban goc.
	t.Gender = false                 -- ĐẶT: nữ (Player000W03W)
	return t
end

--[[ GameUserGlobalData: bảng cờ/mốc-thời-gian linh tinh, KHÓA-THEO-TÊN phẳng
	(UserDataManager:GetUserGlobalData trả về tUserGlobalData[key]).

	FirstEnterGameTime là MỐC người chơi vào game lần đầu. Bản gốc chỉ ĐỌC nó ở
	client (share_ClothingLogic, share_gameWorld, TimeHeroLogic...): server ghi
	lúc tạo tài khoản, không có trong bảng cấu hình *Reset. Thiếu nó thì
	ClothingLogic:GetChargeWingLeftTime báo "FirstEnterGameTime is nil" mỗi lần
	Main làm mới (đo: hàng chục dòng lỗi khi chụp main.png), và các mốc hoạt
	động tính theo nó (cánh sạc, thẻ tháng, mục tiêu 7 ngày) lệch hết. Đây là
	dấu thời gian, không phải số cân bằng game nên ĐẶT được. ]]
function OfflineBootstrap:globalData()
	local t = self:resetOf("GameUserGlobalData") or {}
	if t.FirstEnterGameTime == nil then
		t.FirstEnterGameTime = os.time()   -- ĐẶT: mốc vào game lần đầu
	end
	return t
end

-- ĐẶT: phiên đăng nhập do server cấp.
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
	mong đợi: một bảng khoá-theo-tên-bảng. ]]
function OfflineBootstrap:newUserData()
	local d, nGoc = {}, 0
	for _, name in ipairs(OfflineStore.TABLES) do
		local t = self:resetOf(name)
		if t ~= nil then
			nGoc = nGoc + 1
		end
		d[name] = t or {}
	end
	d.GameUserBaseInfo = self:baseInfo()
	d.GameUserSessionData = self:sessionData()
	d.GameUserGlobalData = self:globalData()
	OfflineLog:info(string.format("nguoi choi moi: %d/%d bang lay tu cau hinh goc",
		nGoc, #OfflineStore.TABLES))
	return d
end

--[[ Đảm bảo có dữ liệu: nạp từ file, không có thì tạo mới.
	Trả về true nếu vừa tạo người chơi mới. ]]
function OfflineBootstrap:ensure()
	if OfflineStore:load() then
		-- bổ sung bảng mới nếu bản lưu cũ thiếu (khi ta mở thêm tính năng)
		for _, name in ipairs(OfflineStore.TABLES) do
			if OfflineStore.data[name] == nil then
				OfflineStore.data[name] = self:resetOf(name) or {}
				OfflineStore.dirty = true
			end
		end
		-- Bù cho bản lưu cũ tạo trước khi ta seed FirstEnterGameTime.
		local g = OfflineStore.data.GameUserGlobalData
		if type(g) == "table" and g.FirstEnterGameTime == nil then
			g.FirstEnterGameTime = os.time()
			OfflineStore.dirty = true
		end
		-- Bù cho bản lưu cũ dat Gender = true (nam). Doi ve nu de khop nhan vat
		-- chinh ban goc (xem baseInfo).
		local b = OfflineStore.data.GameUserBaseInfo
		if type(b) == "table" and b.Gender ~= false then
			b.Gender = false
			OfflineStore.dirty = true
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
