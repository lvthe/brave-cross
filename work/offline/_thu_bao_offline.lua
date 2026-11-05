-- _thu_bao_offline.lua — bộ thử cho `offline/bao_offline.lua` (4/11 tiếp).
--   Chạy qua `_chay_het.py` (lua51.dll). Không cần game, không cần máy chủ.
--
-- Đo: cờ đặt khi đăng nhập bằng kho cục bộ · hẹn 3 giây · CHỈ báo một lần ·
-- đăng nhập lại qua mạng thì `xoa()` không báo nhầm · thiếu `g_CUIToolTips`
-- thì không ném. Mọi thông điệp ASCII (bẫy cp1252 của bộ thử).
package.path = [[__SC__/?.lua;__SC__/?/init.lua;]] .. package.path

local nhat_ky = {}
package.preload['offline.log'] = function ()
    local L = {}
    function L:info(m) nhat_ky[#nhat_ky + 1] = 'info ' .. tostring(m) end
    function L:warn(m) nhat_ky[#nhat_ky + 1] = 'warn ' .. tostring(m) end
    function L:err(m)  nhat_ky[#nhat_ky + 1] = 'err '  .. tostring(m) end
    OfflineLog = L; return L
end

-- Bộ hẹn giờ giả: ghi lại lượt hẹn để test tự gọi.
local hen = nil
S_CCSchedule = {
    scheduleOnce = function (self, target, method, delay)
        hen = { target = target, method = method, delay = delay }
        return true
    end,
}

-- API hiển thị giả của client.
local tips = { cau = nil, soLan = 0 }
function tips:AddTipsWithString(s)
    self.cau = s
    self.soLan = self.soLan + 1
    return true
end
g_CUIToolTips = tips

dofile([[__SC__/offline/bao_offline.lua]])
local M = OfflineBao

local dat, hong = 0, 0
local function check(ok, ten, ct)
    if ok then dat = dat + 1; io.write('  OK   ' .. ten .. '\n')
    else hong = hong + 1; io.write('  HONG ' .. ten .. (ct ~= nil and (' -> ' .. tostring(ct)) or '') .. '\n') end
end

-- 1. Chưa có cờ (vào bằng mạng) => KHÔNG báo
check(M:hen() == false and hen == nil, 'khong co co -> hen() khong lam gi')
check(M:hien() == false and tips.soLan == 0, 'khong co co -> hien() khong ban')

-- 2. dat() => hen 3 giay, mot lan
M:dat('test')
check(M.lyDo == 'test' and not M.daHen and not M.daBao, 'dat() -> co, chua hen chua bao')
check(M:hen() == true and M.daHen, 'hen() -> hen 3 giay')
check(M:hen() == false, 'hen() lan hai trong cung luot -> false')
check(hen ~= nil and hen.method == 'hien' and hen.delay == M.CHO_GIAY,
      'hen dung ham hien sau CHO_GIAY giay', hen and (tostring(hen.method) .. '/' .. tostring(hen.delay)))

-- 3. Chạy lượt hẹn => gọi đúng API của client, đúng câu
hen.target[hen.method](hen.target)
check(tips.soLan == 1 and tips.cau == M.CAU, 'hen chay -> AddTipsWithString(M.CAU)')
check(M.daBao, 'da báo -> co daBao')

-- 4. Chỉ một lần
check(M:hien() == false and tips.soLan == 1, 'hien() lan hai -> false (chi mot lan)')

-- 5. Vào bằng mạng => xoa() xoá cờ, không báo nhầm
M:xoa()
check(M.lyDo == nil and M:hen() == false and tips.soLan == 1, 'xoa() -> khong hen, khong ban')

-- 6. Ngoại tuyến lại => báo lại được
M:dat('lan hai')
M:hen()
hen.target[hen.method](hen.target)
check(tips.soLan == 2 and M.daBao, 'dang nhap offline lan sau -> bao lai')

-- 7. Thiếu API hiển thị => không ném, không đánh dấu đã báo
g_CUIToolTips = nil
M:dat('khong ui')
check(M:hien() == false and not M.daBao, 'thieu g_CUIToolTips -> false, chua danh dau')
check(nhat_ky[#nhat_ky] ~= nil and nhat_ky[#nhat_ky]:find('g_CUIToolTips') ~= nil, 'co dong canh bao trong nhat ky')
g_CUIToolTips = tips

-- 8. Không có bộ hẹn giờ => hiện NGAY
S_CCSchedule = nil
M:dat('khong hen')
check(M:hen() == true and M.daBao and tips.soLan == 3, 'khong co S_CCSchedule -> hien ngay')

io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
if hong > 0 then os.exit(1) end
