--[[
	offline/handlers/login.lua — chuỗi vào game: đăng nhập -> bắt tay -> nạp dữ liệu.

	Đây là đường tối thiểu để game chạy tới màn hình chính. Trình tự thật, đọc
	ngược từ mã client:

	  1. client gọi StartRPC
	         -> offline/net.lua bắn OnConnected(rpc, true)
	  2. CUIGameRPCManager:OnConnected  (sc/user/Logical/CUIGameRPCManager.lua:10)
	         -> G_GameGateway:Handshake(key, channel)
	         -> CallServer(GAME_GATEWAY, "", "Handshake", ...)
	  3. ta trả G_GameGateway:OnServerConnected()
	         -> phát sự kiện GameGateway.OnServerConnected
	  4. client gọi G_GameWorld:EnterGame()
	         -> CallServer(GAME_LOGIC, "G_GameWorld", "ClientEnterGame")
	  5. ta trả G_GameWorld:OnServerEnterGame(errCode, tGameUserData, sngData,
	                                         tOtherData, tServerConfig)
	         -> ClientGameWorld:initData -> G_DataManager:Init(tGameUserData)

	Lưu ý về hình dạng phản hồi: KHÔNG phải handler nào cũng dùng bao bì
	{err=, data=}. OnServerEnterGame nhận 5 tham số vị trí
	(sc/user/Logical/ClientGameWorld.lua:37), nên ở đây dùng ctx:call chứ không
	dùng ctx:reply.
]]

require("offline.log")
require("offline.store")
require("offline.router")
require("offline.bootstrap")

local R = OfflineRouter

--------------------------------------------------------------------- đăng nhập

--[[ Phản hồi đăng nhập.
	ClientLogin:OnServerLogin(tData) chỉ đọc tData.fun rồi phát sự kiện cùng
	tên (sc/user/Logical/ClientLogin.lua:14), nên tData phải mang đúng tên sự
	kiện trong EventManagerLogicEvent.Login. ]]
local function loginOK(ctx, strEvent)
	ctx:call("G_Login", "OnServerLogin", {
		err = 0,
		fun = strEvent,
		Uid = OfflineBootstrap.UID,
		UserName = OfflineBootstrap.NAME,
		SessionId = "offline-session",
	})
end

R:onAll({
	ClientLogin = function(ctx) loginOK(ctx, "OnClientLogin") end,
	ClientSdkLogin = function(ctx) loginOK(ctx, "OnClientLogin") end,
	ClientChannelLogin = function(ctx) loginOK(ctx, "OnClientLogin") end,
	ClientGPlayLogin = function(ctx) loginOK(ctx, "OnClientLogin") end,
	ClientRegister = function(ctx) loginOK(ctx, "OnClientRegister") end,

	--[[ Danh sách máy chủ. Chỉ có một "máy chủ" và nó nằm ngay trong máy;
		địa chỉ là giả, StartRPC đã bị chặn nên không ai quay số cả. ]]
	ClientGetRecomendServers = function(ctx)
		ctx:call("G_Login", "OnServerLogin", {
			err = 0,
			fun = "OnClientGetRecomendServers",
			serverlist = {
				{
					id = 1,
					ip = "127.0.0.1:1",
					name = "Offline",
					state = 1,
					IsRecommend = 1,
				},
			},
		})
	end,
})

----------------------------------------------------------------- bắt tay cổng

R:on("Handshake", function(ctx)
	OfflineLog:info("bat tay — bo qua kiem tra phien ban va khoa")
	ctx:call("G_GameGateway", "OnServerConnected")
end)

--------------------------------------------------------------------- vào game

--[[ Dữ liệu ngoài userData mà OnServerEnterGame nhận.

	tOtherData đi qua ClientGameWorld:DealOtherData: nó chỉ đọc .ConfigMap và
	.Activity, và đều kiểm tra nil trước, nên bảng rỗng là hợp lệ.
	tServerConfig chỉ được đọc lại qua GetServerConfig -> CUIAssist.getValue,
	vốn chịu được nil. ]]
local function otherData()
	return {}
end

local function serverConfig()
	return {
		ServerId = 1,
		ServerName = "Offline",
		OpenTime = os.time() - 86400,   -- ĐẶT: coi như máy chủ mở từ hôm qua
	}
end

R:on("ClientEnterGame", function(ctx)
	local bNew = OfflineBootstrap:ensure()
	local tUserData = OfflineStore:all()

	OfflineLog:info(string.format("vao game (%s), %d bang du lieu",
		bNew and "nguoi choi moi" or "nap tu file luu", OfflineStore:count()))

	-- errCode, tGameUserData, sngData, tOtherData, tServerConfig
	ctx:call("G_GameWorld", "OnServerEnterGame",
		0, tUserData, {}, otherData(), serverConfig())
end)

R:on("ClientCreateCharacter", function(ctx, szName)
	if szName and szName ~= "" then
		OfflineStore:set("GameUserBaseInfo", "UserName", szName)
		OfflineStore:save()
	end
	ctx:reply({ err = 0 })      -- -> OnCreateCharacter
end)

---------------------------------------------------------------- nuốt lặng lẽ

--[[ Không có phản hồi và không chạm trạng thái chơi: nhịp tim, thống kê,
	báo cáo. Liệt kê ra đây để chúng không làm nhiễu offline.log. ]]
R:ignore(
	"Heartbeat",
	"TickFromClient",
	"ClientReportClientInfo",
	"ClientStatistics"
)

return true
