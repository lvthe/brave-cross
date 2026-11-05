-- _thu_qua_ngay.lua — bộ thử cho `offline/qua_ngay.lua`
-- (chạy bằng `python _thu_nha_cua.py _thu_qua_ngay.lua`).
--
-- Đo ba thứ mà một móc "mỗi ngày" dễ hỏng nhất:
--   1. KHOÁ NGÀY: cùng ngày thì KHÔNG chạy lại; sang ngày thì chạy đúng một lượt.
--   2. MỐC 5 GIỜ: 04:59 vẫn là ngày hôm trước (đúng `DialyRefreshHour`).
--   3. MỘT HỆ HỎNG KHÔNG KÉO THEO HỆ KIA, và khoá ngày vẫn được ghi.
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

-- ============================================================ GIẢ LẬP CLIENT
local UC = {}
UC.DATA = {}
G_UserLogic = {}
function G_UserLogic:GetClientCommonData(k) return true, UC.DATA[k] end
function G_UserLogic:SetClientCommonData(k, v) UC.DATA[k] = v; return true end

EventManagerType = { Logic = 1 }
EventManagerLogicEvent = { OnEnterGame = 'OnEnterGame' }
G_EventManager = { registrations = {} }
function G_EventManager:Reg(obj, fn, typ, ev)
    self.registrations[#self.registrations + 1] = { obj = obj, fn = fn, typ = typ, ev = ev }
end

-- Giả lập hai hệ: đếm lượt gọi, có thể bật cờ "ném lỗi".
local function heGia(ten)
    local h = { LAN = 0, NEM = false, ten = ten }
    function h:kiem_ngay()
        self.LAN = self.LAN + 1
        if self.NEM then error('no gia lap ' .. self.ten) end
        return true
    end
    return h
end
OfflineQua7Ngay = heGia('Qua7Ngay')
OfflineKimThu = heGia('KimThu')

dofile([[__SC__/offline/qua_ngay.lua]])

local dat, hong = 0, 0
local function check(ok, ten, ct)
    if ok then dat = dat + 1; io.write('  OK   ' .. ten .. '\n')
    else hong = hong + 1; io.write('  HONG ' .. ten .. (ct ~= nil and (' -> ' .. tostring(ct)) or '') .. '\n') end
end

-- Đóng băng giờ: os.date("*t", t) vẫn tính đúng múi giờ máy, nên chỉ cần khoá os.time.
local REAL_TIME = os.time
local function datGio(nam, thang, ngay, gio, phut)
    local t = REAL_TIME({ year = nam, month = thang, day = ngay,
                          hour = gio or 12, min = phut or 0, sec = 0, isdst = false })
    os.time = function () return t end
    return t
end

-- ============================================================ 1. NỐI SỰ KIỆN
check(OfflineQuaNgay:noi_su_kien() == true, 'noi_su_kien -> true')
check(#G_EventManager.registrations == 1
      and G_EventManager.registrations[1].ev == 'OnEnterGame'
      and G_EventManager.registrations[1].obj == OfflineQuaNgay,
      'dang ky dung su kien OnEnterGame voi chinh module')

-- ============================================================ 2. LẦN ĐẦU TRONG NGÀY
datGio(2026, 11, 1, 12, 0)
UC.DATA = {}
OfflineQua7Ngay.LAN, OfflineKimThu.LAN = 0, 0
local chay2 = OfflineQuaNgay:kiem_ngay()
check(chay2 == true, 'lan dau trong ngay -> chay', tostring(chay2))
check(OfflineQua7Ngay.LAN == 1 and OfflineKimThu.LAN == 1,
      'goi CA HAI he dung mot luot', OfflineQua7Ngay.LAN .. '/' .. OfflineKimThu.LAN)
check(tonumber(UC.DATA['OfflineQuaNgayDay']) == 20261101,
      'ghi khoa ngay 20261101', tostring(UC.DATA['OfflineQuaNgayDay']))

-- ============================================================ 3. CÙNG NGÀY -> KHÔNG CHẠY LẠI
OfflineQua7Ngay.LAN, OfflineKimThu.LAN = 0, 0
local chay3 = OfflineQuaNgay:kiem_ngay()
check(chay3 == false, 'cung ngay -> KHONG chay lai', tostring(chay3))
check(OfflineQua7Ngay.LAN == 0 and OfflineKimThu.LAN == 0,
      'khong he nao bi goi lai', OfflineQua7Ngay.LAN .. '/' .. OfflineKimThu.LAN)

-- ============================================================ 4. MỐC 5 GIỜ
-- 04:59 ngày 2/11 vẫn tính là ngày 1/11 -> khoá phải là 20261101 (đã có) -> không chạy.
datGio(2026, 11, 2, 4, 59)
OfflineQua7Ngay.LAN, OfflineKimThu.LAN = 0, 0
local chay4 = OfflineQuaNgay:kiem_ngay()
check(chay4 == false, '04:59 van la hom truoc -> khong chay', tostring(chay4))
check(tonumber(UC.DATA['OfflineQuaNgayDay']) == 20261101,
      'khoa ngay van la 20261101 luc 04:59', tostring(UC.DATA['OfflineQuaNgayDay']))

-- 05:00 cùng ngày -> sang ngày mới.
datGio(2026, 11, 2, 5, 0)
OfflineQua7Ngay.LAN, OfflineKimThu.LAN = 0, 0
local chay5 = OfflineQuaNgay:kiem_ngay()
check(chay5 == true, '05:00 -> sang ngay moi, chay', tostring(chay5))
check(tonumber(UC.DATA['OfflineQuaNgayDay']) == 20261102,
      'khoa ngay doi thanh 20261102', tostring(UC.DATA['OfflineQuaNgayDay']))
check(OfflineQua7Ngay.LAN == 1 and OfflineKimThu.LAN == 1,
      'ca hai he chay dung mot luot o moc 5 gio', OfflineQua7Ngay.LAN .. '/' .. OfflineKimThu.LAN)

-- ============================================================ 5. MỘT HỆ NÉM LỖI
datGio(2026, 11, 3, 12, 0)
UC.DATA['OfflineQuaNgayDay'] = 20261102
OfflineQua7Ngay.LAN, OfflineKimThu.LAN = 0, 0
OfflineQua7Ngay.NEM = true
local chay6 = OfflineQuaNgay:kiem_ngay()
check(chay6 == true, 'he truoc nem loi -> van coi nhu da chay', tostring(chay6))
check(OfflineKimThu.LAN == 1, 'he sau VAN chay du he truoc nem loi', OfflineKimThu.LAN)
check(tonumber(UC.DATA['OfflineQuaNgayDay']) == 20261103,
      'khoa ngay van duoc ghi', tostring(UC.DATA['OfflineQuaNgayDay']))
OfflineQua7Ngay.NEM = false

-- ============================================================ 6. THIẾU HẲN MỘT HỆ
datGio(2026, 11, 4, 12, 0)
UC.DATA['OfflineQuaNgayDay'] = 20261103
local tam = OfflineKimThu
OfflineKimThu = nil
OfflineQua7Ngay.LAN = 0
local chay7 = OfflineQuaNgay:kiem_ngay()
check(chay7 == true, 'thieu mot he -> van chay he con lai', tostring(chay7))
check(OfflineQua7Ngay.LAN == 1, 'he con lai duoc goi', OfflineQua7Ngay.LAN)
check(tonumber(UC.DATA['OfflineQuaNgayDay']) == 20261104,
      'khoa ngay van duoc ghi khi thieu he', tostring(UC.DATA['OfflineQuaNgayDay']))
OfflineKimThu = tam

-- ============================================================ 7. OnEnterGame LỖI
datGio(2026, 11, 5, 12, 0)
UC.DATA['OfflineQuaNgayDay'] = 20261104
OfflineQua7Ngay.LAN, OfflineKimThu.LAN = 0, 0
local kq8 = OfflineQuaNgay:OnEnterGame(7)
check(kq8 == nil, 'OnEnterGame(loi 7) -> nil (bo qua)', tostring(kq8))
check(OfflineQua7Ngay.LAN == 0 and OfflineKimThu.LAN == 0,
      'EnterGame loi -> khong he nao chay', OfflineQua7Ngay.LAN .. '/' .. OfflineKimThu.LAN)

local kq9 = OfflineQuaNgay:OnEnterGame(0)
check(kq9 == true, 'OnEnterGame(0) -> chay', tostring(kq9))

io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
