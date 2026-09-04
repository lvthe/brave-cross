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

print("\n=== 2. danh sach may chu ===")
Mock:reset()
CallServer(1, "G_Login", "ClientGetRecomendServers", "u", 1)
Mock:tick(1)
local sl = G_Login.tLast and G_Login.tLast.serverlist
check(sl ~= nil and #sl == 1, "tra ve 1 may chu")
check(sl and sl[1].name == "Offline", "ten may chu", sl and sl[1].name)

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
check(ud and ud.GameUserBaseInfo and ud.GameUserBaseInfo.Gold == 50000, "Gold = 50000")
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

print(string.format("\n===== dat %d, hong %d =====", nPass, nFail))
os.exit(nFail == 0 and 0 or 1)
