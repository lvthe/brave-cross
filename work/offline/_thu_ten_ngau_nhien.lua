-- _thu_ten_ngau_nhien.lua — bộ thử cho `offline/handlers/ten_ngau_nhien.lua`
-- (chạy bằng `python _thu_nha_cua.py _thu_ten_ngau_nhien.lua`).
--
-- Đo: chuyển đúng giới tính (true = nam, false = nữ), phát ĐÚNG sự kiện `OnGetRandomName`
-- với CHUỖI tên, và KHÔNG tự bịa tên khi bộ sinh hỏng.
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

EventManagerLogicEvent = { OnGetRandomName = 'OnGetRandomName' }

-- ============================================================ GIẢ LẬP (toàn cục)
G_CharacterNameLogic = {}
G_CharacterNameLogic.LAN = {}
G_CharacterNameLogic.HONG = false
function G_CharacterNameLogic:GetName(gioiTinh)
    self.LAN[#self.LAN + 1] = gioiTinh
    if self.HONG then return false, "" end
    return true, gioiTinh and 'TranVanNam' or 'NguyenThiNu'
end

EVENT = {}
G_EventManager = {}
function G_EventManager:PostLogicEvent(data, ev) EVENT[#EVENT + 1] = { data = data, ev = ev } end

dofile([[__SC__/offline/handlers/ten_ngau_nhien.lua]])
local R = require('offline.router')

local dat, hong = 0, 0
local function check(ok, ten, ct)
    if ok then dat = dat + 1; io.write('  OK   ' .. ten .. '\n')
    else hong = hong + 1; io.write('  HONG ' .. ten .. (ct ~= nil and (' -> ' .. tostring(ct)) or '') .. '\n') end
end
local function ctxGia() local c = {}; function c:call(...) end; return c end
local function datLai()
    G_CharacterNameLogic.LAN = {}
    G_CharacterNameLogic.HONG = false
    EVENT = {}
end
local function coEvent(ten)
    for _, x in ipairs(EVENT) do if x.ev == ten then return x end end
    return nil
end

local KHOA = 'G_GameWorld.ClientGetRandomName'
local function goi(...) R.handlers[KHOA](ctxGia(), ...) end

-- ============================================================ 1. ĐĂNG KÝ
check(R:has(KHOA), 'dang ky ' .. KHOA)
check(type(OfflineTenNgauNhien) == 'table', 'co bang OfflineTenNgauNhien')

-- ============================================================ 2. NAM
datLai()
goi(true)
check(G_CharacterNameLogic.LAN[1] == true, 'gioi tinh true duoc chuyen NGUYEN (nam)',
      tostring(G_CharacterNameLogic.LAN[1]))
local ev2 = coEvent('OnGetRandomName')
check(ev2 ~= nil and ev2.data == 'TranVanNam', 'phat OnGetRandomName voi CHUOI ten',
      ev2 and tostring(ev2.data))

-- ============================================================ 3. NỮ
datLai()
goi(false)
check(G_CharacterNameLogic.LAN[1] == false, 'gioi tinh false -> nu',
      tostring(G_CharacterNameLogic.LAN[1]))
check(coEvent('OnGetRandomName') and coEvent('OnGetRandomName').data == 'NguyenThiNu',
      'ten nu duoc phat')

-- ============================================================ 4. THAM SỐ KHÔNG PHẢI BOOLEAN
datLai()
goi(nil)
check(G_CharacterNameLogic.LAN[1] == false, 'nil -> coi la nu (khac true)', tostring(G_CharacterNameLogic.LAN[1]))

-- ============================================================ 5. BỘ SINH HỎNG -> KHÔNG BỊA TÊN
datLai()
G_CharacterNameLogic.HONG = true
goi(true)
G_CharacterNameLogic.HONG = false
check(coEvent('OnGetRandomName') == nil, 'bo sinh hong -> KHONG phat ten tu che',
      coEvent('OnGetRandomName') and tostring(coEvent('OnGetRandomName').data))
check(#EVENT == 0, 'bo sinh hong -> khong phat su kien nao', #EVENT)

-- ============================================================ 6. THIẾU BỘ SINH
datLai()
local giu = G_CharacterNameLogic
G_CharacterNameLogic = nil
goi(true)
G_CharacterNameLogic = giu
check(#EVENT == 0, 'thieu G_CharacterNameLogic -> khong phat su kien', #EVENT)

io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
