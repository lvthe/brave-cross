-- _thu_cong_thanh.lua — bộ thử cho `offline/handlers/cong_thanh.lua`
-- (chạy bằng `python _thu_nha_cua.py _thu_cong_thanh.lua`).
--
-- Đo hai điều dễ hỏng của một họ "một khuôn, nhiều đuôi tham số":
--   1. Tham số ĐẦU luôn là BẢNG `{}` (client kiểm `ProcessNotTable(eventList)` rồi thoát).
--   2. Đuôi tham số đúng SỐ LƯỢNG, kể cả `nil` ở CUỐI (`unpack` với n tường minh).
package.path = [[__SC__/?.lua;__SC__/?/init.lua;]] .. package.path

local function ghi(m) io.write('[log] ' .. tostring(m) .. '\n') end
package.preload['offline.log'] = function ()
    local L = { info = ghi, warn = ghi, err = ghi }; OfflineLog = L; return L
end
package.preload['offline.store'] = function ()
    local S = { TABLES = {}, data = {}, dirty = false }
    function S:syncFromClient() end
    OfflineStore = S; return S
end
package.preload['offline.router'] = function ()
    local R = { handlers = {} }
    function R:on(k, f) self.handlers[k] = f end
    function R:has(k) return self.handlers[k] ~= nil end
    OfflineRouter = R; return R
end

ErrorCode = { UnknowError = 1, ArgError = 2, Guild = { GuildWarNoFightData = 3538 } }

dofile([[__SC__/offline/handlers/cong_thanh.lua]])
local R = require('offline.router')

local dat, hong = 0, 0
local function check(ok, ten, ct)
    if ok then dat = dat + 1; io.write('  OK   ' .. ten .. '\n')
    else hong = hong + 1; io.write('  HONG ' .. ten .. (ct ~= nil and (' -> ' .. tostring(ct)) or '') .. '\n') end
end
local function ctxGia()
    local c = { calls = {} }
    function c:call(obj, f, ...)
        self.calls[#self.calls + 1] = { obj = obj, f = f, args = { ... }, n = select('#', ...) }
    end
    return c
end
local function goi(khoa)
    local c = ctxGia()
    R.handlers['G_GuildWarLogic.' .. khoa](c)
    return c.calls[1]
end

-- Bảng kỳ vọng: khoá -> { tên hàm nhận, số tham số, mã lỗi }
local KY_VONG = {
	{ 'QueryScore',               'OnQueryScore',               2 },
	{ 'QueryGuildWarRank',        'OnQueryGuildWarRank',        2 },
	{ 'SetGuildWarFightHero',     'OnSetGuildWarFightHero',     2 },
	{ 'QueryAccnList',            'OnQueryAccnList',            2 },
	{ 'AnnounceWar',              'OnAnnounceWar',              2 },
	{ 'GetGuildWarInfo',          'OnGetGuildWarInfo',          3 },
	{ 'GetGuildWarMockFightData', 'OnGetGuildWarMockFightData', 2 },
	{ 'AttackWarBoss',            'OnAttackWarBoss',            4 },
	{ 'AngerAttackWarBoss',       'OnAngerAttackWarBoss',       3 },
	{ 'CheckCanChangeTeam',       'OnCheckCanChangeTeam',       3 },
	{ 'GetCanBeAttackUser',       'OnGetCanBeAttackUser',       6 },
	{ 'QueryAttckCanBeAttack',    'OnQueryAttckCanBeAttack',    3 },
	{ 'GuildWarFightBegin',       'OnGuildWarFightBegin',       3 },
	{ 'GuildWarCompeleteFight',   'OnGuildWarCompeleteFight',   3 },
	{ 'QueryGuildWarEndInfo',     'OnQueryGuildWarEndInfo',     3 },
}

for _, k in ipairs(KY_VONG) do
	local khoa, hamNhan, nThamSo = k[1], k[2], k[3]
	check(R:has('G_GuildWarLogic.' .. khoa), 'dang ky ' .. khoa)
	local x = goi(khoa)
	check(x and x.obj == 'G_GuildWarLogic' and x.f == hamNhan,
		khoa .. ' -> ' .. hamNhan, x and x.f)
	check(x and x.n == nThamSo, khoa .. ': tra DUNG ' .. nThamSo .. ' tham so', x and x.n)
	check(x and type(x.args[1]) == 'table', khoa .. ': tham so 1 la BANG (eventList)', x and type(x.args[1]))
	check(x and x.args[2] == ErrorCode.Guild.GuildWarNoFightData,
		khoa .. ': ma 3538 (khong du bang de mo)', x and x.args[2])
end

io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
