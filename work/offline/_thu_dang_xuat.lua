-- _thu_dang_xuat.lua — bộ thử cho ĐĂNG XUẤT / ĐỔI TÀI KHOẢN:
--   (A) `OfflineTaiKhoan:dangXuat()` — luu kho, xoa phien, goi Logout cua client,
--       va DUONG LUI bon buoc khi `Logout` nem / khong co;
--   (B) lệnh chat `dangxuat` / `doitk` / `doitaikhoan` trong `handlers/chat.lua`.
package.path = [[__SC__/?.lua;__SC__/?/init.lua;]] .. package.path

local function ghi(m) io.write('[log] ' .. tostring(m) .. '\n') end
package.preload['offline.log'] = function ()
    local L = { info = ghi, warn = ghi, err = ghi }; OfflineLog = L; return L
end

local S = { TABLES = {}, data = {}, dirty = false, soLanLuu = 0 }
function S:path() return 'gia/offline_save_123.json' end
function S:save() self.soLanLuu = self.soLanLuu + 1; return true end
function S:syncFromClient() end
package.preload['offline.store'] = function () OfflineStore = S; return S end

package.preload['offline.router'] = function ()
    local R = { handlers = {} }
    function R:on(k, f) self.handlers[k] = f end
    function R:has(k) return self.handlers[k] ~= nil end
    function R:getFor(obj, f) return self.handlers[f] end
    OfflineRouter = R; return R
end

cjson = { decode = function (s) return {} end, encode = function (v) return '{}' end }
G_DataManager = { userData = {} }
G_UserLogic = {}
local BASE = { Diamond = 0, Gold = 0, FirstRechargeTime = 0 }
function G_UserLogic:GetBaseInfo() return true, BASE end
function G_UserLogic:AddDiamond(n) BASE.Diamond = BASE.Diamond + n; return true end
function G_UserLogic:AddGold(n) BASE.Gold = BASE.Gold + n; return true end
function G_UserLogic:GetClientCommonData() return true, nil end
function G_UserLogic:SetClientCommonData() return true end
RechargeLogic = {}
ClientRechargeLogic = {}
G_RechargeLogic = setmetatable({}, { __index = ClientRechargeLogic })
G_RechargeLogic[RechargeLogic] = RechargeLogic

-- Hẹn giờ: chạy NGAY (bộ thử không có engine), để phép kiểm thấy việc thật.
local soLanHen = 0
S_CCSchedule = {
    scheduleOnce = function (self, hen, m, d) soLanHen = soLanHen + 1; hen[m]() end,
}

local dat, hong = 0, 0
local function check(ok, ten, ct)
    if ok then dat = dat + 1; io.write('  OK   ' .. ten .. '\n')
    else hong = hong + 1; io.write('  HONG ' .. ten .. (ct ~= nil and (' -> ' .. tostring(ct)) or '') .. '\n') end
end

--------------------------------------------------------------------------- (A)
dofile([[__SC__/offline/tai_khoan.lua]])
local T = OfflineTaiKhoan

check(type(T) == 'table' and type(T.dangXuat) == 'function', 'nap duoc OfflineTaiKhoan.dangXuat')

--- Dung lai trang thai phien gia + bo dem goi cua cac buoc duong lui.
local function datLai()
    T.uid = 1014
    T.email = 'a@b.c'
    T.DA_MO = true
    T.DEM_CHO = 7
    T.pending = { ['1'] = { cb = function () error('khong duoc goi') end } }
    S.soLanLuu = 0
    soLanHen = 0
end

--- Ban gia bon buoc cua duong lui; tra bang dem.
--- `cheDo`: 'ok' = Logout chay duoc · 'nem' = Logout nem giua duong (SDK chet) ·
---          'khong' = may khong co `g_CUIUserInfo`.
local function giaDuongLui(cheDo)
    local dem = { logout = 0, phat = 0, thoat = 0, canh = 0, reset = 0 }
    G_EventManager = { PostLogicEvent = function () dem.phat = dem.phat + 1 end }
    EventManagerLogicEvent = { Logout = { OnClientLogout = 'OnClientLogout' } }
    G_GameWorld = { ExitGame = function () dem.thoat = dem.thoat + 1 end }
    g_CSceneManager = { RepaleceScene = function (self, ten) dem.canh = dem.canh + 1; dem.canhTen = ten end }
    G_DataManager = { ResetAllModule = function () dem.reset = dem.reset + 1 end }
    if cheDo == 'khong' then
        g_CUIUserInfo = nil
    else
        g_CUIUserInfo = { Logout = function (self, sz)
            dem.logout = dem.logout + 1
            dem.logoutThamSo = sz
            if cheDo == 'nem' then error('SDK_Mgr nil (gia lap SDK chet)') end
        end }
    end
    return dem
