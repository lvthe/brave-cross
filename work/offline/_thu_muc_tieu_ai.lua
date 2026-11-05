-- _thu_muc_tieu_ai.lua — bộ thử cho `offline/handlers/muc_tieu_ai.lua`
-- (chạy bằng `python _thu_nha_cua.py _thu_muc_tieu_ai.lua`).
--
-- KHÔNG thử ở đây: luật THẬT `ChapterLogic:getChapterTargetReward` (bộ thử không có
-- `share/`). Bộ này đo ĐƯỜNG DÂY + cái GÁC [MOI] quan trọng nhất: mốc ĐÃ LĨNH (2) thì
-- KHÔNG được gọi luật gốc, vì luật gốc phát thưởng TRƯỚC rồi mới kiểm trùng.
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

ErrorCode = {
    UnknowError = 1,
    ArgError = 2,
    Chapter = {
        GetChapterTargetRewardStatusMapFaild = 1430,
        ChapterTargetRewardHasGet = 1431,
    },
}

-- ============================================================ LỚP GỐC GIẢ
local LOGIC = {}
LOGIC.STATUS = {}          -- [stage] = trang thai
LOGIC.OK = true
LOGIC.ERR = nil
LOGIC.PRIZE = 101011
LOGIC.NEM = false          -- nem loi o CA HAI ham
LOGIC.NEM_STATUS = false   -- chi GetChapterTargetRewardStatusMap tra false
LOGIC.LAN = {}

