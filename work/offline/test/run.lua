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
-- RecomendList phai RONG: moi muc con bi doc nhu HO SO NHAN VAT
-- (CUILoginServerList.lua:849-944 -> CUITavern:GetHeroExPercentage), thieu
-- Level/Ex la "KDebug: Arg must be number!" va vo ca luong dang nhap —
-- da gap that tren LDPlayer 2026-10-26. May chu that chi dua vao day may chu
-- ma tai khoan DA co nhan vat; tai khoan offline moi toanh thi khong co.
local rl = G_Login.tLast and G_Login.tLast.RecomendList
check(rl ~= nil and next(rl) == nil,
      "RecomendList rong (tai khoan moi chua co nhan vat)", rl and #rl)

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
-- 38 ten trong `TABLES`, nhung khoi userData chi co 36: HAI bang thuoc `TU_DUNG`
-- CO Y vang mat o khoi nay (GameUserEndlessChapter, GameUserCloudShop), de
-- client thay nil ma tu dung hinh dang goc (muc 14 kiem chinh dieu do). Dem
-- duoc chung o day la HONG.
--
-- 38 = 33 bang ban dau + 4 bang client hoi toi bang CHUOI chu khong qua
-- EventManagerTableName, nen truoc do lot luoi (GameUserGuildData,
-- GameUserCloudShop, GameUserStateWar, GameUserRankTitle) + GameUserEndlessChapter.
-- Cach tim 4 bang kia: quet moi GetUserDataWithName("...") trong 973 file roi
-- tru di danh sach dang co.
--
-- LUU Y: GameUserCavern thuoc TU_DUNG (client tu dung khi nil) va DA vao TABLES
-- ngay 28/10 de luu duoc hang Ma Khu — nhung luc khoi dong no VAN vang mat, nen
-- KHONG tinh vao so bang.
--
-- 38 (28/10) = 36 ban dau + GameUserFortuneWheel (vong quay) + DailyTaskList
-- (danh sach nhiem vu ngay — KHONG phai GameUserDailyTask, xem
-- share_CDataManagerPrivate.lua:975). Them vao TABLES thi khoi userData moi co.
--
-- 39 (31/10) = 38 + **GameUserBuilding**: `offline/nha_cua.lua:330-334` TỰ thêm
-- bang nay vao `OfflineStore.TABLES` luc nạp (nó là hệ VIẾT MỚI 30/10). Đây là
-- phép kiểm ĐẦU TIÊN bắt được việc ấy: bộ thử PC chạy trên `sc/offline`, mà cây
-- ấy đã TỤT LẠI sau 28/10 (chỉ `deploy/plain` được sửa) nên suốt 30–31/10
-- `run_tests.py` đo một cây CŨ và vẫn XANH. Sau khi đồng bộ hai cây (31/10) nó
-- ĐỎ đúng một phép — chính phép này.
-- 40 (31/10, tiếp) = 39 + **GameUserHeroPractice**: đo trong game thấy handler
-- gán tướng chạy đúng (callback `Statistics.OnPracticeHero`) nhưng file lưu
-- KHÔNG có khoá ⇒ `PracticeStates` mất sau mỗi lần vào game. Đã thêm vào
-- `OfflineStore.TABLES` (`store.lua`). Bảng KHÔNG thuộc `TU_DUNG` — client tự
-- dựng `PracticeStates = {}` khi thiếu.
-- 39 (31/10, tiếp 6) = 40 − **GameUserStarSoul**: đo trong game thấy panel Chiêm
-- Tinh gửi `G_StarSoulProtocol.ClientGetReq` mà lớp offline không trả lời, nên
-- `_isServerInited` mãi false và panel mở nửa vời. `GetUserStarSoulData` chỉ tự
-- lành khi bảng là NIL (không lành với `{}`), nên bảng phải VẮNG MẶT lúc khởi
-- động ⇒ thêm vào `TU_DUNG` (vẫn ở `TABLES` để lưu được sau khi client dựng).
-- 40 (3/11, CẦU RPC) = 39 + **GameUserSubtitle**: nhóm `G_SubtitleLogic` đi qua cầu
-- thì phụ đề nằm ở bảng này (`phu_de.ts`, Mốc 49). Lớp offline tự lưu ở
-- `ClientCommonData`, nên trước đó bảng không cần có; thêm vào `TABLES` để
-- `syncFromClient` lưu được (thiếu thì phụ đề qua cầu MẤT sau khi mở lại).
check(nTables == 40, "du 40 bang", nTables)
check(OfflineStore.TU_DUNG.GameUserStarSoul == true,
      "GameUserStarSoul thuoc TU_DUNG (client tu dung InitData)")
check(ud and ud.GameUserStarSoul == nil,
      "khoi userData KHONG chua GameUserStarSoul, de client thay nil")
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

--[[ Cửa hàng Vân Du (`GameUserCloudShop`) — cùng loại, nhưng lý do khác hẳn.

	`Setting.lua` của CHÍNH BẢN GỐC (kênh vi) không định nghĩa
	`IS_OPEN_TOURMERCHANT`, và cả 5 chỗ đọc nó đều là `if IS_OPEN_TOURMERCHANT
	then` — nên tính năng này TẮT trong bản ta dựng lại. Mã gốc nói thẳng ra
	điều đó (ClientTourMerchantLogic.lua:112, chú thích của rong34, 2016:
	"nếu tính năng chưa mở thì GameUserCloudShop không có giá trị").

	Trả {} thì `{}` KHÁC nil: `getLeftStandingTime` (:57) đi vào nhánh else và
	làm số học trên `ComeTime` nil. Lỗi đó không chỉ là một dòng nhật ký — nó
	ném ra giữa `CUIMain:postOnMainShowEvent` (qua OnMainShowUI ->
	refreshDyncBuilding -> isLeftStandingTime), nên `g_CUILevelTarget:show()`
	và `self:Tick()` phía sau không bao giờ chạy (CUIMain.lua:314-324). ]]
local coCloud = false
for _, ten in ipairs(OfflineStore.TABLES) do
	if ten == "GameUserCloudShop" then coCloud = true end
end
check(coCloud, "kho giu bang GameUserCloudShop (de LUU, nếu client có điền)")
check(OfflineStore.TU_DUNG.GameUserCloudShop == true,
	"bang nam trong TU_DUNG (tinh nang TAT trong ban nay)")

local ud3 = OfflineBootstrap:newUserData()
check(ud3.GameUserCloudShop == nil,
	"khoi userData KHONG chua bang cua hang Van Du, de client thay nil")

--[[ Hợp đồng đọc: mã 0 (KHÔNG phải mã lỗi — mã khác 0 thì
	`KDebug.ProcessError(bRetCode)` đúng và client `goto Exit0`).

	4/11 (tiếp 9) ĐỔI KỲ VỌNG nil → `{ComeTime = 0}`: bản `nil` làm
	`GetUserDataWithName` (share_CDataManager.lua:225) KHÔNG cache được (nil),
	nên cảnh Main gọi lại mỗi khung hình — đo trong game ≥20 lần/giây. Năm chỗ
	đọc `GameUserCloudShop` cho cùng kết quả với nhánh nil của client; khác biệt
	duy nhất là trả bảng thì cache được. Bảng KHÔNG thuộc HINH_AN_TOAN vẫn nil. ]]
local nErrC, tDataC = CDataManager:initUserDataFromDB("GameUserCloudShop")
check(nErrC == 0 and type(tDataC) == "table" and tDataC.ComeTime == 0,
	"initUserDataFromDB tra (0, {ComeTime = 0}) cho bang cua hang Van Du",
	tostring(nErrC) .. ", " .. tostring(tDataC))
local nErrN, tDataN = CDataManager:initUserDataFromDB("GameUserEndlessChapter")
check(nErrN == 0 and tDataN == nil,
	"bang TU_DUNG KHONG co HINH_AN_TOAN van tra nil (khong doi)", tostring(tDataN))

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
--[[ Tra theo ĐÚNG bộ ba (obj, func) như `net.lua` làm: `ClientCompeleteFight`
	có ở HAI hệ (G_EndlessChapterLogic và G_CavernLogic), nên handler của họ này
	đăng ký có tiền tố obj — `OfflineRouter:get(ten)` trơ sẽ không thấy. ]]
for _, ten in ipairs(DS_RPC) do
	check(OfflineRouter:getFor("G_EndlessChapterLogic", ten) ~= nil,
		"co handler cho " .. ten)
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

--[[ 14b. Thuong thong ai LAN DAU (ClientGetEndlessChapterFirstPrize).

	Day la muc DUY NHAT cua ho ai vo tan lam duoc TRON (xem chu thich dau
	offline/handlers/endless.lua), nen phai kiem THAT chu khong chi kiem "co tra
	loi" nhu vong DS_RPC o tren.

	Bon manh, ca bon deu la ma goc:
	  1. dieu kien   `BestProsees >= n` va `FirstPrizeStates[n]` chua bat
	                 (share/EndlessChapterLogic.lua:127-182)
	  2. ma loi      `ErrorCode.EndlessChapter` (share/error.lua:605-610)
	  3. phat thuong `G_PrizeLogic:GetPrizeWithID(113000+n)` roi
	                 `G_ChapterLogic:SetDataWithPrizeList(PrizeContent, 1, ...)`
	                 — dung cap ham ma share_ChapterLogic.lua:2236-2238 dung cho
	                 thuong chien dich
	  4. dong bo dau "da nhan" xuong kho

	Client gia o day chep DUNG hai ham ma handler dua vao (chep, khong suy dien):
	  * `G_DataManager:ChangeUserData` -> `WriteToTable`
	    (share_CDataManager.lua:334, :395-421): bang VANG MAT trong `userData`
	    ma khoa khong phai "Table_Add" thi tra **false**. Do chinh la dieu kien
	    that cua duong ghi.
	  * `G_EndlessChapterLogic:GetUserEndlessChapterData`
	    (share/EndlessChapterLogic.lua:111-165): lan dung DAU di
	    `craeteUserEndlessChapter` -> `setUserEndlessChapter` ->
	    `PostDataEvent(copyTab(t), ..., "Table_Add")`, nen DataManager giu mot
	    BAN SAO con `self.UserEndlessChapter` giu BAN GOC; tu lan thu hai tra
	    thang ban trong DataManager. Kiem ca hai lan vi hai lan di hai duong khac
	    nhau — do la cho de mat phan thuong nhat.

	So 113000+n khong phai suy ra: `KDBGameCommonConfig.EndlessChapterFirstPrize
	Config` la chuoi `{"1":113001,...,"250":113250}` — do lai: 250 muc, va
	113000+n dung cho CA 250 muc. ]]

-- copyTab cua ban goc (share/public.lua:112) — chep SAU.
local function copyTab(st)
	local t = {}
	for k, v in pairs(st or {}) do
		t[k] = (type(v) == "table") and copyTab(v) or v
	end
	return t
end

--[[ CO Y dat hai ma KHAC ban goc: phep kiem phai chung minh handler DOC
	`ErrorCode` chu khong nhung so. So that (NotPass 4101, HasGetFristPrize
	4102) chi nam o share/error.lua:605-610, khong nam trong lop offline. ]]
local MA_NOT_PASS, MA_DA_LAY = 7411, 7412
ErrorCode = { EndlessChapter = { NotPass = MA_NOT_PASS, HasGetFristPrize = MA_DA_LAY } }

-- ChangeUserData cua ban goc, rut gon con nhanh ma bang nay di (nhanh cuoi cua
-- ChangeUserDataWithDataMap -> WriteToTable). Guard cua ban goc la
-- KDebug.ProcessNotTable/NotString; o day khong co KDebug nen kiem bang nil.
G_DataManager = { userData = {}, soLanGhi = 0 }
function G_DataManager:ChangeUserData(strBang, tDoi, strKhoa)
	if strBang == nil or tDoi == nil or strKhoa == nil then return false end
	if strKhoa == "Table_Replace" then
		self.userData[strBang] = tDoi
		self.soLanGhi = self.soLanGhi + 1
		return true
	end
	if self.userData[strBang] == nil then
		if strKhoa ~= "Table_Add" then return false end
		self.userData[strBang] = {}
	end
	local t = self.userData[strBang]
	for k, v in pairs(tDoi) do t[k] = v end      -- MergeTab (share/public.lua:134)
	t[strKhoa] = tDoi[strKhoa]
	self.soLanGhi = self.soLanGhi + 1
	return true
end

-- Them phan doc du lieu vao chinh bang da co o muc 14 (giu lai `tGot` cua phep
-- kiem bang xep hang).
G_EndlessChapterLogic.ModuleName = "GameUserEndlessChapter"
G_EndlessChapterLogic.ProsessState = { Prepared = 0, Passed = 1 }
function G_EndlessChapterLogic:craeteUserEndlessChapter()
	return {
		CurrentProsess = 1, ChallengesCount = 0, PayChallengesCount = 0,
		ResetCount = 0, IsSweeping = false, LastSweepTime = 0, BestProsees = 0,
		InspireCount = 0, SwapBeginTime = 0, MysteriousLevel = nil,
		FightHeroList = {25}, CurrentState = self.ProsessState.Prepared,
		FirstPrizeStates = {},
	}
end

function G_EndlessChapterLogic:GetUserEndlessChapterData()
	if self.UserEndlessChapter ~= nil then
		return true, self.UserEndlessChapter
	end
	local t = G_DataManager.userData[self.ModuleName]
	if t == nil then
		t = self:craeteUserEndlessChapter()
		-- setUserEndlessChapter: cache BAN GOC roi day BAN SAO sang DataManager
		-- qua PostDataEvent(..., "Table_Add").
		self.UserEndlessChapter = t
		G_DataManager.userData[self.ModuleName] = copyTab(t)
	end
	if t.SwapBeginTime == nil then t.SwapBeginTime = 0 end
	if t.FightHeroList == nil then t.FightHeroList = {25} end
	if t.CurrentProsess == nil then t.CurrentProsess = 1 end
	if t.CurrentState == nil then t.CurrentState = self.ProsessState.Prepared end
	if t.FirstPrizeStates == nil then t.FirstPrizeStates = {} end
	self.UserEndlessChapter = t
	return true, t
end

G_PrizeLogic = { lanHoi = {} }
-- Hai tang co cau hinh trong phep kiem nay. Tang khac tra false, dung nhu
-- GetPrizeWithID khi config khong co (share/PrizeLogic.lua:127-136).
G_PrizeLogic.CoSan = {
	[113001] = { { PrizeResType = 3, PrizeResId = 0, PrizeValue = 500 } },
	[113002] = { { PrizeResType = 3, PrizeResId = 0, PrizeValue = 600 } },
}
function G_PrizeLogic:GetPrizeWithID(nPrizeID)
	table.insert(self.lanHoi, nPrizeID)
	local c = self.CoSan[nPrizeID]
	if c == nil then return false end
	return true, { PrizeContent = c }
end

G_ChapterLogic = { lanPhat = {} }
function G_ChapterLogic:SetDataWithPrizeList(tPrizeList, nCountMultiple, strPrizeFrom)
	table.insert(self.lanPhat, { tPrizeList, nCountMultiple, strPrizeFrom })
	return true
end

-- Dung lai tu dau: chua co gi trong DataManager, chua co ban cache trong logic.
local function dat_lai(tDuLieu)
	G_DataManager.userData = {}
	G_DataManager.soLanGhi = 0
	G_EndlessChapterLogic.UserEndlessChapter = nil
	G_PrizeLogic.lanHoi = {}
	G_ChapterLogic.lanPhat = {}
	if tDuLieu ~= nil then
		G_DataManager.userData.GameUserEndlessChapter = tDuLieu
	end
	Mock:reset()
end

-- Ma loi cua lan tra loi vua roi: ctx:call -> OnReciveResponse("", "", ma, {}).
local function ma_tra_loi()
	local c = Mock:find("OnReciveResponse")
	return c and c.args[3] or nil
end

print("\n=== 14b. thuong thong ai LAN DAU ===")

-- (1) Chua thong tang do thi tra ma NotPass va KHONG phat thuong.
dat_lai({ BestProsees = 3, FirstPrizeStates = {} })
CallServer(5, "G_EndlessChapterLogic", "ClientGetEndlessChapterFirstPrize", 5)
Mock:tick(1)
check(ma_tra_loi() == MA_NOT_PASS, "chua thong tang 5: tra dung ma NotPass",
	tostring(ma_tra_loi()))
check(#G_PrizeLogic.lanHoi == 0, "chua thong: khong doc cau hinh thuong", #G_PrizeLogic.lanHoi)
check(#G_ChapterLogic.lanPhat == 0, "chua thong: khong phat thuong", #G_ChapterLogic.lanPhat)
check(G_DataManager.userData.GameUserEndlessChapter.FirstPrizeStates["5"] == nil,
	"chua thong: KHONG danh dau da nhan")

-- (2) Nguoi choi MOI (bang chua co), du dieu kien, xin lan dau.
dat_lai(nil)
local _, td = G_EndlessChapterLogic:GetUserEndlessChapterData()
check(type(td) == "table" and td.BestProsees == 0,
	"nguoi choi moi: client tu dung hinh dang goc", td and tostring(td.BestProsees))
local tTrongKho = G_DataManager.userData.GameUserEndlessChapter
check(tTrongKho ~= nil and tTrongKho ~= td,
	"lan dung DAU: DataManager giu BAN SAO, khac ban client dang giu")
td.BestProsees = 5      -- tran danh xong, chinh client cap nhat truong nay
Mock:reset()
CallServer(5, "G_EndlessChapterLogic", "ClientGetEndlessChapterFirstPrize", 1)
Mock:tick(1)
check(G_PrizeLogic.lanHoi[1] == 113001, "doc dung cau hinh thuong 113000+n",
	G_PrizeLogic.lanHoi[1])
check(#G_ChapterLogic.lanPhat == 1, "phat thuong dung MOT lan", #G_ChapterLogic.lanPhat)
local p = G_ChapterLogic.lanPhat[1]
check(p ~= nil and p[1] == G_PrizeLogic.CoSan[113001],
	"phat dung PrizeContent doc tu cau hinh, khong tu che")
check(p ~= nil and p[2] == 1 and p[3] == "EndlessChapterFirstPrize",
	"phat 1 lan, nguon 'EndlessChapterFirstPrize'", p and tostring(p[3]))
check(ma_tra_loi() == 0, "lanh thuong thanh cong: khong ma loi", tostring(ma_tra_loi()))
check(td.FirstPrizeStates["1"] == true, "danh dau da nhan tren ban client dang giu")
-- Cho de mat phan thuong nhat: syncFromClient doc BAN SAO trong DataManager, nen
-- chi danh dau tren ban client la khong du.
check(tTrongKho.FirstPrizeStates["1"] == true,
	"danh dau da nhan CUNG vao BAN SAO trong DataManager")
-- Doc thang `OfflineStore.data` chu khong qua `OfflineStore:get`: `table()`
-- TAO muc khi doc (store.lua:242), doc qua no thi phep kiem tu lam cho minh dung.
check(OfflineStore.data and type(OfflineStore.data.GameUserEndlessChapter) == "table"
	and OfflineStore.data.GameUserEndlessChapter.FirstPrizeStates["1"] == true,
	"va xuong duoc kho (OfflineStore), de con nguyen qua lan khoi dong lai")

-- (3) Xin lai chinh tang do: ma HasGetFristPrize, khong phat lan hai.
Mock:reset()
CallServer(5, "G_EndlessChapterLogic", "ClientGetEndlessChapterFirstPrize", 1)
Mock:tick(1)
check(ma_tra_loi() == MA_DA_LAY, "xin lai: tra dung ma HasGetFristPrize",
	tostring(ma_tra_loi()))
check(#G_ChapterLogic.lanPhat == 1, "xin lai: khong phat thuong lan hai",
	#G_ChapterLogic.lanPhat)
check(#G_PrizeLogic.lanHoi == 1, "xin lai: khong doc lai cau hinh thuong",
	#G_PrizeLogic.lanHoi)

-- (4) Tung tang mot: tang 6 chua thong (toi nhat 5) thi van NotPass.
Mock:reset()
CallServer(5, "G_EndlessChapterLogic", "ClientGetEndlessChapterFirstPrize", 6)
Mock:tick(1)
check(ma_tra_loi() == MA_NOT_PASS, "tang 6 chua thong: NotPass", tostring(ma_tra_loi()))
check(#G_ChapterLogic.lanPhat == 1, "tang chua thong: khong phat", #G_ChapterLogic.lanPhat)

-- (5) Chi so khong hop le: phai TRA LOI (khong treo client) va khong phat.
local nPhatTruoc = #G_ChapterLogic.lanPhat
for _, xau in ipairs({ 0, -3, "abc" }) do
	Mock:reset()
	CallServer(5, "G_EndlessChapterLogic", "ClientGetEndlessChapterFirstPrize", xau)
	Mock:tick(1)
	check(ma_tra_loi() == 0 and #G_ChapterLogic.lanPhat == nPhatTruoc,
		"chi so " .. tostring(xau) .. ": tra loi, khong doc cau hinh thuong",
		tostring(ma_tra_loi()))
end

-- (6) Khong doc duoc cau hinh thuong thi KHONG danh dau da nhan — danh dau thi
-- nguoi choi mat luon phan thuong do (client khong hoi lai duoc nua).
dat_lai({ BestProsees = 9, FirstPrizeStates = {} })
CallServer(5, "G_EndlessChapterLogic", "ClientGetEndlessChapterFirstPrize", 4)
Mock:tick(1)   -- 113004 khong co trong CoSan
check(#G_PrizeLogic.lanHoi == 1 and G_PrizeLogic.lanHoi[1] == 113004,
	"thieu cau hinh: van doc dung ma 113004", G_PrizeLogic.lanHoi[1])
check(#G_ChapterLogic.lanPhat == 0, "thieu cau hinh thuong: khong phat", #G_ChapterLogic.lanPhat)
check(G_DataManager.userData.GameUserEndlessChapter.FirstPrizeStates["4"] == nil,
	"thieu cau hinh thuong: KHONG danh dau da nhan")
check(ma_tra_loi() == 0, "thieu cau hinh thuong: van tra loi, khong treo client",
	tostring(ma_tra_loi()))

-- (7) Thieu `ErrorCode` thi tra ma 0, KHONG bia mot con so. Trong game that
-- `ErrorCode` luon co (share/share_public_require.lua:14 -> share.error, keo
-- vao o lua/bootstrap.lua:603) — nhung neu thieu that thi tra 0 la trung thuc.
local ecCu = ErrorCode
ErrorCode = nil
dat_lai({ BestProsees = 9, FirstPrizeStates = {} })
CallServer(5, "G_EndlessChapterLogic", "ClientGetEndlessChapterFirstPrize", 2)
Mock:tick(1)
check(ma_tra_loi() == 0, "thieu ErrorCode: tra 0 chu khong bia so", tostring(ma_tra_loi()))
check(#G_ChapterLogic.lanPhat == 1, "thieu ErrorCode: van phat thuong", #G_ChapterLogic.lanPhat)
ErrorCode = ecCu
G_DataManager.userData = {}

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
		GameUserCloudShop = {},
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
check(OfflineStore.data.GameUserCloudShop == nil,
	"bo bang cua hang Van Du da nhiem {}", tostring(OfflineStore.data.GameUserCloudShop))
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

--[[ Router khoá theo BỘ BA (module, objName, funcName) như `CallLocal` của bản
	gốc — hai hệ KHÁC nhau được phép trùng tên hàm. Đo 27/10: `ClientCompeleteFight`
	có ở CẢ `G_CavernLogic` lẫn `G_EndlessChapterLogic`, tham số khác hẳn; router
	khoá trơ theo tên hàm thì cái sau đè cái trước và lượt gọi đi nhầm hàm. ]]
print("\n=== 17. router: khoa theo (obj, func) ===")
do
	local daGoi = nil
	OfflineRouter:on("TEST.TrungTen", function () daGoi = "obj" end)
	OfflineRouter:on("TrungTen", function () daGoi = "tran" end)

	check(OfflineRouter:getFor("TEST", "TrungTen") ~= nil,
		"getFor tim thay handler co obj")
	check(OfflineRouter:getFor("KHAC", "TrungTen") ~= nil,
		"getFor roi ve ten tran khi obj khac")

	daGoi = nil
	CallServer(5, "TEST", "TrungTen")
	check(daGoi == "obj", "dispatch CHON ban co obj khi obj trung", daGoi)

	daGoi = nil
	CallServer(5, "KHAC", "TrungTen")
	check(daGoi == "tran", "dispatch roi ve ban ten tran khi obj khac", daGoi)

	daGoi = nil
	CallServer(5, "", "TrungTen")
	check(daGoi == "tran", "dispatch voi obj rong dung ban ten tran", daGoi)

	-- Dọn: không để lại handler thử trong bảng đăng ký của lớp thật.
	OfflineRouter.handlers["TEST.TrungTen"] = nil
	OfflineRouter.handlers["TrungTen"] = nil
end

--[[ KHOÁ ĐĂNG KÝ của các nhóm thêm trong 30–31/10.

	Đây KHÔNG phải bộ thử hành vi (mỗi nhóm đã có `_thu_*.lua` riêng, chạy bằng
	`_chay_het.py`). Phép này đo ĐÚNG MỘT việc mà bộ thử tĩnh KHÔNG đo được:
	khoá đăng ký có khớp cặp (objName, funcName) mà `CallServer` thật gử i hay
	không — sai tiền tố obj là handler KHÔNG BAO GIỜ chạy mà cũng không có lỗi
	nào (chỉ một dòng "THIEU" trong offline.log). ]]
print("\n=== 18. khoa dang ky cua cac nhom 30-31/10 + 1/11 ===")
do
	local DS = {
		{ "G_FormationLogic", "ClientUpgrade" },
		{ "G_FormationLogic", "ClientActiveRareFormation" },
		{ "G_FormationLogic", "ClientSelectAdvancedFormation" },
		{ "G_MonthlyCardLogic", "ClientGetReward" },
		{ "G_ClothingLogic", "ClientComposeClothing" },
		{ "G_ClothingLogic", "ClientGetClothingPrize" },
		{ "G_ClothingLogic", "ClientSetClothingPrizeUseStatus" },
		{ "G_HeroPracticeLogic", "ClientPracticeHero" },
		{ "G_HeroPracticeLogic", "ClientGetPracticePrize" },
		{ "G_HeroPracticeLogic", "ClientGetPracticeInfo" },
		{ "G_ActivityFund", "ClientBuyActivityFund" },
		{ "G_ActivityFund", "ClientGetLevelFundPrize" },
		{ "G_ActivityFund", "ClientGetTimeFundPrize" },
		{ "G_ActivityCumulativeRecharge", "ClientGetUserState" },
		{ "G_ActivityCumulativeRecharge", "ClientGetPrize" },
		{ "G_ActivityCumulativeConsume", "ClientGetUserState" },
		{ "G_ActivityCumulativeConsume", "ClientGetPrize" },
		{ "G_MailLogic", "ClientSaveMailPrizeWithMailID" },
		{ "G_ChapterLogic", "ClientBuyChapterBattleResetCount" },
		{ "G_ChapterLogic", "ClientBuyChapterSweepCount" },
		{ "G_SevenDaysGiftLogic", "ClientSevenDaysGift" },
		{ "G_MidasTouchLogic", "ClientRunMidasTouchWithCount" },
		{ "G_ChapterLogic", "ClientGetChapterTargetReward" },
		{ "G_RankLogic", "ClientGet5HeroPowerRank" },
		{ "G_RankLogic", "ClientGetPveNormalRank" },
		{ "G_RankLogic", "ClientGetPveEliteRank" },
		{ "G_RankLogic", "ClientGetPveStarRank" },
		{ "G_RankLogic", "ClientGetGuildRank" },
		{ "G_ItemLogic", "ClientBuyItem" },
		{ "G_ItemLogic", "ClientBuyItemBatch" },
		{ "G_EquipmentLogic", "ClientRefineEquip" },
		{ "G_ItemLogic", "ClientRefineItem" },
		{ "G_HeroLogic", "ClientShowWing" },
		{ "G_HeroLogic", "ClientShowMagicWing" },
		{ "G_HeroLogic", "ClientUpdateHeroSkyFate" },
		{ "G_HeroLogic", "ClientResetHeroSkyFate" },
		{ "G_HeroLogic", "ClientConvertUniversalFragment" },
		{ "G_HeroLogic", "ClientSetExclusiveSkinState" },
		{ "G_HeroLogic", "ClientUpHeroFightSoul" },
		{ "G_SubtitleLogic", "ClientSetUserCopySubtitle" },
		{ "G_SubtitleLogic", "ClientGetCopySubtitle" },
		{ "G_GameWorld", "ClientGetRandomName" },
		{ "G_GuildLogic", "ClientCreateGuild" },
		{ "G_GuildLogic", "ClientGetGuildInfo" },
		{ "G_GuildLogic", "ClientModifyNotice" },
		{ "G_GuildLogic", "ClientGetGuildLogList" },
		{ "G_GuildLogic", "ClientGetGuildApplyList" },
		{ "G_GuildLogic", "ClientExitGuild" },
		{ "G_GuildLogic", "ClientCancelGuild" },
		{ "G_GuildLogic", "ClientDonateGuild" },
		{ "G_FriendLogic", "ClientGetUserRelations" },
		{ "G_FriendLogic", "ClientApplyForFriend" },
		{ "G_FriendLogic", "ClientReceiveGift" },
		{ "G_GuildWarLogic", "QueryScore" },
		{ "G_GuildWarLogic", "AttackWarBoss" },
		-- COG / công thành xuyên máy chủ (2/11): HAI obj GỬI khác nhau nhưng cùng
		-- một obj NHẬN (`g_COGProtocol`). Sai tiền tố obj là handler không bao giờ chạy.
		{ "G_COGProtocol", "ClientGetBriefInfo" },
		{ "G_COGProtocol", "ClientGetCOGInfo" },
		{ "G_COGProtocol", "ClientGetCityInfo" },
		{ "G_COGProtocol", "ClientGetMyTeamList" },
		{ "G_COGProtocol", "ClientGetGuildTeamProfile" },
		{ "G_COGProtocol", "ClientGetGuildTeamList" },
		{ "G_COGProtocol", "ClientGetGuildBattleReport" },
		{ "G_COGProtocol", "ClientGetCityReport" },
		{ "G_COGProtocol", "ClientGetPlayerBattleReport" },
		{ "G_COGProtocol", "ClientGetCityPlayback" },
		{ "G_COGProtocol", "ClientGetPlayerPlayback" },
		{ "G_COGProtocol", "ClientSignUp" },
		{ "G_COGProtocol", "ClientSetTargetCity" },
		{ "G_COGProtocol", "ClientSetGuildMsg" },
		{ "G_COGProtocol", "ClientAddTeam" },
		{ "G_COGProtocol", "ClientUpdateTeam" },
		{ "G_COGProtocol", "ClientRemoveTeam" },
		{ "G_COGProtocol", "ClientDispatchTeam" },
		{ "G_COGProtocol", "ClientBuyGoods" },
		{ "G_COGCityDefendMission", "ClientGetCityDefendMission" },
		{ "G_COGCityDefendMission", "ClientManualRefreshMission" },
		{ "G_COGCityDefendMission", "ClientGetPrize" },
		{ "G_COGCityDefendMission", "ClientRepairCity" },
		{ "G_COGCityDefendMission", "ClientAttackCity" },
		{ "G_COGCityDefendMission", "ClientGetDailyOccupyPrize" },
		-- Bang hội phần nâng cao (2/11): quản lý thành viên, thiết lập, tìm/join,
		-- thuế công nghệ, xúc xắc, điều tướng.
		{ "G_GuildLogic", "ClientAcceptApply" },
		{ "G_GuildLogic", "ClientRejectApply" },
		{ "G_GuildLogic", "ClientSetHead" },
		{ "G_GuildLogic", "ClientSetManager" },
		{ "G_GuildLogic", "ClientCancelManager" },
		{ "G_GuildLogic", "ClientKickGuild" },
		{ "G_GuildLogic", "ClientModifyGuildSetting" },
		{ "G_GuildLogic", "ClientIsHaveGuildRedPoint" },
		{ "G_GuildLogic", "ClientUploadWeChatGroup" },
		{ "G_GuildLogic", "ClientImpeachHeadman" },
		{ "G_GuildLogic", "ClientGetRandGuildList" },
		{ "G_GuildLogic", "ClientSearchGuild" },
		{ "G_GuildLogic", "ClientJoinGuild" },
		{ "G_GuildLogic", "ClientApplyGuild" },
		{ "G_GuildLogic", "ClientCancelApply" },
		{ "G_GuildLogic", "ClientDonateGuildTechnology" },
		{ "G_GuildLogic", "ClientGetDiceGameData" },
		{ "G_GuildLogic", "ClientPlayDiceGame" },
		{ "G_GuildLogic", "ClientGetDiceGameReward" },
		{ "G_GuildLogic", "ClientDispatchHero" },
		{ "G_GuildLogic", "ClientQuerySelfDispatchList" },
		{ "G_GuildLogic", "ClientGetDispatchHeroList" },
		{ "G_GuildLogic", "ClientPickGuildHero" },
		{ "G_GuildLogic", "ClientEmployDispatchHero" },
		-- Phó bản bang hội (2/11): 18 khoá G_GuildChapterLogic.
		{ "G_GuildChapterLogic", "ClientQueryGuildChapterListInfo" },
		{ "G_GuildChapterLogic", "ClientQueryGuildChapterInfo" },
		{ "G_GuildChapterLogic", "ClientOpenGuildChapter" },
		{ "G_GuildChapterLogic", "ClientResetGuildChapter" },
		{ "G_GuildChapterLogic", "ClientPrepareGuildChapter" },
		{ "G_GuildChapterLogic", "ClientGiveUpGuildChapterPrepare" },
		{ "G_GuildChapterLogic", "ClientGuildChapterFightBegin" },
		{ "G_GuildChapterLogic", "ClientGuildChapterFightComplete" },
		{ "G_GuildChapterLogic", "ClientGuildChapterRewardInfo" },
		{ "G_GuildChapterLogic", "ClientQueryReqestRewardMember" },
		{ "G_GuildChapterLogic", "ClientDivideReward" },
		{ "G_GuildChapterLogic", "ClientQueryGuildChapterRewardRecord" },
		{ "G_GuildChapterLogic", "ClientQuerySelfRequestPrize" },
		{ "G_GuildChapterLogic", "ClientChapterRequestDetailed" },
		{ "G_GuildChapterLogic", "ClientRequestReward" },
		{ "G_GuildChapterLogic", "ClientQueryGuildChapterInjuryRank" },
		{ "G_GuildChapterLogic", "ClientQueryGuildChapterServerInjuryRank" },
		{ "G_GuildChapterLogic", "ClientChapterGetCommonDropData" },
		-- Đấu trường điểm APR (2/11): 13 khoá G_ScoreCompetitivePlayProtocol.
		{ "G_ScoreCompetitivePlayProtocol", "ClientGetOpenInfoReq" },
		{ "G_ScoreCompetitivePlayProtocol", "ClientBeginPlayReq" },
		{ "G_ScoreCompetitivePlayProtocol", "ClientViewPlayerReq" },
		{ "G_ScoreCompetitivePlayProtocol", "ClientBeginFightReq" },
		{ "G_ScoreCompetitivePlayProtocol", "ClientEndFightReq" },
		{ "G_ScoreCompetitivePlayProtocol", "ClientAdjustDefTeamReq" },
		{ "G_ScoreCompetitivePlayProtocol", "ClientGetRankRewardReq" },
		{ "G_ScoreCompetitivePlayProtocol", "ClientGetReportReq" },
		{ "G_ScoreCompetitivePlayProtocol", "ClientGetReplayReq" },
		{ "G_ScoreCompetitivePlayProtocol", "ClientGetRankListReq" },
		{ "G_ScoreCompetitivePlayProtocol", "ClientRevengeBeginReq" },
		{ "G_ScoreCompetitivePlayProtocol", "ClientRevengeEndReq" },
		{ "G_ScoreCompetitivePlayProtocol", "ClientFailRecoverReq" },
		-- BXH chế độ ải đặc biệt (2/11): 14 khoá G_RankLogic.
		{ "G_RankLogic", "ClientGetSelfHJRQRankScore" },
		{ "G_RankLogic", "ClientGetSelfSYZLBRankScore" },
		{ "G_RankLogic", "ClientGetSelfSCSZLRankScore" },
		{ "G_RankLogic", "ClientGetSelfDJSJFRankScore" },
		{ "G_RankLogic", "ClientGetSelfXZWCRankScore" },
		{ "G_RankLogic", "ClientGetHjrqRank" },
		{ "G_RankLogic", "ClientGetSYZLBRank" },
		{ "G_RankLogic", "ClientGetSCSZLRank" },
		{ "G_RankLogic", "ClientGetDJSJFRank" },
		{ "G_RankLogic", "ClientGetXZWCRank" },
		{ "G_RankLogic", "ClientGetTGZZRank" },
		{ "G_RankLogic", "ClientGetDKRank" },
		{ "G_RankLogic", "ClientGetArenaDefendPowerRank" },
		{ "G_RankLogic", "ClientGetGuildWarScoreRank" },
		-- Chế độ ải đặc biệt (2/11): 16 khoá G_ChapterLogic.
		{ "G_ChapterLogic", "ClientChapterHJRQComplete" },
		{ "G_ChapterLogic", "ClientChapterSCSComplete" },
		{ "G_ChapterLogic", "ClientChapterDJSJFComplete" },
		{ "G_ChapterLogic", "ClientChapterXZWCComplete" },
		{ "G_ChapterLogic", "ClientChapterTGZZComplete" },
		{ "G_ChapterLogic", "ClientChapterPetBossComplete" },
		{ "G_ChapterLogic", "ClientChapterDKComplete" },
		{ "G_ChapterLogic", "ClientChapterTGZZSweep" },
		{ "G_ChapterLogic", "ClientChapterDKSweep" },
		{ "G_ChapterLogic", "ClientChapterHJRQSweep" },
		{ "G_ChapterLogic", "ClientChapterSYZLBAndXZWCSweep" },
		{ "G_ChapterLogic", "ClientGetChapterDropData" },
		{ "G_ChapterLogic", "ClientGetSCSChapterNPCData" },
		{ "G_ChapterLogic", "ClientGetDKChapterFaction" },
		{ "G_ChapterLogic", "ClientReviveInBattle" },
		{ "G_ChapterLogic", "ClientUserOverHJRQ" },
		-- Ải vô tận (2/11): 9 khoá G_EndlessChapterLogic.
		{ "G_EndlessChapterLogic", "ClientFight" },
		{ "G_EndlessChapterLogic", "ClientCompeleteFight" },
		{ "G_EndlessChapterLogic", "ClientGotoNextProsees" },
		{ "G_EndlessChapterLogic", "ClientInspire" },
		{ "G_EndlessChapterLogic", "ClientResetEndlessChapter" },
		{ "G_EndlessChapterLogic", "ClientBuyChallengesCount" },
		{ "G_EndlessChapterLogic", "ClientSwap" },
		{ "G_EndlessChapterLogic", "ClientStopSwap" },
		{ "G_EndlessChapterLogic", "ClientSwapImmediately" },
		-- Chiến dịch anh hùng (2/11): 5 khoá G_EpicChapterLogic.
		{ "G_EpicChapterLogic", "ClientSetTodayChapterDifficult" },
		{ "G_EpicChapterLogic", "ClientEpicResetDaily" },
		{ "G_EpicChapterLogic", "ClientEpicChapterCompeleteFight" },
		{ "G_EpicChapterLogic", "ClientSweepEpicChapter" },
		{ "G_EpicChapterLogic", "ClientBuyEpicGoods" },
		-- Năm khoá toàn cục còn sống (2/11).
		{ "", "ClientGetSpeechContent" },
		{ "", "ClientCheckNewEquipment" },
		{ "G_ArenaLogic", "ClientSetArenaHero" },
		{ "", "ClientSetArenaHero" },
		{ "G_Login", "ClientBindingAccount" },
		{ "", "ClientBindingAccount" },
		{ "", "ClientReturnHome" },
	}
	local thieu = {}
	for _, cap in ipairs(DS) do
		if OfflineRouter:getFor(cap[1], cap[2]) == nil then
			thieu[#thieu + 1] = cap[1] .. "." .. cap[2]
		end
	end
	check(#thieu == 0, "moi khoa trong danh sach deu dang ky duoc",
		table.concat(thieu, ", "))

	-- Khoá TOÀN CỤC (objName rỗng) của chuỗi vào game.
	check(OfflineRouter:getFor("", "ClientGetActivityList") ~= nil,
		"ClientGetActivityList dang ky (obj rong)")

	-- Lịch hoạt động: LevelFund phải có CẢ trạng thái LẪN cấu hình, nếu không
	-- `GetActivityWithType` trả nil và tab không hiện.
	local tt, ch = OfflineHoatDong:layDanhSach()
	check(tt.LevelFund ~= nil and ch.LevelFund ~= nil,
		"lich: LevelFund co ca trang thai lan cau hinh")
	check(tt.LevelFund and tt.LevelFund.ActivityID ~= 0, "lich: ActivityID khac 0")
	check(OfflineHoatDong:moKhong("CumulativeRecharge") == true,
		"lich: hoat dong KHONG mo duoc co ghi ly do")

	-- Nhịp "việc máy chủ làm mỗi ngày" (1/11): nếu móc này không nối được vào
	-- `OnEnterGame` thì quà 7 ngày đứng ở ngày 1 và lượt điểm kim thủ cộng dồn
	-- vĩnh viễn — không có lỗi nào khác để thấy.
	check(type(OfflineQuaNgay) == "table" and type(OfflineQuaNgay.kiem_ngay) == "function",
		"qua ngay: co OfflineQuaNgay:kiem_ngay")
	check(type(OfflineQua7Ngay) == "table" and type(OfflineQua7Ngay.kiem_ngay) == "function",
		"qua 7 ngay: co OfflineQua7Ngay:kiem_ngay")
	check(type(OfflineKimThu) == "table" and type(OfflineKimThu.kiem_ngay) == "function",
		"kim thu: co OfflineKimThu:kiem_ngay")
end

print(string.format("\n===== dat %d, hong %d =====", nPass, nFail))
os.exit(nFail == 0 and 0 or 1)