end

-- A1. Logout chay duoc: dung MOT lan, dung tham so, va duong lui KHONG chay.
datLai()
local d1 = giaDuongLui('ok')
local ok1, ly1 = T:dangXuat()
check(ok1 == true and (ly1 == 'hoan' or ly1 == 'ngay'), 'A1 dangXuat() tra true', tostring(ly1))
check(S.soLanLuu == 1, 'A1 luu kho DUNG MOT lan truoc khi roi', S.soLanLuu)
check(d1.logout == 1 and d1.logoutThamSo == 'ChangeUser',
      'A1 goi g_CUIUserInfo:Logout("ChangeUser")', tostring(d1.logoutThamSo))
check(d1.phat == 0 and d1.thoat == 0 and d1.canh == 0 and d1.reset == 0,
      'A1 Logout chay duoc thi KHONG chay duong lui',
      string.format('phat=%d thoat=%d canh=%d reset=%d', d1.phat, d1.thoat, d1.canh, d1.reset))
check(T.uid == nil and T.email == nil, 'A1 xoa phien (uid/email = nil)',
      tostring(T.uid) .. '/' .. tostring(T.email))
check(T.DA_MO == false and T.DEM_CHO == 0, 'A1 mo lai co form dang nhap')
check(next(T.pending) == nil, 'A1 xoa het yeu cau HTTP dang cho')
check(soLanHen == 1, 'A1 HOAN mot nhip (khong doi canh giua OnReciveResponse)', soLanHen)

-- A2. Logout NEM (SDK chet): duong lui chay DU bon buoc, dung thu tu.
datLai()
local d2 = giaDuongLui('nem')
local ok2, ly2 = T:dangXuat()
check(ok2 == true, 'A2 dangXuat() van tra true khi Logout nem')
check(d2.logout == 1, 'A2 da thu Logout mot lan', d2.logout)
check(d2.phat == 1 and d2.thoat == 1 and d2.canh == 1 and d2.reset == 1,
      'A2 duong lui chay du bon buoc',
      string.format('phat=%d thoat=%d canh=%d reset=%d', d2.phat, d2.thoat, d2.canh, d2.reset))
check(d2.canhTen == 'Login', 'A2 doi canh "Login"', tostring(d2.canhTen))
check(S.soLanLuu == 1 and T.uid == nil, 'A2 van luu kho va xoa phien')

-- A3. Khong co g_CUIUserInfo: duong lui chay, khong nem.
datLai()
local d3 = giaDuongLui('khong')
local ok3 = T:dangXuat()
check(ok3 == true and d3.logout == 0 and d3.canh == 1 and d3.reset == 1,
      'A3 thieu g_CUIUserInfo -> duong lui, khong nem')

-- A4. Lenh duoc NHAN ke ca khi khong co engine (S_CCSchedule = nil).
datLai()
local cuHen = S_CCSchedule
S_CCSchedule = nil
local d4 = giaDuongLui('ok')
local ok4, ly4 = T:dangXuat()
S_CCSchedule = cuHen
check(ok4 == true and ly4 == 'ngay' and d4.logout == 1,
      'A4 khong hen duoc -> chay NGAY, van goi Logout', tostring(ly4))

