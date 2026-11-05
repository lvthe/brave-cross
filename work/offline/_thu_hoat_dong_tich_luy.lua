-- _thu_hoat_dong_tich_luy.lua — bộ thử cho `offline/handlers/hoat_dong_tich_luy.lua`
-- (chạy bằng `python _thu_nha_cua.py _thu_hoat_dong_tich_luy.lua`).
--
-- Bộ thử nạp LUÔN `offline/hoat_dong.lua` THẬT (qua `require`) để đo cả chỗ nối.
-- KHÔNG thử ở đây: `share/` thật (máy Lua trần không có) — các hàm ấy được giả lập
-- đúng hình dạng đã đọc trong `ClientActivityCumulativeRecharge/Consume.lua`.
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
local CONG = {}                     -- GameUserGlobalData giả
G_UserDataManager = {}
function G_UserDataManager:GetUserGlobalData(k) return 0, CONG[k] end
function G_UserDataManager:SetUserGlobalData(k, v) CONG[k] = v; return true end

G_RechargeLogic = {}
G_RechargeLogic.N = 0
function G_RechargeLogic:GetUserRechargeCount() return true, G_RechargeLogic.N end

local DA_PHAT = {}
G_ChapterLogic = {}
G_ChapterLogic.LOI = false
function G_ChapterLogic:SetDataWithPrizeList(ds)
    if self.LOI then return false end
    DA_PHAT[#DA_PHAT + 1] = ds
    return true
end

local SU_KIEN = {}
G_EventManager = {}
function G_EventManager:PostLogicEvent(d, ten) SU_KIEN[#SU_KIEN + 1] = { ten = ten, d = d } end
EventManagerLogicEvent = {
    Active = {
        OnGetCumulativeRechargePrize = 'OnGetCumulativeRechargePrize',
        OnGetCumulativeConsumePrize = 'OnGetCumulativeConsumePrize',
    },
}

G_GameWorld = {}
function G_GameWorld:GetServerTime() return 1700000000 end

G_ActivityLogic = {}
G_ActivityLogic.MO = true
G_ActivityLogic.CAU_HINH = {
    CumulativeRecharge = {
        { Recharge = 100, PrizeList = { { PrizeResType = 2, PropID = 1, PrizeResCount = 1 } } },
        { Recharge = 500, PrizeList = { { PrizeResType = 2, PropID = 1, PrizeResCount = 5 } } },
    },
    CumulativeConsume = {
        { Consume = 200, PrizeList = { { PrizeResType = 2, PropID = 2, PrizeResCount = 1 } } },
    },
}
function G_ActivityLogic:GetActivityConfigWithType(t) return self.CAU_HINH[t] end
function G_ActivityLogic:CheckActivityIsOpenWithType(t) return self.MO end

-- G_UserLogic: chỉ hai hàm bị bọc.
G_UserLogic = {}
G_UserLogic.DU_VANG = 10000
G_UserLogic.DU_KC = 10000
function G_UserLogic:CostGold(n)
    if self.DU_VANG < n then return false, 0 end
    self.DU_VANG = self.DU_VANG - n
    return true, self.DU_VANG
end
function G_UserLogic:CostDiamond(n)
    if self.DU_KC < n then return false, 0 end
    self.DU_KC = self.DU_KC - n
    return true, self.DU_KC
end

dofile([[__SC__/offline/handlers/hoat_dong_tich_luy.lua]])
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

local NAP_STATE = 'G_ActivityCumulativeRecharge.ClientGetUserState'
local NAP_PRIZE = 'G_ActivityCumulativeRecharge.ClientGetPrize'
local TIEU_STATE = 'G_ActivityCumulativeConsume.ClientGetUserState'
local TIEU_PRIZE = 'G_ActivityCumulativeConsume.ClientGetPrize'

check(R:has(NAP_STATE) and R:has(NAP_PRIZE) and R:has(TIEU_STATE) and R:has(TIEU_PRIZE),
      'dang ky 4 khoa')

-- ============================================================ 1. BOC DEM TIEU
check(OfflineTichLuy:dam_bao() == true, 'dam_bao() boc duoc CostGold + CostDiamond')
--[[ ĐO 31/10: gọi bằng DẤU CHẤM (self = nil) — đúng lỗi làm GAME THOÁT khi
	`init.lua` gọi `OfflineTichLuy.dam_bao()`. Phép này là cái bắt nó. ]]
local okCham, kqCham = pcall(function () return OfflineTichLuy.dam_bao() end)
check(okCham == true, 'goi bang DAU CHAM khong no (self = nil)', kqCham)
check(kqCham == true, 'goi bang DAU CHAM van boc duoc', kqCham)
check(CONG.CumulativeConsumeValue == nil, 'chua tieu gi -> chua co bo dem')
G_UserLogic:CostGold(100)
check(CONG.CumulativeConsumeValue == 100, 'tieu 100 vang -> dem 100', CONG.CumulativeConsumeValue)
G_UserLogic:CostDiamond(50)
check(CONG.CumulativeConsumeValue == 150, 'tieu 50 kim cuong -> dem 150', CONG.CumulativeConsumeValue)

-- trừ THẤT BẠI thì không đếm
G_UserLogic.DU_VANG = 0
local okThat, _ = G_UserLogic:CostGold(999)
check(okThat == false and CONG.CumulativeConsumeValue == 150, 'tru that bai -> KHONG dem',
      CONG.CumulativeConsumeValue)
G_UserLogic.DU_VANG = 10000

-- ============================================================ 2. HOAT DONG DONG
G_ActivityLogic.MO = false
local c1 = ctxGia()
R.handlers[NAP_STATE](c1)
check(demMa(c1) == 4001, 'hoat dong dong -> 4001', demMa(c1))
G_ActivityLogic.MO = true

-- ============================================================ 3. NAP: GETSTATE
G_RechargeLogic.N = 300
CONG.CumulativeRechargeState = nil
local c2 = ctxGia()
R.handlers[NAP_STATE](c2)
check(c2.calls[1] and c2.calls[1].obj == 'G_ActivityCumulativeRecharge'
      and c2.calls[1].f == 'OnGetCumulativeRechargeData',
      'nap GetUserState: dung callback', c2.calls[1] and c2.calls[1].f)
check(c2.calls[1].args[1] == 300, 'nap GetUserState: so nap = 300', c2.calls[1].args[1])
check(type(c2.calls[1].args[2]) == 'table', 'nap GetUserState: state la BANG')

-- ============================================================ 4. NAP: LINH BAC 1
DA_PHAT = {}
SU_KIEN = {}
local c3 = ctxGia()
R.handlers[NAP_PRIZE](c3, 1)
check(#DA_PHAT == 1, 'nap GetPrize: phat 1 danh sach thuong', #DA_PHAT)
check(CONG.CumulativeRechargeState and CONG.CumulativeRechargeState['1'] == true,
      'nap GetPrize: danh dau bac 1')
check(SU_KIEN[1] and SU_KIEN[1].ten == 'OnGetCumulativeRechargePrize',
      'nap GetPrize: phat su kien', SU_KIEN[1] and SU_KIEN[1].ten)
check(c3.calls[1].f == 'OnReciveResponse' and c3.calls[1].args[3] == 0,
      'nap GetPrize: tat lop dang tai')

-- ============================================================ 5. NAP: LINH LAI
local c4 = ctxGia()
R.handlers[NAP_PRIZE](c4, 1)
check(demMa(c4) == 4007, 'nap: linh lai -> 4007', demMa(c4))

-- ============================================================ 6. NAP: CHUA DU
G_RechargeLogic.N = 100
local c5 = ctxGia()
R.handlers[NAP_PRIZE](c5, 2)          -- bac 2 doi 500
check(demMa(c5) == 4008, 'nap 100 < 500 -> 4008', demMa(c5))

-- ============================================================ 7. NAP: BAC LA
local c6 = ctxGia()
R.handlers[NAP_PRIZE](c6, 99)
check(demMa(c6) == 4001, 'bac khong ton tai -> 4001', demMa(c6))
local c6b = ctxGia()
R.handlers[NAP_PRIZE](c6b, nil)
check(demMa(c6b) == 2, 'index nil -> 2', demMa(c6b))

-- ============================================================ 8. TIEU: GETSTATE
CONG.CumulativeConsumeValue = 250
CONG.CumulativeConsumeState = nil
local c7 = ctxGia()
R.handlers[TIEU_STATE](c7)
check(c7.calls[1].f == 'OnGetCumulativeConsumeData', 'tieu GetUserState: dung callback',
      c7.calls[1].f)
check(c7.calls[1].args[1] == 250, 'tieu GetUserState: so tieu = 250', c7.calls[1].args[1])

-- ============================================================ 9. TIEU: LINH
DA_PHAT = {}
SU_KIEN = {}
local c8 = ctxGia()
R.handlers[TIEU_PRIZE](c8, 1)
check(#DA_PHAT == 1, 'tieu GetPrize: phat thuong', #DA_PHAT)
check(CONG.CumulativeConsumeState and CONG.CumulativeConsumeState['1'] == true,
      'tieu GetPrize: danh dau bac 1')
check(SU_KIEN[1] and SU_KIEN[1].ten == 'OnGetCumulativeConsumePrize',
      'tieu GetPrize: phat su kien')

-- ============================================================ 10. TIEU: CHUA DU
CONG.CumulativeConsumeValue = 10
CONG.CumulativeConsumeState = {}      -- bo dau "da linh" cua muc 9
local c9 = ctxGia()
R.handlers[TIEU_PRIZE](c9, 1)         -- bac 1 doi 200
check(demMa(c9) == 4009, 'tieu 10 < 200 -> 4009', demMa(c9))

-- ============================================================ 11. PHAT HONG
CONG.CumulativeConsumeValue = 999
CONG.CumulativeConsumeState = {}
G_ChapterLogic.LOI = true
local c10 = ctxGia()
R.handlers[TIEU_PRIZE](c10, 1)
check(demMa(c10) == 1, 'SetDataWithPrizeList hong -> ma 1', demMa(c10))
check(CONG.CumulativeConsumeState['1'] == nil, 'phat hong -> KHONG danh dau bac')
G_ChapterLogic.LOI = false

io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
