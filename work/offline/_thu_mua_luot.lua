-- _thu_mua_luot.lua — bộ thử cho `offline/handlers/mua_luot_ai.lua`
-- (chạy bằng `python _thu_nha_cua.py _thu_mua_luot.lua`).
--
-- Chỉ đo ĐƯỜNG NỐI của handler: proxy LỚP CHA, phong bì trả lời, ba nhánh lỗi.
-- LUẬT thật (`costDiamondToResetBattleCount`) là mã gốc và KHÔNG chép lại ở đây.
package.path = [[__SC__/?.lua;__SC__/?/init.lua;]] .. package.path

local function ghi(m) io.write('[log] ' .. tostring(m) .. '\n') end
package.preload['offline.log'] = function ()
    local L = { info = ghi, warn = ghi, err = ghi }
    OfflineLog = L
    return L
end
package.preload['offline.store'] = function ()
    local S = { TABLES = {}, data = {}, dirty = false }
    function S:syncFromClient() self.dongBo = (self.dongBo or 0) + 1 end
    OfflineStore = S
    return S
end
package.preload['offline.router'] = function ()
    local R = { handlers = {} }
    function R:on(k, f) self.handlers[k] = f end
    function R:has(k) return self.handlers[k] ~= nil end
    OfflineRouter = R
    return R
end

-- Lớp CHA + thể hiện, đúng khuôn `class()`: thể hiện có proxy trỏ về lớp cha.
ChapterLogic = {}
function ChapterLogic:costDiamondToResetBattleCount(strChapterKey)
    if strChapterKey == "THAP_BAI" then return false end
    if strChapterKey == "NO_BIEN" then error("no bien") end
    return true
end
ClientChapterLogic = {}
G_ChapterLogic = setmetatable({}, { __index = ChapterLogic })
G_ChapterLogic[ChapterLogic] = ChapterLogic


-- Stub cho ClientBuyChapterSweepCount (thêm 30/10)
local BASE = { Diamond = 100 }
G_UserLogic = {}
function G_UserLogic:GetBaseInfo() return true, BASE end
function G_UserLogic:CostDiamond(n) BASE.Diamond = BASE.Diamond - n; return true end
local SWEEP = 2
G_ChapterDataManager = {}
function G_ChapterDataManager:GetSweepCount() return true, SWEEP end
function G_ChapterDataManager:SetSweepCount(n) SWEEP = n; return true end

dofile([[__SC__/offline/handlers/mua_luot_ai.lua]])

local R = require('offline.router')
local dat, hong = 0, 0
local function check(ok, ten, ct)
    if ok then dat = dat + 1; io.write('  OK   ' .. ten .. '\n')
    else hong = hong + 1; io.write('  HONG ' .. ten .. (ct ~= nil and (' -> ' .. tostring(ct)) or '') .. '\n') end
end

local function ctxGia()
    local c = { calls = {} }
    function c:call(obj, f, a, b, err_, ev, ...)
        self.calls[#self.calls + 1] = { obj = obj, f = f, a = a, b = b, err = err_, n = select('#', ...), x = ... }
    end
    return c
end

check(R:has('G_ChapterLogic.ClientBuyChapterBattleResetCount'),
      'da dang ky G_ChapterLogic.ClientBuyChapterBattleResetCount')

local h = R.handlers['G_ChapterLogic.ClientBuyChapterBattleResetCount']

-- 1. thành công: callback PHƯƠNG THỨC + key đi qua vararg
local c1 = ctxGia()
h(c1, 'L_N_01_01')
local k1 = c1.calls[1]
check(k1 ~= nil and k1.obj == 'g_CUIGameRPCManager' and k1.f == 'OnReciveResponse'
      and k1.a == 'G_ChapterLogic' and k1.b == 'OnServerBuyChapterBattleResetCount'
      and k1.err == 0 and k1.x == 'L_N_01_01',
      'thanh cong: OnReciveResponse(G_ChapterLogic, OnServerBuyChapterBattleResetCount, 0, key)', k1 and k1.b)
check(OfflineStore.dongBo and OfflineStore.dongBo > 0, 'co goi syncFromClient sau khi chay')

-- 2. luật gốc từ chối -> mã 1, KHÔNG gọi callback
local c2 = ctxGia()
h(c2, 'THAP_BAI')
local k2 = c2.calls[1]
check(k2 ~= nil and k2.a == '' and k2.b == '' and k2.err == 1,
      'luat goc tra false -> err 1, khong callback', k2 and k2.err)

-- 3. luật gốc NÉM lỗi -> vẫn là mã 1, không sập tiến trình
local c3 = ctxGia()
h(c3, 'NO_BIEN')
check(c3.calls[1] ~= nil and c3.calls[1].err == 1, 'luat goc nem loi -> err 1 (pcall chan)',
      c3.calls[1] and c3.calls[1].err)

-- 4. tham số rỗng -> err 1 ngay
local c4 = ctxGia()
h(c4, '')
check(c4.calls[1] ~= nil and c4.calls[1].err == 1, 'key rong -> err 1')


-- 5. MUA LUOT QUET
check(R:has('G_ChapterLogic.ClientBuyChapterSweepCount'), 'dang ky ClientBuyChapterSweepCount')
local cq1 = ctxGia()
R.handlers['G_ChapterLogic.ClientBuyChapterSweepCount'](cq1, 5)
local kq1 = cq1.calls[1]
check(kq1 and kq1.obj == 'G_ChapterLogic' and kq1.f == 'OnServerBuyChapterSweepCount'
      and kq1.a == 5 and SWEEP == 7 and BASE.Diamond == 95,
      'mua 5 luot: +5 luot, -5 kim cuong, callback (n)', { SWEEP, BASE.Diamond, kq1 and kq1.a })
local cq2 = ctxGia()
R.handlers['G_ChapterLogic.ClientBuyChapterSweepCount'](cq2, 1000)
check(cq2.calls[1].err == 1702 and cq2.calls[1].a == '',
      'thieu kim cuong -> 1702', { cq2.calls[1].err, cq2.calls[1].a })
local cq3 = ctxGia()
R.handlers['G_ChapterLogic.ClientBuyChapterSweepCount'](cq3, 0)
check(cq3.calls[1].err == 4, 'tham so 0 -> 4', cq3.calls[1].err)

io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
