--[[
	offline/handlers/thien_menh.lua — THIÊN MỆNH CỦA TƯỚNG / 英雄天命 (Sky Fate).

	Hai khoá `G_HeroLogic` (thực thể `G_HeroLogic` = `ClientHeroLogic`):

	  · `ClientUpdateHeroSkyFate(nHeroID, strSkyFateType)` (`ClientHeroLogic.lua:1144`)
	  · `ClientResetHeroSkyFate(nHeroID)`                    (`:1155`)

	Bên gọi: `CUIHeroInfoUpgradeHeroDestinyUI` (tab Thiên Mệnh trong màn tướng). Trước lượt
	này KHÔNG có handler ⇒ bấm là lớp tải quay mãi. CẢ HAI đã có hàm nhận trong client
	(`OnUpdateHeroSkyFate(nErrCode)` / `OnResetHeroSkyFate(nErrCode)`, `:1149/:1160`) nên chỉ
	việc gọi đúng tên.

	DỮ LIỆU LÀ CẤU HÌNH THẬT + BẢN GHI THẬT:
	  · `G_ConfigManager:GetGameHeroSkyFateConfig()` →
	    `[tên loại][cấp dạng chuỗi] = { <TênThuộcTính> = số, CostFragment = n,
	                                     CostFragmentPlus = {[heroId] = n} }`
	    (`CUIHeroInfoUpgradeHeroDestinyUI.lua:264-300` đọc đúng hình này).
	  · Cấp hiện tại: `tướng.SkyFate[strTên]` (`:276`).
	  · GIÁ của cấp kế: `nextCfg.CostFragmentPlus[tostring(heroID)]` nếu có, không thì
	    `nextCfg.CostFragment` — chính hàm `getSkyFateCostFragment` của UI (`:246-258`).
	  · Tiền là **mảnh tướng của chính tướng ấy** (`HeroFragment`), không phải tài nguyên chung.
	  · Đặt lại: giá `SkyFateResetPrice[1]` **KIM CƯƠNG** (`:630-631` đọc đúng khoá ấy).

	MÃ LỖI ĐÃ KHAI SẴN cho đúng hệ này (`share/error.lua:132-137`): `HeroFragmentNotEnough =
	1332`, `FateConditionLimit = 1333`. Thiếu mã "đã cấp tối đa" ⇒ dùng `LimitGrowth = 1316`
	(khai cho "đạt cấp tối đa") và ghi log; client không hiện mã này cho người chơi
	(`OnUpdateHeroSkyFate` bỏ qua `nErrCode`), nên đây chỉ là số cho nhật ký.

	ĐẶT LẠI có XOÁ hết cấp thiên mệnh nhưng KHÔNG hoàn mảnh — không có dữ liệu nào nói có
	hoàn, nên không tự thêm việc có lợi cho người chơi.
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineThienMenh = OfflineThienMenh or {}

local R = OfflineRouter
local TEN_FILE = "thien menh"

local function dongBo()
	pcall(function () OfflineStore:syncFromClient() end)
end

local function layTuong(nHeroID)
	local ok, bRet, hero = pcall(function ()
		return G_HeroLogic:GetHeroWithID(nHeroID)
	end)
	if ok and bRet == true and type(hero) == "table" then
		return hero
	end
	return nil
end

local function cauHinh()
	local ok, cfg = pcall(function ()
		return G_ConfigManager:GetGameHeroSkyFateConfig()
	end)
	if ok and type(cfg) == "table" then
		return cfg
	end
	return nil
end

----------------------------------------------------- NÂNG MỘT LOẠI THIÊN MỆNH
R:on("G_HeroLogic.ClientUpdateHeroSkyFate", function (ctx, nHeroID, strLoai)
	local function traLoi(nMa)
		ctx:call("G_HeroLogic", "OnUpdateHeroSkyFate", nMa)
	end

	local nHero = tonumber(nHeroID)
	if nHero == nil or type(strLoai) ~= "string" or strLoai == "" then
		OfflineLog:warn(TEN_FILE .. ": tham so sai")
		traLoi(ErrorCode.ArgError)
		return
	end

	local hero = layTuong(nHero)
	if hero == nil then
		traLoi(ErrorCode.Hero.NotFindHero)
		return
	end

	local cfg = cauHinh()
	local motLoai = cfg and cfg[strLoai]
	if type(motLoai) ~= "table" then
		OfflineLog:warn(string.format("%s: cau hinh khong co loai '%s'", TEN_FILE, tostring(strLoai)))
		traLoi(ErrorCode.Hero.GetGrowthConfigFail)
		return
	end

	local sky = hero.SkyFate
	if type(sky) ~= "table" then
		sky = {}
		hero.SkyFate = sky
	end
	local nCap = tonumber(sky[strLoai]) or 0

	local capKe = motLoai[tostring(nCap + 1)]
	if type(capKe) ~= "table" then
		OfflineLog:info(string.format("%s: tuong %d / %s da o cap toi da (%d)",
			TEN_FILE, nHero, strLoai, nCap))
		traLoi(ErrorCode.Hero.LimitGrowth)
		return
	end

	-- Giá: ưu tiên bảng riêng theo tướng, không có thì giá chung — y như UI.
	local nGia = nil
	if type(capKe.CostFragmentPlus) == "table" then
		nGia = tonumber(capKe.CostFragmentPlus[tostring(nHero)])
	end
	if nGia == nil then
		nGia = tonumber(capKe.CostFragment)
	end
	if nGia == nil or nGia < 0 then
		OfflineLog:warn(string.format("%s: cap %d cua '%s' thieu CostFragment",
			TEN_FILE, nCap + 1, strLoai))
		traLoi(ErrorCode.Hero.LimitGrowth)
		return
	end

	local coManh = tonumber(hero.HeroFragment) or 0
	if coManh < nGia then
		OfflineLog:info(string.format("%s: tuong %d can %d manh, co %d",
			TEN_FILE, nHero, nGia, coManh))
		traLoi(ErrorCode.Hero.HeroFragmentNotEnough)
		return
	end

	-- Trừ mảnh bằng hàm gốc (nó phát event cho UI). `-nGia` = trừ.
	if nGia > 0 then
		local okTru, bTru = pcall(function ()
			return G_HeroLogic:AddHeroFragment(nHero, -nGia, "ClientUpdateHeroSkyFate")
		end)
		if not okTru or bTru ~= true then
			OfflineLog:err(TEN_FILE .. ": tru manh that bai")
			traLoi(ErrorCode.Hero.SetHeroFragmentFail)
			return
		end
	end

	sky[strLoai] = nCap + 1
	dongBo()

	OfflineLog:info(string.format("%s: tuong %d — '%s' len cap %d (tru %d manh)",
		TEN_FILE, nHero, strLoai, nCap + 1, nGia))
	traLoi(ErrorCode.OK)
end)

----------------------------------------------------- ĐẶT LẠI TOÀN BỘ
R:on("G_HeroLogic.ClientResetHeroSkyFate", function (ctx, nHeroID)
	local function traLoi(nMa)
		ctx:call("G_HeroLogic", "OnResetHeroSkyFate", nMa)
	end

	local nHero = tonumber(nHeroID)
	if nHero == nil then
		traLoi(ErrorCode.ArgError)
		return
	end

	local hero = layTuong(nHero)
	if hero == nil then
		traLoi(ErrorCode.Hero.NotFindHero)
		return
	end

	-- Giá: `SkyFateResetPrice[1]`, đúng khoá UI đọc; mặc định 888 như UI.
	local nGia = 888
	local okCfg, tb = pcall(function ()
		return G_ConfigManager:GetCommonConfigWithName("SkyFateResetPrice")
	end)
	if okCfg and type(tb) == "table" and tonumber(tb[1]) then
		nGia = tonumber(tb[1])
	end

	local okTru, bTru = pcall(function ()
		return G_UserLogic:CostDiamond(nGia, "ClientResetHeroSkyFate")
	end)
	if not okTru or bTru ~= true then
		OfflineLog:info(string.format("%s: dat lai can %d kim cuong — khong du", TEN_FILE, nGia))
		traLoi(ErrorCode.Resource.NoEnoughResource)
		return
	end

	hero.SkyFate = {}
	dongBo()

	OfflineLog:info(string.format("%s: tuong %d dat lai thien menh (tru %d kim cuong)",
		TEN_FILE, nHero, nGia))
	traLoi(ErrorCode.OK)
end)

OfflineLog:info("thien menh: da noi 2 khoa (ClientUpdateHeroSkyFate / ClientResetHeroSkyFate)")

return true
