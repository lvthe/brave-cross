-- _thu_luyen_hero.lua — bộ thử cho `offline/handlers/luyen_hero.lua`
-- (chạy bằng `python _thu_nha_cua.py _thu_luyen_hero.lua`).
--
-- KHÔNG thử ở đây: cấu hình THẬT (helper giả cùng hình dạng `HeroPracticeLogic`),
-- và hình trả lời của `ClientGetPracticeInfo` — [GHIM-C] trả bảng rỗng, bộ thử chỉ đo
-- ĐÚNG việc "trả bảng rỗng + đúng đích".
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

-- ============================================================ LỚP GIẢ
--[[ DỰNG ĐÚNG HÌNH DẠNG THẬT của `class()`: LỚP **KHÔNG lộ phương thức**
	(`share/class.lua` giữ chúng trong một `vtbl` ẩn), nên `HeroPracticeLogic.
	IsCanPracticeHero` phải là `nil`; muốn gọi thì phải qua THỰC THỂ
	`G_ClientQuestLogic` + proxy lớp cha. Đây là phép kiểm bắt đúng lỗi đo được
	trong game 31/10 (gọi trên lớp ⇒ trượt ⇒ handler trả mã 1 vô nghĩa). ]]
HeroPracticeLogic = { CAN = true, CAN_MA = 0, DEM_CAN = 0, PracticeTime = 7200 }

local DU_LIEU = { PracticeStates = {} }
HeroPracticeLogic.DU_LIEU = DU_LIEU

local VTBL = {}                     -- "vtbl ẩn" của lớp

function VTBL:GetUserHeroPracticeData()
    return true, DU_LIEU
end

function VTBL:IsCanPracticeHero(nHeroID, strAreaID)
    HeroPracticeLogic.DEM_CAN = HeroPracticeLogic.DEM_CAN + 1
    HeroPracticeLogic.LAN_CUOI = { hero = nHeroID, area = strAreaID }
    return HeroPracticeLogic.CAN, HeroPracticeLogic.CAN_MA
end

function VTBL:getGoldReward(nLevel, strArea)
    return 100 * (nLevel or 1)
end

function VTBL:getHeroExpReward(nLevel)
    return math.ceil((nLevel or 1) * 0.18)
end

ClientQuestLogic = {}
G_ClientQuestLogic = setmetatable({}, { __index = ClientQuestLogic })
G_ClientQuestLogic[HeroPracticeLogic] = VTBL

-- ---------------------------------------------------------- API giả
local gioGia = 1000000
G_GameWorld = {}
function G_GameWorld:GetServerTime() return gioGia end

local daCong = { gold = 0, exp = 0 }
local TUONG = { UserHeroID = 25, Ex = 0 }

G_UserLogic = {}
function G_UserLogic:GetLevel() return true, 10 end
function G_UserLogic:AddGold(n) daCong.gold = daCong.gold + n; return true end

G_HeroLogic = {}
function G_HeroLogic:GetHeroWithID(id) return 0, TUONG end

G_HeroDataManager = {}
function G_HeroDataManager:SetHeroEx(t, n)
    t.Ex = n
    daCong.exp = n
    return true
end

