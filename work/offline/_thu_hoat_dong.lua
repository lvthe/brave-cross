-- _thu_hoat_dong.lua — bộ thử cho `offline/hoat_dong.lua` (lịch hoạt động viết mới).
-- (chạy bằng `python _thu_nha_cua.py _thu_hoat_dong.lua`).
--
-- Đo ĐÚNG những gì thuộc về module: hình trạng thái, cấu hình đi kèm, danh sách
-- ĐÓNG có lý do, và mốc thời gian. KHÔNG đo UI (không có trong máy Lua trần).
package.path = [[__SC__/?.lua;__SC__/?/init.lua;]] .. package.path

local function ghi(m) io.write('[log] ' .. tostring(m) .. '\n') end
package.preload['offline.log'] = function ()
    local L = { info = ghi, warn = ghi, err = ghi }; OfflineLog = L; return L
end

local GIO = 1700000000
G_GameWorld = {}
function G_GameWorld:GetServerTime() return GIO end

local HD = dofile([[__SC__/offline/hoat_dong.lua]])

local dat, hong = 0, 0
local function check(ok, ten, ct)
    if ok then dat = dat + 1; io.write('  OK   ' .. ten .. '\n')
    else hong = hong + 1; io.write('  HONG ' .. ten .. (ct ~= nil and (' -> ' .. tostring(ct)) or '') .. '\n') end
end

check(type(HD) == 'table', 'module tra ve bang')
check(type(HD.layDanhSach) == 'function', 'co layDanhSach')

local tt, ch = HD:layDanhSach()

-- ============================================================ 1. TRANG THAI
check(type(tt) == 'table' and type(ch) == 'table', 'tra HAI bang')
check(#HD.DANH_SACH == 3, 'lich co 3 hoat dong', #HD.DANH_SACH)

local st = tt.LevelFund
check(type(st) == 'table', 'co trang thai LevelFund')
check(st.ActivityID ~= 0, 'ActivityID khac 0', st and st.ActivityID)
check(st.ActivityType == 'LevelFund', 'ActivityType dung', st and st.ActivityType)
check(st.IsActivityClose == false, 'khong dong')
check(st.BeginTime <= GIO and st.EndTime > GIO, 'nam trong khoang dang mo',
      st and (tostring(st.BeginTime) .. '..' .. tostring(st.EndTime)))
check(st.LowestUserLevel == 0 and st.LowestVipLevel == 0, 'khong chan cap/VIP')

check(tt.TimeFund ~= nil and tt.TimeLimitSoulBoxHero ~= nil, 'co TimeFund + hop hon')
local ids = {}
for k, v in pairs(tt) do ids[v.ActivityID] = (ids[v.ActivityID] or 0) + 1 end
local trung = 0
for _, n in pairs(ids) do if n > 1 then trung = trung + 1 end end
check(trung == 0, 'ActivityID KHONG trung nhau', trung)

-- ============================================================ 2. CAU HINH
check(type(ch.LevelFund) == 'table', 'co cau hinh LevelFund')
check(tonumber(ch.LevelFund.Diamond) and ch.LevelFund.Diamond > 0,
      'cau hinh LevelFund co Diamond > 0', ch.LevelFund and ch.LevelFund.Diamond)
check(type(ch.TimeFund) == 'table', 'co cau hinh TimeFund')
check(ch.TimeLimitSoulBoxHero == nil, 'hop hon KHONG co cau hinh (dung: client chi can trang thai)')

-- ============================================================ 3. DONG CO LY DO
local dong = { 'CumulativeRecharge', 'CumulativeConsume', 'SingleRecharge',
               'LevelCapacityTarget', 'RechargeSign' }
local thieu = {}
for _, t in ipairs(dong) do
    if not HD.DONG[t] then thieu[#thieu + 1] = t end
end
check(#thieu == 0, '5 hoat dong DONG deu co ly do', table.concat(thieu, ','))
check(HD:moKhong('CumulativeRecharge') == true, 'moKhong(CumulativeRecharge) = true')
check(HD:moKhong('LevelFund') == false, 'moKhong(LevelFund) = false')
for _, t in ipairs(dong) do
    if tt[t] ~= nil then
        check(false, 'hoat dong DONG khong duoc nam trong lich: ' .. t)
    end
end

-- ============================================================ 4. CAU HINH CUA
check(HD:cauHinhCua('LevelFund') == HD.QUY_CAP, 'cauHinhCua(LevelFund) = bang gia')
check(HD:cauHinhCua('TimeLimitSoulBoxHero') == nil, 'cauHinhCua(hop hon) = nil')

-- ============================================================ 5. MOC THOI GIAN
local tt2 = HD:layDanhSach(1000)
check(tt2.LevelFund.BeginTime == 1000, 'layDanhSach(truoc) dung moc', tt2.LevelFund.BeginTime)
check(tt2.LevelFund.EndTime == 1000 + 3650 * 86400, 'EndTime = truoc + keoDai',
      tt2.LevelFund.EndTime)

-- ============================================================ 6. MO_THEM
HD.MO_THEM = {
    CumulativeRecharge = { keoDai = 7 * 86400, uuTien = 20,
                           cauHinh = { { Recharge = 100, PrizeList = {} } } },
    SingleRecharge = { keoDai = 86400 },          -- THIEU cauHinh -> phai bi bo qua
}
local tt3, ch3 = HD:layDanhSach()
check(tt3.CumulativeRecharge ~= nil and ch3.CumulativeRecharge ~= nil,
      'MO_THEM: hoat dong dien day du duoc mo')
check(tt3.CumulativeRecharge.Priority == 20, 'MO_THEM: giu uuTien',
      tt3.CumulativeRecharge and tt3.CumulativeRecharge.Priority)
check(tt3.SingleRecharge == nil, 'MO_THEM: thieu cauHinh -> KHONG mo')
local demId = {}
for _, v in pairs(tt3) do demId[v.ActivityID] = (demId[v.ActivityID] or 0) + 1 end
local trung2 = 0
for _, n in pairs(demId) do if n > 1 then trung2 = trung2 + 1 end end
check(trung2 == 0, 'MO_THEM: ActivityID van khong trung', trung2)
HD.MO_THEM = {}

io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