-- A5. Co `LGG_CloseGame` -> DONG APP (duong chinh tu 3/11), KHONG goi Logout.
-- Ly do: do trong game, `Logout` lam app SIGSEGV o GLThread (nap lai canh Login lan hai).
datLai()
local d5 = giaDuongLui('ok')
local cuClose = rawget(_G, 'LGG_CloseGame')
LGG_CloseGame = function () d5.close = (d5.close or 0) + 1 end
-- `dangXuat` tra NGAY `(true, 'hoan')`; viec that chay trong `chay()` — nên phai doc
-- qua CALLBACK, khong phai gia tri tra ve (bai hoc tu chinh phep thu nay).
local daCb5 = nil
local ok5, ly5 = T:dangXuat(function (ok, ly) daCb5 = { ok = ok, ly = ly }; end)
LGG_CloseGame = cuClose
check(ok5 == true and ly5 == 'hoan' and daCb5 ~= nil and daCb5.ly == 'close'
      and d5.close == 1 and d5.logout == 0,
      'A5 co LGG_CloseGame -> dong app, KHONG goi Logout',
      string.format('ly=%s cb=%s close=%s logout=%s', tostring(ly5),
        tostring(daCb5 and daCb5.ly), tostring(d5.close), tostring(d5.logout)))

--------------------------------------------------------------------------- (B)
dofile([[__SC__/offline/handlers/chat.lua]])
local R = require('offline.router')

local function ctxGia()
    local c = { calls = {} }
    function c:call(obj, f, ...)
        self.calls[#self.calls + 1] = { obj = obj, f = f, args = { ... } }
    end
    return c
end
local function msg(s) return { Type = 1, Content = s, ChannelId = 1, Param = '{}' } end

check(R:has('ClientNotifyMessage'), 'B0 dang ky ClientNotifyMessage')

-- Boc `dangXuat` de DEM, khong chay lai phan that (da do o A).
local soLanDangXuat = 0
local cuDangXuat = T.dangXuat
T.dangXuat = function (self) soLanDangXuat = soLanDangXuat + 1; return true, 'gia' end

-- B1. Bon cach viet deu nhan.
local dsLenh = { 'dangxuat', '/dangxuat', 'doitk', '  DoiTaiKhoan  ' }
for i = 1, #dsLenh do
    local c = ctxGia()
    soLanDangXuat = 0
    R.handlers['ClientNotifyMessage'](c, msg(dsLenh[i]))
    local k = c.calls[1]
    check(soLanDangXuat == 1 and k ~= nil and k.args[1] == 'G_ChattingLogic'
          and k.args[2] == 'OnNotifyMessage' and k.args[3] == 0,
          'B1 lenh "' .. dsLenh[i] .. '" -> dangXuat + OnNotifyMessage(0, 0)',
          string.format('goi=%d calls=%d', soLanDangXuat, #c.calls))
end

-- B2. KHONG phai lenh: khong goi dangXuat, van tra thanh cong (chat thuong).
local dsKhong = { 'dangxuat ngay', 'dang xuat', 'doitk 1', 'xin chao', 'nap' }
for i = 1, #dsKhong do
    local c = ctxGia()
    soLanDangXuat = 0
    R.handlers['ClientNotifyMessage'](c, msg(dsKhong[i]))
    check(soLanDangXuat == 0 and #c.calls == 1 and c.calls[1].args[3] == 0,
          'B2 "' .. dsKhong[i] .. '" KHONG phai lenh dang xuat', soLanDangXuat)
end

-- B3. Lenh `nap` cu KHONG bi anh huong.
local c3 = ctxGia()
R.handlers['ClientNotifyMessage'](c3, msg('nap 100'))
check(BASE.Diamond == 100 and c3.calls[1].args[3] == 0,
      'B3 lenh "nap 100" van chay (+100 kim cuong)', BASE.Diamond)

-- B4. Thieu OfflineTaiKhoan: nuot lang, van tra loi (khong nem, khong treo).
local cuTK = OfflineTaiKhoan
OfflineTaiKhoan = nil
local c4 = ctxGia()
local okB4, errB4 = pcall(function ()
    R.handlers['ClientNotifyMessage'](c4, msg('dangxuat'))
end)
OfflineTaiKhoan = cuTK
check(okB4 and #c4.calls == 1 and c4.calls[1].args[3] == 0,
      'B4 thieu OfflineTaiKhoan: khong nem, van tra OnNotifyMessage', tostring(errB4))

T.dangXuat = cuDangXuat

io.write(string.format('KET QUA: dat %d, hong %d\n', dat, hong))
os.exit(hong == 0 and 0 or 1)
