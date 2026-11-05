-- _thu_dau_truong_chi_tiet.lua — bộ thử cho `handlers/dau_truong_chi_tiet.lua`
-- (chạy bằng `python _thu_nha_cua.py _thu_dau_truong_chi_tiet.lua`).
package.path = [[__SC__/?.lua;__SC__/?/init.lua;]] .. package.path

local function ghi(m) io.write('[log] ' .. tostring(m) .. '\n') end
package.preload['offline.log'] = function ()
    local L = { info = ghi, warn = ghi, err = ghi }; OfflineLog = L; return L
end
package.preload['offline.store'] = function ()
    return { TABLES = {}, data = {}, dirty = false }
end
package.preload['offline.router'] = function ()
    local R = { handlers = {} }
    function R:on(k, f) self.handlers[k] = f end
    function R:has(k) return self.handlers[k] ~= nil end
    OfflineRouter = R; return R
end

local CFG = {
    GameArenaRobotConfig = {
        ['1'] = {
            Uid = 3578,
            FightData = { Data = { ['25'] = { ['Min Ap'] = 44, ['D p'] = 54, Name = 'Player01' } } },
        },
    },
}
G_ConfigManager = {}
function G_ConfigManager:GetCommonConfigWithName(ten) return CFG[ten] end

G_UserLogic = {}
local BASE = { CharacterName = 'Minh', Gender = true, Level = 40, HeroID = 25,
               UserFightCapacity = 5000, Uid = 42 }
function G_UserLogic:GetBaseInfo() return true, BASE end

G_ArenaDataManager = {}
function G_ArenaDataManager:GetUserArena() return true, { Ranking = 777 } end

dofile([[__SC__/offline/handlers/dau_truong_chi_tiet.lua]])
local R = require('offline.router')

local dat, hong = 0, 0
local function check(ok, ten, ct)
    if ok then dat = dat + 1; io.write('  OK   ' .. ten .. '\n')
    else hong = hong + 1; io.write('  HONG ' .. ten .. (ct ~= nil and (' -> ' .. tostring(ct)) or '') .. '\n') end
end
local function ctxGia()
    local c = { calls = {} }
    function c:call(obj, f, ...)
        self.calls[#self.calls + 1] = { obj = obj, f = f, args = { ... } }
    end
    return c
end

check(R:has('G_ArenaLogic.ClientGetArenaDetailByUid'), 'dang ky ClientGetArenaDetailByUid')
check(R:has('G_ArenaLogic.ClientGetUserArenaFightData'), 'dang ky ClientGetUserArenaFightData')

-- 1. chi tiet
local c1 = ctxGia()
R.handlers['G_ArenaLogic.ClientGetArenaDetailByUid'](c1, 3578, nil)
local d = c1.calls[1].args[1]
check(c1.calls[1].f == 'OnGetArenaDetailByUid' and type(d) == 'table', 'tra OnGetArenaDetailByUid(goi)')
check(d.ArenaRank == 777 and d.UserFightCapacity == 5000, 'co ArenaRank + UserFightCapacity',
      { d.ArenaRank, d.UserFightCapacity })
check(type(d.ArenaHeroMap) == 'table' and d.ArenaHeroMap['25'] ~= nil,
      'ArenaHeroMap co tuong 25')
local h = d.ArenaHeroMap['25']
check(h.UserHeroID == 25 and h.HeroLevel == 40 and h.HeroQuality == 1 and h.IsLock == false,
      'ba truong DAT cho UI ve (UserHeroID/HeroLevel/HeroQuality)', { h.UserHeroID, h.HeroLevel })
check(h.MinAp == 44 and h.Dp == 54 and h['Min Ap'] == nil,
      'khoa hong dau cach da doi ten', h.MinAp)

-- 2. fight data: callback TOAN CUC, data.FightData
local c2 = ctxGia()
R.handlers['G_ArenaLogic.ClientGetUserArenaFightData'](c2, 3578)
local k2 = c2.calls[1]
check(k2.obj == '' and k2.f == 'OnGetUserArenaFightData' and k2.args[1].err == 0
      and type(k2.args[1].data.FightData) == 'table',
      'ClientGetUserArenaFightData: (obj="", ..., {err=0,data.FightData})', k2.f)
check(k2.args[1].data.FightData.BaseInfo.CharacterName == 'Robot 3578',
      'FightData.BaseInfo dung ten robot', k2.args[1].data.FightData.BaseInfo.CharacterName)

-- 3. thieu cau hinh -> 2306
CFG.GameArenaRobotConfig = nil
local c3 = ctxGia()
R.handlers['G_ArenaLogic.ClientGetArenaDetailByUid'](c3, 1, nil)
check(c3.calls[1].args[3] == 2306, 'thieu cau hinh -> 2306', c3.calls[1].args)

io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
