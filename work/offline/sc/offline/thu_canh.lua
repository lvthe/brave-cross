--[[
	offline/thu_canh.lua — ĐỒ THỬ trong game cho CÁNH (tiến cấp + cường hoá).

	Bật bằng cờ `thu_canh.flag` cạnh file lưu (tự xoá khi chạy). Sau khi vào cảnh Main:

	  1. Đo cấu hình thật: `UpgradeWingConfig` · `HeroWingConfig["1"]` · `GameWingIntensifyConfig`.
	  2. Trên TÀI KHOẢN THỬ: thêm cánh 1 cấp 1 cho tướng 25 nếu chưa có; cấp đá 102/101.
	  3. Gọi 5 lượt `ClientUpgradeWing` (đọc cấp + chúc phúc sau từng lượt).
	  4. Gọi `ClientAutoIntensifyWing` 2 lần (lần hai phải chạm trần = 1328).
	  5. Gọi `ClientUpgradeWingWithDiamond` (tài khoản thử thiếu kim cương ⇒ 504).

	CHỈ dùng trên tài khoản thử: nó THÊM cánh + đá vào bản lưu.
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineThuCanh = OfflineThuCanh or {}

local T = OfflineThuCanh

T.TEP_CO = "thu_canh.flag"
T.CHO = 8
T.DEM = 0
T.DA_CHAY = false

local N_HERO = 25

local function thuMuc() return (OfflineStore:path():gsub("[^/]*$", "")) end
local function coTepCo()
	local ok, fp = pcall(io.open, thuMuc() .. T.TEP_CO, "r")
	if ok and fp then fp:close(); return true end
	return false
end
local function xoaCo() pcall(os.remove, thuMuc() .. T.TEP_CO) end
local function ghi(m) OfflineLog:info("THU CANH: " .. tostring(m)) end

local function ctxGia()
	local c = { calls = {} }
	function c:call(obj, f, a, b, ma, ev)
		self.calls[#self.calls + 1] = { obj = obj, f = f, a = a, b = b, err = ma, ev = ev }
		return true
	end
	return c
end

local function goi(obj, func, ...)
	local fn = OfflineRouter:getFor(obj, func)
	if fn == nil then return nil, "CHUA DANG KY" end
	local ctx = ctxGia()
	local ok, err = pcall(fn, ctx, ...)
	if not ok then return nil, tostring(err) end
	return ctx
end

local function maCua(ctx)
	local x = ctx and ctx.calls[#ctx.calls]
	return x and tonumber(x.err) or nil
end

local function docCauHinh(ten)
	local ok, t = pcall(function () return G_ConfigManager:GetCommonConfigWithName(ten) end)
	if ok and type(t) == "table" then return t end
	return nil
end

local function dem(t)
	if type(t) ~= "table" then return 0 end
	local n = 0
	for _ in pairs(t) do n = n + 1 end
	return n
end

local function duDa(nId, nCan)
	local ok, _, n = pcall(function () return G_ItemLogic:GetItemCount(nId) end)
	if (tonumber(n) or 0) < nCan then
		pcall(function () G_ItemLogic:AddItem(nId, nCan, "thu_canh") end)
	end
end

function T:chay()
	local up = docCauHinh("UpgradeWingConfig")
	local hw = docCauHinh("HeroWingConfig")
	local it = docCauHinh("GameWingIntensifyConfig")
	local nUp = dem(up)
	local nHw = 0
	if hw ~= nil then
		local ds = hw["1"] or hw[1]
		if type(ds) == "table" then nHw = #ds end
	end
	ghi(string.format("cau hinh: upgrade=%s (%d) · heroWing[1]=%d · intensify=%s (%d)",
		tostring(up ~= nil), nUp, nHw, tostring(it ~= nil), dem(it)))
	if up == nil or hw == nil or it == nil then
		ghi("THIEU CAU HINH — dung lai")
		return
	end

	local okHero, bCo, hero = pcall(function () return G_HeroLogic:GetHeroWithID(N_HERO) end)
	if not (okHero and bCo == true and type(hero) == "table") then
		ghi("khong thay tuong " .. N_HERO)
		return
	end
	if (tonumber(hero.WingID) or 0) == 0 then
		local ok, r = pcall(function () return G_HeroLogic:AddHeroWing(N_HERO, 1, 1) end)
		ghi("them canh 1 cap 1 -> " .. tostring(ok) .. "/" .. tostring(r))
	end
	duDa(102, 20)
	duDa(101, 10)

	local _, _, v102 = pcall(function () return G_ItemLogic:GetItemCount(102) end)
	local _, _, v101 = pcall(function () return G_ItemLogic:GetItemCount(101) end)
	ghi(string.format("truoc: WingID=%s WingLevel=%s blessing=%s cuong=%s · da102=%s da101=%s",
		tostring(hero.WingID), tostring(hero.WingLevel), tostring(hero.WingBlessing),
		tostring(hero.WingIntensifyLevel), tostring(v102), tostring(v101)))

	for i = 1, 5 do
		local c, err = goi("G_HeroLogic", "ClientUpgradeWing", N_HERO)
		ghi(string.format("tien cap lan %d -> ma=%s%s · WingLevel=%s · blessing=%s",
			i, tostring(maCua(c)), err and (" LOI " .. err) or "",
			tostring(hero.WingLevel), tostring(hero.WingBlessing)))
	end

	local c2, e2 = goi("G_HeroLogic", "ClientAutoIntensifyWing", N_HERO)
	ghi(string.format("tu dong cuong hoa -> ma=%s%s · cap=%s",
		tostring(maCua(c2)), e2 and (" LOI " .. e2) or "", tostring(hero.WingIntensifyLevel)))
	local c3 = goi("G_HeroLogic", "ClientAutoIntensifyWing", N_HERO)
	ghi("tu dong lan hai (phai cham tran 1328) -> ma=" .. tostring(maCua(c3)))

	local c4 = goi("G_HeroLogic", "ClientUpgradeWingWithDiamond", N_HERO)
	ghi("tien cap bang kim cuong (thieu => 504) -> ma=" .. tostring(maCua(c4)))

	local _, _, s102 = pcall(function () return G_ItemLogic:GetItemCount(102) end)
	local _, _, s101 = pcall(function () return G_ItemLogic:GetItemCount(101) end)
	ghi(string.format("sau: WingLevel=%s blessing=%s cuong=%s · da102=%s da101=%s",
		tostring(hero.WingLevel), tostring(hero.WingBlessing),
		tostring(hero.WingIntensifyLevel), tostring(s102), tostring(s101)))

	pcall(function () OfflineStore:syncFromClient() end)
	ghi("XONG")
end

function T:tick()
	if self.DA_CHAY then return end
	self.DEM = self.DEM + 1
	if self.DEM < self.CHO then return end
	if not (Offline and Offline.LAN_VAO_GAME and Offline.LAN_VAO_GAME > 0) then
		return
	end
	self.DA_CHAY = true
	local ok, err = pcall(function () self:chay() end)
	if not ok then
		OfflineLog:err("THU CANH: loi — " .. tostring(err))
	end
end

function T:batDau()
	if not coTepCo() then return end
	OfflineLog:info("THU CANH: thay tep co " .. self.TEP_CO)
	xoaCo()
	if S_CCSchedule == nil then
		OfflineLog:err("THU CANH: khong co S_CCSchedule")
		return
	end
	pcall(function () S_CCSchedule:schedule(self, "tick", 1) end)
end

return OfflineThuCanh
