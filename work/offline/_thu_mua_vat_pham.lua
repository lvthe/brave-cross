-- _thu_mua_vat_pham.lua — bộ thử cho `offline/handlers/mua_vat_pham.lua`
-- (chạy bằng `python _thu_nha_cua.py _thu_mua_vat_pham.lua`).
--
-- KHÔNG thử ở đây: luật THẬT `ShopLogic:BuyGoods` (bộ thử không có `share/`). Bộ này đo
-- ĐƯỜNG DÂY + hai chỗ dễ hỏng nhất:
--   1. Đổi (ItemId, CurrencyType) -> GoodsId đúng dòng giá UI đang hiển thị.
--   2. Phát ĐÚNG hai sự kiện client chờ (tắt lớp tải + "Mua thành công"), vì client bản
--      này KHÔNG có hàm nhận phản hồi cho ClientBuyItem.
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
    UnknowError = 1,
    ArgError = 2,
    Shop = { NotEnoughCurrency = 1901, OutOfDayBuyLimit = 1902 },
}
EventManagerLogicEvent = {
    OnReceiveResponse = 'OnReceiveResponse',
    Item = { OnBuyItem = 'OnBuyItem', OnBuyItemBatch = 'OnBuyItemBatch' },
}
CUINotificationEvent = { OnServerRequestError = 'OnServerRequestError' }

-- ============================================================ GIẢ LẬP CLIENT
local BANG_GIA = {
    ['6|20'] = { GoodsId = 12, Price = 50, GoodsCount = 1, MaxBuyCountPerDay = 2 },
    ['5|20'] = { GoodsId = 13, Price = 50, GoodsCount = 1, MaxBuyCountPerDay = 0 },
}
G_ConfigManager = {}
function G_ConfigManager:GetGoodsConfigWithType(itemId, cur)
    return BANG_GIA[tostring(itemId) .. '|' .. tostring(cur)]
end

