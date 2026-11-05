-- _thu_toan_cuc.lua — bo thu cho `offline/handlers/toan_cuc.lua`
package.path = [[__SC__/?.lua;__SC__/?/init.lua;]] .. package.path

local function ghi(m) io.write('[log] ' .. tostring(m) .. '\n') end
package.preload['offline.log'] = function ()
    local L = { info = ghi, warn = ghi, err = ghi }; OfflineLog = L; return L
end
package.preload['offline.router'] = function ()
    local R = { handlers = {}, silent = {} }
    function R:on(k, f) self.handlers[k] = f end
    function R:has(k) return self.handlers[k] ~= nil end
    function R:ignore(...) for _, n in ipairs({...}) do self.silent[n] = true end end
    function R:isSilent(k) return self.silent[k] == true end
    OfflineRouter = R; return R
end

local KIM_CUONG = 1000
G_UserLogic = {}
function G_UserLogic:GetBaseInfo() return 0, { Diamond = KIM_CUONG } end

dofile([[__SC__/offline/handlers/toan_cuc.lua]])
local R = require('offline.router')

local dat, hong = 0, 0
local function check(ok, ten, ct)
    if ok then dat = dat + 1; io.write('  OK   ' .. ten .. '\n')
    else hong = hong + 1; io.write('  HONG ' .. ten .. (ct ~= nil and (' -> ' .. tostring(ct)) or '') .. '\n') end
end
local function ctxGia()
    local c = { calls = {} }
    function c:call(obj, f, ...) self.calls[#self.calls + 1] = { obj = obj, f = f, args = { ... } } end
    function c:reply(tData, f, obj) self.calls[#self.calls + 1] = { obj = obj, f = f or 'OnReduceDiamondToGold', args = { tData } } end
    return c
end
local function kq(c) local x = c.calls[#c.calls]; return x and x.args[1] or nil end

-- 1. nuot lang
local dsNuot = { 'ClientBeginGuide', 'ClientCompeleGuide', 'ClientSystemLog', 'ClientGetMissionData',
                 'ClientTestAddMail', 'ClientTestFullLevelResouces', 'ClientTestFullWorker' }
local thieu = {}
for _, n in ipairs(dsNuot) do if not R:isSilent(n) then thieu[#thieu + 1] = n end end
check(#thieu == 0, 'nuot lang du 7 khoa', table.concat(thieu, ','))

-- 2. doi vang OK
local c1 = ctxGia(); R.handlers['ClientReduceDiamondToGold'](c1, 50000)
local r1 = kq(c1)
-- 50000^0.89 = 15055.6... -> ceil(150.556) = 151
check(r1 and r1.err == 0 and r1.data.NeedGold == 50000, 'doi vang: tra err 0 + NeedGold', r1 and r1.err)
check(r1.data.NeedDiamond == math.ceil((50000 ^ 0.89) / 100),
      'doi vang: NeedDiamond theo cong thuc goc', r1 and r1.data.NeedDiamond)
check(c1.calls[1].f == 'OnReduceDiamondToGold' and c1.calls[1].obj == '',
      'doi vang: dung callback TOAN CUC', c1.calls[1].f)

-- 3. thieu kim cuong (>= NGAT nen bang dung cung hong)
KIM_CUONG = r1.data.NeedDiamond
local c2 = ctxGia(); R.handlers['ClientReduceDiamondToGold'](c2, 50000)
check(kq(c2).err == 1702, 'doi vang: bang dung kim cuong -> 1702 (bat dang thuc NGAT)',
      kq(c2) and kq(c2).err)
KIM_CUONG = 1000

-- 4. tham so hong
local c3 = ctxGia(); R.handlers['ClientReduceDiamondToGold'](c3, -5)
check(kq(c3).err == 4, 'doi vang: so am -> 4', kq(c3).err)
local c4 = ctxGia(); R.handlers['ClientReduceDiamondToGold'](c4, 'abc')
check(kq(c4).err == 4, 'doi vang: khong phai so -> 4', kq(c4).err)

-- 5. KHONG tu tru kim cuong (client tu tru)
local truoc = KIM_CUONG
local c5 = ctxGia(); R.handlers['ClientReduceDiamondToGold'](c5, 1000)
check(KIM_CUONG == truoc, 'doi vang: handler KHONG tu tru kim cuong', KIM_CUONG)

io.write('KET QUA: dat ' .. dat .. ', hong ' .. hong .. '\n')
