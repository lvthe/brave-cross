-- _thu_thien_menh.lua — bộ thử cho `offline/handlers/thien_menh.lua`
-- (chạy bằng `python _thu_nha_cua.py _thu_thien_menh.lua`).
--
-- Đo bốn chỗ dễ sai nhất: giá riêng theo tướng (`CostFragmentPlus`), trừ ĐÚNG mảnh của
-- tướng ấy, cửa "đã cấp tối đa", và đặt lại (giá kim cương + xoá hết cấp).
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

ErrorCode = {
    OK = 0,
    UnknowError = 1,
    ArgError = 2,
    Resource = { NoEnoughResource = 1702 },
    Hero = {
        NotFindHero = 1301,
        GetGrowthConfigFail = 1305,
        SetHeroFragmentFail = 1309,
        LimitGrowth = 1316,
        HeroFragmentNotEnough = 1332,
        FateConditionLimit = 1333,
    },
}

-- ============================================================ GIẢ LẬP
CFG = {
    qinglong = {
        ['1'] = { CostFragment = 3 },
        ['2'] = { CostFragment = 3, CostFragmentPlus = { ['92'] = 20 } },
    },
}
G_ConfigManager = {}
function G_ConfigManager:GetGameHeroSkyFateConfig() return CFG end
function G_ConfigManager:GetCommonConfigWithName(ten)
    if ten == 'SkyFateResetPrice' then return { 888 } end
    return nil
end

HERO = { UserHeroID = 92, SkyFate = {}, HeroFragment = 10 }
G_HeroLogic = {}
G_HeroLogic.KHONG_CO = false
function G_HeroLogic:GetHeroWithID(id)
    if self.KHONG_CO then return false end
    return true, HERO
end
function G_HeroLogic:AddHeroFragment(id, delta, from)
    self.DA_GOI = { id = id, delta = delta }
    if (HERO.HeroFragment or 0) + delta < 0 then return false end
    HERO.HeroFragment = (HERO.HeroFragment or 0) + delta
    return true
end

DIAMOND = 5000
G_UserLogic = {}
function G_UserLogic:CostDiamond(n, from)
    if DIAMOND < n then return false end
    DIAMOND = DIAMOND - n
    return true
end

dofile([[__SC__/offline/handlers/thien_menh.lua]])
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
local function datLai()
    HERO.SkyFate, HERO.HeroFragment = {}, 10
    DIAMOND = 5000
    G_HeroLogic.KHONG_CO = false
    G_HeroLogic.DA_GOI = nil
    OfflineStore.dongBo = 0
