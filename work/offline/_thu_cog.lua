-- _thu_cog.lua — bộ thử cho `offline/handlers/cog.lua` (COG / 攻城战).
-- Chạy bằng `python _thu_nha_cua.py _thu_cog.lua` (hoặc qua `_chay_het.py`).
--
-- Đo bốn thứ dễ hỏng của nhóm này:
--   1. KHOÁ ĐĂNG KÝ: 25 khoá chia hai obj GỬI khác nhau (G_COGProtocol /
--      G_COGCityDefendMission) — sai tiền tố là handler KHÔNG BAO GIỜ chạy.
--   2. OBJ NHẬN: mọi phản hồi phải đi qua `g_COGProtocol` (chữ thường) — client
--      KHÔNG có biến toàn cục `G_COGProtocol`; gửi nhầm là lớp tải quay mãi.
--   3. SỐ THAM SỐ của từng hàm nhận (một số hàm KHÔNG có tham số mã lỗi).
--   4. SHOP: đủ điểm mới mua, phát thưởng hỏng thì HOÀN điểm.
package.path = [[__SC__/?.lua;__SC__/?/init.lua;]] .. package.path

-- Gọi bằng dấu hai chấm (OfflineLog:info) nên tham số đầu có thể là chính bảng
-- log — bỏ nó đi để đọc được lý do thật.
local function ghi(a, b)
    local m = b
    if type(a) == 'string' then m = a end
    io.write('[log] ' .. tostring(m) .. '\n')
end
package.preload['offline.log'] = function ()
    local L = { info = ghi, warn = ghi, err = ghi }; OfflineLog = L; return L
end
package.preload['offline.store'] = function ()
    local S = { TABLES = {}, data = {}, dirty = false }
    function S:syncFromClient() end
    OfflineStore = S; return S
end
package.preload['offline.router'] = function ()
    local R = { handlers = {} }
    function R:on(k, f) self.handlers[k] = f end
    function R:has(k) return self.handlers[k] ~= nil end
    OfflineRouter = R; return R
end

-- Mã GỐC: `share/error.lua` (ErrorCode.COGCode + ErrorCode.RedPack.ScoreLimit).
ErrorCode = {
    COGCode = {
        NotSignUpState = 4501, AuthFail = 4502, CityNotOpen = 4504,
        NoDismissTeamId = 4506, NoDispatchTime = 4507, NoTeamDeployTime = 4512,
        NoGuild = 4513, RemainingCompleteTimesNotEnough = 4518,
        MissionStateIsNotCompleted = 4521, NoCityPlayback = 4522,
        NoPlayerPlayback = 4523, ConfigError = 4524, NotGetPrizeState = 4526,
    },
    RedPack = { ScoreLimit = 5651 },
}

-- Trạng thái giả, ĐỔI ĐƯỢC giữa các phép thử.
CO_BANG = true
DIEM = 0
PHAT_OK = true
DU_LIEU = {}
HANG = {
    { PrizeID = 119001, Cost = 1500 },
    { PrizeID = 119002, Cost = 1500 },
}

G_GuildLogic = {
    CheckIsHasJoinGuild = function () return true, CO_BANG end,
}
G_UserLogic = {
    GetClientCommonData = function (self, k) return true, DU_LIEU[k] end,
    SetClientCommonData = function (self, k, v) DU_LIEU[k] = v; return true end,
}
G_ConfigManager = {
    GetCommonConfigWithName = function (self, ten)
        if ten == "GameCOGGoodsConfig" then return HANG end
        return nil
    end,
}
G_PrizeLogic = {
    GetPrizeWithID = function (self, id) return true, { PrizeContent = { { PrizeID = id } } } end,
}
G_ChapterLogic = {
    SetDataWithPrizeData = function (self, prize, so, lyDo) return PHAT_OK end,
}
G_COGDataManager = {
    GetCOGScore = function (self) return true, DIEM end,
    AddCOGScore = function (self, n) DIEM = DIEM + n; return true end,
}
EventManagerType = { Logic = 1 }
EventManagerLogicEvent = { COG = { OnBuyCOGGoods = "OnBuyCOGGoods" } }

g_CUIGameRPCManager = {}
function g_CUIGameRPCManager:OnReciveResponse(...)
    self.lan = { n = select('#', ...), ... }
end

