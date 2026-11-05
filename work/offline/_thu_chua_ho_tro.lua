-- _thu_chua_ho_tro.lua — bộ thử cho `offline/handlers/chua_ho_tro.lua` (lớp chắn cuối).
-- Chạy: `python _thu_nha_cua.py _thu_chua_ho_tro.lua`.
--
-- Mỗi nhóm một mã GỐC; mọi khoá phải DỪNG lớp tải (OnReciveResponse) và KHÔNG gọi
-- hàm nhận nào khác (không bịa dữ liệu).
package.path = [[__SC__/?.lua;__SC__/?/init.lua;]] .. package.path

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

RSP = {}
g_CUIGameRPCManager = {}
function g_CUIGameRPCManager:OnReciveResponse(...)
    RSP[#RSP + 1] = { n = select('#', ...), ... }
end

dofile([[__SC__/offline/handlers/chua_ho_tro.lua]])
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
        if obj == 'g_CUIGameRPCManager' then
            local o = _G[obj]
            if type(o) == 'table' and type(o[f]) == 'function' then o[f](o, ...) end
        end
    end
    return c
end
local function goi(chave)
    local c = ctxGia()
    local h = R.handlers[chave]
    if h == nil then return nil end
    h(c)
    return c
end
local function maCuoi() return RSP[#RSP] and RSP[#RSP][3] end

--=========================================================== 1. ĐĂNG KÝ
io.write('\n-- 1. dang ky\n')
local dong = 0
for _, h in pairs(R.handlers) do dong = dong + 1 end
check(dong == 76, 'dang ky DU 76 khoa (da rut 2 khoa trang bi doc quyen + 2 canh + 2 dich vu ngoai + 2 giai dau)', dong)

--=========================================================== 2. MÃ GỐC THEO NHÓM
io.write('\n-- 2. ma goc theo nhom\n')
local DS = {
    { 'G_TournamentLogic.ClientGetBattleReport', 4401, 'giai dau (nhom chua noi) -> 4401 Closed' },
    { 'G_WCSProtocol.ClientGetWCSInfo', 5201, 'xuyen may chu -> 5201 Closed' },
    { 'G_ActivityRankLogic.ClientGetPlayerDiamondConsume', 4001, 'hoat dong -> 4001' },
    { 'G_ActivityWushuang.ClientGetWushuangRankList', 4001, 'hoat dong khac -> 4001' },
    { 'G_GuildStoreLogic.ClientRefreshWithContribution', 1, 'cua hang bang -> 1' },
    { 'G_MagicWeaponTreasureBox.ClientOpenBoxWithKey', 5002, 'hop than binh -> 5002' },
    { 'G_ItemLogic.ClientSellRedundantExclusiveItem', 1, 'ban do du thua -> 1' },
    { 'G_CloudShopLogic.ClientChangeCloudShopStatus', 1, 'khong co ma rieng -> 1' },
}
for _, m in ipairs(DS) do
    local x = goi(m[1])
    check(x and #x.calls == 1 and x.calls[1].obj == 'g_CUIGameRPCManager'
        and x.calls[1].f == 'OnReciveResponse' and maCuoi() == m[2],
        m[1] .. ' -> ' .. m[3], maCuoi())
end

--=========================================================== 3. NUỐT LẶNG
io.write('\n-- 3. hai khoa nuot lang (ma 0, khong toast)\n')
goi('G_Login.ClientBindingChannelAccount')
check(maCuoi() == 0, 'lien ket kenh -> ma 0')
goi('G_PotionLogic.ClientCompleteUpgradePotion')
check(maCuoi() == 0, 'thuoc chet -> ma 0')

--=========================================================== 4. KHÔNG GỌI HÀM NHẬN
io.write('\n-- 4. khong goi ham nhan nao khac\n')
local x = goi('G_FriendLogic.ClientGetQQWXFriendDetail')
check(x and #x.calls == 1, 'chi dung MOT loi goi (dong lop tai)', x and #x.calls)

io.write('\nKET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
