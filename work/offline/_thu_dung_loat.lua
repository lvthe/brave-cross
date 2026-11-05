-- _thu_dung_loat.lua — bộ thử cho `ClientBatchUseItemWithItemList` trong `handlers/vat_pham.lua`
-- (chạy bằng `python _thu_nha_cua.py _thu_dung_loat.lua`).
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

-- Luật giả: `UseItem(id, n, prize)` đổ danh sách thưởng vào `prize`; id 999 là hỏng.
ItemLogic = {}
function ItemLogic:UseItem(id, n, prize)
    if id == 999 then return false end
    prize[#prize + 1] = { PrizeResType = 2, PropID = id, PrizeResCount = n }
    return true
end
ClientItemLogic = {}
G_ItemLogic = setmetatable({}, { __index = ClientItemLogic })
G_ItemLogic[ItemLogic] = ItemLogic

dofile([[__SC__/offline/handlers/vat_pham.lua]])
local R = require('offline.router')

local dat, hong = 0, 0
local function check(ok, ten, ct)
    if ok then dat = dat + 1; io.write('  OK   ' .. ten .. '\n')
    else hong = hong + 1; io.write('  HONG ' .. ten .. (ct ~= nil and (' -> ' .. tostring(ct)) or '') .. '\n') end
end
local function ctxGia()
    local c = { calls = {} }
    function c:call(obj, f, ...)
        self.calls[#self.calls + 1] = { obj = obj, f = f, a = ..., args = { ... } }
    end
    return c
end

check(R:has('G_ItemLogic.ClientBatchUseItemWithItemList'), 'dang ky ClientBatchUseItemWithItemList')

-- 1. hai muc tot
local c1 = ctxGia()
R.handlers['G_ItemLogic.ClientBatchUseItemWithItemList'](c1,
    { { ItemID = 10, UserCount = 3 }, { ItemID = 11, UserCount = 2 } })
local k1 = c1.calls[1]
local ds1 = k1.args[1]
check(k1.obj == 'G_ItemLogic' and k1.f == 'OnBatchUseItemWithItemList'
      and #ds1 == 2 and ds1[1].ItemID == 10 and ds1[2].UserCount == 2,
      'hai muc: callback + danh sach 2 muc', k1.f)
check(type(ds1[1].RetData) == 'table' and ds1[1].RetData[1].PropID == 10,
      'moi muc co RetData = danh sach thuong do UseItem do vao', ds1[1].RetData)

-- 2. mot tot + mot hong -> bo muc hong
local c2 = ctxGia()
R.handlers['G_ItemLogic.ClientBatchUseItemWithItemList'](c2,
    { { ItemID = 12, UserCount = 1 }, { ItemID = 999, UserCount = 1 } })
local ds2 = c2.calls[1].args[1]
check(#ds2 == 1 and ds2[1].ItemID == 12, 'muc hong bi BO, muc tot van tra', #ds2)

-- 3. tat ca hong -> ma 1
local c3 = ctxGia()
R.handlers['G_ItemLogic.ClientBatchUseItemWithItemList'](c3, { { ItemID = 999, UserCount = 1 } })
check(c3.calls[1].a == '' and c3.calls[1].args[3] == 1, 'tat ca hong -> ma 1', c3.calls[1].args[3])

-- 4. danh sach rong -> 4
local c4 = ctxGia()
R.handlers['G_ItemLogic.ClientBatchUseItemWithItemList'](c4, {})
check(c4.calls[1].args[3] == 4, 'danh sach rong -> 4', c4.calls[1].args[3])

check(OfflineStore.dongBo and OfflineStore.dongBo > 0, 'co goi syncFromClient')
io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
