-- _thu_dau_truong_con.lua — bộ thử cho `offline/handlers/dau_truong_con.lua` (4 khoá).
-- Chạy: `python _thu_nha_cua.py _thu_dau_truong_con.lua`.
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
    function R:getFor(obj, f)
        if obj ~= nil and obj ~= '' and self.handlers[obj .. '.' .. f] then
            return self.handlers[obj .. '.' .. f]
        end
        return self.handlers[f]
    end
    OfflineRouter = R; return R
end

ErrorCode = { Arenal = {
    GetUserArenaDataFaild = 2306, GetRandomGoodsListFaild = 2311,
    GetRefreshGoodsCostFaild = 2320, NoEnoughHonor = 2319,
} }

ARENA = { UserHonnor = 100, RefreshGoodsCount = 0, GoodsList = nil }
RSP = {}
g_CUIGameRPCManager = {}
function g_CUIGameRPCManager:OnReciveResponse(...)
    RSP[#RSP + 1] = { n = select('#', ...), ... }
end

G_ArenaDataManager = {
    GetUserArena = function (self) return true, ARENA end,
    GetUserArenaHonnor = function (self) return true, ARENA.UserHonnor end,
    AddUserArenaHonnor = function (self, d)
        if ARENA.UserHonnor + d < 0 then return false end
        ARENA.UserHonnor = ARENA.UserHonnor + d
        return true
    end,
    SetUserArenaGoodsList = function (self, ds) ARENA.GoodsList = ds; return true end,
    SetLastRefreshGoodsListTime = function (self, t) ARENA.LastRefreshGoodsListTime = t; return true end,
    SetRefreshGoodsCount = function (self, n) ARENA.RefreshGoodsCount = n; return true end,
}
G_ArenaLogic = {
    GetRefreshHonour = function (self)
        local n = ARENA.RefreshGoodsCount or 0
        if n == 0 then return true, 10 end
        if n == 1 then return true, 50 end
        if n == 2 then return true, 100 end
        return true, 100 + (n - 2) * 50
    end,
}
G_GameWorld = { GetServerTime = function (self) return 1000 end }
G_ConfigManager = {
    GetCommonConfigWithName = function (self, ten)
        if ten == 'GameArenaGoodsCrateConfig' then
            return { { Range = 1, GoodsList = { 1, 2 } }, { Range = 1, GoodsList = { 3 } } }
        end
        if ten == 'GameArenaGoodsConfig' then
            return { ['1'] = { cost = 10 }, ['2'] = { cost = 20 }, ['3'] = { cost = 30 } }
        end
        return nil
    end,
}
G_HeroLogic = {
    GetHeroWithID = function (self, id)
        if tonumber(id) == 25 then return true, { UserHeroID = 25, HeroLevel = 90 } end
        return false, nil
    end,
}
G_MagicWeaponLogic = { GetMagicWeaponData = function (self) return true, { STAR = {}, STRENGTHEN = {} } end }
G_DataManager = {
    GetUserDataWithName = function (self, ten)
        if ten == 'GameUserEquipment' then return 0, { ['25'] = { ['1'] = { EquipPartID = 1 } } } end
        if ten == 'GameUserSkill' then return 0, { ['25'] = { ['1'] = 1001 } } end
        if ten == 'GameUserBaseInfo' then return 0, { CharacterName = 'Offline' } end
        return 0, {}
    end,
}

dofile([[__SC__/offline/handlers/dau_truong_con.lua]])
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
    for _, v in ipairs(c.calls) do
        if v.obj ~= 'g_CUIGameRPCManager' then return v, c end
    end
    return c.calls[#c.calls], c
end
local function maCuoi() return RSP[#RSP] and RSP[#RSP][3] end

--=========================================================== 1. ĐĂNG KÝ
io.write('\n-- 1. dang ky 4 khoa\n')
local KHOA = {
    'ClientRefreshArenaGoodsWithHonor', 'ClientGetArenaHeroInfo',
    'ClientCheckArenaRecord', 'GetArenaDetailByUid',
}
local thieu = {}
for _, k in ipairs(KHOA) do
    if not R:has('G_ArenaLogic.' .. k) then thieu[#thieu + 1] = k end
end
check(#thieu == 0, 'dang ky DU 4 khoa', table.concat(thieu, ', '))

--=========================================================== 2. LÀM MỚI BẰNG DANH VỌNG
io.write('\n-- 2. lam moi cua hang bang danh vong\n')
ARENA.UserHonnor = 100
ARENA.RefreshGoodsCount = 0
ARENA.GoodsList = nil
local x = goi('G_ArenaLogic.ClientRefreshArenaGoodsWithHonor')
check(x and x.f == 'OnRefreshArenaGoodsWithHonor' and type(x.args[1]) == 'table'
    and #x.args[1] > 0, 'lam moi -> OnRefreshArenaGoodsWithHonor(danh sach)')
check(ARENA.UserHonnor == 90, 'tru 10 danh vong (100 -> 90)', ARENA.UserHonnor)
check(ARENA.RefreshGoodsCount == 1, 'tang RefreshGoodsCount 1')
check(type(ARENA.GoodsList) == 'table' and #ARENA.GoodsList == 2, 'sinh 2 mon (2 nhom x 1)',
    ARENA.GoodsList and #ARENA.GoodsList)
check(ARENA.LastRefreshGoodsListTime == 1000, 'ghi moc lam moi')

ARENA.UserHonnor = 5
ARENA.RefreshGoodsCount = 1        -- giá 50
local nR = #RSP
goi('G_ArenaLogic.ClientRefreshArenaGoodsWithHonor')
check(#RSP > nR and maCuoi() == 2319, 'thieu danh vong -> 2319 NoEnoughHonor')
check(ARENA.UserHonnor == 5, 'that bai: KHONG tru danh vong')

--=========================================================== 3. TƯỚNG TRÊN BẢNG HẠNG
io.write('\n-- 3. thong tin tuong\n')
x = goi('G_ArenaLogic.ClientGetArenaHeroInfo', 1, 25)
check(x and x.f == 'OnGetArenaHeroInfo' and type(x.args[1]) == 'table'
    and x.args[1].HeroData.UserHeroID == 25, 'tuong 25 -> OnGetArenaHeroInfo')
check(x and type(x.args[1].EquipsData) == 'table' and x.args[1].EquipsData['1'] ~= nil,
    'co EquipsData cua tuong')
check(x and type(x.args[1].GameMagicWeapon) == 'table' and type(x.args[1].SkillList) == 'table',
    'co GameMagicWeapon + SkillList')

nR = #RSP
goi('G_ArenaLogic.ClientGetArenaHeroInfo', 2, 999)
check(#RSP > nR and maCuoi() == 2306, 'tuong khong co -> 2306')

--=========================================================== 4. HAI KHOÁ CÒN LẠI
io.write('\n-- 4. xem chien bao / chi tiet doi thu\n')
local c = ctxGia()
R.handlers['G_ArenaLogic.ClientCheckArenaRecord'](c)
check(#c.calls == 0, 'xem chien bao: KHONG tra loi')

local daChuyen = nil
R.handlers['G_ArenaLogic.ClientGetArenaDetailByUid'] = function (ctx, uid, robot)
    daChuyen = { uid = uid, robot = robot }
end
goi('G_ArenaLogic.GetArenaDetailByUid', 7, 99)
check(daChuyen and daChuyen.uid == 7 and daChuyen.robot == 99,
    'ten CU chuyen tiep nguyen tham so sang ClientGetArenaDetailByUid')

io.write('\nKET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