dofile([[__SC__/offline/handlers/luyen_hero.lua]])
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
local function demMa(c)
    local x = c.calls[#c.calls]
    return x and x.args[3]
end

local GAN = 'G_HeroPracticeLogic.ClientPracticeHero'
local NHAN = 'G_HeroPracticeLogic.ClientGetPracticePrize'
local INFO = 'G_HeroPracticeLogic.ClientGetPracticeInfo'

check(R:has(GAN) and R:has(NHAN) and R:has(INFO), 'dang ky 3 khoa')

-- ============================================================ 1. GAN OK
DU_LIEU.PracticeStates = {}
local c1 = ctxGia()
R.handlers[GAN](c1, 25, '1')
check(c1.calls[1] and c1.calls[1].obj == 'Statistics' and c1.calls[1].f == 'OnPracticeHero',
      'gan OK: callback Statistics.OnPracticeHero', c1.calls[1] and c1.calls[1].f)
local st1 = DU_LIEU.PracticeStates['1']
check(type(st1) == 'table' and st1.HeroID == 25 and st1.BeginTime == gioGia,
      'gan OK: ghi HeroID + BeginTime', st1 and tostring(st1.HeroID))
check(OfflineStore.dongBo and OfflineStore.dongBo > 0, 'gan OK: co syncFromClient')

-- ============================================================ 2. GAN BI TU CHOI
HeroPracticeLogic.CAN, HeroPracticeLogic.CAN_MA = false, 4207
local c2 = ctxGia()
R.handlers[GAN](c2, 25, '1')
check(demMa(c2) == 4207, 'gan bi tu choi -> ma cua luat goc (4207)', demMa(c2))
HeroPracticeLogic.CAN = true

-- ============================================================ 3. GAN THAM SO SAI
local c3 = ctxGia()
R.handlers[GAN](c3, nil, '1')
check(demMa(c3) == 2, 'heroId nil -> 2', demMa(c3))
local dem3 = HeroPracticeLogic.DEM_CAN
R.handlers[GAN](ctxGia(), 25, nil)
check(HeroPracticeLogic.DEM_CAN == dem3, 'area nil -> KHONG goi IsCanPracticeHero',
      HeroPracticeLogic.DEM_CAN - dem3)

-- ============================================================ 4. NHAN KHI O TRONG
DU_LIEU.PracticeStates = { ['1'] = { AreaID = '1', HeroID = 0, BeginTime = 0 } }
local c4 = ctxGia()
R.handlers[NHAN](c4, '1')
check(demMa(c4) == 4201, 'o trong -> 4201', demMa(c4))

-- ============================================================ 5. NHAN KHI CHUA DU GIO
DU_LIEU.PracticeStates = { ['1'] = { AreaID = '1', HeroID = 25, BeginTime = gioGia - 60 } }
local c5 = ctxGia()
R.handlers[NHAN](c5, '1')
check(demMa(c5) == 4201, 'chua du gio -> 4201', demMa(c5))

-- ============================================================ 6. NHAN OK
daCong.gold, daCong.exp = 0, 0
TUONG.Ex = 0
DU_LIEU.PracticeStates = { ['1'] = { AreaID = '1', HeroID = 25, BeginTime = gioGia - 7200 } }
local c6 = ctxGia()
R.handlers[NHAN](c6, '1')
check(daCong.gold == 1000, 'nhan OK: vang = 100 x level 10', daCong.gold)
check(daCong.exp == 2, 'nhan OK: exp tuong = ceil(10 x 0.18)', daCong.exp)
check(DU_LIEU.PracticeStates['1'].HeroID == 0 and DU_LIEU.PracticeStates['1'].BeginTime == 0,
      'nhan OK: XOA o sau khi phat')
check(c6.calls[1] and c6.calls[1].f == 'OnReciveResponse' and c6.calls[1].args[3] == 0,
      'nhan OK: tat lop dang tai', c6.calls[1] and c6.calls[1].f)

-- ============================================================ 7. THAM SO SAI
local c7 = ctxGia()
R.handlers[NHAN](c7, nil)
check(demMa(c7) == 2, 'nhan arg nil -> 2', demMa(c7))

-- ============================================================ 8. INFO -> BANG RONG
local c8 = ctxGia()
R.handlers[INFO](c8)
check(c8.calls[1] and c8.calls[1].obj == 'G_ClientQuestLogic'
      and c8.calls[1].f == 'ClientGetPracticeInfo', 'info: dung dich G_ClientQuestLogic',
      c8.calls[1] and c8.calls[1].f)
check(type(c8.calls[1].args[1]) == 'table' and next(c8.calls[1].args[1]) == nil,
      'info: tham so la BANG RONG ([GHIM-C])')

io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