end
local function maCuoi(c)
    local x = c.calls[#c.calls]
    return x and x.args[1], x
end

local KU = 'G_HeroLogic.ClientUpdateHeroSkyFate'
local KR = 'G_HeroLogic.ClientResetHeroSkyFate'

-- ============================================================ 1. ĐĂNG KÝ
check(R:has(KU), 'dang ky ' .. KU)
check(R:has(KR), 'dang ky ' .. KR)
check(type(OfflineThienMenh) == 'table', 'co bang OfflineThienMenh')

-- ============================================================ 2. NÂNG CẤP OK (cấp 0 -> 1)
datLai()
local c2 = ctxGia()
R.handlers[KU](c2, 92, 'qinglong')
local ma2, x2 = maCuoi(c2)
check(HERO.SkyFate.qinglong == 1, 'cap 0 -> 1', HERO.SkyFate.qinglong)
check(HERO.HeroFragment == 7, 'tru DUNG 3 manh (CostFragment cua cap 1)', HERO.HeroFragment)
check(x2 and x2.obj == 'G_HeroLogic' and x2.f == 'OnUpdateHeroSkyFate' and ma2 == 0,
      'tra OnUpdateHeroSkyFate(0)', x2 and (x2.f .. '/' .. tostring(ma2)))
check(OfflineStore.dongBo >= 1, 'co dong bo file luu')

-- ============================================================ 3. GIÁ RIÊNG THEO TƯỚNG
datLai()
HERO.HeroFragment = 30
local c3 = ctxGia()
R.handlers[KU](c3, 92, 'qinglong')      -- 0 -> 1, giá 3
R.handlers[KU](c3, 92, 'qinglong')      -- 1 -> 2, giá RIÊNG 20 cho tướng 92
check(HERO.SkyFate.qinglong == 2, 'len cap 2', HERO.SkyFate.qinglong)
check(HERO.HeroFragment == 7, 'tru 3 roi 20 (CostFragmentPlus[92] duoc uu tien)',
      HERO.HeroFragment)

-- ============================================================ 4. THIẾU MẢNH
datLai()
HERO.HeroFragment = 1
local c4 = ctxGia()
R.handlers[KU](c4, 92, 'qinglong')
local ma4 = maCuoi(c4)
check(ma4 == ErrorCode.Hero.HeroFragmentNotEnough, 'thieu manh -> ma 1332', ma4)
check(HERO.SkyFate.qinglong == nil, 'thieu manh -> KHONG len cap')
check(HERO.HeroFragment == 1, 'thieu manh -> KHONG tru gi', HERO.HeroFragment)

-- ============================================================ 5. ĐÃ CẤP TỐI ĐA
datLai()
HERO.HeroFragment = 100
HERO.SkyFate.qinglong = 2
local c5 = ctxGia()
R.handlers[KU](c5, 92, 'qinglong')
local ma5 = maCuoi(c5)
check(ma5 == ErrorCode.Hero.LimitGrowth, 'cap toi da -> ma 1316', ma5)
check(HERO.HeroFragment == 100, 'cap toi da -> khong tru manh')

-- ============================================================ 6. LOẠI KHÔNG CÓ / KHÔNG CÓ TƯỚNG
datLai()
local c6 = ctxGia()
R.handlers[KU](c6, 92, 'khong_co_loai_nay')
check(maCuoi(c6) == ErrorCode.Hero.GetGrowthConfigFail, 'loai la -> ma 1305', maCuoi(c6))
datLai()
G_HeroLogic.KHONG_CO = true
local c6b = ctxGia()
R.handlers[KU](c6b, 99, 'qinglong')
check(maCuoi(c6b) == ErrorCode.Hero.NotFindHero, 'khong co tuong -> ma 1301', maCuoi(c6b))
G_HeroLogic.KHONG_CO = false

-- ============================================================ 7. ĐẶT LẠI OK
datLai()
HERO.SkyFate = { qinglong = 2 }
local c7 = ctxGia()
R.handlers[KR](c7, 92)
local ma7, x7 = maCuoi(c7)
check(ma7 == 0 and x7 and x7.f == 'OnResetHeroSkyFate', 'tra OnResetHeroSkyFate(0)',
      x7 and (x7.f .. '/' .. tostring(ma7)))
check(next(HERO.SkyFate) == nil, 'dat lai -> xoa het cap thien menh')
check(DIAMOND == 5000 - 888, 'tru DUNG 888 kim cuong (SkyFateResetPrice[1])', DIAMOND)

-- ============================================================ 8. ĐẶT LẠI THIẾU KIM CƯƠNG
datLai()
HERO.SkyFate = { qinglong = 1 }
DIAMOND = 10
local c8 = ctxGia()
R.handlers[KR](c8, 92)
check(maCuoi(c8) == ErrorCode.Resource.NoEnoughResource, 'thieu kim cuong -> ma 1702', maCuoi(c8))
check(HERO.SkyFate.qinglong == 1, 'thieu kim cuong -> KHONG xoa cap', HERO.SkyFate.qinglong)

-- ============================================================ 9. THAM SỐ SAI
datLai()
local c9 = ctxGia()
R.handlers[KU](c9, 'x', 'qinglong')
check(maCuoi(c9) == ErrorCode.ArgError, 'heroID sai -> ma 2', maCuoi(c9))

io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
