-- _thu_dau_truong_bxh.lua — bộ thử cho `offline/handlers/dau_truong_bxh.lua`
-- (chạy bằng `python _thu_nha_cua.py _thu_dau_truong_bxh.lua`).
package.path = [[__SC__/?.lua;__SC__/?/init.lua;]] .. package.path

local function ghi(m) io.write('[log] ' .. tostring(m) .. '\n') end
package.preload['offline.log'] = function ()
    local L = { info = ghi, warn = ghi, err = ghi }; OfflineLog = L; return L
end
package.preload['offline.store'] = function ()
    local S = { TABLES = {}, data = {}, dirty = false }
    function S:uid() return 42 end
    function S:syncFromClient() self.dongBo = (self.dongBo or 0) + 1 end
    OfflineStore = S; return S
end
package.preload['offline.router'] = function ()
    local R = { handlers = {} }
    function R:on(k, f) self.handlers[k] = f end
    function R:has(k) return self.handlers[k] ~= nil end
    OfflineRouter = R; return R
end

local UA = { Ranking = 777 }
G_ArenaDataManager = {}
function G_ArenaDataManager:GetUserArena() return true, UA end

G_UserLogic = {}
local BASE = { Uid = 42, CharacterName = 'Minh', Gender = true, Level = 30, HeroID = 25,
               UserFightCapacity = 4321, Portrait = 'p' }
function G_UserLogic:GetBaseInfo() return true, BASE end

G_HeroLogic = {}
function G_HeroLogic:GetHeroMap()
    return true, {
        ['25'] = { UserHeroID = 25, HeroLevel = 30 },
        ['13'] = { UserHeroID = 13, HeroLevel = 50 },
        ['1']  = { UserHeroID = 1,  HeroLevel = 10 },
        ['2']  = { UserHeroID = 2,  HeroLevel = 40 },
        ['3']  = { UserHeroID = 3,  HeroLevel = 20 },
        ['4']  = { UserHeroID = 4,  HeroLevel = 5 },
    }
end

dofile([[__SC__/offline/handlers/dau_truong_bxh.lua]])
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

check(R:has('G_ArenaLogic.GetWorldArenalRanking'), 'dang ky GetWorldArenalRanking')
check(R:has('G_ArenaLogic.GetArenaRankWithYesterday'), 'dang ky GetArenaRankWithYesterday')
check(R:has('G_ArenaLogic.ClientGetUserArenaData'), 'dang ky ClientGetUserArenaData')

-- 1. trang đầu: đúng MỘT dòng của mình, đủ trường
local c1 = ctxGia()
R.handlers['G_ArenaLogic.GetWorldArenalRanking'](c1, 1, 20)
local ds = c1.calls[1].args[1]
local d = ds[1]
check(#ds == 1 and d.RankID == 777 and d.Uid == 42, 'trang dau: 1 dong, RankID/Uid dung',
      d and (tostring(d.RankID) .. '/' .. tostring(d.Uid)))
check(d.BaseInfo.CharacterName == 'Minh' and d.BaseInfo.UserFightCapacity == 4321,
      'BaseInfo: ten + luc chien that', d.BaseInfo.CharacterName)
check(#d.HeroList == 5 and d.HeroList[1].UserHeroID == 13 and d.HeroList[5].UserHeroID == 1,
      'HeroList: 5 tuong MANH NHAT theo cap (13,2,25,3,1) — bo tuong cap 5', d.HeroList[1].UserHeroID)

-- 2. trang sau: rỗng (mot nguoi choi)
local c2 = ctxGia()
R.handlers['G_ArenaLogic.GetWorldArenalRanking'](c2, 21, 40)
check(#c2.calls[1].args[1] == 0, 'khoang 21..40: RONG (mot nguoi choi)', #c2.calls[1].args[1])

-- 3. BXH chung: ban do khoa uid chuoi + hang
local c3 = ctxGia()
R.handlers['G_ArenaLogic.GetArenaRankWithYesterday'](c3)
local k3 = c3.calls[1]
check(k3.f == 'OnGetArenaRankWithYesterday' and k3.args[1]['42'] ~= nil
      and k3.args[1]['42'].Rank == 777, 'ban do khoa uid CHUOI + Rank', k3.args[1]['42'] and k3.args[1]['42'].Rank)
check(k3.args[2] == 777 and k3.args[3] == 777, 'nSelfRank = nYesterdayRank = hang', { k3.args[2], k3.args[3] })

-- 4. du lieu dau truong: callback TOAN CUC nhan {err=0,data}
local c4 = ctxGia()
R.handlers['G_ArenaLogic.ClientGetUserArenaData'](c4)
local k4 = c4.calls[1]
check(k4.obj == '' and k4.f == 'OnGetUserArenaData' and k4.args[1].err == 0
      and k4.args[1].data == UA, 'ClientGetUserArenaData: (obj="", OnGetUserArenaData, {err=0,data})',
      k4.args[1].err)

io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
