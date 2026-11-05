-- _thu_thoi_trang.lua — bộ thử cho `offline/handlers/thoi_trang.lua`
-- (chạy bằng `python _thu_nha_cua.py _thu_thoi_trang.lua`).
--
-- KHÔNG thử ở đây: cấu hình THẬT (helper giả cùng hình dạng), `AddHeroSkin`, UI.
-- `cjson` là bản GIẢ tối thiểu (lua51.dll trần không có cjson) — chỉ giải chuỗi
-- `{"HeroID":N,...}` đủ để đo cổng khớp anh hùng.
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

-- cjson giả: chỉ đủ cho `UserProperty` của cấu hình.
cjson = {}
function cjson.decode(s)
    local hero = string.match(s, '"HeroID"%s*:%s*(%d+)')
    return { HeroID = tonumber(hero) }
end

-- ============================================================ API GIẢ
G_ConfigManager = {}
G_ConfigManager.CAU_HINH = {
    Coat005 = {
        ItemId = 15, Count = 10,
        PrizeData = { PrizeResType = 9, UserProperty = '{"HeroID":25,"PartID":"Coat","SkinID":"Coat005"}' },
    },
}
function G_ConfigManager:GetCommonConfigWithName(ten, khoa)
    if ten ~= 'GameClothingComposeConfig' then return nil end
    return self.CAU_HINH[khoa]
end

local daDung = { item = 0, phat = 0, phatLoi = false }
G_ItemLogic = {}
G_ItemLogic.CO = 99
function G_ItemLogic:GetItemCount(id) return true, self.CO end

G_ItemDataManager = {}
function G_ItemDataManager:ReduceItem(id, n, tu) daDung.item = daDung.item + n; return true end

G_ChapterLogic = {}
function G_ChapterLogic:SetDataWithPrizeData(prize, mul, tu)
    if daDung.phatLoi then return false end
    daDung.phat = daDung.phat + 1
    return true
end

-- Lớp cha của thời trang: chỉ hai hàm cần cho hai khoá sau.
ClothingLogic = {}
ClothingLogic.KQ = true
ClothingLogic.MA = 0
ClothingLogic.LAN = {}
function ClothingLogic:getClothingPrize(strIndex)
    self.LAN[#self.LAN + 1] = { ten = 'getClothingPrize', idx = strIndex }
    return self.KQ, self.MA
end
function ClothingLogic:setClothingPrizeUseStatus(strIndex)
    self.LAN[#self.LAN + 1] = { ten = 'setClothingPrizeUseStatus', idx = strIndex }
    return self.KQ
end

ClientClothingLogic = {}
G_ClothingLogic = setmetatable({}, { __index = ClothingLogic })
G_ClothingLogic[ClothingLogic] = ClothingLogic

dofile([[__SC__/offline/handlers/thoi_trang.lua]])
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

local GHEP = 'G_ClothingLogic.ClientComposeClothing'
local NHAN = 'G_ClothingLogic.ClientGetClothingPrize'
local DANH = 'G_ClothingLogic.ClientSetClothingPrizeUseStatus'

check(R:has(GHEP) and R:has(NHAN) and R:has(DANH), 'dang ky 3 khoa')

-- ============================================================ 1. GHEP OK
daDung.item, daDung.phat = 0, 0
local c1 = ctxGia()
R.handlers[GHEP](c1, 25, 'Coat005')
check(c1.calls[1] and c1.calls[1].obj == 'G_ClothingLogic' and c1.calls[1].f == 'OnComposeClothing',
      'ghep OK: callback OnComposeClothing', c1.calls[1] and c1.calls[1].f)
check(daDung.item == 10, 'ghep OK: tru dung 10 nguyen lieu', daDung.item)
check(daDung.phat == 1, 'ghep OK: phat dung 1 lan', daDung.phat)
check(OfflineStore.dongBo and OfflineStore.dongBo > 0, 'ghep OK: co syncFromClient')

-- ============================================================ 2. THIEU CAU HINH
local c2 = ctxGia()
R.handlers[GHEP](c2, 25, 'KhongCo')
check(demMa(c2) == 3302, 'ma trang phuc la -> 3302', demMa(c2))

-- ============================================================ 3. SAI ANH HUNG
local c3 = ctxGia()
R.handlers[GHEP](c3, 36, 'Coat005')
check(demMa(c3) == 3306, 'sai anh hung -> 3306', demMa(c3))

-- ============================================================ 4. THIEU NGUYEN LIEU
G_ItemLogic.CO = 3
local c4 = ctxGia()
R.handlers[GHEP](c4, 25, 'Coat005')
check(demMa(c4) == 3305, 'thieu nguyen lieu -> 3305', demMa(c4))
G_ItemLogic.CO = 99

-- ============================================================ 5. PHAT HONG
daDung.phatLoi = true
local c5 = ctxGia()
R.handlers[GHEP](c5, 25, 'Coat005')
check(demMa(c5) == 3301, 'SetDataWithPrizeData hong -> 3301', demMa(c5))
daDung.phatLoi = false

-- ============================================================ 6. ARG SAI
local c6 = ctxGia()
R.handlers[GHEP](c6, nil, 'Coat005')
check(demMa(c6) == 2, 'heroId nil -> 2', demMa(c6))
local c6b = ctxGia()
R.handlers[GHEP](c6b, 25, nil)
check(demMa(c6b) == 2, 'clothId nil -> 2', demMa(c6b))

-- ============================================================ 7. NHAN OK
ClothingLogic.KQ = true
ClothingLogic.LAN = {}
local c7 = ctxGia()
R.handlers[NHAN](c7, '1')
check(ClothingLogic.LAN[1] and ClothingLogic.LAN[1].ten == 'getClothingPrize'
      and ClothingLogic.LAN[1].idx == '1', 'nhan: goi DUNG luat goc', ClothingLogic.LAN[1] and ClothingLogic.LAN[1].ten)
check(c7.calls[1] and c7.calls[1].f == 'OnServerGetClothingPrize',
      'nhan OK: callback OnServerGetClothingPrize', c7.calls[1] and c7.calls[1].f)

-- ============================================================ 8. NHAN HONG
ClothingLogic.KQ, ClothingLogic.MA = false, 3301
local c8 = ctxGia()
R.handlers[NHAN](c8, '1')
check(demMa(c8) == 3301, 'nhan hong -> ma cua luat goc', demMa(c8))
ClothingLogic.KQ = true

-- ============================================================ 9. DANH DAU OK
ClothingLogic.LAN = {}
local c9 = ctxGia()
R.handlers[DANH](c9, '1')
check(ClothingLogic.LAN[1] and ClothingLogic.LAN[1].ten == 'setClothingPrizeUseStatus',
      'danh dau: goi DUNG luat goc', ClothingLogic.LAN[1] and ClothingLogic.LAN[1].ten)
check(c9.calls[1] and c9.calls[1].f == 'OnServerSetClothingPrizeUseStatus',
      'danh dau OK: callback', c9.calls[1] and c9.calls[1].f)

-- ============================================================ 10. DANH DAU ARG SAI
local c10 = ctxGia()
R.handlers[DANH](c10, nil)
check(demMa(c10) == 2, 'danh dau arg nil -> 2', demMa(c10))

io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
