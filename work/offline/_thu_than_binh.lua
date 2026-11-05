-- _thu_than_binh.lua — bộ thử cho `offline/handlers/than_binh.lua` (4 khoá thần binh).
-- Chạy: `python _thu_nha_cua.py _thu_than_binh.lua`.
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

cjson = { decode = function (s)
    if type(s) ~= 'string' then return nil end
    -- chuỗi trong bộ thử viết theo cú pháp Lua: [{PropID=…,PrizeResCount=…}]
    local f = loadstring or load
    local ok, fn = pcall(f, 'return ' .. s)
    if not ok then return nil end
    local ok2, t = pcall(fn)
    return ok2 and t or nil
end }
ErrorCode = { MagicWeapon = { DataException = 5001, SystemIsClosed = 5002,
    OverLevelLimit = 5003, ResourceIsNotEnough = 5004, OverExpLimit = 5005 } }

MW = { STAR = {}, STRENGTHEN = {} }
TUI = { [160] = 5, [161] = 5, [1] = 10, [200] = 1 }
GOLD = 1000
RSP = {}
g_CUIGameRPCManager = {}
function g_CUIGameRPCManager:OnReciveResponse(...)
    RSP[#RSP + 1] = { n = select('#', ...), ... }
end

G_DataManager = {
    GetUserDataWithName = function (self, ten) if ten == 'GameMagicWeapon' then return 0, MW end return 0, {} end,
    SetUserDataWithName = function (self, ten, t) MW = t; return true end,
}
G_HeroLogic = {
    GetHeroWithID = function (self, id) return true, { UserHeroID = id, HeroLevel = 50 } end,
}
G_ItemLogic = {
    GetItemCount = function (self, id) return true, TUI[tonumber(id)] or 0 end,
}
G_ItemDataManager = {
    ReduceItem = function (self, id, so)
        local have = TUI[tonumber(id)] or 0
        if have < so then return false end
        TUI[tonumber(id)] = have - so
        return true
    end,
}
G_UserLogic = {
    CostGold = function (self, n)
        if GOLD < n then return false, GOLD end
        GOLD = GOLD - n
        return true, GOLD
    end,
}
-- Bảng cường hoá: cấp n cần TotalExp = 50n.
local STRENGTH = {}
for lv = 1, 20 do STRENGTH[tostring(lv)] = { Level = lv, Exp = 50, TotalExp = 50 * lv,
    BreakResource = '{ {PropID=200,PrizeResCount=1} }' } end
G_ConfigManager = {
    GetStrengthConfig = function (self, part) return STRENGTH end,
    GetMagicWeaponStrengthConfigEx = function (self, cap, part) return STRENGTH[tostring(cap)] end,
    GetMagicWeaponRefineConfig = function (self, hero, part, star)
        if star > 3 then return nil end
        return { StarLevel = star, OpenNeedLevel = 37, CostGold = 100,
            CostResource = '{ {PropID=160,PrizeResCount=1} }' }
    end,
    GetCommonConfigWithName = function (self, ten)
        if ten == 'GameMagicWeaponItemExpConfig' then return { ['1'] = { Exp = 30 } } end
        return nil
    end,
}
G_MagicWeaponLogic = {
    GetEquipmentStarLevel = function (self, hero, part)
        local h = MW.STAR[tostring(hero)]
        local p = h and h[tostring(part)]
        return p and tonumber(p.star) or 0
    end,
    MapExpToLevel = function (self, part, exp)
        local lv = 0
        for i = 1, 20 do
            if exp < 50 * i then lv = i - 1; break end
            lv = i
        end
        return lv
    end,
}

dofile([[__SC__/offline/handlers/than_binh.lua]])
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
local KHOA = { 'ClientStarUp', 'ClientStarDown', 'ClientStrengthen', 'ClientBreakThrough' }
local thieu = {}
for _, k in ipairs(KHOA) do
    local fn = R.handlers['G_MagicWeaponProtocol.' .. k] or R.handlers[k]
    if fn == nil then thieu[#thieu + 1] = k end
end
check(#thieu == 0, 'dang ky DU 4 khoa', table.concat(thieu, ', '))

--=========================================================== 2. LÊN SAO
io.write('\n-- 2. len sao\n')
GOLD = 1000
TUI[160] = 5
local x = goi('G_MagicWeaponProtocol.ClientStarUp', { heroId = 25, equipmentType = 7 })
check(x and x.obj == 'g_SBProtocol' and x.f == 'OnStarUp', 'len sao -> g_SBProtocol.OnStarUp')
check(MW.STAR['25']['7'].star == 1 and GOLD == 900 and TUI[160] == 4,
    'sao 0->1, -100 vang, -1 mon 160')
check(MW.STAR['25']['7'].star == 1, 'luu sao')

TUI[160] = 0
local nR = #RSP
goi('G_MagicWeaponProtocol.ClientStarUp', { heroId = 26, equipmentType = 7 })
check(#RSP > nR and maCuoi() == 5004, 'thieu nguyen lieu -> 5004')
check(MW.STAR['26'] == nil, 'that bai: KHONG ghi sao')

MW.STAR['26'] = { ['7'] = { star = 3 } }
nR = #RSP
goi('G_MagicWeaponProtocol.ClientStarUp', { heroId = 26, equipmentType = 7 })
check(#RSP > nR and maCuoi() == 5003, 'da sao toi da -> 5003')

--=========================================================== 3. GIÁNG SAO
io.write('\n-- 3. giang sao\n')
x = goi('G_MagicWeaponProtocol.ClientStarDown', { heroId = 25, equipmentType = 7 })
check(x and x.f == 'OnStarDown' and MW.STAR['25']['7'].star == 0, 'giang sao 1 -> 0')

--=========================================================== 4. CƯỜNG HOÁ
io.write('\n-- 4. cuong hoa\n')
TUI[1] = 10
x = goi('G_MagicWeaponProtocol.ClientStrengthen',
    { heroId = 25, equipmentType = 7, costItem = { { id = 1, count = 2 } } })
check(x and x.f == 'OnStrengthen', 'cuong hoa -> OnStrengthen')
local e = MW.STRENGTHEN['25']['7']
check(e and e.exp == 60 and e.level == 1, 'exp 60, cap 1 (MapExpToLevel)',
    e and tostring(e.exp) .. '/' .. tostring(e.level))
check(e and e.breakThroughLevel == 5 and e.needToBreakThrough == false, 'tran 5, chua can dot pha')

-- Đẩy exp tới trần: thêm 2 món (60 exp) -> 120 exp -> cap 2 … tới trần 5.
TUI[1] = 10
for i = 1, 10 do
    goi('G_MagicWeaponProtocol.ClientStrengthen',
        { heroId = 25, equipmentType = 7, costItem = { { id = 1, count = 2 } } })
end
e = MW.STRENGTHEN['25']['7']
check(e.level == 5 and e.needToBreakThrough == true,
    'cham tran 5 -> CAN DOT PHA', e and tostring(e.level) .. '/' .. tostring(e.needToBreakThrough))

TUI[1] = 0
nR = #RSP
goi('G_MagicWeaponProtocol.ClientStrengthen',
    { heroId = 25, equipmentType = 7, costItem = { { id = 1, count = 1 } } })
check(#RSP > nR and maCuoi() == 5004, 'thieu nguyen lieu cuong hoa -> 5004')

--=========================================================== 5. ĐỘT PHÁ
io.write('\n-- 5. dot pha\n')
TUI[200] = 1
x = goi('G_MagicWeaponProtocol.ClientBreakThrough', { heroId = 25, equipmentType = 7 })
check(x and x.f == 'OnBreakThrough', 'dot pha -> OnBreakThrough')
e = MW.STRENGTHEN['25']['7']
check(e.breakThroughLevel == 10 and e.needToBreakThrough == false, 'tran 5 -> 10, het can dot pha')
check(TUI[200] == 0, 'tru 1 nguyen lieu dot pha')

TUI[200] = 0
e.level = 10
nR = #RSP
goi('G_MagicWeaponProtocol.ClientBreakThrough', { heroId = 25, equipmentType = 7 })
check(#RSP > nR and maCuoi() == 5004, 'thieu nguyen lieu dot pha -> 5004')

e.level = 3
nR = #RSP
goi('G_MagicWeaponProtocol.ClientBreakThrough', { heroId = 25, equipmentType = 7 })
check(#RSP > nR and maCuoi() == 5005, 'chua cham tran -> 5005')

io.write('\nKET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
