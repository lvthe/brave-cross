-- _thu_tran_phap.lua — bộ thử cho `offline/handlers/tran_phap.lua`
-- (chạy bằng `python _thu_nha_cua.py _thu_tran_phap.lua`).
--
-- KHÔNG thử ở đây: config THẬT (bộ thử dựng helper GIẢ cùng hình dạng với
-- `share/FormationLogic.lua`), đường mạng, UI `CUIZF`, và việc client có đọc lại
-- `GameUserFormation` đúng hay không.
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

-- ============================================================ LỚP CHA GIẢ
-- Hình dạng chép từ `share/FormationLogic.lua`: chỉ ĐỌC/KIỂM.
FormationLogic = {}

local DU_LIEU = { Formations = {}, CurrentAdvancedFormation = nil }

local CAU_HINH = {
    jichu      = { Type = "Default" },
    heyi       = { Type = "Advanced" },
    bagua      = { Type = "Rare" },
    beidou     = { Type = "Rare" },   -- Rare NHUNG thieu bang gia kich hoat
}

-- cấp hiện tại -> cost cấp kế (nil = hết cấp)
local COST = { [0] = { CostGold = 0 }, [1] = { CostGold = 0 } }   -- tối đa cấp 2

FormationLogic.MO = false          -- cờ giả: IsOpen
FormationLogic.CHECK_OK = true     -- cờ giả: CheckCost
FormationLogic.CHECK_MA = 0        -- mã CheckCost trả khi hỏng
FormationLogic.MAX_LEVEL = 2
FormationLogic.MAX_SENIOR = 1

function FormationLogic:GetFormationConfig(strName)
    return CAU_HINH[strName]
end

function FormationLogic:IsOpen(strType)
    return self.MO
end

function FormationLogic:GetUserFormationData()
    return true, DU_LIEU
end

function FormationLogic:GetLevel(strName, uf)
    local st = (uf and uf.Formations and uf.Formations[strName]) or nil
    return true, (st and st.Level) or 0, (st and st.SeniorLevel) or -1
end

function FormationLogic:GetFormationMaxLevel(strName)
    return self.MAX_LEVEL, self.MAX_SENIOR
end

function FormationLogic:GetFormationUpgradeCostWithName(strName, nLevel, nSenior)
    if nLevel >= self.MAX_LEVEL and nSenior >= self.MAX_SENIOR then return nil end
    return COST[nLevel] or COST[0]
end

function FormationLogic:CheckCost(cost)
    if not self.CHECK_OK then return false, self.CHECK_MA end
    return true, 0
end

function FormationLogic:GetRareFormationActiveConfig(strName)
    if strName == "bagua" then return { CostGold = 0 } end
    return nil
end

ClientFormationLogic = {}
G_FormationLogic = setmetatable({}, { __index = FormationLogic })
G_FormationLogic[FormationLogic] = FormationLogic

-- ---------------------------------------------------------- tài nguyên giả
local daTru = { gold = 0, diamond = 0, item = 0 }
G_ItemDataManager = {}
function G_ItemDataManager:ReduceItem(id, n) daTru.item = daTru.item + n; return true end
G_UserLogic = {}
function G_UserLogic:CostGold(n) daTru.gold = daTru.gold + n; return true end
function G_UserLogic:CostDiamond(n) daTru.diamond = daTru.diamond + n; return true end

