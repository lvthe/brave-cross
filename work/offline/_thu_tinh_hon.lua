-- _thu_tinh_hon.lua — bộ thử cho `offline/handlers/tinh_hon.lua`
-- (chạy bằng `python _thu_nha_cua.py _thu_tinh_hon.lua`).
--
-- KHÔNG thử ở đây: `share/StarSoul/*` thật — dựng lại đúng hình dạng đã đọc trong
-- `share_StarSoulDataManager.lua` (pack[i] = {star_soul_id, level, exp},
-- career[career_id][cell_id] = {…}, career có ĐÚNG 5 phần tử).
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

-- ============================================================ API GIẢ
StarSoulDataManager = {}
StarSoulDataManager.DU_LIEU = nil

function StarSoulDataManager:InitData()
    return { cur_divide = 1, conjure_ziwen = 0, conjure_ziwen_count = 0,
             last_conjure_ziwen_date = 0, extra_pack_size = 0,
             pack = {}, career = { {}, {}, {}, {}, {} } }
end

function StarSoulDataManager:GetUserStarSoulData()
    if self.DU_LIEU == nil then self.DU_LIEU = self:InitData() end
    return 0, self.DU_LIEU
end

G_StarSoulDataManager = setmetatable({}, { __index = StarSoulDataManager })
G_StarSoulDataManager[StarSoulDataManager] = StarSoulDataManager

-- Cấu hình: MẢNG các dòng có `id` (đúng hình tệp JSON gốc).
G_ConfigManager = { configCacheName = {
    StarSoulStaticConf = 'StarSoulStaticConf',
    StarSoulDivineConf = 'StarSoulDivineConf',
    StarSoulDivineChanceConf = 'StarSoulDivineChanceConf',
    StarSoulLevelConf = 'StarSoulLevelConf',
} }
G_ShareStarSoulLogic = { MAX_STAR_SOUL_LEVEL = 5 }
-- Bang cap: moi cap la MOT NGUONG exp rieng (đúng `getXingHunLevelExpAbsolute`).
G_ConfigManager.LEVEL = {
    { id = 1001, level = 1, exp = 0 },
    { id = 1001, level = 2, exp = 100 },
    { id = 1001, level = 3, exp = 200 },
}
G_ConfigManager.CONF = {
    { id = 1001, quality = 7, price = 500 },   -- bán được
    { id = 1002, quality = 6, price = 300 },   -- bán được
    { id = 1003, quality = 6, price = 0 },     -- KHÔNG bán được
    { id = 1004, quality = 1, price = 100 },   -- để chiêm bốc loại 1 có hàng
}
G_ConfigManager.DIVINE = {
    { id = 1, price = 15000 },
    { id = 2, price = 30000 },
}
G_ConfigManager.CHANCE = {
    { divine_id = 1, quality = 1, chance = 100, use_diamond = 0 },   -- divine 1 luon ra q1
    { divine_id = 2, quality = 6, chance = 100, use_diamond = 0 },
    { divine_id = 2, quality = 7, chance = 50,  use_diamond = 1 },   -- nhánh kim cương: PHAI bi bo qua
}
function G_ConfigManager:GetConfigWithNameArg(ten)
    if ten == 'StarSoulStaticConf' then return self.CONF end
    if ten == 'StarSoulDivineConf' then return self.DIVINE end
    if ten == 'StarSoulDivineChanceConf' then return self.CHANCE end
    if ten == 'StarSoulLevelConf' then return self.LEVEL end
    return nil
end

local VANG = 0
G_UserLogic = {}
G_UserLogic.GOLD = 100000
function G_UserLogic:GetBaseInfo() return 0, { Gold = G_UserLogic.GOLD } end
function G_UserLogic:AddGold(n) VANG = VANG + n; G_UserLogic.GOLD = G_UserLogic.GOLD + n; return true end
function G_UserLogic:CostGold(n)
    if G_UserLogic.GOLD < n then return false, G_UserLogic.GOLD end
    G_UserLogic.GOLD = G_UserLogic.GOLD - n
    return true, G_UserLogic.GOLD
end