-- LOP GOC GIA: handler KHONG dung `G_ShopLogic` (ban that khong thua ke —
-- `require("share.ShopLogic")` bi chu thich), no `require("share.ShopLogic")` roi tu
-- tao thuc the. Nen o day chi can `ShopLogic` + `ShopLogic:new()`. `new()` tra ve CHINH
-- bang SHOP de moi lan dat `SHOP.MA` deu toi duoc `self.MA`.
local SHOP = { LAN = {}, MA = 0, NEM = false }
ShopLogic = {}
function ShopLogic:new() return SHOP end
function SHOP:BuyGoods(goodsId, nCount)
    self.LAN[#self.LAN + 1] = { goodsId = goodsId, nCount = nCount }
    if self.NEM then error('no gia lap') end
    return self.MA
end

local EVENT = { LAN = {} }
G_EventManager = {}
function G_EventManager:PostLogicEvent(data, ev)
    EVENT.LAN[#EVENT.LAN + 1] = { data = data, ev = ev }
    return true
end

local THONG_BAO = { LAN = {} }
g_CUINotificationCenter = {}
function g_CUINotificationCenter:PostNotification(ev, ma)
    THONG_BAO.LAN[#THONG_BAO.LAN + 1] = { ev = ev, ma = ma }
end

local ITEMLOGIC = { DU = true }
G_ItemLogic = {}
function G_ItemLogic:CheckIsEnoughResourceBuyItems(buyList)
    ITEMLOGIC.DA_KIEM = buyList
    return true, ITEMLOGIC.DU, ITEMLOGIC.DU and nil or 20
end

dofile([[__SC__/offline/handlers/mua_vat_pham.lua]])
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
    end
    return c
end

local function datLai()
    SHOP.LAN, SHOP.MA, SHOP.NEM = {}, 0, false
    EVENT.LAN, THONG_BAO.LAN = {}, {}
    ITEMLOGIC.DU = true
end

local function coEvent(ten)
    for _, x in ipairs(EVENT.LAN) do
        if x.ev == ten then return x end
    end
    return nil
end

-- ============================================================ 1. ĐĂNG KÝ
check(R:has('G_ItemLogic.ClientBuyItem'), 'dang ky ClientBuyItem')
check(R:has('G_ItemLogic.ClientBuyItemBatch'), 'dang ky ClientBuyItemBatch')
check(type(OfflineMuaVatPham) == 'table', 'co bang OfflineMuaVatPham')

-- ============================================================ 2. MUA MỘT MÓN OK
datLai()
R.handlers['G_ItemLogic.ClientBuyItem'](ctxGia(), 6, 2, 20)
check(SHOP.LAN[1] and SHOP.LAN[1].goodsId == 12 and SHOP.LAN[1].nCount == 2,
      'goi DUNG BuyGoods(goodsId 12, 2)', SHOP.LAN[1] and (SHOP.LAN[1].goodsId .. 'x' .. SHOP.LAN[1].nCount))
check(coEvent('OnReceiveResponse') ~= nil, 'phat OnReceiveResponse (tat lop tai)')
local evMua = coEvent('OnBuyItem')
check(evMua ~= nil and type(evMua.data) == 'table' and evMua.data.ItemID == 6
      and evMua.data.BuyCount == 2 and evMua.data.ResourceType == 20,
      'phat OnBuyItem dung hinh {ItemID, BuyCount, ResourceType}',
      evMua and (tostring(evMua.data.ItemID) .. '/' .. tostring(evMua.data.BuyCount) .. '/' .. tostring(evMua.data.ResourceType)))
check(#THONG_BAO.LAN == 0, 'thanh cong -> KHONG co toast loi', #THONG_BAO.LAN)

-- ============================================================ 3. KHÔNG CÓ DÒNG GIÁ
datLai()
R.handlers['G_ItemLogic.ClientBuyItem'](ctxGia(), 999, 1, 20)
check(#SHOP.LAN == 0, 'khong co dong gia -> KHONG goi BuyGoods', #SHOP.LAN)
check(coEvent('OnBuyItem') == nil, 'khong co dong gia -> khong phat "Mua thanh cong"')
check(THONG_BAO.LAN[1] and THONG_BAO.LAN[1].ma == 1901, 'khong co dong gia -> bao 1901',
      THONG_BAO.LAN[1] and THONG_BAO.LAN[1].ma)

-- ============================================================ 4. LUẬT TỪ CHỐI
datLai()
SHOP.MA = 1902
R.handlers['G_ItemLogic.ClientBuyItem'](ctxGia(), 6, 1, 20)
check(THONG_BAO.LAN[1] and THONG_BAO.LAN[1].ma == 1902, 'luat tu choi -> bao ma goc 1902',
      THONG_BAO.LAN[1] and THONG_BAO.LAN[1].ma)
check(coEvent('OnBuyItem') == nil, 'luat tu choi -> KHONG phat "Mua thanh cong"')

-- ============================================================ 5. THAM SỐ SAI
datLai()
R.handlers['G_ItemLogic.ClientBuyItem'](ctxGia(), 6, 0, 20)
check(#SHOP.LAN == 0 and THONG_BAO.LAN[1] and THONG_BAO.LAN[1].ma == ErrorCode.ArgError,
      'so luong 0 -> err 2, khong goi luat')

-- ============================================================ 6. LUẬT NÉM LỖI
datLai()
SHOP.NEM = true
R.handlers['G_ItemLogic.ClientBuyItem'](ctxGia(), 6, 1, 20)
SHOP.NEM = false
check(THONG_BAO.LAN[1] and THONG_BAO.LAN[1].ma == ErrorCode.UnknowError,
      'luat nem loi -> err 1', THONG_BAO.LAN[1] and THONG_BAO.LAN[1].ma)

-- ============================================================ 7. BATCH OK
datLai()
local list = { { ItemId = 6, CurrencyType = 20, BuyCount = 1 },
               { ItemId = 5, CurrencyType = 20, BuyCount = 3 } }
R.handlers['G_ItemLogic.ClientBuyItemBatch'](ctxGia(), list)
check(ITEMLOGIC.DA_KIEM == list, 'batch: kiem du tien bang luat goc TRUOC khi mua')
check(#SHOP.LAN == 2 and SHOP.LAN[1].goodsId == 12 and SHOP.LAN[2].goodsId == 13,
      'batch: mua DU hai mon dung thu tu', #SHOP.LAN)
check(SHOP.LAN[2] and SHOP.LAN[2].nCount == 3, 'batch: so luong dung', SHOP.LAN[2] and SHOP.LAN[2].nCount)
local evBatch = coEvent('OnBuyItemBatch')
check(evBatch ~= nil and evBatch.data == list, 'batch: phat OnBuyItemBatch voi danh sach goc')

-- ============================================================ 8. BATCH THIẾU TIỀN
datLai()
ITEMLOGIC.DU = false
R.handlers['G_ItemLogic.ClientBuyItemBatch'](ctxGia(), list)
check(#SHOP.LAN == 0, 'batch thieu tien -> KHONG mua mon nao', #SHOP.LAN)
check(THONG_BAO.LAN[1] and THONG_BAO.LAN[1].ma == 1901, 'batch thieu tien -> 1901',
      THONG_BAO.LAN[1] and THONG_BAO.LAN[1].ma)
check(coEvent('OnBuyItemBatch') == nil, 'batch thieu tien -> khong phat su kien thanh cong')

-- ============================================================ 9. BATCH DỪNG Ở MÓN HỎNG
datLai()
local listHong = { { ItemId = 6, CurrencyType = 20, BuyCount = 1 },
                   { ItemId = 999, CurrencyType = 20, BuyCount = 1 } }
R.handlers['G_ItemLogic.ClientBuyItemBatch'](ctxGia(), listHong)
check(#SHOP.LAN == 1, 'batch: dung o mon hong, KHONG mua tiep', #SHOP.LAN)
check(THONG_BAO.LAN[1] and THONG_BAO.LAN[1].ma == 1901, 'batch: bao ma cua mon hong',
      THONG_BAO.LAN[1] and THONG_BAO.LAN[1].ma)

-- ============================================================ 10. BATCH RỖNG
datLai()
R.handlers['G_ItemLogic.ClientBuyItemBatch'](ctxGia(), {})
check(#SHOP.LAN == 0 and THONG_BAO.LAN[1] and THONG_BAO.LAN[1].ma == ErrorCode.ArgError,
      'batch rong -> err 2, khong goi luat')

io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
