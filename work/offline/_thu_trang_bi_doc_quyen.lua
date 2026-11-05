-- _thu_trang_bi_doc_quyen.lua — bo thu cho `offline/handlers/trang_bi_doc_quyen.lua`
-- (chay bang `python _thu_nha_cua.py _thu_trang_bi_doc_quyen.lua`, hoac ca cong
--  `python _chay_het.py`).
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

-- Ma loi dung trong handler
ErrorCode = {
    ArgError = 2,
    Equipment = {
        NotEquipmentExist = 1106, NotEnoughConcentrate = 1109,
        IsNotExclusive = 1111, CanNotPurifyThisPartEquip = 1112,
        IsMaxPurifyLevel = 1113, NoEnoughPurifyLevel = 1114,
        NoGetAllExclusiveEquip = 1115, IsExclusive = 1116,
        CanNotForgingExclusiveWeapon = 1117,
    },
    Hero = { NotExclusiveHero = 1330 },
    Item = { NotEnoughItem = 1201, ReduceItemError = 1202 },
}

-- Cau hinh THAT (rut gon dung hinh dang KDBGameExclusiveEquipConfig)
local CFG_TUONG = { 25, 9 }
local CFG_DUC = {
    ["25"] = {
        ["1"] = { ItemList = { { ItemID = 601, Count = 5 } } },
        ["2"] = { ItemList = { { ItemID = 501, Count = 2 }, { ItemID = 502, Count = 3 } } },
    },
    ["9"] = { ["2"] = { ItemList = { { ItemID = 501, Count = 1 } } } },
}
local CFG_LUYEN = {
    ["1"] = { { NeedConcentrate = 100, AddPrecent = 25 }, { NeedConcentrate = 200, AddPrecent = 30 } },
    ["2"] = { { NeedConcentrate = 100, AddPrecent = 25 }, { NeedConcentrate = 200, AddPrecent = 30 } },
}
G_ConfigManager = {}
function G_ConfigManager:GetExclusiveEquipHeroConfig() return CFG_TUONG end
function G_ConfigManager:GetExclusiveEquipForgeConfig() return CFG_DUC end
function G_ConfigManager:GetExclusiveEquipPurifyConfig() return CFG_LUYEN end

-- The gioi gia
local lo, kho, tinhHoa, events
local function datLai()
    lo, kho, tinhHoa, events = {}, { [501] = 10, [502] = 10, [601] = 10 }, 1000, {}
end
local function taoDo(h, p, q, ref)
    lo[h] = lo[h] or {}
    lo[h][p] = { HeroID = h, EquipPartID = p, EquipLevel = 1, Quality = q or 6,
                 RefineLevel = ref or 0, IsExclusive = false }
    return lo[h][p]
end

EquipmentLogic = {}
function EquipmentLogic:GetEquipment(h, p)
    local e = lo[h] and lo[h][p]
    return true, e
end
function EquipmentLogic:updateEquipData(e)
    e.__upd = (e.__upd or 0) + 1
    return true
end
G_EquipmentLogic = EquipmentLogic

G_EquipmentDataManager = {}
function G_EquipmentDataManager:SetEquipIsExclusive(h, p)
    local e = lo[h] and lo[h][p]
    if e == nil then return false end
    e.IsExclusive = true
    return true
end
function G_EquipmentDataManager:SetEquipRefineLevel(h, p, lv)
    local e = lo[h] and lo[h][p]
    if e == nil then return false end
    e.RefineLevel = lv
    return true
end

G_ItemLogic = {}
function G_ItemLogic:GetItemCount(id) return true, kho[id] or 0 end
function G_ItemLogic:AddItem(id, n) kho[id] = (kho[id] or 0) + n; return true end
G_ItemDataManager = {}
function G_ItemDataManager:ReduceItem(id, n)
    if (kho[id] or 0) < n then return false end
    kho[id] = kho[id] - n
    return true
end