dofile([[__SC__/offline/handlers/tran_phap.lua]])
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
local function goi(ten, ...) return R.handlers[ten](ctxGia(), ...) end
local function demMa(c)                      -- mã lỗi của lần gọi gần nhất
    local x = c.calls[#c.calls]
    return x and x.args[3]
end

local U = 'G_FormationLogic.ClientUpgrade'
local A = 'G_FormationLogic.ClientActiveRareFormation'
local S = 'G_FormationLogic.ClientSelectAdvancedFormation'

check(R:has(U) and R:has(A) and R:has(S), 'dang ky 3 khoa')

-- ============================================================ 1. UPGRADE OK
FormationLogic.MO = true
DU_LIEU.Formations = {}
local c1 = ctxGia()
R.handlers[U](c1, 'jichu')
check(c1.calls[1] and c1.calls[1].obj == 'G_FormationLogic' and c1.calls[1].f == 'OnUpgrade',
      'Upgrade OK: callback OnUpgrade', c1.calls[1] and c1.calls[1].f)
check(c1.calls[1].args[1] == 'jichu', 'Upgrade OK: gui = strName', c1.calls[1].args[1])
check(DU_LIEU.Formations.jichu and DU_LIEU.Formations.jichu.Level == 1,
      'Upgrade OK: Level 0 -> 1', DU_LIEU.Formations.jichu and DU_LIEU.Formations.jichu.Level)
check(DU_LIEU.Formations.jichu.SeniorLevel == -1, 'Upgrade OK: Senior giu -1',
      DU_LIEU.Formations.jichu.SeniorLevel)

-- ============================================================ 2. LEN SENIOR
local c2 = ctxGia()
R.handlers[U](c2, 'jichu')                   -- 1 -> 2
R.handlers[U](c2, 'jichu')                   -- 2 max -> Senior 0
R.handlers[U](c2, 'jichu')                   -- Senior 0 -> 1
check(DU_LIEU.Formations.jichu.Level == 2 and DU_LIEU.Formations.jichu.SeniorLevel == 1,
      'Upgrade: het Level thi len Senior', DU_LIEU.Formations.jichu.SeniorLevel)

-- ============================================================ 3. HET CAP
local c3 = ctxGia()
R.handlers[U](c3, 'jichu')
check(demMa(c3) == 5104, 'het cap -> 5104', demMa(c3))

-- ============================================================ 4. KHONG CO CONFIG
local c4 = ctxGia()
R.handlers[U](c4, 'khongco')
check(demMa(c4) == 5101, 'config la -> 5101', demMa(c4))

-- ============================================================ 5. CHUA MO
FormationLogic.MO = false
local c5 = ctxGia()
R.handlers[U](c5, 'heyi')
check(demMa(c5) == 5102, 'chua mo -> 5102', demMa(c5))

-- ============================================================ 6. THIEU TAI NGUYEN
FormationLogic.MO = true
FormationLogic.CHECK_OK = false
FormationLogic.CHECK_MA = 1201
DU_LIEU.Formations = {}
local c6 = ctxGia()
R.handlers[U](c6, 'jichu')
check(demMa(c6) == 1201, 'CheckCost hong -> ma cua no (1201)', demMa(c6))
check(DU_LIEU.Formations.jichu == nil, 'CheckCost hong -> KHONG ghi cap')
FormationLogic.CHECK_OK = true

-- ============================================================ 7. TRU TAI NGUYEN
DU_LIEU.Formations = {}
daTru.gold, daTru.diamond, daTru.item = 0, 0, 0
COST[0] = { CostGold = 500, CostDiamond = 3, ItemList = { { ItemID = 195, Count = 2 } } }
local c7 = ctxGia()
R.handlers[U](c7, 'jichu')
check(daTru.gold == 500 and daTru.diamond == 3 and daTru.item == 2,
      'tru du vang/kim cuong/vat pham', string.format('%d/%d/%d', daTru.gold, daTru.diamond, daTru.item))
COST[0] = { CostGold = 0 }

-- ============================================================ 8. ARG SAI
local c8 = ctxGia()
R.handlers[U](c8, nil)
check(demMa(c8) == 2, 'strName nil -> 2', demMa(c8))

-- ============================================================ 9. ACTIVE RARE OK
DU_LIEU.Formations = {}
local c9 = ctxGia()
R.handlers[A](c9, 'bagua')
check(c9.calls[1] and c9.calls[1].f == 'OnActiveRareFormation' and c9.calls[1].args[1] == 'bagua',
      'ActiveRare OK: callback + gui', c9.calls[1] and c9.calls[1].f)
check(DU_LIEU.Formations.bagua and DU_LIEU.Formations.bagua.IsActived == true,
      'ActiveRare OK: IsActived = true')

-- ============================================================ 10. ACTIVE LAI
local c10 = ctxGia()
R.handlers[A](c10, 'bagua')
check(demMa(c10) == 5106, 'da kich hoat -> 5106', demMa(c10))

-- ============================================================ 11. ACTIVE SAI LOAI
local c11 = ctxGia()
R.handlers[A](c11, 'heyi')
check(demMa(c11) == 5105, 'ActiveRare tren Advanced -> 5105', demMa(c11))

-- ============================================================ 12. ACTIVE THIEU COST
DU_LIEU.Formations = {}
FormationLogic.MO = true
local c12 = ctxGia()
R.handlers[A](c12, 'beidou')
check(demMa(c12) == 5101, 'ActiveRare thieu bang gia kich hoat -> 5101', demMa(c12))
local c12b = ctxGia()
R.handlers[A](c12b, 'khongco')
check(demMa(c12b) == 5101, 'ActiveRare tran phap la -> 5101', demMa(c12b))

-- ============================================================ 13. SELECT ADVANCED
DU_LIEU.CurrentAdvancedFormation = nil
local c13 = ctxGia()
R.handlers[S](c13, 'heyi')
check(c13.calls[1] and c13.calls[1].f == 'OnSelectAdvancedFormation'
      and c13.calls[1].args[1] == 'heyi', 'SelectAdvanced OK: callback + gui',
      c13.calls[1] and c13.calls[1].f)
check(DU_LIEU.CurrentAdvancedFormation == 'heyi', 'SelectAdvanced OK: da ghi')
check(OfflineStore.dongBo and OfflineStore.dongBo > 0, 'co goi syncFromClient')

-- ============================================================ 14. SELECT SAI LOAI
local c14 = ctxGia()
R.handlers[S](c14, 'bagua')
check(demMa(c14) == 5105, 'SelectAdvanced tren Rare -> 5105', demMa(c14))

-- ============================================================ 15. SELECT CHUA MO
FormationLogic.MO = false
local c15 = ctxGia()
R.handlers[S](c15, 'heyi')
check(demMa(c15) == 5102, 'SelectAdvanced chua mo -> 5102', demMa(c15))

io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