dofile([[__SC__/offline/handlers/cog.lua]])
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
        -- Bộ thử tối thiểu chỉ có MỘT hàm nhận "thật": g_CUIGameRPCManager.
        -- (Trong game, net.lua gọi CallLocal; ở đây không có net.)
        local o = _G[obj]
        if type(o) == 'table' and type(o[f]) == 'function' then
            o[f](o, ...)
        end
    end
    return c
end
local function goi(khoa, ...)
    local c = ctxGia()
    local h = R.handlers[khoa]
    if h == nil then return nil, c end
    h(c, ...)
    return c.calls[1], c, #c.calls
end

--=========================================================== 1. ĐĂNG KÝ + OBJ
io.write('\n-- 1. dang ky 25 khoa + obj nhan la g_COGProtocol\n')

local KHOA = {
    { 'G_COGProtocol', 'ClientGetBriefInfo' },
    { 'G_COGProtocol', 'ClientGetCOGInfo' },
    { 'G_COGProtocol', 'ClientGetCityInfo' },
    { 'G_COGProtocol', 'ClientGetMyTeamList' },
    { 'G_COGProtocol', 'ClientGetGuildTeamProfile' },
    { 'G_COGProtocol', 'ClientGetGuildTeamList' },
    { 'G_COGProtocol', 'ClientGetGuildBattleReport' },
    { 'G_COGProtocol', 'ClientGetCityReport' },
    { 'G_COGProtocol', 'ClientGetPlayerBattleReport' },
    { 'G_COGProtocol', 'ClientGetCityPlayback' },
    { 'G_COGProtocol', 'ClientGetPlayerPlayback' },
    { 'G_COGProtocol', 'ClientSignUp' },
    { 'G_COGProtocol', 'ClientSetTargetCity' },
    { 'G_COGProtocol', 'ClientSetGuildMsg' },
    { 'G_COGProtocol', 'ClientAddTeam' },
    { 'G_COGProtocol', 'ClientUpdateTeam' },
    { 'G_COGProtocol', 'ClientRemoveTeam' },
    { 'G_COGProtocol', 'ClientDispatchTeam' },
    { 'G_COGProtocol', 'ClientBuyGoods' },
    { 'G_COGCityDefendMission', 'ClientGetCityDefendMission' },
    { 'G_COGCityDefendMission', 'ClientManualRefreshMission' },
    { 'G_COGCityDefendMission', 'ClientGetPrize' },
    { 'G_COGCityDefendMission', 'ClientRepairCity' },
    { 'G_COGCityDefendMission', 'ClientAttackCity' },
    { 'G_COGCityDefendMission', 'ClientGetDailyOccupyPrize' },
}
local thieu = {}
for _, cap in ipairs(KHOA) do
    if not R:has(cap[1] .. '.' .. cap[2]) then thieu[#thieu + 1] = cap[1] .. '.' .. cap[2] end
end
check(#thieu == 0, 'dang ky DU 25 khoa', table.concat(thieu, ', '))

-- Mọi phản hồi (trừ shop đi qua g_CUIGameRPCManager) phải là obj `g_COGProtocol`.
local function nhan(khoa, ...)
    local x = goi(khoa, ...)
    check(x ~= nil and x.obj == 'g_COGProtocol',
        khoa .. ': tra loi qua g_COGProtocol (chu thuong)', x and x.obj)
    return x
end

--=========================================================== 2. ĐỌC
io.write('\n-- 2. lenh DOC: mua CHUA MO (Step = 0)\n')

local x = nhan('G_COGProtocol.ClientGetBriefInfo')
check(x and x.f == 'OnGetBriefInfo' and x.n == 2, 'brief -> OnGetBriefInfo(err, data)')
check(x and x.args[1] == 0 and type(x.args[2]) == 'table' and x.args[2].Step == 0,
    'brief: ma 0 + Step = 0 (chua mo)')

x = nhan('G_COGProtocol.ClientGetCOGInfo')
check(x and x.f == 'OnGetCOGInfo' and x.n == 2, 'info -> OnGetCOGInfo(err, data)')
check(x and x.args[1] == 0 and type(x.args[2]) == 'table', 'info: ma 0 + bang du lieu')
check(x and x.args[2].Step == 0, 'info: Step = 0')
check(x and type(x.args[2].CityList) == 'table', 'info: CityList la BANG (28 thanh client tu dung)')
check(x and type(x.args[2].DfendTask) == 'table', 'info: DfendTask dung loi chinh ta cua client')
check(x and type(x.args[2].BattleReport) == 'table', 'info: BattleReport la bang')

x = nhan('G_COGProtocol.ClientGetCityInfo', 7)
check(x and x.f == 'OnGetCityInfo' and x.n == 2, 'city info -> OnGetCityInfo(err, data)')
check(x and x.args[1] == 0 and x.args[2].CityID == 7, 'city info: giu CityID = 7')
check(x and x.args[2].GuildID == 0 and x.args[2].Defend == 0, 'city info: thanh VO CHU')
check(x and type(x.args[2].ApplyList) == 'table' and #x.args[2].ApplyList == 0,
    'city info: khong co don xin danh')

x = nhan('G_COGProtocol.ClientGetMyTeamList')
check(x and x.f == 'OnGetMyTeamList' and x.args[1] == 0 and #x.args[2] == 0,
    'doi cua minh -> ma 0 + danh sach RONG')

x = nhan('G_COGProtocol.ClientGetGuildTeamProfile', 1)
check(x and x.f == 'OnGetGuildTeamProfile' and x.args[1] == 0 and #x.args[2] == 0,
    'doi bang khac -> ma 0 + rong')

x = nhan('G_COGProtocol.ClientGetGuildTeamList', {})
check(x and x.f == 'OnGetGuildTeamList' and #x.args[2] == 0, 'danh sach doi bang -> rong')

x = nhan('G_COGProtocol.ClientGetGuildBattleReport')
check(x and x.f == 'OnGetGuildBattleReport' and x.args[1] == 0, 'chien bao bang -> ma 0')

x = nhan('G_COGProtocol.ClientGetCityReport', 3)
check(x and x.f == 'OnGetCityReport' and x.args[1] == 0 and #x.args[2] == 0,
    'chien bao thanh -> ma 0 + rong')

x = nhan('G_COGProtocol.ClientGetPlayerBattleReport')
check(x and x.args[1] == 4523, 'chien bao ca nhan -> 4523 (ham nhan cua client KHONG TON TAI)')

x = nhan('G_COGProtocol.ClientGetCityPlayback', 3, true)
check(x and x.args[1] == 4522 and x.args[3] == true, 'ban ghi hinh thanh -> 4522 + giu bBattle')

x = nhan('G_COGProtocol.ClientGetPlayerPlayback')
check(x and x.args[1] == 4523, 'ban ghi hinh ca nhan -> 4523')

--=========================================================== 3. THAO TÁC
io.write('\n-- 3. lenh THAO TAC: ma GOC COGCode\n')

CO_BANG = true

x = nhan('G_COGProtocol.ClientSignUp', 5)
check(x and x.f == 'OnSignUp' and x.args[1] == 4501 and x.args[2] == 5,
    'dang ky -> 4501 NotSignUpState + giu cityId')

CO_BANG = false
x = nhan('G_COGProtocol.ClientSignUp', 5)
check(x and x.args[1] == 4513, 'dang ky khi CHUA CO BANG -> 4513 NoGuild')
CO_BANG = true

x = nhan('G_COGProtocol.ClientSetTargetCity', 9, true)
check(x and x.f == 'OnSetTargetCity' and x.args[1] == 4501 and x.args[2] == 9,
    'chon thanh -> 4501 + giu cityId')

x = nhan('G_COGProtocol.ClientAddTeam', { 25 })
check(x and x.f == 'OnAddTeam' and x.args[1] == 4512, 'lap doi -> 4512 NoTeamDeployTime')

x = nhan('G_COGProtocol.ClientUpdateTeam', 1, { 25 })
check(x and x.f == 'OnUpdateTeam' and x.args[1] == 4512, 'sua doi -> 4512')

x = nhan('G_COGProtocol.ClientRemoveTeam', 4)
check(x and x.f == 'OnRemoveTeam' and x.args[1] == 4506 and x.args[2] == 4,
    'giai tan doi -> 4506 + giu teamId')

x = nhan('G_COGProtocol.ClientDispatchTeam', { ['1'] = 1 })
check(x and x.f == 'OnDispatchTeam' and x.args[1] == 4507, 'dieu doi -> 4507 NoDispatchTime')

x = nhan('G_COGCityDefendMission.ClientRepairCity', 3)
check(x and x.f == 'OnRepairCity' and x.args[1] == 4518, 'sua thanh -> 4518 (con 0 luot)')

x = nhan('G_COGCityDefendMission.ClientAttackCity', 3)
check(x and x.f == 'OnAttackCity' and x.args[1] == 4518, 'pha thanh -> 4518')

--=========================================================== 4. THÀNH TRÌ
io.write('\n-- 4. thanh tri: ham nhan KHONG co tham so ma loi\n')

x = nhan('G_COGCityDefendMission.ClientGetCityDefendMission')
check(x and x.f == 'OnGetCityDefendMission' and x.args[1] == 0 and #x.args[2] == 0,
    'nhiem vu thanh -> ma 0 + nhiem vu RONG')

x = nhan('G_COGCityDefendMission.ClientManualRefreshMission')
check(x and x.f == 'OnManualRefreshMission' and x.n == 1 and type(x.args[1]) == 'table',
    'lam moi -> OnManualRefreshMission(data) MOT tham so')

x = nhan('G_COGCityDefendMission.ClientGetPrize', 12)
check(x and x.f == 'OnGetPrize' and x.n == 1 and type(x.args[1]) == 'table',
    'nhan thuong -> OnGetPrize(data) MOT tham so')

x = nhan('G_COGCityDefendMission.ClientGetDailyOccupyPrize')
check(x and x.f == 'OnGetDailyOccupyPrize' and x.n == 0,
    'thuong chiem thanh -> OnGetDailyOccupyPrize() KHONG tham so')

--=========================================================== 5. LỜI NHẮN
io.write('\n-- 5. loi nhan bang hoi: luu that + tra lai trong info\n')

x = nhan('G_COGProtocol.ClientSetGuildMsg', 'Bang thu offline')
check(x and x.f == 'OnSetGuildMsg' and x.args[1] == 0, 'dat loi nhan -> ma 0')
check(DU_LIEU['OfflineCOGGuildMsg'] == 'Bang thu offline', 'loi nhan da LUU vao common data')
x = nhan('G_COGProtocol.ClientGetCOGInfo')
check(x and x.args[2].GuildMsg == 'Bang thu offline', 'info tra lai DUNG loi nhan')

--=========================================================== 6. SHOP
io.write('\n-- 6. shop diem COG\n')

-- Hàm trả kết quả shop ghi vào g_CUIGameRPCManager:OnReciveResponse.
local function lanShop() return g_CUIGameRPCManager.lan end

DIEM = 0
g_CUIGameRPCManager.lan = nil
goi('G_COGProtocol.ClientBuyGoods', 1)
check(lanShop() ~= nil and lanShop().n == 4, 'mua -> OnReciveResponse(4 tham so)')
check(lanShop() and lanShop()[3] == 5651, 'diem 0 -> 5651 (khong du diem)')
check(DIEM == 0, 'diem 0: KHONG bi tru')

DIEM = 2000
PHAT_OK = true
g_CUIGameRPCManager.lan = nil
goi('G_COGProtocol.ClientBuyGoods', 1)
check(lanShop() and lanShop()[3] == 0, 'du diem -> ma 0')
check(DIEM == 500, 'tru dung gia 1500 (2000 -> 500)', DIEM)
check(lanShop() and type(lanShop()[4]) == 'table' and #lanShop()[4] == 1
    and lanShop()[4][1].EventName == 'OnBuyCOGGoods',
    'mua xong PHAI phat COG.OnBuyCOGGoods de UI ve lai')

-- Phát thưởng hỏng: phải HOÀN điểm.
DIEM = 3000
PHAT_OK = false
g_CUIGameRPCManager.lan = nil
goi('G_COGProtocol.ClientBuyGoods', 2)
check(lanShop() and lanShop()[3] == 4524, 'phat thuong hong -> 4524 ConfigError')
check(DIEM == 3000, 'phat thuong hong -> HOAN du diem (van 3000)', DIEM)
PHAT_OK = true

-- Chỉ số ngoài bảng.
DIEM = 5000
g_CUIGameRPCManager.lan = nil
goi('G_COGProtocol.ClientBuyGoods', 99)
check(lanShop() and lanShop()[3] == 4524, 'chi so ngoai bang -> 4524')
check(DIEM == 5000, 'chi so ngoai bang: khong tru diem')

-- Chưa có bang.
CO_BANG = false
g_CUIGameRPCManager.lan = nil
goi('G_COGProtocol.ClientBuyGoods', 1)
check(lanShop() and lanShop()[3] == 4513, 'chua co bang -> 4513 NoGuild')
check(DIEM == 5000, 'chua co bang: khong tru diem')
CO_BANG = true

io.write('\nKET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