G_UserLogic = {}
function G_UserLogic:GetConcentrate() return true, tinhHoa end
function G_UserLogic:CostConcentrate(n, _)
    if tinhHoa < n then return false end
    tinhHoa = tinhHoa - n
    return true
end
function G_UserLogic:AddConcentrate(n) tinhHoa = tinhHoa + n; return true end
G_HeroLogic = {}
function G_HeroLogic:GetUpgradeRefineCost(n) return n end     -- VIP < 10

G_EventManager = {}
function G_EventManager:PostLogicEvent(tData, ten)
    events[#events + 1] = { data = tData, name = ten }
end

dofile([[__SC__/offline/handlers/trang_bi_doc_quyen.lua]])
local R = require('offline.router')

local dat, hong = 0, 0
local function check(ok, ten, ct)
    if ok then dat = dat + 1; io.write('  OK   ' .. ten .. '\n')
    else hong = hong + 1; io.write('  HONG ' .. ten .. (ct ~= nil and (' -> ' .. tostring(ct)) or '') .. '\n') end
end
local function ctxGia()
    local c = { calls = {} }
    function c:call(obj, f, a, b, ma, ev, ...)
        self.calls[#self.calls + 1] = { obj = obj, f = f, a = a, b = b, err = ma, ev = ev }
        return true
    end
    return c
end
local function maCua(ctx)
    local x = ctx.calls[#ctx.calls]
    return x and tonumber(x.err)
end

local fnDuc = R.handlers['G_EquipmentLogic.ClientForgingExclusiveEquip']
local fnLuyen = R.handlers['G_EquipmentLogic.ClientPurifyExclusiveEquip']

io.write('\n=== dang ky khoa ===\n')
check(fnDuc ~= nil, 'co handler ClientForgingExclusiveEquip')
check(fnLuyen ~= nil, 'co handler ClientPurifyExclusiveEquip')

--------------------------------------------------------------------- DUC
io.write('\n=== duc doc quyen ===\n')
datLai()
local c = ctxGia(); fnDuc(c, nil, 1)
check(maCua(c) == 2, 'tham so sai -> 2', maCua(c))

datLai()
c = ctxGia(); fnDuc(c, 7, 2)
check(maCua(c) == 1330, 'tuong khong co trong danh sach -> 1330', maCua(c))

datLai()
c = ctxGia(); fnDuc(c, 25, 3)
check(maCua(c) == 1106, 'khong co trang bi -> 1106', maCua(c))

datLai(); local e1 = taoDo(25, 2); e1.IsExclusive = true
c = ctxGia(); fnDuc(c, 25, 2)
check(maCua(c) == 1116, 'da doc quyen -> 1116', maCua(c))

datLai(); taoDo(25, 2, 5, 5)
c = ctxGia(); fnDuc(c, 25, 2)
check(maCua(c) == 1117, 'chat luong 5 < 6 -> 1117', maCua(c))

datLai(); taoDo(25, 2, 6, 4)
c = ctxGia(); fnDuc(c, 25, 2)
check(maCua(c) == 1117, 'tinh luyen thuong 4/5 chua day -> 1117', maCua(c))

datLai(); taoDo(25, 1, 6, 5)
c = ctxGia(); fnDuc(c, 25, 1)
check(maCua(c) == 1115, 'vu khi ma 4 mon kia chua doc quyen -> 1115', maCua(c))

datLai(); taoDo(25, 2, 6, 5); kho[501] = 1
c = ctxGia(); fnDuc(c, 25, 2)
check(maCua(c) == 1201, 'thieu nguyen lieu -> 1201', maCua(c))
check(kho[501] == 1 and lo[25][2].IsExclusive == false,
    'thieu nguyen lieu thi KHONG tru gi va KHONG dat co')

datLai(); local e2 = taoDo(25, 2, 6, 5)
c = ctxGia(); fnDuc(c, 25, 2)
check(maCua(c) == 0, 'duc thanh cong -> 0', maCua(c))
check(e2.IsExclusive == true, 'trang bi duoc dat IsExclusive = true')
check(kho[501] == 8 and kho[502] == 7, 'tru dung nguyen lieu (501 10->8, 502 10->7)',
    tostring(kho[501]) .. '/' .. tostring(kho[502]))
check(e2.__upd and e2.__upd >= 1, 'goi updateEquipData (tinh lai thuoc tinh)')
check(OfflineStore.dongBo and OfflineStore.dongBo >= 1, 'dong bo file luu')
check(#events == 1 and events[1].name == 'OnForgingExclusiveEquip' and events[1].data == 25,
    'phat logic event OnForgingExclusiveEquip(heroID la SO)')

datLai(); taoDo(25, 1, 6, 5)
for p = 2, 5 do local t = taoDo(25, p, 6, 5); t.IsExclusive = true end
c = ctxGia(); fnDuc(c, 25, 1)
check(maCua(c) == 0 and lo[25][1].IsExclusive == true,
    'vu khi du 4 mon kia doc quyen -> duc duoc', maCua(c))

------------------------------------------------------------------ LUYEN
io.write('\n=== tinh luyen doc quyen ===\n')
datLai(); taoDo(25, 2, 6)
c = ctxGia(); fnLuyen(c, 25, 2)
check(maCua(c) == 1111, 'chua doc quyen -> 1111', maCua(c))

datLai(); local e3 = taoDo(25, 7, 6); e3.IsExclusive = true
c = ctxGia(); fnLuyen(c, 25, 7)
check(maCua(c) == 1112, 'o khong co cau hinh -> 1112', maCua(c))

datLai(); local e4 = taoDo(25, 2, 6); e4.IsExclusive = true; e4.RefineLevel = 2
c = ctxGia(); fnLuyen(c, 25, 2)
check(maCua(c) == 1113, 'da o cap toi da 2/2 -> 1113', maCua(c))

datLai(); local e5 = taoDo(25, 2, 6); e5.IsExclusive = true; tinhHoa = 50
c = ctxGia(); fnLuyen(c, 25, 2)
check(maCua(c) == 1109, 'thieu tinh hoa -> 1109', maCua(c))
check(e5.RefineLevel == 0, 'thieu tinh hoa thi KHONG len cap')

datLai(); local e6 = taoDo(25, 2, 6); e6.IsExclusive = true
c = ctxGia(); fnLuyen(c, 25, 2)
check(maCua(c) == 0, 'tinh luyen thanh cong -> 0', maCua(c))
check(e6.RefineLevel == 1, 'cap 0 -> 1', e6.RefineLevel)
check(tinhHoa == 900, 'tru 100 tinh hoa (1000 -> 900)', tinhHoa)
check(e6.__upd and e6.__upd >= 1, 'goi updateEquipData')
check(#events == 1 and events[1].name == 'OnPurifyExclusiveEquip'
    and type(events[1].data) == 'table'
    and events[1].data.HeroID == 25 and events[1].data.EquipPartID == 2
    and events[1].data.RefineLevel == 1,
    'phat logic event OnPurifyExclusiveEquip({HeroID,EquipPartID,RefineLevel})')

-- Khoa lop chan: hai khoa nay KHONG con nam trong `chua_ho_tro`
dofile([[__SC__/offline/handlers/chua_ho_tro.lua]])
local R2 = require('offline.router')
check(R2.handlers['G_EquipmentLogic.ClientForgingExclusiveEquip'] == fnDuc,
    'lop chan KHONG de len handler duc')
check(R2.handlers['G_EquipmentLogic.ClientPurifyExclusiveEquip'] == fnLuyen,
    'lop chan KHONG de len handler tinh luyen')

io.write(string.format('\nKET QUA: dat %d, hong %d\n', dat, hong))
os.exit(hong == 0 and 0 or 1)