-- `AddToBagByDivine` gốc: cất vào túi rồi TĂNG `cur_divide` (quay vòng 1..5).
function StarSoulDataManager:AddToBagByDivine(strId, quality, doDivine)
    local _, d = self:GetUserStarSoulData()
    if #d.pack >= 100 then return 5403, nil end
    d.pack[#d.pack + 1] = { quality = quality, star_soul_id = strId, exp = 0, level = 1 }
    if doDivine then
        d.cur_divide = (d.cur_divide or 1) + 1
        if d.cur_divide > 5 then d.cur_divide = 1 end
    end
    return 0, d.cur_divide
end

dofile([[__SC__/offline/handlers/tinh_hon.lua]])
local R = require('offline.router')

local dat, hong = 0, 0
local function check(ok, ten, ct)
    if ok then dat = dat + 1; io.write('  OK   ' .. ten .. '\n')
    else hong = hong + 1; io.write('  HONG ' .. ten .. (ct ~= nil and (' -> ' .. tostring(ct)) or '') .. '\n') end
end
local function ctxGia()
    local c = { calls = {} }
    function c:call(obj, f, ...) self.calls[#self.calls + 1] = { obj = obj, f = f, args = { ... } } end
    return c
end
local function lay() return G_StarSoulDataManager.DU_LIEU end

local THAO_TAC = {
    'ClientBatchDivineReq', 'ClientBatchSellReq', 'ClientBatchUpgradeReq',
    'ClientBuyPackReq', 'ClientConjureZiwenReq', 'ClientDemountReq',
    'ClientDivineReq', 'ClientMountReq', 'ClientSellReq', 'ClientSortPackReq',
    'ClientUpgradeInCellReq', 'ClientUpgradeInPackReq',
}

-- ============================================================ 1. DANG KY
local thieu = {}
for _, t in ipairs(THAO_TAC) do
    if not R:has('G_StarSoulProtocol.' .. t) then thieu[#thieu + 1] = t end
end
check(#thieu == 0, 'dang ky du 12 khoa thao tac', table.concat(thieu, ','))
check(R:has('G_StarSoulProtocol.ClientGetReq'), 'dang ky ClientGetReq')

-- ============================================================ 2. GET
G_StarSoulDataManager.DU_LIEU = nil
local c1 = ctxGia(); R.handlers['G_StarSoulProtocol.ClientGetReq'](c1)
check(c1.calls[1] and c1.calls[1].obj == 'g_StarSoulProtocol' and c1.calls[1].f == 'ClientGetRsp',
      'Get: dung callback ClientGetRsp', c1.calls[1] and c1.calls[1].f)
check(type(c1.calls[1].args[1].pack) == 'table', 'Get: co pack')

-- ============================================================ 3. SAP KHO
G_StarSoulDataManager.DU_LIEU = StarSoulDataManager:InitData()
lay().pack = {
    { star_soul_id = 1002, level = 9, exp = 0 },    -- quality 6
    { star_soul_id = 1001, level = 1, exp = 0 },    -- quality 7  -> len dau
    { star_soul_id = 1003, level = 5, exp = 0 },    -- quality 6, level 5
}
local c2 = ctxGia(); R.handlers['G_StarSoulProtocol.ClientSortPackReq'](c2)
local p = lay().pack
check(p[1].star_soul_id == 1001, 'sap kho: chat luong cao nhat len dau', p[1].star_soul_id)
check(p[2].star_soul_id == 1002 and p[3].star_soul_id == 1003,
      'sap kho: cung chat luong thi cap cao truoc', tostring(p[2].star_soul_id) .. '/' .. tostring(p[3].star_soul_id))
check(c2.calls[1] and c2.calls[1].f == 'ClientSortPackRsp', 'sap kho: dung callback')

-- ============================================================ 4. BAN MOT
VANG = 0
local c3 = ctxGia(); R.handlers['G_StarSoulProtocol.ClientSellReq'](c3, 1, 1001)
check(VANG == 500, 'ban 1: cong dung gia cau hinh (500)', VANG)
check(#lay().pack == 2, 'ban 1: kho con 2 mon', #lay().pack)
check(c3.calls[1].f == 'ClientSellRsp', 'ban 1: dung callback')

-- ban mon price=0 -> tu choi (5400), khong xoa
VANG = 0
lay().pack = { { star_soul_id = 1003, level = 1, exp = 0 } }
local c4 = ctxGia(); R.handlers['G_StarSoulProtocol.ClientSellReq'](c4, 1, 1003)
check(c4.calls[1].args[3] == 5400 and #lay().pack == 1 and VANG == 0,
      'ban mon price=0: tu choi, KHONG xoa, KHONG cong vang')

-- ============================================================ 5. BAN HET
VANG = 0
lay().pack = {
    { star_soul_id = 1001, level = 1, exp = 0 },   -- 500
    { star_soul_id = 1003, level = 1, exp = 0 },   -- 0   -> giu lai
    { star_soul_id = 1002, level = 1, exp = 0 },   -- 300
}
local c5 = ctxGia(); R.handlers['G_StarSoulProtocol.ClientBatchSellReq'](c5)
check(VANG == 800, 'ban het: cong 500+300', VANG)
check(#lay().pack == 1 and lay().pack[1].star_soul_id == 1003,
      'ban het: GIU LAI mon price=0', #lay().pack)

-- ============================================================ 6. KHAM
lay().pack = { { star_soul_id = 1001, level = 4, exp = 0 } }
local c6 = ctxGia()
R.handlers['G_StarSoulProtocol.ClientMountReq'](c6, {
    { career_id = 1, cell_id = 3, pack_item = { pack_idx = 1, star_soul_id = 1001 } },
})
check(#lay().pack == 0, 'kham: kho rong', #lay().pack)
check(lay().career[1][3] and lay().career[1][3].star_soul_id == 1001,
      'kham: mon nam o career[1][3]', lay().career[1][3] and lay().career[1][3].star_soul_id)
check(c6.calls[1].f == 'ClientMountRsp', 'kham: dung callback')

-- kham de len o dang co -> mon CU ve kho
lay().pack = { { star_soul_id = 1002, level = 1, exp = 0 } }
local c6b = ctxGia()
R.handlers['G_StarSoulProtocol.ClientMountReq'](c6b, {
    { career_id = 1, cell_id = 3, pack_item = { pack_idx = 1, star_soul_id = 1002 } },
})
check(#lay().pack == 1 and lay().pack[1].star_soul_id == 1001,
      'kham de len: mon CU ve kho (khong mat do)',
      lay().pack[1] and lay().pack[1].star_soul_id)

-- ============================================================ 7. THAO
local c7 = ctxGia()
R.handlers['G_StarSoulProtocol.ClientDemountReq'](c7, { { career_id = 1, cell_id = 3 } })
check(#lay().pack == 2, 'thao: mon ve kho', #lay().pack)
check(lay().career[1][3] == nil, 'thao: o trong')
check(c7.calls[1].f == 'ClientDemountRsp', 'thao: dung callback')

-- ============================================================ 8. THAM SO SAI
local c8 = ctxGia()
R.handlers['G_StarSoulProtocol.ClientMountReq'](c8, {})
check(c8.calls[1].args[3] == 2, 'kham danh sach rong -> 2', c8.calls[1].args[3])
local c9 = ctxGia()
R.handlers['G_StarSoulProtocol.ClientDemountReq'](c9, { { career_id = 9, cell_id = 1 } })
check(c9.calls[1].args[3] == 5400, 'thao o khong ton tai -> 5400', c9.calls[1].args[3])

-- ============================================================ 9. CHIEM BOC DON
G_StarSoulDataManager.DU_LIEU = StarSoulDataManager:InitData()
lay().cur_divide = 1
G_UserLogic.GOLD = 100000
local truocVang = G_UserLogic.GOLD
local c10 = ctxGia(); R.handlers['G_StarSoulProtocol.ClientDivineReq'](c10)
check(G_UserLogic.GOLD == truocVang - 15000, 'chiem boc: tru dung 15000 vang',
      truocVang - G_UserLogic.GOLD)
check(#lay().pack == 1 and lay().pack[1].quality == 1,
      'chiem boc: cat 1 hon chat luong 1 vao tui',
      lay().pack[1] and lay().pack[1].quality)
check(type(lay().pack[1].star_soul_id) == 'string', 'chiem boc: star_soul_id la CHUOI',
      type(lay().pack[1].star_soul_id))
check(lay().cur_divide == 2, 'chiem boc: cur_divide 1 -> 2', lay().cur_divide)
check(c10.calls[1] and c10.calls[1].f == 'ClientDivineRsp'
      and type(c10.calls[1].args[1]) == 'table' and type(c10.calls[1].args[1][1]) == 'table',
      'chiem boc: ClientDivineRsp nhan MANG (setZhanXingResult lay data[1])')

-- divine 2: ti le chi co dong use_diamond=0 la quality 6 -> phai ra q6
lay().cur_divide = 2
local c11 = ctxGia(); R.handlers['G_StarSoulProtocol.ClientDivineReq'](c11)
check(lay().pack[2] and lay().pack[2].quality == 6,
      'chiem boc: bo qua nhanh kim cuong, ra chat luong 6',
      lay().pack[2] and lay().pack[2].quality)

-- khong du vang
lay().cur_divide = 1
G_UserLogic.GOLD = 10
local c12 = ctxGia(); R.handlers['G_StarSoulProtocol.ClientDivineReq'](c12)
check(c12.calls[1].args[3] == 5405, 'chiem boc: thieu vang -> 5405', c12.calls[1].args[3])

-- tui day -> hoan vang
lay().cur_divide = 1
G_UserLogic.GOLD = 100000
local d = lay()
d.pack = {}
for i = 1, 100 do d.pack[i] = { star_soul_id = '1003', quality = 6, level = 1, exp = 0 } end
local c13 = ctxGia(); R.handlers['G_StarSoulProtocol.ClientDivineReq'](c13)
check(c13.calls[1].args[3] == 5403, 'chiem boc: tui day -> 5403', c13.calls[1].args[3])
check(G_UserLogic.GOLD == 100000, 'chiem boc: tui day -> HOAN vang', G_UserLogic.GOLD)

-- ============================================================ 9b. SAU KHOA DONG
local DONG = { 'ClientBatchDivineReq', 'ClientConjureZiwenReq',
               'ClientBuyPackReq', 'ClientBatchUpgradeReq' }
local sai = {}
for _, t in ipairs(DONG) do
    local c = ctxGia()
    R.handlers['G_StarSoulProtocol.' .. t](c)
    if c.calls[1].args[3] ~= 5400 then sai[#sai + 1] = t end
end
check(#sai == 0, 'bay khoa CHUA LAM tra 5400', table.concat(sai, ','))

-- ============================================================ 10. GHEP CAP
G_StarSoulDataManager.DU_LIEU = StarSoulDataManager:InitData()
lay().pack = {
    { star_soul_id = '1001', level = 1, exp = 0 },
    { star_soul_id = '1001', level = 1, exp = 150 },
    { star_soul_id = '1001', level = 1, exp = 60 },
}
local c20 = ctxGia()
R.handlers['G_StarSoulProtocol.ClientUpgradeInPackReq'](c20, 1, lay().pack[1],
    { { pack_idx = 3, star_soul_id = '1001', level = 1, exp = 60 },
      { pack_idx = 2, star_soul_id = '1001', level = 1, exp = 150 } })
check(#lay().pack == 1, 'gop: tieu het 2 mon, con 1', #lay().pack)
check(lay().pack[1].level == 2 and lay().pack[1].exp == 110,
      'gop: cap/exp dung (2 / 110)',
      tostring(lay().pack[1].level) .. ' / ' .. tostring(lay().pack[1].exp))
check(c20.calls[1].f == 'ClientUpgradeInPackRsp', 'gop: dung callback')

lay().career[1][2] = { star_soul_id = '1001', level = 2, exp = 110 }
lay().pack = { { star_soul_id = '1001', level = 1, exp = 90 } }
local c21 = ctxGia()
R.handlers['G_StarSoulProtocol.ClientUpgradeInCellReq'](c21, 1, 2, lay().career[1][2],
    { { pack_idx = 1, star_soul_id = '1001', level = 1, exp = 90 } })
check(lay().career[1][2].level == 3 and lay().career[1][2].exp == 0,
      'gop trong O: cap 3 / exp 0',
      tostring(lay().career[1][2].level) .. ' / ' .. tostring(lay().career[1][2].exp))
check(#lay().pack == 0, 'gop trong O: kho rong', #lay().pack)

local c22 = ctxGia()
R.handlers['G_StarSoulProtocol.ClientUpgradeInPackReq'](c22, 1, {}, {})
check(c22.calls[1].args[3] == 2, 'gop: tham so hong -> 2', c22.calls[1].args[3])
io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
