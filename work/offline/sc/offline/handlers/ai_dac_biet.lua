--[[
	offline/handlers/ai_dac_biet.lua — CHẾ ĐỘ ẢI ĐẶC BIỆT, 16 KHOÁ `G_ChapterLogic`.

	Gồm: 7 `…Complete` · 4 `…Sweep` · 5 tiện ích (GetChapterDropData /
	GetSCSChapterNPCData / GetDKChapterFaction / ReviveInBattle / UserOverHJRQ).

	VÌ SAO LÀM ĐƯỢC MÀ KHÔNG BỊA: phần LỚN luật là hàm MÁY CHỦ GỐC còn nguyên trong
	`share/share_ChapterLogic.lua`:
	  · `activityChapterComplete(key, tDropList, tKillIdList, nDamage)` — máy结算
	    đầy đủ của ải hoạt động: lọc rơi theo quái đã giết, nhân rơi theo tuần/hoạt
	    động, gọi `getOtherPrize` (Định Quân Sơn: vàng theo sát thương; Thập Thường
	    Thị: vật phẩm theo số giết), rồi `chapterVictoryHandle` lưu báo cáo.
	  · `chapterSweepHandle(cfg, ex, tDropList, rating, bSweepMode, from)` — luật
	    CÀN QUÉT (trao rơi + thưởng + lưu báo cáo).
	  · `GetTGZZChapterPrize` / `GetDKChapterPrize` — thưởng theo cấp mùa × % sát thương.
	  · `GetChapterReviveCost(n) = 50 × (n+1)` — giá hồi sinh trong trận.
	Dữ liệu rơi dùng CHÍNH bộ sinh của lớp offline (`OfflineDrop_build`, cùng xác
	suất `DropValue/TotalDropValue` như ải thường).

	[GHIM] — chỗ luật không ship, chọn cách trung thực và ghi rõ:
	1. TGZZ/DK: sweep tính thưởng với `DamagePercent = 1` (coi như đánh lại đúng
	   thành tích tốt nhất); phải ĐÃ QUA ải mới quét (1435 `NotCrossCantSweep`).
	2. HJRQ/SYZLB/XZWC: sweep gọi `chapterSweepHandle` với danh sách rơi sinh lại và
	   sao đã lưu; cũng phải đã qua ải (1435).
	3. SCS NPC preview (`ClientGetSCSChapterNPCData`) trả `NpcList = {}` — hình phản
	   hồi THẬT của client chịu được rỗng; không dựng dữ liệu NPC giả.
	4. DK faction: offline không có máy chủ luân phiên phe ⇒ trả phe MẶC ĐỊNH 1
	   (đúng giá trị client tự dùng khi chưa có dữ liệu, `CUIDKData.lua:31-34`).
	5. PetBoss: chỉ có một ải loại 8; dùng `tClientData.ChapterData.ChapterKey`, thiếu
	   thì lấy ải duy nhất của loại đó.

	⚠ BA BẪY HÌNH GỌI:
	· `ClientChapterDKComplete` GỬI MỘT tham số (không có chapterKey) — khoá ải phải
	  lấy trong dữ liệu.
	· Hàm nhận của SCS/HJRQ/DJSJF/XZWC/PetBoss/TGZZ **không có mã lỗi**; dùng
	  `g_CUIGameRPCManager:OnReciveResponse("", "", mã, {})` để báo lỗi.
	· `GetTGZZChapterLevel`/`GetDKChapterLevel` trả `(bResult, cấp, cấpTốiĐa)` — đọc
	  BA giá trị.
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineAiDacBiet = OfflineAiDacBiet or {}

local R = OfflineRouter
local TEN_FILE = "ai dac biet"

------------------------------------------------------------------- tiện ích

local function ma(ten, macDinh)
	local ok, v = pcall(function ()
		local E = _G.ErrorCode
		return E and E.Chapter and E.Chapter[ten]
	end)
	return (ok and tonumber(v)) or macDinh
end

local function goi(ctx, hamNhan, ...)
	local a = { n = select("#", ...), ... }
	local ok, e = pcall(function ()
		return ctx:call("G_ChapterLogic", hamNhan, unpack(a, 1, a.n))
	end)
	if not ok then
		OfflineLog:err(string.format("%s: khong goi duoc G_ChapterLogic.%s -> %s",
			TEN_FILE, tostring(hamNhan), tostring(e)))
	end
end

local function baoLoi(ctx, nMa, lyDo)
	OfflineLog:info(string.format("%s: tu choi -> ma %d (%s)", TEN_FILE, nMa, lyDo or ""))
	pcall(function ()
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", nMa, {})
	end)
end

local function thongBao(nMa)
	if nMa == nil or nMa == 0 then return end
	pcall(function ()
		g_CUINotificationCenter:PostNotification(
			CUINotificationEvent.OnServerRequestError, nMa)
	end)
end

local function dongBo()
	pcall(function () OfflineStore:syncFromClient() end)
end

local function cauHinh(key)
	local ok, cfg = pcall(function ()
		return G_ConfigManager:GetChapterConfig(tostring(key))
	end)
	if ok and type(cfg) == "table" then return cfg end
	return nil
end

-- Ải DUY NHẤT của một loại (dùng cho DK / PetBoss vì client không gửi khoá).
local function aiDuyNhat(chapterType)
	local ok, ds = pcall(function ()
		return G_ChapterLogic:GetChapterListByChapterType(chapterType)
	end)
	if ok and type(ds) == "table" and ds[1] ~= nil and type(ds[1].ChapterKey) == "string" then
		return ds[1].ChapterKey
	end
	return nil
end

local function soLieu(key)
	local ok, b, v = pcall(function () return G_UserLogic:GetStatisticsCommonData(key) end)
	if ok and b ~= false and tonumber(v) then return tonumber(v) end
	return 0
end

local function datSoLieu(key, giaTri)
	pcall(function () G_UserLogic:SetStatisticsCommonData(key, giaTri) end)
end

local function daQuaAi(key)
	local ok, b, qua = pcall(function ()
		return G_ChapterLogic:CheckChapterIsPass(tostring(key))
	end)
	return ok and b ~= false and qua == true
end

-- Danh sách rơi do CHÍNH lớp offline sinh (cùng xác suất như ải thường).
local function danhSachRoi(key)
	if type(_G.OfflineDrop_build) == "function" then
		local ok, t = pcall(OfflineDrop_build, tostring(key))
		if ok and type(t) == "table" then return t end
	end
	return { DropConfig = {}, Drop = {} }
end

-- Lọc rơi theo quái đã giết; không có KillIdList thì trao NGUYÊN danh sách
-- (cùng quyết định với `handlers/chapter.lua`).
local function locRoi(key, tRoi, kills)
	if type(kills) ~= "table" then
		return tRoi, "client khong gui KillIdList"
	end
	local ok, b, tGiet = pcall(function ()
		return G_ChapterLogic:filterKillDropList(kills, tRoi)
	end)
	if ok and b ~= false and type(tGiet) == "table" then return tGiet, nil end
	return tRoi, "filterKillDropList tu choi"
end

local function phatMotPrizeList(ds, from)
	local ok, r = pcall(function ()
		return G_ChapterLogic:SetDataWithPrizeList(ds, 1, from or "ActivityChapter")
	end)
	return ok and r ~= false
end

------------------------------------------------------------------- 1. 7 KHOÁ KẾT THÚC
--[[ Dùng NGUYÊN `activityChapterComplete` của share. Trả về:
	`(bResult, nErrCode, KillDropList, nResourceCount, nDropExtraGold, nAddGold, tAddDropList)`.
	Mode TGZZ/DK có thêm `PrizeList` từ hàm thưởng riêng; HJRQ ghi thống kê sóng. ]]
local function ketThuc(ctx, key, tClientData, hamNhan, loaiThem)
	local cfg = cauHinh(key)
	if cfg == nil then
		return baoLoi(ctx, ma("CanNotFoundConfig", 1404), "khong co cau hinh " .. tostring(key))
	end
	local cd = (type(tClientData) == "table" and type(tClientData.ChapterData) == "table")
		and tClientData.ChapterData or {}
	local tRoi = danhSachRoi(key)
	local tRoiDung, viSao = locRoi(key, tRoi, cd.KillIdList)
	if viSao then OfflineLog:info(TEN_FILE .. ": " .. viSao) end
	local satThuong = tonumber(cd.DamageCount) or tonumber(cd.TotalHart) or 0

	local ok, b, nErr, killDrop, resCount, dropGold, addGold, addDrop = pcall(function ()
		return G_ChapterLogic:activityChapterComplete(key, tRoiDung, cd.KillIdList or {}, satThuong)
	end)
	if not ok or b ~= true then
		OfflineLog:warn(string.format("%s: activityChapterComplete '%s' tu choi -> %s / %s",
			TEN_FILE, tostring(key), tostring(b), tostring(nErr)))
		return baoLoi(ctx, nErr or ma("CanNotFoundConfig", 1404), "ket thuc that bai")
	end

	local ret = {
		ChapterKey = tostring(key),
		KillDropList = killDrop or tRoiDung,
		DropList = tRoiDung,
		AddDropList = addDrop or {},
		AddDropGold = (tonumber(dropGold) or 0) + (tonumber(addGold) or 0),
		ResourceCount = tonumber(resCount) or 0,
	}

	-- TGZZ / DK: thưởng riêng theo cấp mùa × % sát thương (luật GỐC của share).
	if loaiThem == "tgzz" or loaiThem == "dk" then
		local cap = 1
		pcall(function ()
			local okL, bL, c = pcall(function ()
				return G_ChapterLogic[loaiThem == "tgzz" and "GetTGZZChapterLevel" or "GetDKChapterLevel"](G_ChapterLogic)
			end)
			if okL and bL ~= false and tonumber(c) then cap = tonumber(c) end
		end)
		local pct = tonumber(tClientData and tClientData.DamagePercent)
		if pct == nil or pct <= 0 then pct = 1 end
		local prizeList = {}
		pcall(function ()
			local okP, ds = pcall(function ()
				if loaiThem == "tgzz" then
					return G_ChapterLogic:GetTGZZChapterPrize(cap, pct)
				end
				return G_ChapterLogic:GetDKChapterPrize(cap, pct)
			end)
			if okP and type(ds) == "table" then
				prizeList = ds
				phatMotPrizeList(ds, loaiThem == "tgzz" and "TGZZ" or "DK")
			end
		end)
		ret.PrizeList = prizeList
		ret.DamagePercent = pct
	end

	-- HJRQ: ghi kỷ lục sóng — ĐÚNG luật `share/Statistics.lua:294-339`.
	if loaiThem == "hjrq" then
		local song = tonumber(cd.BatchCount) or 0
		local cu = soLieu("MaxHJRQBatchCount")
		if song > cu then
			datSoLieu("MaxHJRQBatchCount", song)
			OfflineLog:info(string.format("%s: ky luc song HJRQ %d -> %d", TEN_FILE, cu, song))
		end
		ret.BatchCount = song
	end

	dongBo()
	OfflineLog:info(string.format("%s: ket thuc '%s' — roi %d mon, +%d vang",
		TEN_FILE, tostring(key), #((ret.KillDropList or {}).Drop or {}), ret.AddDropGold))
	goi(ctx, hamNhan, ret)
end

R:on("G_ChapterLogic.ClientChapterHJRQComplete", function (ctx, key, tData)
	ketThuc(ctx, key or aiDuyNhat(3), tData, "OnServerChapterHJRQComplete", "hjrq")
end)

R:on("G_ChapterLogic.ClientChapterSCSComplete", function (ctx, key, tData)
	ketThuc(ctx, key or aiDuyNhat(4), tData, "OnServerChapterSCSComplete")
end)

R:on("G_ChapterLogic.ClientChapterDJSJFComplete", function (ctx, key, tData)
	ketThuc(ctx, key or aiDuyNhat(6), tData, "OnServerChapterDJSJFComplete")
end)

R:on("G_ChapterLogic.ClientChapterXZWCComplete", function (ctx, key, tData)
	ketThuc(ctx, key or aiDuyNhat(7), tData, "OnServerChapterXZWCComplete")
end)

R:on("G_ChapterLogic.ClientChapterTGZZComplete", function (ctx, key, tData)
	ketThuc(ctx, key or aiDuyNhat(13), tData, "OnChapterTGZZComplete", "tgzz")
end)

R:on("G_ChapterLogic.ClientChapterPetBossComplete", function (ctx, key, tData)
	ketThuc(ctx, key or aiDuyNhat(8), tData, "OnChapterPetBossComplete")
end)

--[[ DK: client GỬI MỘT tham số (`CUIDKData:ClientChapterDKComplete_cs`) — khoá ải
	lấy trong dữ liệu, thiếu thì lấy ải duy nhất của loại 14. ]]
R:on("G_ChapterLogic.ClientChapterDKComplete", function (ctx, tData)
	local key = nil
	pcall(function ()
		local cd = type(tData) == "table" and tData.ChapterData or nil
		key = cd and tostring(cd.ChapterKey or "")
		if key == "" then key = nil end
	end)
	ketThuc(ctx, key or aiDuyNhat(14), tData, "OnChapterDKComplete", "dk")
end)

------------------------------------------------------------------- 2. 4 KHOÁ CÀN QUÉT
--[[ Càn quét ải hoạt động: PHẢI đã qua ải (mã gốc 1435 `NotCrossCantSweep`);
	rồi dùng `chapterSweepHandle` (luật GỐC) với danh sách rơi sinh lại. ]]
local function canQuet(ctx, key, hamNhan, loaiThem)
	if key == nil or cauHinh(key) == nil then
		return baoLoi(ctx, ma("CanNotFoundConfig", 1404), "khong co cau hinh ai")
	end
	if not daQuaAi(key) then
		return baoLoi(ctx, ma("NotCrossCantSweep", 1435), "chua qua ai " .. tostring(key))
	end
	local cfg = cauHinh(key)
	local tRoi = danhSachRoi(key)
	local ok, b, nErr, dropList, prizeList, resCount, dropGold = pcall(function ()
		return G_ChapterLogic:chapterSweepHandle(cfg, cfg.ChapterUserEx or 0, tRoi, 1, true, "ActivitySweep")
	end)
	if not ok or b ~= true then
		OfflineLog:warn(string.format("%s: chapterSweepHandle '%s' tu choi -> %s / %s",
			TEN_FILE, tostring(key), tostring(b), tostring(nErr)))
		return baoLoi(ctx, nErr or 1, "can quet that bai")
	end

	-- TGZZ / DK: thưởng riêng (sweep coi như đánh lại đúng thành tích — pct = 1).
	local prizeRieng = nil
	if loaiThem == "tgzz" or loaiThem == "dk" then
		local cap = 1
		pcall(function ()
			local okL, bL, c = pcall(function ()
				return G_ChapterLogic[loaiThem == "tgzz" and "GetTGZZChapterLevel" or "GetDKChapterLevel"](G_ChapterLogic)
			end)
			if okL and bL ~= false and tonumber(c) then cap = tonumber(c) end
		end)
		pcall(function ()
			local okP, ds = pcall(function ()
				if loaiThem == "tgzz" then
					return G_ChapterLogic:GetTGZZChapterPrize(cap, 1)
				end
				return G_ChapterLogic:GetDKChapterPrize(cap, 1)
			end)
			if okP and type(ds) == "table" then
				prizeRieng = ds
				phatMotPrizeList(ds, loaiThem == "tgzz" and "TGZZSweep" or "DKSweep")
			end
		end)
	end
	dongBo()
	OfflineLog:info(string.format("%s: can quet '%s' -> roi %d mon, thuong %d mon",
		TEN_FILE, tostring(key), #((dropList or {}).Drop or {}), #(prizeRieng or prizeList or {})))

	if loaiThem == "tgzz" then
		goi(ctx, hamNhan, prizeRieng or {})
	elseif loaiThem == "dk" then
		goi(ctx, hamNhan, prizeRieng or {})
	else
		-- HJRQ / SYZLB+XZWC: hàm nhận đòi `tData.ChapterKey`.
		goi(ctx, hamNhan, {
			ChapterKey = tostring(key),
			Data = { DropList = dropList, PrizeList = prizeList, ResourceCount = resCount, AddDropGold = dropGold },
			DropList = dropList,
			PrizeList = prizeList,
			AddDropList = {},
			AddDropGold = dropGold or 0,
		})
	end
end

R:on("G_ChapterLogic.ClientChapterTGZZSweep", function (ctx)
	canQuet(ctx, aiDuyNhat(13), "OnChapterTGZZSweep", "tgzz")
end)

R:on("G_ChapterLogic.ClientChapterDKSweep", function (ctx)
	canQuet(ctx, aiDuyNhat(14), "OnChapterDKSweep", "dk")
end)

R:on("G_ChapterLogic.ClientChapterHJRQSweep", function (ctx, key)
	canQuet(ctx, key or aiDuyNhat(3), "OnServerChapterHJRQSweep")
end)

R:on("G_ChapterLogic.ClientChapterSYZLBAndXZWCSweep", function (ctx, key)
	canQuet(ctx, key or aiDuyNhat(5), "OnChapterSYZLBAndXZWCSweep")
end)

------------------------------------------------------------------- 3. NĂM TIỆN ÍCH
--[[ Xem trước danh sách rơi của một ải (UI dev + đường mạng cũ đọc
	`OnServerGetChapterDropData`). Trả ĐÚNG bộ sinh rơi của lớp offline. ]]
R:on("G_ChapterLogic.ClientGetChapterDropData", function (ctx, key)
	local k = tostring(key or "")
	local tRoi = danhSachRoi(k)
	local d = { ChapterKey = k, DropList = tRoi,
		DropConfig = tRoi.DropConfig or {}, Drop = tRoi.Drop or {} }
	OfflineLog:info(string.format("%s: xem truoc roi '%s' -> %d mon", TEN_FILE, k,
		#(d.Drop or {})))
	goi(ctx, "OnServerGetChapterDropData", d)
end)

--[[ Xem trước NPC/drop của ải Thập Thường Thị. Không có bảng NPC theo TỪNG CẤP
	được ship theo hình client dựng (`getSCSChapterNpcConfig` đòi cả `Data`/`Groups`
	của cấu hình ải) ⇒ trả `NpcList = {}` đúng hình; client tự bỏ qua vòng lặp. ]]
R:on("G_ChapterLogic.ClientGetSCSChapterNPCData", function (ctx, tLevelList)
	OfflineLog:info(TEN_FILE .. ": SCS NPC preview -> rong (khong co bang theo cap)")
	goi(ctx, "OnServerGetSCSChapterNPCData", { NpcList = {} })
end)

--[[ Phe của ĐK: máy chủ gốc luân phiên phe. Offline không có nguồn luân phiên ⇒
	trả phe MẶC ĐỊNH 1 — đúng giá trị client tự dùng khi chưa có dữ liệu. ]]
R:on("G_ChapterLogic.ClientGetDKChapterFaction", function (ctx)
	goi(ctx, "OnGetDKChapterFaction", 0, 1, os.time())
end)

--[[ Hồi sinh trong trận: giá GỐC `GetChapterReviveCost(n) = 50 × (n+1)` (kim cương).
	Trừ tiền, tăng bộ đếm `ChapterReviveCount`, rồi phát sự kiện mà
	`ChapterNormalLevel` nghe (`Chapter.OnReviveInBattle`). ]]
R:on("G_ChapterLogic.ClientReviveInBattle", function (ctx)
	local soLan = 0
	pcall(function ()
		local ok, b, n = pcall(function () return G_UserLogicDataManager:GetChapterReviveCount() end)
		if ok and b ~= false and tonumber(n) then soLan = tonumber(n) end
	end)
	local gia = 50 * (soLan + 1)
	pcall(function ()
		local ok, v = pcall(function () return G_ChapterLogic:GetChapterReviveCost(soLan) end)
		if ok and tonumber(v) then gia = tonumber(v) end
	end)
	local okTru, daTru = pcall(function () return G_UserLogic:CostDiamond(gia, "ChapterRevive") end)
	if not okTru or daTru ~= true then
		return thongBao(504)     -- ErrorCode.Common.NotEnoughDiamond
	end
	pcall(function () G_UserLogicDataManager:SetChapterReviveCount(soLan + 1) end)
	dongBo()
	OfflineLog:info(string.format("%s: hoi sinh lan %d (-%d kim cuong)", TEN_FILE, soLan + 1, gia))
	pcall(function ()
		G_EventManager:PostLogicEvent(nil, EventManagerLogicEvent.Chapter.OnReviveInBattle)
	end)
end)

--[[ Client báo đã vượt `nCount` sóng HJRQ. Không có hàm nhận — chỉ ghi kỷ lục
	vào thống kê (đúng luật `share/Statistics.lua:294-339`). ]]
R:on("G_ChapterLogic.ClientUserOverHJRQ", function (ctx, nCount, strChapterKey)
	local song = tonumber(nCount) or 0
	local cu = soLieu("MaxHJRQBatchCount")
	if song > cu then
		datSoLieu("MaxHJRQBatchCount", song)
		dongBo()
		OfflineLog:info(string.format("%s: HJRQ vuot %d song (ky luc cu %d)", TEN_FILE, song, cu))
	end
end)

OfflineLog:info("ai dac biet: da noi 16 khoa (7 ket thuc, 4 can quet, 5 tien ich)")

return true
