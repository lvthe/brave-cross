--[[
	test/mock.lua — dựng lại đủ phần môi trường game để chạy lớp offline trên PC.

	Chỉ giả lập những gì offline/* thực sự chạm tới: cjson, CallLocal,
	S_CCSchedule, LGG_GetSetFilePath, CUIRPCManager, CDataManager, sngUtil_log.
	Mục đích là kiểm tra logic chuỗi vào game, không phải chạy game.
]]

Mock = {}
Mock.calls = {}          -- mọi lời gọi CallLocal, theo thứ tự
Mock.timers = {}
Mock.logs = {}

--------------------------------------------------------------------- cjson tối giản

local function esc(s)
	return (s:gsub('[%c"\\]', function(c)
		local map = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\t'] = '\\t', ['\r'] = '\\r' }
		return map[c] or string.format('\\u%04x', c:byte())
	end))
end

-- Sentinel cho JSON null, đúng vai trò cjson.null của lua-cjson: encode ra
-- `null`, và decode `null` trả về chính nó chứ KHÔNG phải nil — nếu trả nil
-- thì một null giữa mảng sẽ làm mọi phần tử sau nó biến mất.
local NULL = setmetatable({}, { __tostring = function() return "null" end })

--[[ Bảng rỗng: lua-cjson mã hoá thành `{}` (object) chứ không phải `[]`.
	Mock phải theo cho khớp, nếu không test sẽ xác nhận một hành vi mà game
	thật không có. ]]
local function isArray(t)
	local n = 0
	for k in pairs(t) do
		if type(k) ~= "number" then return false end
		n = n + 1
	end
	return n > 0 and n == #t
end

local function enc(v)
	local tv = type(v)
	if v == nil or v == NULL then return "null" end
	if tv == "number" then return tostring(v) end
	if tv == "boolean" then return tostring(v) end
	if tv == "string" then return '"' .. esc(v) .. '"' end
	if tv ~= "table" then error("khong encode duoc kieu " .. tv) end
	local out = {}
	if isArray(v) then
		for i = 1, #v do out[#out + 1] = enc(v[i]) end
		return "[" .. table.concat(out, ",") .. "]"
	end
	-- Giữ NGUYÊN khoá gốc chứ không tostring() rồi tra ngược: mẹo
	-- `v[k] ~= nil and v[k] or ...` biến giá trị `false` thành null, mà
	-- codebase này đầy cờ boolean.
	local keys = {}
	for k in pairs(v) do keys[#keys + 1] = k end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	for _, k in ipairs(keys) do
		out[#out + 1] = '"' .. esc(tostring(k)) .. '":' .. enc(v[k])
	end
	return "{" .. table.concat(out, ",") .. "}"
end

local dec
local function skip(s, i)
	while i <= #s and s:sub(i, i):match("%s") do i = i + 1 end
	return i
end

dec = function(s, i)
	i = skip(s, i)
	local c = s:sub(i, i)
	if c == "{" then
		local t = {}
		i = skip(s, i + 1)
		if s:sub(i, i) == "}" then return t, i + 1 end
		while true do
			local k; k, i = dec(s, i)
			i = skip(s, i)
			i = i + 1                                   -- dấu :
			local v; v, i = dec(s, i)
			t[k] = v
			i = skip(s, i)
			if s:sub(i, i) == "," then i = i + 1 else return t, i + 1 end
		end
	elseif c == "[" then
		local t = {}
		i = skip(s, i + 1)
		if s:sub(i, i) == "]" then return t, i + 1 end
		while true do
			local v; v, i = dec(s, i)
			t[#t + 1] = v
			i = skip(s, i)
			if s:sub(i, i) == "," then i = i + 1 else return t, i + 1 end
		end
	elseif c == '"' then
		local out, j = {}, i + 1
		while j <= #s do
			local ch = s:sub(j, j)
			if ch == "\\" then
				local n = s:sub(j + 1, j + 1)
				local map = { n = "\n", t = "\t", r = "\r", ['"'] = '"', ["\\"] = "\\" }
				out[#out + 1] = map[n] or n
				j = j + 2
			elseif ch == '"' then
				return table.concat(out), j + 1
			else
				out[#out + 1] = ch
				j = j + 1
			end
		end
		error("chuoi khong dong")
	elseif s:sub(i, i + 3) == "true" then return true, i + 4
	elseif s:sub(i, i + 4) == "false" then return false, i + 5
	elseif s:sub(i, i + 3) == "null" then return NULL, i + 4
	else
		local num = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", i)
		if not num then error("JSON hong tai vi tri " .. i .. ": " .. s:sub(i, i + 20)) end
		return tonumber(num), i + #num
	end
end

cjson = {
	null = NULL,
	encode = enc,
	decode = function(s) local v = dec(s, 1); return v end,
}

------------------------------------------------------------------ môi trường game

function sngUtil_log(msg)
	Mock.logs[#Mock.logs + 1] = msg
end

function LGG_GetSetFilePath()
	return Mock.dir or "./"
end

--[[ CallLocal thật (sc/system/rpc.lua:79) giải mã mảng JSON rồi gọi
	_G[strObj][strFunc](obj, unpack(args)). Bản mock ghi lại lời gọi và cũng
	thực hiện luôn, để phía client giả có thể phản ứng. ]]
function CallLocal(strObj, strFunc, szArgs)
	local args = (szArgs and szArgs ~= "") and cjson.decode(szArgs) or {}
	Mock.calls[#Mock.calls + 1] = { obj = strObj, func = strFunc, args = args }
	local obj = (strObj ~= nil and strObj ~= "") and _G[strObj] or nil
	local fn = obj and obj[strFunc] or _G[strFunc]
	if type(fn) == "function" then
		if obj then fn(obj, table.unpack(args)) else fn(table.unpack(args)) end
	end
	return ""
end

S_CCSchedule = {}
function S_CCSchedule:schedule(obj, strFunc, fInterval)
	local t = { obj = obj, func = strFunc, alive = true }
	function t:stop() self.alive = false end
	function t:retain() end
	function t:pause() end
	function t:resume() end
	Mock.timers[#Mock.timers + 1] = t
	return t
end

CUIRPCManager = {}
function CUIRPCManager:StartRPC() error("khong duoc goi ban goc trong test") end
function CUIRPCManager:CloseRPC() end
function CUIRPCManager:Uninit() end

CDataManager = {}
function CDataManager:initUserDataFromDB() return 0, nil end

--------------------------------------------------------------------- tiện ích

-- Chạy N khung hình: đẩy hàng đợi phản hồi của offline/net.lua.
function Mock:tick(n)
	for _ = 1, (n or 1) do
		for _, t in ipairs(self.timers) do
			if t.alive then t.obj[t.func](t.obj) end
		end
	end
end

function Mock:reset()
	self.calls = {}
end

-- Tìm lời gọi CallLocal theo tên hàm.
function Mock:find(strFunc)
	for _, c in ipairs(self.calls) do
		if c.func == strFunc then return c end
	end
	return nil
end

return Mock
