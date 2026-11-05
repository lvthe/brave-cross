-- _thu_dau_truong_tran.lua — bộ thử cho `offline/handlers/dau_truong_tran.lua`
-- (chạy bằng `python _thu_nha_cua.py _thu_dau_truong_tran.lua`).
package.path = [[__SC__/?.lua;__SC__/?/init.lua;]] .. package.path

local function ghi(m) io.write('[log] ' .. tostring(m) .. '\n') end
package.preload['offline.log'] = function ()
    local L = { info = ghi, warn = ghi, err = ghi }; OfflineLog = L; return L
end
package.preload['offline.store'] = function ()
    local S = { TABLES = {}, data = {}, dirty = false }
    function S:syncFromClient() self.dongBo = (self.dongBo or 0) + 1 end
    OfflineStore = S; return S
end
package.preload['offline.router'] = function ()
    local R = { handlers = {} }
    function R:on(k, f) self.handlers[k] = f end
    function R:has(k) return self.handlers[k] ~= nil end
    OfflineRouter = R; return R
end

-- Cấu hình giả: đúng hình dạng bản thật (khoá "Groups " hỏng + chín khoá hỏng dấu cách).
local CFG = {
    GameArenaConfig = { WinHonour = 20, LoseHonour = 10 },
    GameArenaRobotConfig = {
        ['1'] = {
            Uid = 3578,
            FightData = {
                Data = {
                    ['25'] = { ['Min Ap'] = 44, ['MaxA p'] = 187, ['CriticalStr ike'] = 0.024,
                               [' MaxAttackDistance'] = 350, Name = 'Player01', HP = 1477 },
                },
                ['Groups '] = { { PosX = 13, PosY = 0, Soldiers = { { Data = '25', NpcID = 25, Num = 1 } } } },
            },
        },
    },
}
G_ConfigManager = {}
function G_ConfigManager:GetCommonConfigWithName(ten) return CFG[ten] end

G_UserLogic = {}
local BASE = { CharacterName = 'Minh', Gender = true, Level = 40, HeroID = 25,
              UserArenaFightCapacity = 5000 }
function G_UserLogic:GetBaseInfo() return true, BASE end

local UA = { Ranking = 1000, UserHonnor = 0, FightRecords = {} }
G_ArenaDataManager = {}
function G_ArenaDataManager:GetUserArena() return true, UA end
function G_ArenaDataManager:AddUserArenaHonnor(n) UA.UserHonnor = UA.UserHonnor + n; return true end
function G_ArenaDataManager:GetUserArenaHonnor() return true, UA.UserHonnor end
function G_ArenaDataManager:SetArenaRanking(r) UA.Ranking = r; return true end
function G_ArenaDataManager:SetUserArena(u) UA = u; return true end

dofile([[__SC__/offline/handlers/dau_truong_tran.lua]])
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

check(R:has('G_ArenaLogic.ArenaFightRanking'), 'dang ky ArenaFightRanking')
check(R:has('G_ArenaLogic.CompeleteArenaFight'), 'dang ky CompeleteArenaFight')
check(R:has('G_ArenaLogic.GetUserArenaFightRecord'), 'dang ky GetUserArenaFightRecord')

-- 1. vào trận
local c1 = ctxGia()
R.handlers['G_ArenaLogic.ArenaFightRanking'](c1, { Uid = 3578, HeroList = { 25, 13 }, Ranking = 1000 })
local k1 = c1.calls[1]
local g = k1 and k1.args[1]
check(k1 and k1.f == 'OnArenaFightRanking' and type(g) == 'table', 'tra OnArenaFightRanking(gói)')
check(type(g.FightData) == 'table' and type(g.FightData.BaseInfo) == 'table'
      and g.FightData.BaseInfo.CharacterName == 'Robot 3578',
      'FightData co BaseInfo dung ten robot', g.FightData.BaseInfo.CharacterName)
check(g.FightData.Data['25'].CriticalStrike == 0.024 and g.FightData.Data['25'].MinAp == 44
      and g.FightData.Data['25'].MaxAttackDistance == 350,
      'chin khoa HONG DAU CACH da doi ve ten dung',
      g.FightData.Data['25'].CriticalStrike)
check(g.FightData.Groups ~= nil and #g.FightData.Groups == 1 and g.FightData['Groups '] == nil,
      'khoa "Groups " da chuan hoa thanh Groups')
check(type(g.FightHeroList) == 'table' and #g.FightHeroList == 2 and g.FightHeroList[1] == 25,
      'FightHeroList = TUONG CUA MINH (khong phai cua dich)', #g.FightHeroList)
check(type(g.BattleRandom) == 'number', 'co BattleRandom', g.BattleRandom)

-- 2. thắng: +20 danh vọng, hạng -1
local c2 = ctxGia()
R.handlers['G_ArenaLogic.CompeleteArenaFight'](c2, { bResult = true })
local r2 = c2.calls[1].args[1]
check(r2.bResult == true and r2.Ranking == 999 and r2.UserHonnor == 20,
      'thang: {bResult, Ranking 999, UserHonnor 20}', r2)

-- 3. thua: +10, hạng KHONG doi
local c3 = ctxGia()
R.handlers['G_ArenaLogic.CompeleteArenaFight'](c3, { bResult = false })
local r3 = c3.calls[1].args[1]
check(r3.bResult == false and r3.Ranking == 999 and r3.UserHonnor == 30,
      'thua: +10 danh vong, hang giu nguyen', r3)

-- 4. chien bao: moi nhat dung dau, co IsTarget
local c4 = ctxGia()
R.handlers['G_ArenaLogic.GetUserArenaFightRecord'](c4)
local ds = c4.calls[1].args[1]
check(#ds == 2 and ds[1].Result == false and ds[2].Result == true and ds[1].IsTarget == true,
      'chien bao: moi nhat dau, co IsTarget', #ds)

-- 5. thieu cau hinh robot -> 2306
CFG.GameArenaRobotConfig = nil
local c5 = ctxGia()
R.handlers['G_ArenaLogic.ArenaFightRanking'](c5, { HeroList = {} })
check(c5.calls[1].args[3] == 2306,
      'thieu cau hinh -> 2306 (dong lop tai)', c5.calls[1].args)

check(OfflineStore.dongBo and OfflineStore.dongBo > 0, 'co goi syncFromClient')
io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