function LOGIC:GetChapterTargetRewardStatusMap(nMainChapter, nChapterDifficulty)
    self.LAN[#self.LAN + 1] = { ten = 'status', chuong = nMainChapter, kho = nChapterDifficulty }
    if self.NEM or self.NEM_STATUS then return false end
    local m = {}
    for k, v in pairs(self.STATUS) do m[tostring(k)] = v end
    return true, m
end

function LOGIC:getChapterTargetReward(nMainChapter, nChapterDifficulty, nStage)
    self.LAN[#self.LAN + 1] = { ten = 'nhan', chuong = nMainChapter, kho = nChapterDifficulty, moc = nStage }
    if self.NEM then error('no gia lap') end
    if self.OK ~= true then return false, nil, self.ERR end
    return true, self.PRIZE, 0
end

G_ChapterLogic = setmetatable({}, { __index = LOGIC })

dofile([[__SC__/offline/handlers/muc_tieu_ai.lua]])
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
    end
    return c
end

local KHOA = 'G_ChapterLogic.ClientGetChapterTargetReward'
local function goi(...)
    local c = ctxGia()
    R.handlers[KHOA](c, ...)
    return c
end
local function traLoiCuoi(c) return c.calls[#c.calls] and c.calls[#c.calls].args[1] end

-- ============================================================ 1. ĐĂNG KÝ
check(R:has(KHOA), 'dang ky ' .. KHOA)
check(type(OfflineMucTieuAi) == 'table', 'co bang OfflineMucTieuAi')

-- ============================================================ 2. LĨNH OK
LOGIC.STATUS, LOGIC.OK, LOGIC.ERR, LOGIC.NEM, LOGIC.LAN = { [3] = 1 }, true, nil, false, {}
local c2 = goi({ nMainChapter = 1, nChapterDifficulty = 1, nStage = 3 })
local goiNhan = nil
for _, x in ipairs(LOGIC.LAN) do if x.ten == 'nhan' then goiNhan = x end end
check(goiNhan and goiNhan.chuong == 1 and goiNhan.kho == 1 and goiNhan.moc == 3,
      'goi DUNG luat goc getChapterTargetReward(1, 1, 3)',
      goiNhan and string.format('%s/%s/%s', goiNhan.chuong, goiNhan.kho, goiNhan.moc))
local t2 = traLoiCuoi(c2)
check(c2.calls[1] and c2.calls[1].f == 'OnServerGetChapterTargetReward',
      'tra loi qua OnServerGetChapterTargetReward', c2.calls[1] and c2.calls[1].f)
check(type(t2) == 'table' and t2.nPrizeID == 101011,
      'tra {nPrizeID} — client doi tData.nPrizeID la SO', type(t2) == 'table' and tostring(t2.nPrizeID))
check(OfflineStore.dongBo ~= nil and OfflineStore.dongBo >= 1, 'co dong bo file luu')

-- ============================================================ 3. ĐÃ LĨNH -> 1431, KHÔNG gọi luật
LOGIC.STATUS, LOGIC.LAN = { [3] = 2 }, {}
local c3 = goi({ nMainChapter = 1, nChapterDifficulty = 1, nStage = 3 })
local goiNhan3 = nil
for _, x in ipairs(LOGIC.LAN) do if x.ten == 'nhan' then goiNhan3 = x end end
check(goiNhan3 == nil, 'moc DA LINH -> KHONG goi luat goc (chan phat thuong hai lan)',
      LOGIC.LAN[1] and LOGIC.LAN[1].ten)
local t3 = traLoiCuoi(c3)
check(type(t3) == 'table' and t3.err == 1431, 'moc da linh -> ma 1431',
      type(t3) == 'table' and tostring(t3.err))

-- ============================================================ 4. CHƯA MỞ (0) -> LUẬT GỐC quyết
LOGIC.STATUS, LOGIC.OK, LOGIC.ERR, LOGIC.LAN = { [3] = 0 }, false, 1430, {}
local c4 = goi({ nMainChapter = 1, nChapterDifficulty = 1, nStage = 3 })
local goiNhan4 = nil
for _, x in ipairs(LOGIC.LAN) do if x.ten == 'nhan' then goiNhan4 = x end end
check(goiNhan4 ~= nil, 'moc CHUA MO -> VAN goi luat goc (khong tu doan)', #LOGIC.LAN)
local t4 = traLoiCuoi(c4)
check(type(t4) == 'table' and t4.err == 1430, 'luat goc tu choi -> tra ma goc 1430',
      type(t4) == 'table' and tostring(t4.err))

-- ============================================================ 5. KHÔNG DỰNG ĐƯỢC TRẠNG THÁI
LOGIC.NEM_STATUS = true     -- chi bang trang thai hong, luat goc VAN chay duoc
LOGIC.OK, LOGIC.ERR, LOGIC.LAN = true, nil, {}
local c5 = goi({ nMainChapter = 2, nChapterDifficulty = 2, nStage = 9 })
LOGIC.NEM_STATUS = false
local goiNhan5 = nil
for _, x in ipairs(LOGIC.LAN) do if x.ten == 'nhan' then goiNhan5 = x end end
check(goiNhan5 ~= nil, 'bang trang thai hong -> van goi luat goc, de no tra ma', #LOGIC.LAN)
local t5 = traLoiCuoi(c5)
check(type(t5) == 'table' and t5.nPrizeID ~= nil, 'va van tra {nPrizeID}', type(t5) == 'table' and tostring(t5.nPrizeID))

-- ============================================================ 6. LUẬT NÉM LỖI
LOGIC.STATUS, LOGIC.NEM, LOGIC.LAN = {}, true, {}
local c6 = goi({ nMainChapter = 1, nChapterDifficulty = 1, nStage = 3 })
LOGIC.NEM = false
local t6 = traLoiCuoi(c6)
check(type(t6) == 'table' and t6.err == 1, 'luat nem loi -> err 1', type(t6) == 'table' and tostring(t6.err))

-- ============================================================ 7. THAM SỐ SAI
LOGIC.STATUS, LOGIC.OK, LOGIC.LAN = { [3] = 1 }, true, {}
local c7 = goi('khong-phai-bang')
local t7 = traLoiCuoi(c7)
check(type(t7) == 'table' and t7.err == ErrorCode.ArgError, 'tham so khong phai bang -> err 2',
      type(t7) == 'table' and tostring(t7.err))

local c8 = goi({ nMainChapter = 1 })
local t8 = traLoiCuoi(c8)
check(type(t8) == 'table' and t8.err == ErrorCode.ArgError, 'thieu truong -> err 2',
      type(t8) == 'table' and tostring(t8.err))

local goiNhan8 = nil
for _, x in ipairs(LOGIC.LAN) do if x.ten == 'nhan' then goiNhan8 = x end end
check(goiNhan8 == nil, 'tham so sai -> KHONG goi luat goc', #LOGIC.LAN)

io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
