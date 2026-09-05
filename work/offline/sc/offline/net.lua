--[[
	offline/net.lua — thay toàn bộ tầng mạng bằng một server chạy ngay trong client.

	Vì sao chặn được sạch sẽ ở đây: giao thức gốc đi qua đúng hai hàm Lua toàn cục
	(sc/system/rpc.lua) —

		CallServer(nModule, strObjName, strFunction, ...)   -- client -> server
		CallLocal(strObjName, strFunction, szJsonArgs)      -- server -> client

	Lua tra cứu biến toàn cục lúc gọi, nên ghi đè `CallServer` là bắt được cả các
	lời gọi do CUIAssist.bindRpcToEvent sinh ra lúc chạy. Tầng protobuf và socket
	C++ bên dưới không bao giờ được chạm tới.

	Ba thứ phải giả lập:
	  1. CallServer      -> định tuyến vào OfflineRouter
	  2. StartRPC        -> báo "đã kết nối" thay vì mở socket
	  3. tính bất đồng bộ -> server thật không trả lời ngay trong lời gọi; trả lời
	     đồng bộ sẽ tái nhập logic client giữa chừng và làm hỏng giả định của nó.
	     Nên mọi phản hồi được xếp hàng và đẩy ra ở khung hình sau.
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineNet = {}

OfflineNet.queue = {}           -- phản hồi chờ đẩy về client
OfflineNet.timer = nil
OfflineNet.installed = false
OfflineNet.nSaveTick = 0
OfflineNet.SAVE_EVERY = 120     -- số tick giữa hai lần ghi file (~4s ở 30fps)

------------------------------------------------------------------- tiện ích

--[[ Gói danh sách tham số GIỮ NGUYÊN SỐ LƯỢNG, kể cả khi có nil ở giữa.

	`{ ... }` một mình là không đủ: {1, nil, 3} cho ra bảng thưa, cjson mã hoá
	nó thành object {"1":1,"3":3} (hoặc báo lỗi "sparse array"), và `unpack`
	bên kia trả về KHÔNG GÌ CẢ — client mất sạch tham số mà không có một dòng
	lỗi nào. Nên đếm bằng select("#", ...) rồi lấp chỗ trống ở denseArgs(). ]]
local function packv(...)
	local t = { ... }
	t.n = select("#", ...)
	return t
end

--[[ Đổi gói tham số thành mảng đặc để cjson ra đúng số phần tử.

	Chỗ trống lấp bằng cjson.null — đúng thứ server thật cũng buộc phải gửi,
	vì transport là JSON và JSON không có "vắng mặt" ở giữa mảng. Bên client
	nó về thành cjson.null chứ không phải nil, y như với server gốc. ]]
local function denseArgs(t)
	local n = t.n or #t
	local out, nHoles = {}, 0
	for i = 1, n do
		local v = t[i]
		if v == nil then
			v = cjson.null
			nHoles = nHoles + 1
		end
		out[i] = v
	end
	return out, n, nHoles
end

--[[ Tra cứu hàm client Y HỆT CallLocal (sc/system/rpc.lua:79):
	obj = _G[szObjName];  func = obj and obj[szFunName] or _G[szFunName] ]]
local function resolveClientFunc(strObj, strFunc)
	if strFunc == nil or strFunc == "" then
		return nil
	end
	local obj = (strObj ~= nil and strObj ~= "") and _G[strObj] or nil
	local fn = obj and obj[strFunc]
	if fn == nil then
		fn = _G[strFunc]
	end
	return type(fn) == "function" and fn or nil
end

------------------------------------------------------------------ ngữ cảnh gọi

local Ctx = {}
Ctx.__index = Ctx

function Ctx.new(nModule, strObj, strFunc)
	return setmetatable({
		module = nModule,
		objName = strObj,
		funcName = strFunc,
		store = OfflineStore,
	}, Ctx)
end

--[[ Trả kết quả về client.
	Mặc định gọi ngược đúng cặp (objName, "On"..tên) mà client chờ; truyền
	strFunc/strObj để chỉ định khác đi.

	Quy ước payload của game: { err = <mã lỗi>, data = <nội dung> } — mọi handler
	client đều kiểm tra tData.err ~= 0 trước tiên. ]]
function Ctx:reply(tData, strFunc, strObj)
	OfflineNet:push(strObj or self.objName, strFunc or self:defaultHandler(), packv(tData))
end

-- Trả lỗi.
function Ctx:fail(nErr, strFunc, strObj)
	self:reply({ err = nErr or 1 }, strFunc, strObj)
end

-- Trả thành công kèm dữ liệu.
function Ctx:ok(data, strFunc, strObj)
	self:reply({ err = 0, data = data }, strFunc, strObj)
end

-- Gọi thẳng một hàm client với danh sách tham số tuỳ ý (không theo bao bì err/data).
function Ctx:call(strObj, strFunc, ...)
	OfflineNet:push(strObj, strFunc, packv(...))
end

--[[ Các tên handler có thể có, cùng thứ tự build_spec.candidates() thử
	(build_spec.py:90): bỏ tiền tố Client/Req/Request rồi thêm On. ]]
function Ctx:handlerNames()
	local fn = self.funcName
	local out, seen = {}, {}
	local function add(name)
		if name and name ~= "" and not seen[name] then
			seen[name] = true
			out[#out + 1] = name
		end
	end

	if string.match(fn, "^On") then
		add(fn)
	end
	local base = fn
	for _, pfx in ipairs({ "Client", "Req", "Request" }) do
		local rest = string.match(fn, "^" .. pfx .. "(.+)$")
		if rest then
			base = rest
			break
		end
	end
	add("On" .. base)
	-- nhóm bindRpcToEvent dùng reqFormat "Client%sReq" mà handler là On<khoá>
	local trimmed = string.match(base, "^(.+)Req$")
	if trimmed then
		add("On" .. trimmed)
	end
	add("On" .. fn)
	return out
end

local resolvedHandler = {}

--[[ Tên handler client mặc định.

	build_spec.candidates() chỉ có mã nguồn tĩnh để dò nên phải đoán bằng quy
	tắc chuỗi; ở đây ta đang chạy TRONG client nên chọn được bằng cách thử
	thật — tên nào phân giải ra một hàm theo đúng luật của CallLocal thì dùng
	tên đó. Nhờ vậy bắt được cả handler do bindRpcToEvent sinh lúc chạy, thứ mà
	không quy tắc chuỗi nào suy ra được.

	Không có tên nào phân giải được = client sẽ ngồi chờ mãi. Đó là kiểu hỏng
	tệ nhất ở đây nên phải kêu to. ]]
function Ctx:defaultHandler()
	local key = (self.objName or "") .. "|" .. self.funcName
	if resolvedHandler[key] then
		return resolvedHandler[key]
	end

	local names = self:handlerNames()
	local found = {}
	for _, name in ipairs(names) do
		if resolveClientFunc(self.objName, name) then
			found[#found + 1] = name
		end
	end
	local chosen = found[1] or names[1]

	if #found == 0 then
		-- không cache: handler của bindRpcToEvent chỉ xuất hiện khi UI tương
		-- ứng được dựng, nên lần gọi sau có thể đã có
		OfflineLog:warn(string.format(
			"%s: khong tim thay handler nao (da thu: %s) — client se treo",
			self.funcName, table.concat(names, ", ")))
	else
		if #found > 1 then
			OfflineLog:warn(string.format("%s: %d handler cung ton tai (%s), chon %s",
				self.funcName, #found, table.concat(found, ", "), chosen))
		end
		resolvedHandler[key] = chosen
	end
	return chosen
end

------------------------------------------------------------- hàng đợi phản hồi

function OfflineNet:push(strObj, strFunc, tArgs)
	table.insert(self.queue, {
		obj = strObj or "",
		func = strFunc,
		args = tArgs or { n = 0 },
	})
end

function OfflineNet:flushOne(item)
	local args, _, nHoles = denseArgs(item.args)
	if nHoles > 0 and cjson.null == nil then
		OfflineLog:err(string.format(
			"%s: %d tham so nil ma cjson khong co null — danh sach se lech",
			tostring(item.func), nHoles))
	end

	local okEnc, szData = pcall(cjson.encode, args)
	if not okEnc then
		OfflineLog:err(string.format("khong encode duoc phan hoi %s: %s", item.func, tostring(szData)))
		return
	end

	-- CallLocal nuốt lặng lẽ tên hàm không tồn tại, mà đó lại đúng là kiểu
	-- hỏng khó tìm nhất: client chờ mãi một phản hồi không bao giờ tới.
	if not resolveClientFunc(item.obj, item.func) then
		OfflineLog:warn(string.format("tra ve %s.%s nhung client khong co ham nay",
			item.obj ~= "" and item.obj or "(toan cuc)", tostring(item.func)))
	end

	local okCall, err = pcall(CallLocal, item.obj, item.func, szData)
	if not okCall then
		OfflineLog:err(string.format("loi khi tra %s.%s: %s", item.obj, item.func, tostring(err)))
	end
end

-- Chạy mỗi khung hình: đẩy hết hàng đợi rồi lưu định kỳ.
function OfflineNet:tick()
	if #self.queue > 0 then
		local batch = self.queue
		self.queue = {}
		for _, item in ipairs(batch) do
			self:flushOne(item)
		end
	end

	self.nSaveTick = self.nSaveTick + 1
	if self.nSaveTick >= self.SAVE_EVERY then
		self.nSaveTick = 0
		OfflineStore:flush()
	end
end

--------------------------------------------------------------- điều phối lệnh

function OfflineNet:dispatch(nModule, strObj, strFunc, ...)
	local fn = OfflineRouter:get(strFunc)
	if not fn then
		if not OfflineRouter:isSilent(strFunc) then
			OfflineLog:missing(nModule, strObj, strFunc, packv(...))
		end
		return
	end

	local ctx = Ctx.new(nModule, strObj, strFunc)
	local ok, err = pcall(fn, ctx, ...)
	if not ok then
		OfflineLog:err(string.format("handler %s loi: %s", strFunc, tostring(err)))
	end
end

--------------------------------------------------------------------- cài đặt

function OfflineNet:install()
	if self.installed then
		return
	end

	-- 1. chặn chiều client -> server
	self.rawCallServer = CallServer
	CallServer = function(nModule, strObjName, strFunction, ...)
		OfflineNet:dispatch(nModule, strObjName or "", strFunction, ...)
	end

	--[[ 2. giả lập kết nối.
		StartRPC bản gốc mở socket rồi để C++ gọi ngược
		_G[szCallbackObj]:szCallback(rpc, bConnected). Ta gọi thẳng callback đó ở
		khung hình sau với bConnected = true — client đi tiếp đúng luồng bình
		thường (CUIGameRPCManager:OnConnected -> G_GameGateway:Handshake). ]]
	if CUIRPCManager then
		self.rawStartRPC = CUIRPCManager.StartRPC
		CUIRPCManager.StartRPC = function(mgr, szIP, bNeedToResponse, szCallbackLuaObj,
		                                  szCallback, szInterruptCallback, szHeartBeatFuncName)
			mgr.szServerIP = szIP or "offline"
			OfflineLog:info(string.format("StartRPC gia lap: %s -> %s:%s",
				tostring(szIP), tostring(szCallbackLuaObj), tostring(szCallback)))
			OfflineNet:push(szCallbackLuaObj, szCallback, packv(false, true))
			return true
		end

		-- CloseRPC / Uninit: không có socket nào để đóng.
		self.rawCloseRPC = CUIRPCManager.CloseRPC
		CUIRPCManager.CloseRPC = function() return true end
		self.rawUninit = CUIRPCManager.Uninit
		CUIRPCManager.Uninit = function() return true end
		self.rawCheckConn = CUIRPCManager.CheckConnection
		CUIRPCManager.CheckConnection = function() return true end
	end

	-- 3. nhịp đẩy hàng đợi
	if S_CCSchedule then
		self.timer = S_CCSchedule:schedule(self, "tick", 0)
		if self.timer and self.timer.retain then
			self.timer:retain()
		end
	else
		OfflineLog:err("khong co S_CCSchedule — phan hoi se khong duoc day ra")
	end

	self.installed = true
	OfflineLog:info(string.format("da chan tang mang, %d handler dang ky",
		OfflineRouter:count()))
end

function OfflineNet:uninstall()
	if not self.installed then return end
	if self.rawCallServer then CallServer = self.rawCallServer end
	if CUIRPCManager and self.rawStartRPC then
		CUIRPCManager.StartRPC = self.rawStartRPC
		CUIRPCManager.CloseRPC = self.rawCloseRPC
		CUIRPCManager.Uninit = self.rawUninit
		CUIRPCManager.CheckConnection = self.rawCheckConn
	end
	if self.timer and self.timer.stop then self.timer:stop() end
	self.timer = nil
	self.installed = false
end

OfflineNet.Ctx = Ctx
return OfflineNet
