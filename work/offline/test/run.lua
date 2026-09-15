--[[
	test/run.lua — chạy thử chuỗi vào game của lớp offline trên PC.

	Diễn lại đúng trình tự thật, dựng từ mã client:
	  StartRPC -> OnConnected -> Handshake -> OnServerConnected
	           -> ClientEnterGame -> OnServerEnterGame -> G_DataManager:Init

	  lua test/run.lua        (cần package.path trỏ vào sc/)
]]

require("test.mock")
require("offline.init")

local nPass, nFail = 0, 0

local function check(bCond, strDesc, strDetail)
	if bCond then
		nPass = nPass + 1
		print("  dat   " .. strDesc)
	else
		nFail = nFail + 1
		print("  HONG  " .. strDesc .. (strDetail and ("  -> " .. tostring(strDetail)) or ""))
	end
end

--------------------------------------------- client giả: nhận các lời gọi ngược

G_GameGateway = {}
function G_GameGateway:OnServerConnected()
	self.bConnected = true
	-- client thật: sự kiện này dẫn tới G_GameWorld:EnterGame()
	CallServer(5, "G_GameWorld", "ClientEnterGame")
end

G_GameWorld = {}
function G_GameWorld:OnServerEnterGame(errCode, tUserData, sngData, tOther, tSvrConf)
	self.errCode = errCode
	self.tUserData = tUserData
	self.tSvrConf = tSvrConf
end

G_Login = {}
function G_Login:OnServerLogin(tData)
	self.tLast = tData
end

g_CUIGameRPCManager = { RPC = {} }
function g_CUIGameRPCManager:OnConnected(rpc, bConnected)
	self.bCalled = true
	self.bConnected = bConnected
	if bConnected then
		G_GameGateway.strKey = "k"
		CallServer(3, "", "Handshake", "k", { ClientVersion = "1.26.81485" })
	end
end

------------------------------------------------------------------------ chạy

print("\n=== 1. dang nhap ===")
Mock:reset()
CallServer(1, "G_Login", "ClientLogin", "u", "p", 0)
Mock:tick(1)
check(G_Login.tLast ~= nil, "OnServerLogin duoc goi")
check(G_Login.tLast and G_Login.tLast.err == 0, "err = 0")
check(G_Login.tLast and G_Login.tLast.fun == "OnClientLogin",
      "dinh tuyen bang truong fun", G_Login.tLast and G_Login.tLast.fun)
-- Client doc tData.uid / tData.session viet thuong (CUILogin2.lua:3208, :3211).
check(G_Login.tLast and G_Login.tLast.uid == OfflineBootstrap.UID,
      "phan hoi dang nhap mang uid (viet thuong)", G_Login.tLast and G_Login.tLast.uid)

