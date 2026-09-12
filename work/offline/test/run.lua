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
check(nTables == 33, "du 33 bang", nTables)

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

print(string.format("\n===== dat %d, hong %d =====", nPass, nFail))
os.exit(nFail == 0 and 0 or 1)
