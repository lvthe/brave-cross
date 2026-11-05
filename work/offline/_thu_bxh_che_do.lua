-- _thu_bxh_che_do.lua — bộ thử cho `offline/handlers/bang_xep_hang_che_do.lua`
-- (14 khoá BXH của chế độ ải đặc biệt).
-- Chạy: `python _thu_nha_cua.py _thu_bxh_che_do.lua`.
--
-- Đo: đăng ký 14 khoá, HÌNH PHẢN HỒI của từng khoá (số lượng tham số), dòng của mình
-- có đủ trường UI đọc (`Rank`, tên/cấp/ảnh, `power` + trường riêng chế độ), điểm lấy
-- từ THỐNG KÊ THẬT, và bảng rỗng khi chưa có bang (vẫn qua vì hai số là NUMBER).
package.path = [[__SC__/?.lua;__SC__/?/init.lua;]] .. package.path

local function ghi(a, b)
    local m = b
    if type(a) == 'string' then m = a end
    io.write('[log] ' .. tostring(m) .. '\n')
end
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

UID = 100001
BANG = { GuildId = 777, Name = 'Bang Thu' }
GUD = { GuildWarCoin = 1234 }
STATS = {
    MaxHJRQBatchCount = 7,
    TGZZChapterLevel = 3,
    TGZZChapterBestDamage = 45000,
    TGZZChapterBestCostTime = 90,
    DKChapterLevel = 2,
    DKChapterBestDamage = 12000,
    DKChapterBestCostTime = 60,
}
BASE = { CharacterName = 'Offline', Level = 90, Portrait = 'player000M', Gender = true }

OfflineBangHoi = {
    uid = function () return UID end,
    doc = function () return BANG end,
}
G_UserLogic = {
    GetStatisticsCommonData = function (self, k) return true, STATS[k] end,
    GetBaseInfo = function (self) return true, BASE end,
}
G_RankLogic = {
    GetUserHotData = function (self)
        return true, {
            CharacterName = 'Offline', Level = 90, Gender = true,
            UserArenaFightCapacity = 5555,
        }
    end,
}
G_DataManager = {
    GetUserDataWithName = function (self, ten)
        if ten == 'GameUserGuildData' then return 0, GUD end
        return 0, {}
    end,
}