print("\n=== 2. danh sach may chu ===")
Mock:reset()
CallServer(1, "G_Login", "ClientGetRecomendServers", "u", 1)
Mock:tick(1)
local sl = G_Login.tLast and G_Login.tLast.serverlist
check(sl ~= nil and #sl == 1, "tra ve 1 may chu")
check(sl and sl[1].name == "Offline", "ten may chu", sl and sl[1].name)
-- Client doc danh sach o RecomendList (CUILoginServerList.lua:490).
local rl = G_Login.tLast and G_Login.tLast.RecomendList
check(rl ~= nil and #rl == 1 and rl[1].state == 1,
      "RecomendList co 1 may chu, trang thai IDLE (1)")

print("\n=== 3. ket noi + bat tay + vao game ===")
Mock:reset()
-- StartRPC da bi offline/net.lua ghi de: no xep hang OnConnected
CUIRPCManager.StartRPC(g_CUIGameRPCManager, "1.2.3.4:1001", false,
                       "g_CUIGameRPCManager", "OnConnected", "OnUnConnected", "hb")
Mock:tick(1)   -- OnConnected -> Handshake
Mock:tick(1)   -- OnServerConnected -> ClientEnterGame
Mock:tick(1)   -- OnServerEnterGame

check(g_CUIGameRPCManager.bCalled, "OnConnected duoc goi")
check(g_CUIGameRPCManager.bConnected == true, "bao la da ket noi")
check(G_GameGateway.bConnected == true, "OnServerConnected duoc goi")
check(G_GameWorld.errCode == 0, "OnServerEnterGame err = 0", G_GameWorld.errCode)

local ud = G_GameWorld.tUserData
check(type(ud) == "table", "co khoi userData")
check(ud and ud.GameUserBaseInfo ~= nil, "co bang GameUserBaseInfo")
check(ud and ud.GameUserBaseInfo and ud.GameUserBaseInfo.Level == 1, "Level = 1")
local bi = ud and ud.GameUserBaseInfo or {}
check(bi.Gold == 50000, "Gold = 50000 (GameUserBaseInfoReset)", bi.Gold)
-- Hai so ban truoc tu dat (5000 va 10); cau hinh goc ghi 0 va 6.
check(bi.Diamond == 0, "Diamond lay tu cau hinh goc, khong tu dat", bi.Diamond)
check(bi.LeaderShip == 6, "LeaderShip lay tu cau hinh goc", bi.LeaderShip)
check(bi.Uid == OfflineBootstrap.UID, "danh tinh do lop offline cap", bi.Uid)
-- Client doc ten o CharacterName; thieu thi CUILogin:OnServerEnterGame dung.
check(bi.CharacterName == OfflineBootstrap.NAME, "ten nhan vat o truong CharacterName",
      bi.CharacterName)
local h = ud and ud.GameUserHero and ud.GameUserHero["25"]
check(h ~= nil and h.UserHeroID == 25, "tuong khoi dau tu GameUserHeroReset")
check(ud and ud.GameUserMail and next(ud.GameUserMail) == nil,
      "bang khong co muc Reset thi de rong, khong bia")
check(ud and ud.GameUserSessionData ~= nil, "co bang GameUserSessionData")

local nTables = 0
for _ in pairs(ud or {}) do nTables = nTables + 1 end
-- 37 = 33 bang ban dau + 4 bang client hoi toi bang CHUOI chu khong qua
-- EventManagerTableName, nen truoc do lot luoi (GameUserGuildData,
-- GameUserCloudShop, GameUserStateWar, GameUserRankTitle). Cach tim: quet moi
-- GetUserDataWithName("...") trong 973 file roi tru di danh sach dang co.
--
-- Con 37 chu khong tang, du `TABLES` vua them GameUserEndlessChapter: bang
-- thuoc TU_DUNG CO Y vang mat o khoi nay, de client tu dung hinh dang goc khi
-- thay nil (muc 14 kiem chinh dieu do). Dem duoc no o day la HONG.
check(nTables == 37, "du 37 bang", nTables)
check(ud and ud.GameUserGuildData ~= nil, "co bang GameUserGuildData")

print("\n=== 4. luu va nap lai ===")
OfflineStore:set("GameUserBaseInfo", "Gold", 12345)
check(OfflineStore:save(), "ghi duoc file luu")
OfflineStore.data = nil
check(OfflineStore:load(), "nap lai duoc")
check(OfflineStore:get("GameUserBaseInfo", "Gold") == 12345, "giu nguyen gia tri da sua",
      OfflineStore:get("GameUserBaseInfo", "Gold"))
check(OfflineStore:add("GameUserBaseInfo", "Gold", -345) == 12000, "cong don hoat dong")

print("\n=== 5. API chua co handler ===")
Mock:reset()
CallServer(5, "G_ActivityStock", "ClientBuyStock", "S001", 10, 99)
Mock:tick(1)
check(#Mock.calls == 0, "khong tra loi bua")
local bLogged = false
for _, m in ipairs(Mock.logs) do
	if m:find("THIEU") and m:find("ClientBuyStock") then bLogged = true end
end
check(bLogged, "da ghi vao log la thieu handler")

print("\n=== 6. API nuot lang le ===")
Mock:reset()
local nBefore = #Mock.logs
CallServer(2, "", "Heartbeat")
Mock:tick(1)
check(#Mock.calls == 0, "khong tra loi")
local bNoisy = false
for i = nBefore + 1, #Mock.logs do
	if Mock.logs[i]:find("THIEU") then bNoisy = true end
end
check(not bNoisy, "khong lam nhieu log")

--[[ Từ đây là test hồi quy cho bốn lỗi đã sửa. Cả bốn đều thuộc loại hỏng
	IM LẶNG — không ném lỗi, không ghi log, chỉ là dữ liệu bốc hơi — nên phải
	có test giữ, không thì lần sau tái phát cũng chẳng ai biết. ]]

print("\n=== 7. tham so nil khong lam mat danh sach (net.lua) ===")
Mock:reset()
G_Probe = {}
function G_Probe:OnProbeNil(a, b, c)
	self.tGot = { a, b, c }
end
OfflineRouter:on("ClientProbeNil", function(ctx)
	ctx:call("G_Probe", "OnProbeNil", 1, nil, 3)
end)
CallServer(5, "G_Probe", "ClientProbeNil")
Mock:tick(1)

local got = Mock:find("OnProbeNil")
check(got ~= nil and #got.args == 3, "giu du 3 tham so du co nil o giua",
      got and #got.args or "khong goi duoc")
check(G_Probe.tGot and G_Probe.tGot[3] == 3, "tham so DUNG SAU nil van toi noi",
      G_Probe.tGot and tostring(G_Probe.tGot[3]))
check(G_Probe.tGot and G_Probe.tGot[2] == cjson.null,
      "cho trong thanh cjson.null, dung nhu transport JSON that")

print("\n=== 8. cjson gia phai giong lua-cjson ===")
check(cjson.encode({ b = false }) == '{"b":false}',
      "false khong bien thanh null", cjson.encode({ b = false }))
check(cjson.decode(cjson.encode({ b = false })).b == false,
      "false song sot round-trip")
check(cjson.encode({}) == "{}",
      "bang rong ra {} chu khong phai []", cjson.encode({}))
check(#cjson.decode("[1,null,3]") == 3,
      "null giua mang khong nuot cac phan tu sau no")

print("\n=== 9. defaultHandler do bang cach thu that ===")
local Ctx = OfflineNet.Ctx
G_Fish = {}
function G_Fish:OnCatchFish() end        -- ten dung theo server-spec-vn
OnClientGetData = function() end          -- ten dung theo server-spec-vn

-- quy tac chuoi don thuan cho ra OnCatchFishReq / OnGetData, deu sai
local h1 = Ctx.new(5, "G_Fish", "ClientCatchFishReq"):defaultHandler()
check(h1 == "OnCatchFish", "ClientCatchFishReq -> OnCatchFish", h1)
local h2 = Ctx.new(5, "", "ClientGetData"):defaultHandler()
check(h2 == "OnClientGetData", "ClientGetData -> OnClientGetData", h2)

local nBefore = #Mock.logs
Ctx.new(5, "G_Fish", "ClientKhongAiNghe"):defaultHandler()
local bWarn = false
for i = nBefore + 1, #Mock.logs do
	if Mock.logs[i]:find("khong tim thay handler") then bWarn = true end
end
check(bWarn, "khong tim duoc handler nao thi phai keu, khong duoc im")

print("\n=== 10. gia tri khoi tao la BAN CHEP cua cau hinh ===")
-- Muc 4 da sua Gold trong kho thanh 12000; cau hinh goc phai con nguyen.
check(Mock.config.GameUserBaseInfoReset.Gold == 50000,
      "sua kho khong sua lay cau hinh goc", Mock.config.GameUserBaseInfoReset.Gold)

print("\n=== 11. danh sach hoat dong -> cua vao canh chinh ===")
G_ActivityLogic = {}
function G_ActivityLogic:OnGetAcvitityList(tState, tConfig)
	self.tGot = { tState, tConfig }
end
Mock:reset()
CallServer(5, "G_ActivityLogic", "ClientGetActivityList")
Mock:tick(1)
local ga = G_ActivityLogic.tGot
check(ga ~= nil, "OnGetAcvitityList (ten sai chinh ta cua ban goc) duoc goi")
check(ga and type(ga[1]) == "table" and type(ga[2]) == "table",
      "hai danh sach rong: khong co may chu thi khong co hoat dong")

print("\n=== 12. bang khong co *Reset thi lay hinh dang tu InitData() cua client ===")
--[[ Bảng rỗng KHÔNG vô hại: GetUserDataWithName trả OK với `{}`, client đi
	tiếp rồi chết ở dòng sau (PetData.lua:50 gọi pairs(tData.pets) với pets
	là nil). Vài bộ quản lý tự khai hình dạng ban đầu bằng InitData() —
	đó là định nghĩa của bản gốc, dùng lại được. ]]
PetDataManager = { TABLE_NAME = "GamePet" }
function PetDataManager:InitData()
	return { pets = {}, possess = {}, fight_pet = 0 }
end
G_PetDataManager = setmetatable({ TABLE_NAME = "GamePet" },
	{ __index = PetDataManager })   -- phương thức ở vtable, giống hệ lớp bản gốc

local d = OfflineBootstrap:newUserData()
check(type(d.GamePet) == "table" and type(d.GamePet.pets) == "table"
	and d.GamePet.fight_pet == 0,
	"GamePet lay dung hinh dang tu InitData()",
	type(d.GamePet) == "table" and tostring(next(d.GamePet)) or "?")

-- Bang CO *Reset thi cau hinh goc van thang.
check(d.GameUserBaseInfo ~= nil and d.GameUserBaseInfo.Gold == 50000,
	"bang co *Reset van lay tu cau hinh goc", d.GameUserBaseInfo
		and d.GameUserBaseInfo.Gold)

-- Tra cuu phai di QUA metatable: he lop cua ban goc de phuong thuc trong
-- vtable, rawget luon tra nil. Bo kiem nay giu cho khoi lap lai loi do.
check(rawget(G_PetDataManager, "InitData") == nil,
	"InitData KHONG phai truong tho (nen phai tra qua metatable)")

print("\n=== 13. bang hoi: nguoi choi offline khong o bang nao ===")
--[[ Bang hoi la tinh nang NHIEU NGUOI CHOI. Offline khong co nguoi choi khac
	va khong co kho bang hoi, nen cau tra loi trung thuc la "chua co bang" —
	dung ma GuildNotExist cua chinh ban goc, chu khong dung mot cai bang gia. ]]
ErrorCode = ErrorCode or {}
ErrorCode.Guild = ErrorCode.Guild or { GuildNotExist = 3501 }
G_GuildLogic = {}
function G_GuildLogic:OnGetGuildInfo(nErrCode, tGuildInfo)
	self.tGot = { nErrCode, tGuildInfo }
end
Mock:reset()
CallServer(5, "G_GuildLogic", "ClientGetGuildInfo", 0, 0, 0)
Mock:tick(1)
local g = G_GuildLogic.tGot
check(g ~= nil, "OnGetGuildInfo duoc goi")
check(g and g[1] == ErrorCode.Guild.GuildNotExist,
	"tra dung ma GuildNotExist cua ban goc", g and g[1])
check(g and type(g[2]) == "table",
	"tra bang rong chu khong phai nil (client goi ProcessError len no)")

-- Bang GameUserGuildData phai co trong kho: thieu no thi
-- ClientGuildLogic:GetGuildData thoat ngay va CUIGuildControl:onInit khong
-- chay tiep — ma khong bao gi ca.
local coBang = false
for _, ten in ipairs(OfflineStore.TABLES) do
	if ten == "GameUserGuildData" then coBang = true end
end
check(coBang, "kho giu bang GameUserGuildData")

print("\n=== 14. ai vo tan (EndlessChapter) ===")

--[[ Bang `GameUserEndlessChapter` KHONG co muc `<bang>Reset` trong cau hinh va
	khong lop nao khai `InitData()`, nen hinh dang goc chi co MOT duong: de nó la
	NIL cho `EndlessChapterLogic:GetUserEndlessChapterData`
	(share/EndlessChapterLogic.lua:127) tu goi `craeteUserEndlessChapter()`.

	Tra {} la client tuong da co du lieu, bo qua buoc dung, roi hai man hinh lam
	so hoc tren nil:
	  CUIInfiniteLevelMain.lua:619            FreeChallengesCount + PayChallengesCount(nil) - ChallengesCount(nil)
	  CUIInfiniteLevelFirstPassRewards.lua:211 BestProsees(nil) >= i
]]
local coTrongKho = false
for _, ten in ipairs(OfflineStore.TABLES) do
	if ten == "GameUserEndlessChapter" then coTrongKho = true end
end
check(coTrongKho, "kho giu bang GameUserEndlessChapter (de LUU duoc tien trinh)")
check(OfflineStore.TU_DUNG.GameUserEndlessChapter == true,
	"bang nam trong TU_DUNG (de client tu dung hinh dang goc)")

-- TU_DUNG tac dung bang cach de bang VANG MAT trong khoi userData. Kiem bang
-- chinh ham dung khoi, khong suy doan.
local ud2 = OfflineBootstrap:newUserData()
check(ud2.GameUserEndlessChapter == nil,
	"khoi userData KHONG chua bang nay, de client thay nil ma tu dung")
check(ud2.GameUserGuildData ~= nil,
	"doi chieu: bang thuong VAN co mat trong khoi (phep kiem tren khong vo nghia)")

-- Duong doc cua client di qua day (share_CDataManager.lua:225 -> ban va o
-- offline/init.lua). Phai tra NIL, khong phai {}.
local nErrE, tDataE = CDataManager:initUserDataFromDB("GameUserEndlessChapter")
check(nErrE == 0 and tDataE == nil,
	"initUserDataFromDB tra NIL (khong phai {}) cho bang TU_DUNG", tostring(tDataE))
local nErrT, tDataT = CDataManager:initUserDataFromDB("GameUserChuaBiet")
check(nErrT == 0 and type(tDataT) == "table",
	"bang KHONG thuoc TU_DUNG van tra {} nhu cu")

--[[ Bang xep hang: cung loai voi ClientGetGuildInfo cua bang hoi — can NGUOI
	CHOI KHAC. Tra rong chu khong dung ten gia. Hinh dang {} / 0 / 0 khong phai
	so ta nghi ra: ban goc co san mau y het o CUILeaderboard.lua:1633. ]]
G_EndlessChapterLogic = {}
function G_EndlessChapterLogic:OnGetEndlessChapterRank(tRankList, nSelfRank, nYesterdayRank)
	self.tGot = { tRankList, nSelfRank, nYesterdayRank }
end
Mock:reset()
CallServer(5, "G_EndlessChapterLogic", "ClientGetEndlessChapterRank")
Mock:tick(1)
local r = G_EndlessChapterLogic.tGot
check(r ~= nil, "OnGetEndlessChapterRank duoc goi")
check(r and type(r[1]) == "table" and next(r[1]) == nil,
	"tra danh sach RONG (khong dung ten gia)", r and type(r[1]))
check(r and r[2] == 0 and r[3] == 0, "chua co hang thi 0/0", r and tostring(r[2]))

-- Phai DON LOP "DANG TAI": CUIMain chi ha lop do o OnReceiveResponse
-- (CUIMain.lua:470, than ham :941), nen tra loi bang ham `On...` rieng KHONG du.
local coDon = false
for _, c in ipairs(Mock.calls) do
	if c.func == "OnReciveResponse" then coDon = true end
end
check(coDon, "co goi OnReciveResponse de ha lop 'dang tai'")

--[[ Moi RPC cua ho nay phai TRA LOI. Handler dang ky ma khong tra loi thi client
	treo o lop "dang tai" chu khong bao gi (net.lua:252-262) — do la ly do cac
	RPC thuoc phan may chu van duoc dang ky du chua lam duoc gi. ]]
local DS_RPC = {
	"ClientFight", "ClientInspire", "ClientResetEndlessChapter",
	"ClientCompeleteFight", "ClientGotoNextProsees", "ClientGetEndlessChapterRank",
	"ClientSwap", "ClientStopSwap", "ClientSwapImmediately",
	"ClientBuyChallengesCount", "ClientGetEndlessChapterFirstPrize",
}
for _, ten in ipairs(DS_RPC) do
	check(OfflineRouter:get(ten) ~= nil, "co handler cho " .. ten)
end
for _, ten in ipairs(DS_RPC) do
	Mock:reset()
	local ok = pcall(function()
		CallServer(5, "G_EndlessChapterLogic", ten)
	end)
	Mock:tick(1)
	-- KHONG duoc khong tra loi (client treo, net.lua:252-262). Con SO phan hoi
	-- thi khong nhat thiet la 1: ClientGetEndlessChapterRank tra loi HAI dich —
	-- du lieu cho G_EndlessChapterLogic, roi don lop cho g_CUIGameRPCManager.
	-- Bat bien that la: lop "dang tai" duoc ha DUNG MOT lan.
	check(ok and #Mock.calls >= 1, ten .. " TRA LOI (khong treo client)", #Mock.calls)
	-- Va phai ha lop "dang tai": moi CallX cua ho nay deu phat
	-- OnWaitingForRequest, chi OnReceiveResponse ha duoc (CUIMain.lua:941).
	-- (ClientGotoNextProsees la ngoai le cua ban goc — no bi chu thich mat dong
	-- phat OnWaitingForRequest o ClientEndlessChapterLogic.lua:302 — nhung don
	-- lop o day van dung va vo hai.)
	local nHa = 0
	for _, c in ipairs(Mock.calls) do
		if c.func == "OnReciveResponse" then nHa = nHa + 1 end
	end
	check(nHa == 1, ten .. " ha lop 'dang tai' dung MOT lan (khong hai)", nHa)
end

--[[ 15. Tien trinh ai vo tan phai SONG qua lan khoi dong lai.

	Day la toan bo ly do cua phuong an persistence: bang nam trong `TABLES` (nen
	`syncFromClient` luu duoc) NHUNG cung nam trong `TU_DUNG` (nen luc khoi dong
	no VANG MAT khi chua choi, va client tu dung hinh dang goc). Hai lan doc
	khac nhau di hai duong khac nhau — kiem ca hai. ]]
print("\n=== 15. tien trinh ai vo tan qua lan khoi dong lai ===")

-- Da choi: client dung xong bang, syncFromClient chep ve kho, roi luu.
OfflineStore.data = OfflineBootstrap:newUserData()
OfflineStore.data.GameUserEndlessChapter = {
	BestProsees = 7, ChallengesCount = 3, PayChallengesCount = 1,
	ResetCount = 0, InspireCount = 2, FirstPrizeStates = { ["1"] = true },
}
check(OfflineStore:save(), "luu duoc tien trinh")

OfflineStore.data = nil
check(OfflineStore:load(), "khoi dong lai: nap lai duoc")
check(OfflineBootstrap:ensure() == false, "lan nay la nguoi choi CU, khong tao lai")
local e = OfflineStore.data.GameUserEndlessChapter
check(type(e) == "table", "bang ai vo tan CON trong kho sau khi khoi dong lai")
check(e and e.BestProsees == 7, "tien trinh con nguyen (BestProsees = 7)",
	e and e.BestProsees)
check(e and e.FirstPrizeStates and e.FirstPrizeStates["1"] == true,
	"trang thai da lanh thuong con nguyen")

--[[ Ban luu CU, tao TRUOC khi co tinh nang: khong he co khoa nay. Ham bu trong
	`ensure()` khong duoc nhet {} vao — nhet lai la dung loi :619/:211 quay ve,
	vi {} khac nil nen client bo qua ham dung cua chinh no. ]]
OfflineStore.data = { GameUserBaseInfo = { Gold = 1 } }
OfflineStore:save()
OfflineStore.data = nil
OfflineStore:load()
OfflineBootstrap:ensure()
check(OfflineStore.data.GameUserEndlessChapter == nil,
	"ban luu cu KHONG bi nhet {} (nhet la loi :619/:211 quay lai)",
	tostring(OfflineStore.data.GameUserEndlessChapter))
check(OfflineStore.data.GameUserGuildData ~= nil,
	"doi chieu: bang thuong VAN duoc bu cho ban luu cu")

--[[ 16. Nang cap file luu cu (phien ban dinh dang).

	File luu do ban build TRUOC khi co `TU_DUNG` ghi ra: khong co khoa phien
	ban, va cac bang `TU_DUNG` bi nhiem `{}`. Do la lo hong THAT, do duoc tren
	file luu that: ban ghi co dung 5 truong ma `GetUserEndlessChapterData` va
	(:133-152) va THIEU ca 5 bo dem, nen `CUIInfiniteLevelMain.lua:619` van
	chay so hoc tren nil. Sua `TU_DUNG` khong cuu duoc no, vi khoa da CO MAT
	trong file — client thay khac nil nen bo qua ham dung cua chinh no. ]]
print("\n=== 16. nang cap file luu cu (phien ban dinh dang) ===")

local tHong = {
	SwapBeginTime = 0, FightHeroList = { 25 }, CurrentProsess = 1,
	CurrentState = 0, FirstPrizeStates = {},
}
local function ghiFileKieuCu()
	local fp = io.open(OfflineStore:path(), "w")
	fp:write(cjson.encode({
		GameUserBaseInfo = { Gold = 50000 },
		GameUserEndlessChapter = tHong,
		GameUserCavern = {},
	}))
	fp:close()
end

ghiFileKieuCu()
OfflineStore.data = nil
OfflineStore.phien_ban = nil
check(OfflineStore:load(), "nap duoc file luu kieu cu")
check(OfflineStore.data.GameUserEndlessChapter == nil,
	"bo bang ai vo tan da nhiem {}", tostring(OfflineStore.data.GameUserEndlessChapter))
check(OfflineStore.data.GameUserCavern == nil, "bo luon bang hang (cung thuoc TU_DUNG)")
check(OfflineStore.data.GameUserBaseInfo ~= nil, "bang thuong KHONG bi bo")
check(OfflineStore.phien_ban == OfflineStore.PHIEN_BAN,
	"ghi nhan phien ban moi", tostring(OfflineStore.phien_ban))

-- Khoa phien ban KHONG duoc lot vao khoi du lieu dua cho client: `all()` tra
-- thang `self.data`, ma khoi do di nguyen vao `G_DataManager:Init`.
check(OfflineStore.data[OfflineStore.KHOA_PHIEN_BAN] == nil,
	"self.data sach khoa phien ban")
check(OfflineStore:all()[OfflineStore.KHOA_PHIEN_BAN] == nil,
	"khoa phien ban KHONG lot vao khoi du lieu cua client")

-- File dinh dang HIEN TAI, co tien trinh that: KHONG duoc bo gi.
OfflineStore.data = OfflineBootstrap:newUserData()
OfflineStore.data.GameUserEndlessChapter = { BestProsees = 4 }
check(OfflineStore:save(), "ghi duoc file dinh dang hien tai")
OfflineStore.data = nil
OfflineStore.phien_ban = nil
check(OfflineStore:load(), "nap lai duoc")
local e2 = OfflineStore.data.GameUserEndlessChapter
check(type(e2) == "table" and e2.BestProsees == 4,
	"file dinh dang hien tai: tien trinh KHONG bi bo", e2 and e2.BestProsees)

-- Va sau khi nang cap thi lan luu ke tiep mang phien ban hien tai, nen khong
-- nang cap lai nua.
ghiFileKieuCu()
OfflineStore.data = nil
OfflineStore.phien_ban = nil
OfflineStore:load()
check(OfflineStore:nangCap() == 0, "nang cap lai lan hai khong bo gi (idempotent)")

print(string.format("\n===== dat %d, hong %d =====", nPass, nFail))
os.exit(nFail == 0 and 0 or 1)
