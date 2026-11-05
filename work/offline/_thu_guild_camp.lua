-- _thu_guild_camp.lua — bộ thử cho `offline/handlers/guild_camp.lua` (8 khoá doanh trại).
-- Chạy: `python _thu_nha_cua.py _thu_guild_camp.lua`.
-- Đồng hồ được GHIM để đo đúng cửa giờ (tưới 9–21, củi 20–21) và hồi.
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

ErrorCode = { Guild = {
    GuildNotExist = 3501, GuildNotActivityTime = 3519, GuildDonateCdTime = 3533,
} }

-- Đồng hồ GHIM: 2026-11-02 10:00 (trong cửa tưới, ngoài cửa củi).
local FIX = os.time({ year = 2026, month = 11, day = 2, hour = 10, min = 0, sec = 0 })
local os_date, os_time = os.date, os.time
os.time = function (t) if t ~= nil then return os_time(t) end return FIX end
os.date = function (fmt, t) return os_date(fmt, t or FIX) end

BANG = { GuildId = 123, Name = 'Bang Thu' }
GUD = {
    CampTreeGrow = 0, UserLastWaterTime = 0, UserTreeRewardCount = 0,
    ReceivedTreeRewardCount = 0, UserFireWoodCount = 0, UserLastFireWoodTime = 0,
}
EVENT = {}
RSP = {}
g_CUIGameRPCManager = {}
function g_CUIGameRPCManager:OnReciveResponse(...)
    RSP[#RSP + 1] = { n = select('#', ...), ... }
end

OfflineBangHoi = {
    uid = function () return 100001 end,
    doc = function () return BANG end,
}
G_DataManager = {
    GetUserDataWithName = function (self, ten)
        if ten == 'GameUserGuildData' then return 0, GUD end
        if ten == 'GameUserHero' then return 0, { ['25'] = {} } end
        return 0, {}
    end,
}
G_UserLogic = {
    GetBaseInfo = function (self) return true, { CharacterName = 'Offline', Level = 90 } end,
}
G_HeroLogic = {
    GetCharacterID = function (self) return true, 25 end,
    GetHeroWithID = function (self, id) return true, { UserHeroID = id, HeroLevel = 90 } end,
}
G_EventManager = {
    PostDataEvent = function (self, d, ten, khoa) EVENT[#EVENT + 1] = { ten = ten, khoa = khoa } end,
}

dofile([[__SC__/offline/handlers/guild_camp.lua]])
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
        if obj == 'g_CUIGameRPCManager' then
            local o = _G[obj]
            if type(o) == 'table' and type(o[f]) == 'function' then o[f](o, ...) end
        end
    end
    return c
end
local function goi(khoa, ...)
    local c = ctxGia()
    local h = R.handlers[khoa]
    if h == nil then return nil end
    h(c, ...)
    return c.calls[1], c
end

--=========================================================== 1. ĐĂNG KÝ
io.write('\n-- 1. dang ky 8 khoa\n')
local KHOA = {
    'ClientEnterGuildCamp', 'ClientLeaveGuildCamp', 'ClientUserMoveTo', 'ClientDoAction',
    'ClientGetGuildCampData', 'ClientWaterTree', 'ClientGetWaterTreeReward', 'ClientFirewood',
}
local thieu = {}
for _, k in ipairs(KHOA) do
    if not R:has('G_GuildCampLogic.' .. k) then thieu[#thieu + 1] = k end
end
check(#thieu == 0, 'dang ky DU 8 khoa', table.concat(thieu, ', '))

--=========================================================== 2. VÀO / RỜI / DI CHUYỂN
io.write('\n-- 2. vao/roi/di chuyen\n')
local x = goi('G_GuildCampLogic.ClientEnterGuildCamp', {})
check(x and x.obj == 'G_GuildCampLogic' and x.f == 'OnEnterGuildCamp'
    and x.args[1] == 0 and x.args[2]['100001'] ~= nil, 'vao doanh trai -> 1 nguoi (chinh minh)')
check(x and x.args[2]['100001'].GameUserBaseInfo.CharacterName == 'Offline', 'co BaseInfo')

BANG = nil
x = goi('G_GuildCampLogic.ClientEnterGuildCamp', {})
check(x and x.args[1] == 3501, 'chua co bang -> 3501')
BANG = { GuildId = 123, Name = 'Bang Thu' }

x = goi('G_GuildCampLogic.ClientUserMoveTo', 3, 4, 1)
check(x and x.f == 'OnUserMoveTo' and x.args[1] == 100001 and x.args[2] == 3 and x.args[4] == 1,
    'di chuyen -> echo OnUserMoveTo(uid,x,y,dir)')
x = goi('G_GuildCampLogic.ClientDoAction', 'sit')
check(x and x.f == 'OnUserDoAction' and x.args[1] == 100001 and x.args[2] == 'sit',
    'hanh dong -> echo OnUserDoAction')
x = goi('G_GuildCampLogic.ClientLeaveGuildCamp')
check(x and x.f == 'OnUserLeaveGuildCamp' and x.args[1] == 100001, 'roi -> OnUserLeaveGuildCamp(uid)')

--=========================================================== 3. TRẠNG THÁI
io.write('\n-- 3. trang thai doanh trai\n')
x = goi('G_GuildCampLogic.ClientGetGuildCampData')
check(x and x.f == 'OnGetGuildCampData' and x.args[1] == 0, 'trang thai -> err 0')
check(x and x.args[2].CampData.Tree.GrowUpStateCount == 0
    and x.args[2].UserData.UserTreeRewardCount == 0, 'cay 0, thuong 0')

--=========================================================== 4. TƯỚI CÂY
io.write('\n-- 4. tuoi cay (10:00, hoi 120 phut)\n')
FIX = os_time({ year = 2026, month = 11, day = 2, hour = 10, min = 0, sec = 0 })
GUD.UserLastWaterTime = 0
x = goi('G_GuildCampLogic.ClientWaterTree')
check(x and x.f == 'OnSelfWaterTree' and x.args[1] == 0 and x.args[2].GrowUpStateCount == 1,
    'tuoi lan 1 -> GrowUp 1')
check(GUD.CampTreeGrow == 1 and GUD.UserLastWaterTime == FIX, 'luu grow + thoi diem')

x = goi('G_GuildCampLogic.ClientWaterTree')
check(x and x.args[1] == 3533, 'tuoi lai ngay -> 3533 (dang hoi)')

FIX = FIX + 121 * 60
x = goi('G_GuildCampLogic.ClientWaterTree')
check(x and x.args[1] == 0 and x.args[2].GrowUpStateCount == 2, 'sau 121 phut -> tuoi duoc lan 2')

FIX = os_time({ year = 2026, month = 11, day = 2, hour = 22, min = 0, sec = 0 })
x = goi('G_GuildCampLogic.ClientWaterTree')
check(x and x.args[1] == 3519, 'ngoai gio 9-21 -> 3519')

--=========================================================== 5. CÂY CHÍN + NHẬN THƯỞNG
io.write('\n-- 5. cay chin / nhan thuong\n')
GUD.CampTreeGrow = 25
GUD.UserTreeRewardCount = 2
GUD.ReceivedTreeRewardCount = 0
goi('G_GuildCampLogic.ClientGetWaterTreeReward')
check(GUD.ReceivedTreeRewardCount == 2, 'danh dau da nhan 2 luot thuong cay')
check(#RSP == 0, 'KHONG goi ham nhan nao (client khong co)')

--=========================================================== 6. THÊM CỦI
io.write('\n-- 6. them cui (20:00-21:00, 3 lan, hoi 120 giay)\n')
FIX = os_time({ year = 2026, month = 11, day = 2, hour = 10, min = 0, sec = 0 })
GUD.UserFireWoodCount = 0
GUD.UserLastFireWoodTime = 0
GUD.CampFirewoodDay = nil
goi('G_GuildCampLogic.ClientFirewood')
check(GUD.UserFireWoodCount == 0, '10:00 ngoai gio cui -> khong tang')

FIX = os_time({ year = 2026, month = 11, day = 2, hour = 20, min = 30, sec = 0 })
goi('G_GuildCampLogic.ClientFirewood')
check(GUD.UserFireWoodCount == 1, '20:30 -> them cui lan 1')
check(#EVENT > 0 and EVENT[#EVENT].khoa == 'UserFireWoodCount', 'phat DataEvent cho UI')

goi('G_GuildCampLogic.ClientFirewood')
check(GUD.UserFireWoodCount == 1, 'hoi 120 giay -> chua them duoc')

FIX = FIX + 121
goi('G_GuildCampLogic.ClientFirewood')
FIX = FIX + 121
goi('G_GuildCampLogic.ClientFirewood')
check(GUD.UserFireWoodCount == 3, 'du 3 lan/ngay')
goi('G_GuildCampLogic.ClientFirewood')
check(GUD.UserFireWoodCount == 3, 'lan 4 -> khong tang')

io.write('\nKET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