dofile([[__SC__/offline/handlers/bang_xep_hang_che_do.lua]])
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
local function goi(khoa, ...)
    local c = ctxGia()
    local h = R.handlers[khoa]
    if h == nil then return nil end
    h(c, ...)
    return c.calls[#c.calls]
end

--=========================================================== 1. ĐĂNG KÝ
io.write('\n-- 1. dang ky 14 khoa\n')
local KHOA = {
    { 'ClientGetSelfHJRQRankScore', 'OnGetSelfHJRQRankScore' },
    { 'ClientGetSelfSYZLBRankScore', 'OnGetSelfSYZLBRankScore' },
    { 'ClientGetSelfSCSZLRankScore', 'OnGetSelfSCSZLRankScore' },
    { 'ClientGetSelfDJSJFRankScore', 'OnGetSelfDJSJFRankScore' },
    { 'ClientGetSelfXZWCRankScore', 'OnGetSelfXZWCRankScore' },
    { 'ClientGetHjrqRank', 'OnGetHjrqRank' },
    { 'ClientGetSYZLBRank', 'OnGetSYZLBRank' },
    { 'ClientGetSCSZLRank', 'OnGetSCSZLRank' },
    { 'ClientGetDJSJFRank', 'OnGetDJSJFRank' },
    { 'ClientGetXZWCRank', 'OnGetXZWCRank' },
    { 'ClientGetTGZZRank', 'OnGetTGZZRank' },
    { 'ClientGetDKRank', 'OnGetDKRank' },
    { 'ClientGetArenaDefendPowerRank', 'OnGetArenaDefendPowerRank' },
    { 'ClientGetGuildWarScoreRank', 'OnGetGuildWarScoreRank' },
}
local thieu = {}
for _, k in ipairs(KHOA) do
    if not R:has('G_RankLogic.' .. k[1]) then thieu[#thieu + 1] = k[1] end
end
check(#thieu == 0, 'dang ky DU 14 khoa', table.concat(thieu, ', '))

--=========================================================== 2. ĐIỂM CỦA MÌNH
io.write('\n-- 2. diem cua minh: dung so luong tham so\n')
local x = goi('G_RankLogic.ClientGetSelfHJRQRankScore', 'FB_E_HJRQ')
check(x and x.obj == 'G_RankLogic' and x.f == 'OnGetSelfHJRQRankScore' and x.n == 2,
    'HJRQ -> OnGetSelfHJRQRankScore(costTime, wave) HAI so')
check(x and x.args[1] == 0 and x.args[2] == 7, 'HJRQ: wave = MaxHJRQBatchCount (7)')

x = goi('G_RankLogic.ClientGetSelfSYZLBRankScore', 'FB_E_SYZLB')
check(x and x.f == 'OnGetSelfSYZLBRankScore' and x.n == 1, 'SYZLB -> mot so')
x = goi('G_RankLogic.ClientGetSelfSCSZLRankScore')
check(x and x.f == 'OnGetSelfSCSZLRankScore' and x.n == 1, 'SCS -> mot so')
x = goi('G_RankLogic.ClientGetSelfDJSJFRankScore')
check(x and x.f == 'OnGetSelfDJSJFRankScore' and x.n == 1, 'DJSJF -> mot so')
x = goi('G_RankLogic.ClientGetSelfXZWCRankScore', 'FB_E_XZWC')
check(x and x.f == 'OnGetSelfXZWCRankScore' and x.n == 1, 'XZWC -> mot so')

--=========================================================== 3. BẢNG XẾP HẠNG
io.write('\n-- 3. bang xep hang: mot dong cua minh, du truong\n')
local function motDong(khoa, tenHam, truongRieng, soThamSo)
    local y = goi(khoa, 'FB_E_X')
    check(y and y.f == tenHam and y.n == soThamSo, khoa .. ' -> ' .. tenHam)
    local d = nil
    if y and type(y.args[1]) == 'table' then
        for _, v in pairs(y.args[1]) do d = v break end
    end
    check(type(d) == 'table' and d.Rank == 1 and type(d.CharacterName) == 'string'
        and type(d.Level) == 'number' and d.power == 5555,
        tenHam .. ': dong co Rank/ten/cap/power', d and tostring(d.Rank))
    if truongRieng then
        check(type(d) == 'table' and d[truongRieng] ~= nil,
            tenHam .. ': co truong rieng ' .. truongRieng, d and tostring(d[truongRieng]))
    end
    return y, d
end

local y, d = motDong('G_RankLogic.ClientGetHjrqRank', 'OnGetHjrqRank', 'wave', 2)
check(y and y.args[2] == 'FB_E_X', 'HJRQ: giu chapterKey o tham so 2')
check(d and d.wave == 7 and d.costTime == 0, 'HJRQ: wave 7, costTime 0')

motDong('G_RankLogic.ClientGetSYZLBRank', 'OnGetSYZLBRank', 'costTime', 1)
motDong('G_RankLogic.ClientGetSCSZLRank', 'OnGetSCSZLRank', 'killCount', 1)
motDong('G_RankLogic.ClientGetDJSJFRank', 'OnGetDJSJFRank', 'damage', 1)
motDong('G_RankLogic.ClientGetXZWCRank', 'OnGetXZWCRank', 'costTime', 1)

y, d = motDong('G_RankLogic.ClientGetTGZZRank', 'OnGetTGZZRank', 'level', 1)
check(d and d.level == 3 and d.damage == 45000, 'TGZZ: level 3, damage 45000')
y, d = motDong('G_RankLogic.ClientGetDKRank', 'OnGetDKRank', 'level', 1)
check(d and d.level == 2 and d.damage == 12000, 'DK: level 2, damage 12000')

--=========================================================== 4. BXH KHÁC
io.write('\n-- 4. phong thu dau truong + ho phu\n')
x = goi('G_RankLogic.ClientGetArenaDefendPowerRank')
check(x and x.f == 'OnGetArenaDefendPowerRank' and x.n == 3, 'phong thu -> BA tham so')
check(type(x.args[1]) == 'table' and x.args[2] == 1 and x.args[3] == 1, 'phong thu: bang + hang 1/1')

x = goi('G_RankLogic.ClientGetGuildWarScoreRank', 777)
check(x and x.f == 'OnGetGuildWarScoreRank' and x.n == 3, 'ho phu -> BA tham so')
local row = x.args[1] and x.args[1]['777']
check(type(row) == 'table' and row.Rank == 1 and row.Score == 1234 and row.GuildName == 'Bang Thu',
    'ho phu: 1 dong bang minh, Score = GuildWarCoin (1234)')

BANG = nil
x = goi('G_RankLogic.ClientGetGuildWarScoreRank', 0)
check(x and x.args[2] == 0 and x.args[3] == 0 and next(x.args[1]) == nil,
    'chua co bang -> bang rong, hang 0/0')

io.write('\nKET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
