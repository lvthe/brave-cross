--[[
	offline/thu_nhom_moi.lua — TỰ KIỂM CÁC NHÓM MỚI, CHẠY TRONG GAME.

	VÌ SAO CÓ TỆP NÀY: bấm UI để nghiệm thu từng panel là đường rất đắt trên máy
	này — panel Ma Động / Lôi Đài / Chiêm Tinh **nuốt cả nút BACK lẫn nút mũi tên**
	của chúng (bẫy đã ghi ở `BAY-UI.md`), nên mỗi lần thử một panel là một lần
	khởi động lại game + chạy lại hook SDK. Tệp này gọi THẲNG handler qua
	`OfflineRouter:getFor(obj, func)` với một `ctx` giả, ĐÚNG sau khi đã vào cảnh
	Main — dữ liệu người chơi, cấu hình, file lưu đều là THẬT, chỉ thiếu lớp UI.

	Đo được gì: handler có đăng ký đúng khoá, có chạy trên dữ liệu thật, và trả
	đúng mã lỗi / đúng callback. KHÔNG đo được: hình vẽ của panel (việc của UI).

	BẬT/TẮT KHÔNG CẦN BUILD LẠI: chỉ chạy khi có tệp cờ
	    /data/user/0/com.cmn.buatanew/files/selftest.flag
	tạo bằng `adb shell touch …`, xoá là thôi. Chạy MỘT lần mỗi lần vào game.

	⚠ Tệp này TIÊU TÀI NGUYÊN THẬT (nâng trận pháp, ghép thời trang, kích hoạt
	thẻ tháng) — nó là đồ thử, đừng bật trên bản lưu người chơi thật.
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineThuNhomMoi = OfflineThuNhomMoi or {}

OfflineThuNhomMoi.TEP_CO = "selftest.flag"
OfflineThuNhomMoi.DEM = 0
OfflineThuNhomMoi.DA_CHAY = false
OfflineThuNhomMoi.CHO = 8        -- nhịp (giây) chờ vào cảnh Main trước khi chạy

local function coTepCo()
	local ok, fp = pcall(function ()
		-- Bóc MỌI tên tệp (file lưu có thể là `offline_save_<uid>.json`).
		return io.open(OfflineStore:path():gsub("[^/]*$", "") .. OfflineThuNhomMoi.TEP_CO, "r")
	end)
	if ok and fp then fp:close(); return true end
	return false
end

--[[ `ctx` giả: ghi lại mọi lời gọi trả về để đọc mã lỗi / tên callback. ]]
local function ctxGia()
	local c = { calls = {} }
	function c:call(obj, f, ...)
		local t = { obj = obj, f = f, args = { ... } }
		self.calls[#self.calls + 1] = t
		return true
	end
	return c
end

--[[ Mã lỗi của lượt trả lời CUỐI. Dạng chuẩn của lớp offline là
	`OnReciveResponse("", "", mã, {})` ⇒ args[3]; dạng thành công là gọi thẳng
	một hàm client ⇒ không có mã (trả 0). ]]
local function maCua(ctx)
	local x = ctx.calls[#ctx.calls]
	if x == nil then return nil, "khong tra loi" end
	if x.f == "OnReciveResponse" then
		return tonumber(x.args[3]) or -1, x.f
	end
	-- Dạng "gọi thẳng hàm client": mã nằm trong `{err = …}` nếu có, không thì là
	-- thành công. Đọc thêm trường này để log không báo "ma=0" cho một lượt TỪ CHỐI
	-- (đã vấp khi thử gác 1431 của mục tiêu ải, 1/11).
	local a = x.args[1]
	if type(a) == "table" and tonumber(a.err) ~= nil then
		return tonumber(a.err), x.obj .. "." .. tostring(x.f)
	end
	return 0, x.obj .. "." .. tostring(x.f)
end

local function goi(obj, func, ...)
	local fn = OfflineRouter:getFor(obj, func)
	if fn == nil then return nil, "CHUA DANG KY " .. tostring(obj) .. "." .. tostring(func) end
	local ctx = ctxGia()
	local ok, err = pcall(fn, ctx, ...)
	if not ok then return nil, "NEM LOI: " .. tostring(err) end
	local ma, ten = maCua(ctx)
	return { ma = ma, ten = ten, ctx = ctx }, nil
end

local function ghi(ten, kq, chiTiet)
	if kq == nil then
		OfflineLog:err(string.format("THU %s: HONG — %s", ten, tostring(chiTiet)))
		return
	end
	OfflineLog:info(string.format("THU %s: ma=%s, tra loi=%s%s",
		ten, tostring(kq.ma), tostring(kq.ten), chiTiet and ("  " .. chiTiet) or ""))
end

function OfflineThuNhomMoi:chay()
	OfflineLog:info("THU ===== bat dau tu kiem cac nhom 31/10 =====")

	-- 1. TRẬN PHÁP — cấp trước/sau
	local truoc = "?"
	pcall(function () local _, l = G_FormationLogic:GetLevel("jichu"); truoc = tostring(l) end)
	local k1, e1 = goi("G_FormationLogic", "ClientUpgrade", "jichu")
	local sau = "?"
	pcall(function () local _, l = G_FormationLogic:GetLevel("jichu"); sau = tostring(l) end)
	ghi("tran phap (jichu)", k1, e1 or ("Level " .. truoc .. " -> " .. sau))

	-- 2. THỜI TRANG — ghép Coat005 (cần ItemID 15 x10)
	local k2, e2 = goi("G_ClothingLogic", "ClientComposeClothing", 25, "Coat005")
	ghi("thoi trang (Coat005)", k2, e2)

	-- 3. LUYỆN HERO — gán tướng 25 vào ô 1
	local k3, e3 = goi("G_HeroPracticeLogic", "ClientPracticeHero", 25, "1")
	ghi("luyen hero (gan o 1)", k3, e3)

	-- 4. LUYỆN HERO — truy vấn trạng thái (không cần UI)
	local k4, e4 = goi("G_HeroPracticeLogic", "ClientGetPracticeInfo")
	ghi("luyen hero (GetPracticeInfo)", k4, e4)

	-- 5. THẺ THÁNG — nhận khi CHƯA có thẻ (phải từ chối, mã 1)
	local k5, e5 = goi("G_MonthlyCardLogic", "ClientGetReward", "Normal")
	ghi("the thang (chua kich hoat)", k5, e5)

	-- 6. THẺ THÁNG — kích hoạt bằng luật GỐC rồi nhận
	if OfflineTheThang and type(OfflineTheThang.kichHoat) == "function" then
		local okK, lyDo = OfflineTheThang:kichHoat("Normal")
		OfflineLog:info(string.format("THU the thang (kich hoat): %s %s",
			tostring(okK), tostring(lyDo or "")))
	end
	local k6, e6 = goi("G_MonthlyCardLogic", "ClientGetReward", "Normal")
	ghi("the thang (sau kich hoat)", k6, e6)

	-- 7-8. TÍCH LUỸ NẠP/TIÊU — hai hoạt động đang ĐÓNG ⇒ phải là 4001
	local k7, e7 = goi("G_ActivityCumulativeRecharge", "ClientGetUserState")
	ghi("tich luy nap (dang dong)", k7, e7)
	local k8, e8 = goi("G_ActivityCumulativeConsume", "ClientGetUserState")
	ghi("tich luy tieu (dang dong)", k8, e8)

	-- 9. QUỸ CẤP — đã mua + đã lĩnh hết ⇒ phải là 4002 (hết bậc)
	local k9, e9 = goi("G_ActivityFund", "ClientGetLevelFundPrize")
	ghi("quy cap (da linh het bac)", k9, e9)

	-- 10. QUÀ 7 NGÀY — nhận ngày 1. Móc `OfflineQuaNgay` đã gọi `SetDailyLogin` lúc
	-- vào game nên ngày 1 phải ở trạng thái `NotGet`; nhận được = đường dây đúng.
	local k10, e10 = goi("G_SevenDaysGiftLogic", "ClientSevenDaysGift", 1)
	ghi("qua 7 ngay (ngay 1)", k10, e10)

	-- 11. ĐIỂM KIM THỦ — 1 lượt. Trả về phải đủ NĂM trường mà UI đọc.
	local k11, e11 = goi("G_MidasTouchLogic", "ClientRunMidasTouchWithCount", 1)
	ghi("kim thu (1 luot)", k11, e11)
	if k11 and k11.ctx then
		local x = k11.ctx.calls[#k11.ctx.calls]
		local d = x and x.args[1]
		if type(d) == "table" and d.tGoldGetList then
			OfflineLog:info(string.format(
				"THU kim thu chi tiet: %s luot, kim cuong %s, vang +%s, he so %s",
				tostring(d.nCount), table.concat(d.tDiamondCostList or {}, "+"),
				table.concat(d.tGoldGetList or {}, "+"),
				table.concat(d.tTimesList or {}, ",")))
		else
			OfflineLog:err("THU kim thu: tra loi KHONG phai bang du 5 truong — UI se khong chay")
		end
	end

	-- 12. MỤC TIÊU ẢI — rương ở màn chọn ải. Trạng thái tính từ SỐ SAO các ải BOSS đã
	-- thắng (ngưỡng 3/9/12 của chương); nên đọc bảng trạng thái trước rồi mới bấm
	-- đúng mốc đang lĩnh được. Không có mốc nào mở ⇒ gọi mốc 3 để đo ĐÚNG cửa từ chối
	-- (1430), không phải đoán.
	local dsMoc = "?"
	pcall(function ()
		local _, st = G_ChapterLogic:GetChapterTargetRewardStatusMap(1, CHAPTER_TYPE.NORMAL_LEVEL)
		local t = {}
		if type(st) == "table" then
			for k, v in pairs(st) do t[#t + 1] = tostring(k) .. "=" .. tostring(v) end
		end
		table.sort(t)
		dsMoc = table.concat(t, ",")
	end)
	OfflineLog:info("THU muc tieu ai: trang thai chuong 1 thuong = " .. dsMoc)

	local mocThu = 3
	pcall(function ()
		local _, st = G_ChapterLogic:GetChapterTargetRewardStatusMap(1, CHAPTER_TYPE.NORMAL_LEVEL)
		if type(st) == "table" then
			for k, v in pairs(st) do
				if tonumber(v) == 1 and tonumber(k) < mocThu then mocThu = tonumber(k) end
			end
		end
	end)
	local k12, e12 = goi("G_ChapterLogic", "ClientGetChapterTargetReward",
		{ nMainChapter = 1, nChapterDifficulty = CHAPTER_TYPE.NORMAL_LEVEL, nStage = mocThu })
	ghi("muc tieu ai (chuong 1, moc " .. mocThu .. ")", k12, e12)

	-- 13. BẢNG XẾP HẠNG — bốn tab. Offline một người ⇒ bảng rỗng + hạng 1; UI tự vá
	-- dòng của mình. Đo ở đây là đo ĐƯỜNG DÂY (đúng tên hàm nhận + đúng ba tham số).
	for _, tab in ipairs({
		{ "ClientGet5HeroPowerRank", "OnGet5HeroPowerRank", "5 tuong" },
		{ "ClientGetPveNormalRank", "OnGetPveNormalRank", "PvE thuong" },
		{ "ClientGetPveEliteRank", "OnGetPveEliteRank", "PvE tinh anh" },
		{ "ClientGetPveStarRank", "OnGetPveStarRank", "PvE sao" },
	}) do
		local k13, e13 = goi("G_RankLogic", tab[1])
		ghi("bang xep hang (" .. tab[3] .. ")", k13, e13)
		if k13 and k13.ctx then
			local x = k13.ctx.calls[#k13.ctx.calls]
			if not (x and x.f == tab[2] and type(x.args[1]) == "table"
				and x.args[2] == 1 and x.args[3] == 1) then
				OfflineLog:err("THU bang xep hang: " .. tab[3]
					.. " tra SAI hinh (can 3 tham so: bang, hang 1, hang 1)")
			end
		end
	end

	-- 14. BXH QUA ĐƯỜNG THẬT — mở panel rồi chuyển tab, để `CallServer` đi qua router
	-- thật và UI thật nhận dữ liệu (mục 13 ở trên dùng ctx GIẢ nên không chạm UI).
	if g_CUILeaderboard and type(g_CUILeaderboard.refreshUI) == "function" then
		-- Bọc hàm NHẬN PHÍA LOGIC (`G_RankLogic.OnGet5HeroPowerRank`) — đây mới là
		-- chỗ `CallLocal` tra cứu LÚC GỌI, nên bọc ăn. Bọc hàm của UI thì KHÔNG ăn:
		-- `G_EventManager:Reg` đã giữ tham chiếu hàm CŨ từ `onShow` (đã vấp).
		local goc = G_RankLogic.OnGet5HeroPowerRank
		if type(goc) == "function" then
			G_RankLogic.OnGet5HeroPowerRank = function (self, tList, nSelf, nYest)
				local uid = "?"
				pcall(function () uid = tostring(g_CUIGameRPCManager:GetChinaMixUid()) end)
				OfflineLog:info(string.format(
					"THU ban that: logic nhan duoc (list=%s, self=%s, uid=%s)",
					type(tList), tostring(nSelf), uid))
				return goc(self, tList, nSelf, nYest)
			end
		else
			OfflineLog:warn("THU ban that: khong thay G_RankLogic.OnGet5HeroPowerRank")
		end

		-- Đo SỰ KIỆN: post có tới nơi không, và lúc post có ai đăng ký chưa. Hai câu
		-- hỏi khác nhau — "logic chạy" không bảo đảm "UI đã nghe".
		local postGoc = G_EventManager.PostLogicEvent
		if type(postGoc) == "function" then
			G_EventManager.PostLogicEvent = function (self, tData, ...)
				local ev = select(1, ...)
				if ev == "OnServerGet5HeroPowerRank" then
					local n = -1
					pcall(function ()
						local t = self.listRegister[EventManagerType.Logic]["OnServerGet5HeroPowerRank"]
						n = 0
						if t and t.Registers then
							for _ in pairs(t.Registers) do n = n + 1 end
						end
					end)
					OfflineLog:info("THU ban that: POST OnServerGet5HeroPowerRank, so dang ky = " .. n)
				end
				return postGoc(self, tData, ...)
			end
		end

		--[[ MỞ PANEL RỒI CHỜ — không được gọi `refreshUI` ngay trong cùng khung:
		    các listener của UI chỉ đăng ký trong `onVisible()`, mà `onVisible` chạy
		    SAU khi dialog dựng xong. Đo được: gọi ngay thì `POST ... so dang ky = 0`
		    ⇒ phản hồi bắn vào khoảng không, `t5HeroRankData` rỗng. Đó là BẪY CỦA ĐỒ
		    THỬ, không phải lỗi handler. ]]
		local ok, err = pcall(function ()
			-- Đường THẬT: `CUIMainBuildingManager:_btnMainLeaderboard` dùng
			-- `g_CUINormalDlg`, KHÔNG phải `g_CUISubDialog` (dùng sai là các layer
			-- không dựng và `refreshUI` thoát ở dòng kiểm userdata đầu tiên — đã vấp).
			g_CUINormalDlg:Show(g_CUILeaderboard:GetUIName())
		end)
		OfflineLog:info("THU ban that: mo BXH -> " .. tostring(ok)
			.. (ok and "" or (" (" .. tostring(err) .. ")")))

		if S_CCSchedule then
			-- Bước 2: sau 1 giây, `onVisible` đã chạy ⇒ đổi tab + gọi refreshUI.
			local doiTab = {}
			function doiTab:chay()
				local ok2, err2 = pcall(function ()
					g_CUILeaderboard.CurrentTab = g_CUILeaderboard.State.fight
					g_CUILeaderboard:refreshUI()
				end)
				OfflineLog:info("THU ban that: doi tab chien luc 5 tuong -> " .. tostring(ok2)
					.. (ok2 and "" or (" (" .. tostring(err2) .. ")")))
			end
			pcall(function () S_CCSchedule:scheduleOnce(doiTab, "chay", 1) end)

			-- Bước 3: sau 3 giây, kiểm dữ liệu UI thật đã nhận.
			local kiem = {}
			function kiem:chay()
				local n, ten, hien = -1, "?", "?"
				pcall(function ()
					n = #(g_CUILeaderboard.t5HeroRankData or {})
					local d = g_CUILeaderboard.t5HeroRankData and g_CUILeaderboard.t5HeroRankData[1]
					if type(d) == "table" then
						ten = tostring(d.CharacterName) .. "/hang " .. tostring(d.Rank)
					end
				end)
				pcall(function () hien = tostring(g_CUINormalDlg:IsUIShow()) end)
				OfflineLog:info(string.format(
					"THU ban that: kiem sau 3s — %d dong (dong 1: %s), panel hien: %s",
					n, ten, hien))
			end
			pcall(function () S_CCSchedule:scheduleOnce(kiem, "chay", 3) end)
		end
	else
		OfflineLog:warn("THU ban that: khong thay g_CUILeaderboard")
	end

	-- 15. MUA VẬT PHẨM — dòng giá THẬT `KDBGameGoodsConfig`: ItemId 6, kim cương, 50.
	-- Handler KHÔNG trả lời qua ctx (client bản này không có hàm nhận phản hồi) nên đo
	-- bằng CHÊNH LỆCH KIM CƯƠNG, không bằng mã trả về.
	local muaFn = OfflineRouter:getFor("G_ItemLogic", "ClientBuyItem")
	if muaFn then
		local truoc, sau = nil, nil
		pcall(function () local _, d = G_UserLogic:GetDiamond(); truoc = tonumber(d) end)
		local ok15, err15 = pcall(muaFn, ctxGia(), 6, 1, ResourceType.Diamond)
		pcall(function () local _, d = G_UserLogic:GetDiamond(); sau = tonumber(d) end)
		local tru = (truoc and sau) and (truoc - sau) or "?"
		OfflineLog:info(string.format(
			"THU mua vat pham (6 x1, kim cuong): ok=%s, kim cuong %s -> %s (tru %s)",
			tostring(ok15), tostring(truoc), tostring(sau), tostring(tru)))
		if not ok15 then
			OfflineLog:err("THU mua vat pham: nem loi: " .. tostring(err15))
		elseif tru ~= 50 then
			OfflineLog:err("THU mua vat pham: tru " .. tostring(tru) .. " kim cuong, dang le phai la 50")
		end
	else
		OfflineLog:err("THU mua vat pham: CHUA DANG KY G_ItemLogic.ClientBuyItem")
	end

	-- 16. TINH LUYEN TRANG BI — tìm một trang bị ĐÃ CÓ THẬT (EquipLevel > 0) trong bản
	-- lưu, cấp tinh hoa đủ để thử, rồi đo cấp trước/sau + tinh hoa trước/sau.
	local heroQ, partQ = nil, nil
	pcall(function ()
		local _, map = G_DataManager:GetUserDataWithName("GameUserEquipment")
		for hid, parts in pairs(map or {}) do
			for pid, e in pairs(parts or {}) do
				if heroQ == nil and type(e) == "table" and (tonumber(e.EquipLevel) or 0) > 0 then
					heroQ, partQ = tonumber(hid), tonumber(pid)
				end
			end
		end
	end)
	if heroQ ~= nil then
		local fnTl = OfflineRouter:getFor("G_EquipmentLogic", "ClientRefineEquip")
		if fnTl then
			pcall(function () G_UserLogic:AddConcentrate(2000, "THU tinh luyen") end)
			local capT, capS, tinhT, tinhS = nil, nil, nil, nil
			pcall(function ()
				local _, e = G_EquipmentLogic:GetEquipment(heroQ, partQ)
				capT = tonumber(e and e.RefineLevel) or 0
				local _, c = G_UserLogic:GetConcentrate()
				tinhT = tonumber(c)
			end)
			local ok16, err16 = pcall(fnTl, ctxGia(), heroQ, partQ)
			pcall(function ()
				local _, e = G_EquipmentLogic:GetEquipment(heroQ, partQ)
				capS = tonumber(e and e.RefineLevel) or 0
				local _, c = G_UserLogic:GetConcentrate()
				tinhS = tonumber(c)
			end)
			OfflineLog:info(string.format(
				"THU tinh luyen (hero %s / o %s): ok=%s, cap %s -> %s, tinh hoa %s -> %s",
				tostring(heroQ), tostring(partQ), tostring(ok16),
				tostring(capT), tostring(capS), tostring(tinhT), tostring(tinhS)))
			if not ok16 then
				OfflineLog:err("THU tinh luyen: nem loi: " .. tostring(err16))
			elseif capS == capT then
				OfflineLog:warn("THU tinh luyen: cap KHONG doi (xem dong 'tinh luyen trang bi' ngay tren)")
			end
		else
			OfflineLog:err("THU tinh luyen: CHUA DANG KY G_EquipmentLogic.ClientRefineEquip")
		end
	else
		OfflineLog:warn("THU tinh luyen: ban luu khong co trang bi nao EquipLevel > 0")
	end

	-- 17. LUYEN VAT PHAM — tìm trong TÚI một vật liệu có trường `Concentrate` > 0 (tỉ lệ
	-- do CẤU HÌNH quyết, chính UI dùng nó để hiện "sẽ được N tinh hoa"), rồi đo tỉ lệ.
	local fnLuyen = OfflineRouter:getFor("G_ItemLogic", "ClientRefineItem")
	if fnLuyen then
		local mucLuyen = nil
		pcall(function ()
			local _, bag = G_DataManager:GetUserDataWithName("GameUserItem")
			for id, it in pairs(bag or {}) do
				-- `IsExist` phải đúng: bảng có dòng với ItemCount > 0 mà IsExist=false là
				-- dòng "ma", `GetItemCount` vẫn trả 0 (đã vấp 1/11: chọn nhầm món 88).
				if mucLuyen == nil and type(it) == "table" and it.IsExist == true
					and (tonumber(it.ItemCount) or 0) > 0 then
					local cfg = G_ConfigManager:GetItemConfigWithId(tonumber(id))
					if type(cfg) == "table" and (tonumber(cfg.Concentrate) or 0) > 0 then
						mucLuyen = { ItemId = tonumber(id), Count = 1, mot = tonumber(cfg.Concentrate) }
					end
				end
			end
		end)
		if mucLuyen == nil then
			-- Túi sạch: CẤP một vật liệu THẬT (id 88, `Concentrate = 8` trong cấu hình) để
			-- vẫn đo được tỉ lệ. Đây là việc của ĐỒ THỬ, không phải luật.
			pcall(function ()
				G_ItemLogic:AddItem(88, 3, "THU luyen vat pham")
				local cfg = G_ConfigManager:GetItemConfigWithId(88)
				if type(cfg) == "table" and (tonumber(cfg.Concentrate) or 0) > 0 then
					mucLuyen = { ItemId = 88, Count = 1, mot = tonumber(cfg.Concentrate) }
				end
			end)
			OfflineLog:info("THU luyen vat pham: tui sach — da cap 3 vat lieu 88 de do")
		end
		if mucLuyen then
			local tr, sau, thT, thS = nil, nil, nil, nil
			pcall(function ()
				local _, n0 = G_ItemLogic:GetItemCount(mucLuyen.ItemId); tr = tonumber(n0)
				local _, c = G_UserLogic:GetConcentrate(); thT = tonumber(c)
			end)
			local ok17, err17 = pcall(fnLuyen, ctxGia(), { { ItemId = mucLuyen.ItemId, Count = 1 } })
			pcall(function ()
				local _, n1 = G_ItemLogic:GetItemCount(mucLuyen.ItemId); sau = tonumber(n1)
				local _, c = G_UserLogic:GetConcentrate(); thS = tonumber(c)
			end)
			OfflineLog:info(string.format(
				"THU luyen vat pham (id %s, 1 cai, Concentrate=%s): ok=%s, so luong %s -> %s, tinh hoa %s -> %s",
				tostring(mucLuyen.ItemId), tostring(mucLuyen.mot), tostring(ok17),
				tostring(tr), tostring(sau), tostring(thT), tostring(thS)))
			if not ok17 then OfflineLog:err("THU luyen vat pham: " .. tostring(err17)) end
		else
			OfflineLog:warn("THU luyen vat pham: tui khong co vat lieu nao Concentrate > 0")
		end
	else
		OfflineLog:err("THU luyen vat pham: CHUA DANG KY G_ItemLogic.ClientRefineItem")
	end

	-- 18. CÁNH ĐANG HIỂN THỊ — chọn cấp 1 cho một tướng ĐANG CÓ cánh (WingLevel > 0),
	-- rồi đọc lại `ShowWingLevel` trên chính bản ghi ấy.
	local fnCanh = OfflineRouter:getFor("G_HeroLogic", "ClientShowWing")
	if fnCanh then
		local idCanh, truocCanh = nil, nil
		pcall(function ()
			local _, map = G_DataManager:GetUserDataWithName("GameUserHero")
			for id, h in pairs(map or {}) do
				if idCanh == nil and type(h) == "table" and (tonumber(h.WingLevel) or 0) > 0 then
					idCanh = tonumber(id)
					truocCanh = tonumber(h.ShowWingLevel) or 0
				end
			end
		end)
		if idCanh then
			local ok18, err18 = pcall(fnCanh, ctxGia(), idCanh, 1)
			local sauCanh = nil
			pcall(function ()
				local _, h = G_HeroLogic:GetHeroWithID(idCanh)
				sauCanh = tonumber(h and h.ShowWingLevel) or 0
			end)
			OfflineLog:info(string.format(
				"THU canh hien thi (tuong %s): ok=%s, ShowWingLevel %s -> %s",
				tostring(idCanh), tostring(ok18), tostring(truocCanh), tostring(sauCanh)))
			if not ok18 then OfflineLog:err("THU canh hien thi: " .. tostring(err18)) end
		else
			OfflineLog:warn("THU canh hien thi: khong tuong nao co canh (WingLevel > 0)")
		end
	else
		OfflineLog:err("THU canh hien thi: CHUA DANG KY G_HeroLogic.ClientShowWing")
	end

	-- 19. THIÊN MỆNH (Sky Fate) — nâng 'qinglong' một cấp cho một tướng có thật, đo cấp
	-- và số mảnh trước/sau. Cấp mảnh trước để chắc chắn đủ giá cấp 1.
	local fnTM = OfflineRouter:getFor("G_HeroLogic", "ClientUpdateHeroSkyFate")
	if fnTM then
		local idTM = nil
		pcall(function ()
			local _, map = G_DataManager:GetUserDataWithName("GameUserHero")
			for id, h in pairs(map or {}) do
				if idTM == nil and type(h) == "table" then idTM = tonumber(id) end
			end
		end)
		if idTM then
			pcall(function () G_HeroLogic:AddHeroFragment(idTM, 50, "THU thien menh") end)
			local lvT, frT, lvS, frS = nil, nil, nil, nil
			pcall(function ()
				local _, h = G_HeroLogic:GetHeroWithID(idTM)
				lvT = tonumber((h.SkyFate or {}).qinglong) or 0
				frT = tonumber(h.HeroFragment) or 0
			end)
			local ok19, err19 = pcall(fnTM, ctxGia(), idTM, "qinglong")
			pcall(function ()
				local _, h = G_HeroLogic:GetHeroWithID(idTM)
				lvS = tonumber((h.SkyFate or {}).qinglong) or 0
				frS = tonumber(h.HeroFragment) or 0
			end)
			OfflineLog:info(string.format(
				"THU thien menh (tuong %s, qinglong): ok=%s, cap %s -> %s, manh %s -> %s",
				tostring(idTM), tostring(ok19), tostring(lvT), tostring(lvS),
				tostring(frT), tostring(frS)))
			if not ok19 then OfflineLog:err("THU thien menh: " .. tostring(err19)) end
		else
			OfflineLog:warn("THU thien menh: ban luu khong co tuong nao")
		end
	else
		OfflineLog:err("THU thien menh: CHUA DANG KY G_HeroLogic.ClientUpdateHeroSkyFate")
	end

	-- 20. MẢNH VẠN NĂNG — chọn một tướng CÓ trong danh sách trắng và trong bản lưu, cấp
	-- 5 mảnh vạn năng (vật phẩm 20), rồi đo số mảnh trước/sau của cả hai bên.
	local fnVN = OfflineRouter:getFor("G_HeroLogic", "ClientConvertUniversalFragment")
	if fnVN then
		local idVN = nil
		pcall(function ()
			local _, cfg = G_ConfigManager:GetCommonConfigWithName("GameUniversalFragmentConfig")
			local _, map = G_DataManager:GetUserDataWithName("GameUserHero")
			-- Bảng trắng có thể VẮNG trong cache của bản client này (đo 1/11: nil) —
			-- khi ấy chọn tướng đầu tiên, vì handler cũng bỏ bước gác ấy.
			for id, h in pairs(map or {}) do
				if idVN == nil and type(h) == "table" then
					if type(cfg) ~= "table"
						or cfg[tostring(id)] ~= nil or cfg[tonumber(id)] ~= nil then
						idVN = tonumber(id)
					end
				end
			end
		end)
		if idVN then
			pcall(function () G_ItemLogic:AddItem(20, 5, "THU manh van nang") end)
			local vnT, vnS, mtT, mtS = nil, nil, nil, nil
			pcall(function ()
				local _, a = G_ItemLogic:GetItemCount(20); vnT = tonumber(a)
				local _, h = G_HeroLogic:GetHeroWithID(idVN); mtT = tonumber(h.HeroFragment) or 0
			end)
			local ok20, err20 = pcall(fnVN, ctxGia(), idVN, 5)
			pcall(function ()
				local _, a = G_ItemLogic:GetItemCount(20); vnS = tonumber(a)
				local _, h = G_HeroLogic:GetHeroWithID(idVN); mtS = tonumber(h.HeroFragment) or 0
			end)
			OfflineLog:info(string.format(
				"THU manh van nang (tuong %s): ok=%s, van nang %s -> %s, manh tuong %s -> %s",
				tostring(idVN), tostring(ok20), tostring(vnT), tostring(vnS),
				tostring(mtT), tostring(mtS)))
			if not ok20 then OfflineLog:err("THU manh van nang: " .. tostring(err20)) end
		else
			local chanDoan = "?"
			pcall(function ()
				local _, cfg = G_ConfigManager:GetCommonConfigWithName("GameUniversalFragmentConfig")
				local _, map = G_DataManager:GetUserDataWithName("GameUserHero")
				local nCfg, ds = -1, {}
				if type(cfg) == "table" then
					nCfg = 0
					for k in pairs(cfg) do
						nCfg = nCfg + 1
						if nCfg <= 3 then ds[#ds + 1] = tostring(k) .. "(" .. type(k) .. ")" end
					end
				end
				local dsH = {}
				for k in pairs(map or {}) do dsH[#dsH + 1] = tostring(k) end
				chanDoan = string.format("cfg=%s, %d khoa [%s], tuong: %s",
					type(cfg), nCfg, table.concat(ds, ","), table.concat(dsH, ","))
			end)
			OfflineLog:warn("THU manh van nang: khong tim duoc tuong phu hop — " .. chanDoan)
		end
	else
		OfflineLog:err("THU manh van nang: CHUA DANG KY G_HeroLogic.ClientConvertUniversalFragment")
	end

	-- 21. TRANG PHỤC ĐỘC QUYỀN — bật/tắt hiển thị cho một tướng, đo `IsCancelExclusive`.
	local fnEX = OfflineRouter:getFor("G_HeroLogic", "ClientSetExclusiveSkinState")
	if fnEX then
		local idEX = nil
		pcall(function ()
			local _, map = G_DataManager:GetUserDataWithName("GameUserHero")
			for id, h in pairs(map or {}) do
				if idEX == nil and type(h) == "table" then idEX = tonumber(id) end
			end
		end)
		if idEX then
			local tr, sau = nil, nil
			pcall(function ()
				local _, h = G_HeroLogic:GetHeroWithID(idEX)
				tr = tostring(h.IsCancelExclusive)
			end)
			local ok21, err21 = pcall(fnEX, ctxGia(), idEX, true)
			pcall(function ()
				local _, h = G_HeroLogic:GetHeroWithID(idEX)
				sau = tostring(h.IsCancelExclusive)
			end)
			OfflineLog:info(string.format(
				"THU trang phuc doc quyen (tuong %s): ok=%s, IsCancelExclusive %s -> %s",
				tostring(idEX), tostring(ok21), tostring(tr), tostring(sau)))
			if not ok21 then OfflineLog:err("THU trang phuc doc quyen: " .. tostring(err21)) end
		else
			OfflineLog:warn("THU trang phuc doc quyen: ban luu khong co tuong nao")
		end
	else
		OfflineLog:err("THU trang phuc doc quyen: CHUA DANG KY G_HeroLogic.ClientSetExclusiveSkinState")
	end

	-- 22. VÕ HỒN — nâng cho một tướng, cấp vật liệu trước (id lấy từ CẤU HÌNH của cấp kế),
	-- đo cấp trước/sau + kết quả 1/2/3 mà client đọc.
	local fnVH = OfflineRouter:getFor("G_HeroLogic", "ClientUpHeroFightSoul")
	if fnVH then
		local idVH = nil
		pcall(function ()
			local _, map = G_DataManager:GetUserDataWithName("GameUserHero")
			for id, h in pairs(map or {}) do
				if idVH == nil and type(h) == "table" then idVH = tonumber(id) end
			end
		end)
		if idVH then
			local capT, capS, kqVH = nil, nil, nil
			pcall(function ()
				local _, h = G_HeroLogic:GetHeroWithID(idVH)
				capT = tonumber(h.FightSoulLevel) or 0
			end)
			-- Cấp vật liệu theo ĐÚNG dòng cấu hình của cấp kế.
			pcall(function ()
				local cfgAll = G_ConfigManager:GetHeroSoulConfig()
				local cfg = cfgAll and cfgAll[(capT or 0) + 1]
				local ds = cfg and cfg.MaterialList
				if type(ds) == "string" then ds = cjson.decode(ds) end
				local mot = type(ds) == "table" and ds[1] or nil
				if mot and tonumber(mot.MaterialID) then
					G_ItemLogic:AddItem(tonumber(mot.MaterialID), 20, "THU vo hon")
				end
			end)
			local c22 = ctxGia()
			local ok22, err22 = pcall(fnVH, c22, idVH, 1)
			pcall(function ()
				local _, h = G_HeroLogic:GetHeroWithID(idVH)
				capS = tonumber(h.FightSoulLevel) or 0
			end)
			for _, x in ipairs(c22.calls or {}) do
				if x.f == "OnUpHeroFightSoul" then kqVH = x.args[1] end
			end
			OfflineLog:info(string.format(
				"THU vo hon (tuong %s): ok=%s, ket qua=%s, cap %s -> %s",
				tostring(idVH), tostring(ok22), tostring(kqVH), tostring(capT), tostring(capS)))
			if not ok22 then OfflineLog:err("THU vo hon: " .. tostring(err22)) end
		else
			OfflineLog:warn("THU vo hon: ban luu khong co tuong nao")
		end
	else
		OfflineLog:err("THU vo hon: CHUA DANG KY G_HeroLogic.ClientUpHeroFightSoul")
	end

	-- 23. PHỤ ĐỀ — gửi một dòng cho một ải rồi đọc lại, đo số dòng trả về.
	local fnPDG = OfflineRouter:getFor("G_SubtitleLogic", "ClientSetUserCopySubtitle")
	local fnPDL = OfflineRouter:getFor("G_SubtitleLogic", "ClientGetCopySubtitle")
	if fnPDG and fnPDL then
		local okG = pcall(fnPDG, ctxGia(), "L_N_01_03", "thu phu de offline", 1234, "white")
		local c23 = ctxGia()
		local okL = pcall(fnPDL, c23, "L_N_01_03")
		local n23, kq23 = -1, "?"
		pcall(function ()
			local x = c23.calls and c23.calls[1]
			if x then
				kq23 = tostring(x.f) .. "/" .. tostring(x.n) .. " tham so"
				if type(x.args[3]) == "table" then n23 = #x.args[3] end
			end
		end)
		OfflineLog:info(string.format(
			"THU phu de: gui=%s doc=%s, %s, so dong cua minh = %s",
			tostring(okG), tostring(okL), kq23, tostring(n23)))
	else
		OfflineLog:err("THU phu de: CHUA DANG KY mot trong hai khoa G_SubtitleLogic")
	end

	-- 24. TÊN NGẪU NHIÊN — sinh thử cả hai giới. Bắt sự kiện bằng cách bọc PostLogicEvent.
	local fnTen = OfflineRouter:getFor("G_GameWorld", "ClientGetRandomName")
	if fnTen then
		local bat = { ten = nil, nam = nil }
		local postGoc2 = G_EventManager.PostLogicEvent
		pcall(function ()
			G_EventManager.PostLogicEvent = function (self, data, ev)
				if ev == "OnGetRandomName" and type(data) == "string" then bat.ten = data end
				return postGoc2(self, data, ev)
			end
		end)
		pcall(fnTen, ctxGia(), true)
		bat.nam = bat.ten
		bat.ten = nil
		pcall(fnTen, ctxGia(), false)
		pcall(function () G_EventManager.PostLogicEvent = postGoc2 end)
		OfflineLog:info(string.format("THU ten ngau nhien: nam='%s', nu='%s'",
			tostring(bat.nam), tostring(bat.ten)))
		if type(bat.nam) ~= "string" or type(bat.ten) ~= "string" then
			OfflineLog:err("THU ten ngau nhien: KHONG sinh duoc ten (xem dong 'ten ngau nhien' ngay tren)")
		end
	else
		OfflineLog:err("THU ten ngau nhien: CHUA DANG KY G_GameWorld.ClientGetRandomName")
	end

	-- 25. BANG HỘI — lập một bang rồi đọc lại (mô hình một người).
	local fnTaoBang = OfflineRouter:getFor("G_GuildLogic", "ClientCreateGuild")
	local fnInfoBang = OfflineRouter:getFor("G_GuildLogic", "ClientGetGuildInfo")
	if fnTaoBang and fnInfoBang then
		local ok25 = pcall(fnTaoBang, ctxGia(), "1", "Bang Thu Offline", "Chao mung")
		local c25 = ctxGia()
		local ok25b = pcall(fnInfoBang, c25, 1, 10, 0)
		local ten, soTv, ma = "?", -1, "?"
		pcall(function ()
			local x = c25.calls and c25.calls[1]
			if x then
				ma = tostring(x.args[1])
				local info = x.args[2]
				if type(info) == "table" then
					ten = tostring(info.Name)
					if type(info.memberList) == "table" then soTv = #info.memberList end
				end
			end
		end)
		local idGD = "?"
		pcall(function ()
			local _, d = G_DataManager:GetUserDataWithName("GameUserGuildData")
			idGD = tostring(d and d.GuildId)
		end)
		OfflineLog:info(string.format(
			"THU bang hoi: tao=%s doc=%s, ten='%s', thanh vien=%s, ma=%s, GuildId trong du lieu=%s",
			tostring(ok25), tostring(ok25b), ten, tostring(soTv), ma, idGD))
		if soTv ~= 1 then
			OfflineLog:err("THU bang hoi: so thanh vien khac 1 — xem dong 'bang hoi' ngay tren")
		end
	else
		OfflineLog:err("THU bang hoi: CHUA DANG KY ClientCreateGuild/ClientGetGuildInfo cua G_GuildLogic")
	end

	-- 26. BXH QUÂN ĐOÀN — khoá `G_RankLogic.ClientGetGuildRank` (tab "Quân Đoàn" của
	-- `CUILeaderboard` từng báo THIEU và quay mãi). Bang đã lập ở mục 25 nên phải có 1 dòng.
	local fnBXH = OfflineRouter:getFor("G_RankLogic", "ClientGetGuildRank")
	if fnBXH then
		local c26 = ctxGia()
		local ok26 = pcall(fnBXH, c26, nil)
		local so26, ten26, hang26 = -1, "?", "?"
		pcall(function ()
			local x = c26.calls[#c26.calls]
			if x and x.f == "OnGetGuildRank" then
				hang26 = tostring(x.args[2])
				local ds = x.args[1]
				if type(ds) == "table" then
					so26 = 0
					for k, v in pairs(ds) do
						so26 = so26 + 1
						ten26 = tostring(v and v.GuildName)
					end
				end
			end
		end)
		OfflineLog:info(string.format(
			"THU BXH quan doan: ok=%s, %s dong, ten='%s', hang=%s",
			tostring(ok26), tostring(so26), ten26, hang26))
		if so26 ~= 1 then
			OfflineLog:err("THU BXH quan doan: so dong khac 1 — xem dong 'bang xep hang' ngay tren")
		end
	else
		OfflineLog:err("THU BXH quan doan: CHUA DANG KY G_RankLogic.ClientGetGuildRank")
	end

	-- 27. BẠN BÈ — gọi ĐƯỜNG THẬT (`G_FriendLogic:GetUserRelations()` → CallServer → router),
	-- rồi kiểm `tFriends` sau một nhịp. Đây là đường mà `CUIFriend2:onShow` dùng.
	if type(G_FriendLogic) == "table" and type(G_FriendLogic.GetUserRelations) == "function" then
		pcall(function () G_FriendLogic:GetUserRelations() end)
		local kiemBB = {}
		function kiemBB:chay()
			local mo, so = "?", -1
			pcall(function ()
				local t = G_FriendLogic.tFriends
				mo = type(t)
				if type(t) == "table" then
					so = 0
					for _ in pairs(t) do so = so + 1 end
				end
			end)
			OfflineLog:info(string.format("THU ban be (duong that): tFriends = %s, %s nhom quan he",
				mo, tostring(so)))
			if mo ~= "table" then
				OfflineLog:err("THU ban be: tFriends KHONG duoc dat — panel se quay mai")
			end
		end
		if S_CCSchedule then
			pcall(function () S_CCSchedule:scheduleOnce(kiemBB, "chay", 1) end)
		end
	else
		OfflineLog:err("THU ban be: khong thay G_FriendLogic:GetUserRelations")
	end

	-- 28. CÔNG THÀNH — gọi ĐƯỜNG THẬT (CallServer → router → ctx:call) để chắc rằng đuôi
	-- tham số có nil vẫn qua được tầng mạng (cjson/`denseArgs`), không chỉ qua ctx giả.
	if type(G_GuildWarLogic) == "table" then
		local okA = pcall(function () G_GuildWarLogic:CallQueryScore() end)
		local okB = pcall(function () G_GuildWarLogic:CallCheckCanChangeTeam() end)
		OfflineLog:info(string.format("THU cong thanh (duong that): QueryScore=%s, CheckCanChangeTeam=%s",
			tostring(okA), tostring(okB)))
	else
		OfflineLog:err("THU cong thanh: khong thay G_GuildWarLogic")
	end

	-- 29. COG (công thành xuyên máy chủ) — ĐƯỜNG THẬT: `g_COGProtocol` gọi qua `CallServer`
	-- → router → handler → trả lại `g_COGProtocol`. Đây là chỗ dễ sai NHẤT: obj GỬI là
	-- `G_COGProtocol` nhưng obj NHẬN phải là `g_COGProtocol` (chữ thường). Nếu trả nhầm
	-- thì bảng COG đứng im và log không có lỗi nào.
	if type(g_COGProtocol) == "table" then
		local okInfo = pcall(function () g_COGProtocol:CallGetCOGInfo() end)
		local okBrief = pcall(function () g_COGProtocol:CallGetBriefInfo() end)
		local okCity = pcall(function () g_COGProtocol:CallGetCityInfo(1) end)
		local kiemCOG = {}
		function kiemCOG:chay()
			local buoc, soThanh, chu, ma = "?", -1, "?", "?"
			pcall(function ()
				buoc = tostring(g_COGDataManager:GetStep())
				local ds = g_COGDataManager:GetCityList()
				if type(ds) == "table" then soThanh = #ds end
				local cd = g_COGDataManager:GetCityData(1)
				if cd then chu = tostring(cd.GuildID) end
			end)
			OfflineLog:info(string.format(
				"THU cog (duong that): goi info=%s brief=%s thanh=%s; Step=%s, so thanh=%s, GuildID thanh 1=%s",
				tostring(okInfo), tostring(okBrief), tostring(okCity), buoc, tostring(soThanh), chu))
			if buoc ~= "0" then
				OfflineLog:err("THU cog: Step KHAC 0 — phan hoi khong ve duoc g_COGProtocol?")
			end
			if soThanh < 1 then
				OfflineLog:err("THU cog: danh sach thanh RONG — thieu cau hinh GuildAttackCity?")
			end
		end
		if S_CCSchedule then
			pcall(function () S_CCSchedule:scheduleOnce(kiemCOG, "chay", 1) end)
		end
	else
		OfflineLog:err("THU cog: khong thay g_COGProtocol")
	end

	-- 30. BANG HỘI NÂNG CAO (2/11) — gọi handler với ctx GIẢ (như các mục 1–26) vì
	-- đường thật của điều tướng phụ thuộc panel đang mở (lớp tải khoá "CUIGuildDispatch").
	-- Đo: thuế công nghệ (trừ vàng thật + exp), xúc xắc (6 mặt vào GameUserLottery),
	-- điều tướng (vào MapDispatchHero), và cổng chặn "thu hồi trước 30 phút" (3517).
	do
		local gu = nil
		pcall(function ()
			local _, d = G_DataManager:GetUserDataWithName("GameUserGuildData")
			gu = d
		end)
		local gold0 = -1
		pcall(function () local _, g = G_UserLogic:GetGold(); gold0 = tonumber(g) or -1 end)

		local fnDonate = OfflineRouter:getFor("G_GuildLogic", "ClientDonateGuildTechnology")
		local fnDice = OfflineRouter:getFor("G_GuildLogic", "ClientPlayDiceGame")
		local fnDisp = OfflineRouter:getFor("G_GuildLogic", "ClientDispatchHero")

		local okDonate = false
		if fnDonate then okDonate = pcall(fnDonate, ctxGia(), "1", 1) end
		local okDice = false
		if fnDice then okDice = pcall(fnDice, ctxGia()) end

		local heroId = nil
		pcall(function ()
			local _, hs = G_DataManager:GetUserDataWithName("GameUserHero")
			for k, v in pairs(hs or {}) do
				local n = tonumber((type(v) == "table" and v.UserHeroID) or k)
				if n then
					local okH, bH, tH = pcall(function () return G_HeroLogic:GetHeroWithID(n) end)
					if okH and bH ~= false and type(tH) == "table" then
						local okC, laChu = pcall(function () return G_HeroLogic:IsCharacter(tH) end)
						if okC and laChu ~= true then heroId = n; break end
					end
				end
			end
		end)
		local okDisp = false
		if fnDisp and heroId and type(gu) == "table" then
			okDisp = pcall(fnDisp, ctxGia(), tonumber(gu.GuildId) or 0, heroId)
		end

		local gold1, expTech, soXucXac, soDieu = -1, "?", -1, -1
		pcall(function () local _, g = G_UserLogic:GetGold(); gold1 = tonumber(g) or -1 end)
		pcall(function ()
			local _, t = G_GuildLogic:GetUserGuildTechnology("1")
			expTech = tostring(t and t.Exp)
		end)
		pcall(function ()
			local _, lo = G_DataManager:GetUserDataWithName("GameUserLottery")
			if type(lo) == "table" and type(lo.DiceGameData) == "table" then
				soXucXac = #lo.DiceGameData
			end
		end)
		pcall(function ()
			if type(gu) == "table" and type(gu.MapDispatchHero) == "table" then
				soDieu = 0
				for _ in pairs(gu.MapDispatchHero) do soDieu = soDieu + 1 end
			end
		end)
		OfflineLog:info(string.format(
			"THU bang hoi nang cao: thue=%s (vang %s -> %s, exp=%s), xuc xac=%s (%s mat), dieu tuong=%s (hero %s, %s muc)",
			tostring(okDonate), tostring(gold0), tostring(gold1), tostring(expTech),
			tostring(okDice), tostring(soXucXac), tostring(okDisp), tostring(heroId), tostring(soDieu)))
		if not okDonate or gold1 >= gold0 then
			OfflineLog:err("THU bang hoi nang cao: thue cong nghe KHONG tru duoc vang")
		end
		if soXucXac ~= 6 then
			OfflineLog:err("THU bang hoi nang cao: xuc xac KHONG ghi 6 mat vao GameUserLottery")
		end
		if okDisp and heroId and soDieu < 1 then
			OfflineLog:err("THU bang hoi nang cao: dieu tuong KHONG vao MapDispatchHero")
		end
	end

	-- 31. PHÓ BẢN BANG HỘI (2/11) — máy trạng thái trên DỮ LIỆU THẬT. Ải `L_G_01_01`
	-- đòi đã qua `L_N_03_20` (bản lưu thử chưa qua), nên TẠM vá `CheckChapterIsPass`
	-- để đo phần CÒN LẠI (máu boss thật, trừ máu, chốt thưởng, bể rơi). Vá trả lại
	-- ngay sau lượt; bản lưu được phục hồi sau buổi thử nên số liệu không ở lại.
	do
		local gu = nil
		pcall(function ()
			local _, d = G_DataManager:GetUserDataWithName("GameUserGuildData")
			gu = d
		end)
		if type(gu) == "table" then gu.Resouce = math.max(tonumber(gu.Resouce) or 0, 10000) end

		local fnPassCu = nil
		pcall(function ()
			if G_ChapterLogic and type(G_ChapterLogic.CheckChapterIsPass) == "function" then
				fnPassCu = G_ChapterLogic.CheckChapterIsPass
				G_ChapterLogic.CheckChapterIsPass = function () return true, true end
			end
		end)

		local fnList = OfflineRouter:getFor("G_GuildChapterLogic", "ClientQueryGuildChapterListInfo")
		local fnOpen = OfflineRouter:getFor("G_GuildChapterLogic", "ClientOpenGuildChapter")
		local fnPre = OfflineRouter:getFor("G_GuildChapterLogic", "ClientPrepareGuildChapter")
		local fnBeg = OfflineRouter:getFor("G_GuildChapterLogic", "ClientGuildChapterFightBegin")
		local fnEnd = OfflineRouter:getFor("G_GuildChapterLogic", "ClientGuildChapterFightComplete")

		local okOpen, okPre, okBeg, okEnd = false, false, false, false
		local hpMax = 0
		if fnOpen then okOpen = pcall(fnOpen, ctxGia(), "L_G_01_01") end
		if fnPre then okPre = pcall(fnPre, ctxGia(), "L_G_01_01") end
		if fnBeg then okBeg = pcall(fnBeg, ctxGia(), { ChapterKey = "L_G_01_01" }) end

		local e = nil
		pcall(function ()
			local _, all = G_UserLogic:GetClientCommonData("OfflineGuildChapter")
			e = type(all) == "table" and all["L_G_01_01"] or nil
			hpMax = tonumber(e and e.BossMax) or 0
		end)

		-- Đánh đúng một đòn bằng TOÀN BỘ máu boss ⇒ chốt thưởng + roll bể rơi.
		if fnEnd and hpMax > 0 then
			okEnd = pcall(fnEnd, ctxGia(), "L_G_01_01", { ChapterData = { TotalHart = hpMax } })
		end

		local okList, soMo, bossCon, daQua, soBe = false, -1, -1, false, -1
		if fnList then
			local c = ctxGia()
			okList = pcall(fnList, c)
			pcall(function ()
				local x = c.calls[#c.calls]
				if x and type(x.args[3]) == "table" then soMo = #x.args[3] end
			end)
		end
		pcall(function ()
			bossCon = tonumber(e and e.BossHp) or -1
			daQua = (e and e.Passed) == true
			soBe = 0
			if e and type(e.Pool) == "table" then for _ in pairs(e.Pool) do soBe = soBe + 1 end end
		end)

		-- Trả lại hàm vừa vá.
		if fnPassCu ~= nil then
			pcall(function () G_ChapterLogic.CheckChapterIsPass = fnPassCu end)
		end

		OfflineLog:info(string.format(
			"THU pho ban bang: mo=%s chuanbi=%s vaotran=%s ketthuc=%s danhsach=%s (%s mo) — boss %s -> %s, daQua=%s, %s mon trong be rơi",
			tostring(okOpen), tostring(okPre), tostring(okBeg), tostring(okEnd), tostring(okList),
			tostring(soMo), tostring(hpMax), tostring(bossCon), tostring(daQua), tostring(soBe)))
		if not okOpen or not okPre or not okBeg or not okEnd then
			OfflineLog:err("THU pho ban bang: mot buoc trong may trang thai KHONG chay")
		end
		if hpMax > 0 and bossCon ~= 0 then
			OfflineLog:err("THU pho ban bang: mau boss KHONG ve 0")
		end
	end

	-- 32. ĐẤU TRƯỜNG ĐIỂM (APR, 2/11) — gọi handler với ctx giả trên DỮ LIỆU THẬT:
	-- 1000 robot từ `KDBScoreCompetitiveRobot` (luật sinh robot của share), đội phòng
	-- thủ từ tướng thật, và thưởng thăng bậc. Bốn khoá trận phải trả 5500.
	do
		local fnOpen = OfflineRouter:getFor("G_ScoreCompetitivePlayProtocol", "ClientGetOpenInfoReq")
		local fnPlay = OfflineRouter:getFor("G_ScoreCompetitivePlayProtocol", "ClientBeginPlayReq")
		local fnView = OfflineRouter:getFor("G_ScoreCompetitivePlayProtocol", "ClientViewPlayerReq")
		local fnDef = OfflineRouter:getFor("G_ScoreCompetitivePlayProtocol", "ClientAdjustDefTeamReq")
		local fnFight = OfflineRouter:getFor("G_ScoreCompetitivePlayProtocol", "ClientBeginFightReq")

		local state, soDoiThu, hang, soBXH, soDoi, maTran = "?", -1, -1, -1, -1, "?"
		if fnOpen then
			local c = ctxGia()
			pcall(fnOpen, c)
			pcall(function ()
				local x = c.calls[#c.calls]
				if x and x.f == "ClientGetOpenInfoRsp" then state = tostring(x.args[1]) end
			end)
		end
		if fnPlay then
			local c = ctxGia()
			pcall(fnPlay, c)
			pcall(function ()
				local x = c.calls[#c.calls]
				if x and x.f == "ClientBeginPlayRsp" then
					hang = tonumber(x.args[1] and x.args[1].SelfRank) or -1
					soBXH = #(x.args[1] and x.args[1].RankList or {})
				end
			end)
			pcall(function ()
				local _, d = G_DataManager:GetUserDataWithName("GameScoreCompetitivePlay")
				soDoiThu = #((d and d.challenge) or {})
			end)
		end
		if fnView then
			pcall(function ()
				local _, d = G_DataManager:GetUserDataWithName("GameScoreCompetitivePlay")
				local sid = d and d.challenge and d.challenge[1] and d.challenge[1].Id
				if sid ~= nil then
					local c = ctxGia()
					pcall(fnView, c, sid)
					local x = c.calls[#c.calls]
					if x and x.f == "ClientViewPlayerRsp" and type(x.args[1]) == "table" then
						soDoi = type(x.args[1].GameScoreCompetitivePlay) == "table"
							and #(x.args[1].GameScoreCompetitivePlay.defence or {}) or 0
					end
				end
			end)
		end
		if fnDef then
			pcall(function ()
				local _, hs = G_DataManager:GetUserDataWithName("GameUserHero")
				local ds = {}
				for k, v in pairs(hs or {}) do
					local id = tonumber((type(v) == "table" and v.UserHeroID) or k)
					if id then ds[#ds + 1] = { id }; if #ds >= 3 then break end end
				end
				if #ds > 0 then pcall(fnDef, ctxGia(), ds) end
			end)
		end
		if fnFight then
			local c = ctxGia()
			pcall(fnFight, c, { {} }, 1, "1_0")
			pcall(function ()
				local x = c.calls[#c.calls]
				if x and x.f == "ClientBeginFightRsp" then maTran = tostring(x.args[1]) end
			end)
		end

		OfflineLog:info(string.format(
			"THU dau truong diem: state=%s, %s doi thu, hang=%s, %s dong BXH, xem doi thu: %s doi phong thu, tran=%s",
			tostring(state), tostring(soDoiThu), tostring(hang), tostring(soBXH), tostring(soDoi), tostring(maTran)))
		if maTran ~= "5500" then
			OfflineLog:err("THU dau truong diem: khoa tran KHONG tra 5500")
		end
		if soDoiThu ~= 6 then
			OfflineLog:err("THU dau truong diem: challenge KHONG du 6 doi thu")
		end
	end

	-- 33. BXH CHẾ ĐỘ ẢI ĐẶC BIỆT (2/11) — 14 khoá `G_RankLogic`, một dòng của mình.
	do
		local ds = {
			{ "ClientGetTGZZRank", "OnGetTGZZRank", "level" },
			{ "ClientGetDKRank", "OnGetDKRank", "level" },
			{ "ClientGetHjrqRank", "OnGetHjrqRank", "wave" },
			{ "ClientGetSCSZLRank", "OnGetSCSZLRank", "killCount" },
			{ "ClientGetXZWCRank", "OnGetXZWCRank", "costTime" },
			{ "ClientGetGuildWarScoreRank", "OnGetGuildWarScoreRank", nil },
		}
		local dat, loi = 0, {}
		for _, m in ipairs(ds) do
			local fn = OfflineRouter:getFor("G_RankLogic", m[1])
			if fn == nil then
				loi[#loi + 1] = m[1] .. " (chua dang ky)"
			else
				local c = ctxGia()
				local ok = pcall(fn, c, "FB_E_X")
				local x = c.calls[#c.calls]
				local dung = ok and x ~= nil and x.f == m[2]
				local dong = 0
				if dung and type(x.args[1]) == "table" then
					for _, v in pairs(x.args[1]) do
						dong = dong + 1
						if m[3] ~= nil and v[m[3]] == nil then dung = false end
					end
				end
				if dung and dong ~= 1 then dung = false end
				if dung then dat = dat + 1 else loi[#loi + 1] = m[1] end
			end
		end
		OfflineLog:info(string.format("THU BXH che do: %d/%d khoa dung hinh%s", dat, #ds,
			#loi > 0 and (" — loi: " .. table.concat(loi, ", ")) or ""))
		if dat ~= #ds then
			OfflineLog:err("THU BXH che do: co khoa KHONG dung hinh")
		end
	end

	-- 34. CHẾ ĐỘ ẢI ĐẶC BIỆT (2/11) — 16 khoá `G_ChapterLogic`: đo phần KHÔNG cần
	-- vào trận (xem trước rơi, phe ĐK, hồi sinh, sóng HJRQ, cổng càn quét 1435).
	do
		local kq = {}
		local fnDrop = OfflineRouter:getFor("G_ChapterLogic", "ClientGetChapterDropData")
		if fnDrop then
			local c = ctxGia()
			pcall(fnDrop, c, "FB_E_HJRQ")
			pcall(function ()
				local x = c.calls[#c.calls]
				local dl = x and x.args[1] and x.args[1].DropList
				kq.roi = type(dl) == "table" and #(dl.Drop or {}) or -1
			end)
		end

		local fnFac = OfflineRouter:getFor("G_ChapterLogic", "ClientGetDKChapterFaction")
		if fnFac then
			local c = ctxGia()
			pcall(fnFac, c)
			pcall(function ()
				local x = c.calls[#c.calls]
				kq.phe = x and (tostring(x.args[2]) .. "/" .. tostring(type(x.args[3]))) or "?"
			end)
		end

		local fnSong = OfflineRouter:getFor("G_ChapterLogic", "ClientUserOverHJRQ")
		if fnSong then
			pcall(fnSong, ctxGia(), 5, "FB_E_HJRQ")
			pcall(function ()
				-- `GetStatisticsCommonData` trả HAI giá trị (bResult, value).
				local _, v = G_UserLogic:GetStatisticsCommonData("MaxHJRQBatchCount")
				kq.song = tostring(v)
			end)
		end

		-- Chưa qua ải ⇒ càn quét phải bị chặn bằng 1435 (đường OnReciveResponse).
		local fnSweep = OfflineRouter:getFor("G_ChapterLogic", "ClientChapterHJRQSweep")
		if fnSweep then
			local c = ctxGia()
			pcall(fnSweep, c, "FB_E_HJRQ")
			pcall(function ()
				local x = c.calls[#c.calls]
				kq.canquat = x and x.f == "OnReciveResponse" and tostring(x.args[3]) or "?"
			end)
		end

		-- Hồi sinh: trừ kim cương thật theo `GetChapterReviveCost`.
		local fnRevive = OfflineRouter:getFor("G_ChapterLogic", "ClientReviveInBattle")
		if fnRevive then
			pcall(function ()
				local _, truoc = G_UserLogic:GetDiamond()
				pcall(fnRevive, ctxGia())
				local _, sau = G_UserLogic:GetDiamond()
				kq.hoisinh = tostring(truoc) .. " -> " .. tostring(sau)
			end)
		end

		OfflineLog:info(string.format(
			"THU ai dac biet: roi=%s mon, phe=%s, song=%s, can quet=%s, hoi sinh=%s",
			tostring(kq.roi), tostring(kq.phe), tostring(kq.song), tostring(kq.canquat),
			tostring(kq.hoisinh)))
		if kq.canquat ~= "1435" then
			OfflineLog:err("THU ai dac biet: can quet chua qua ai KHONG tra 1435")
		end
	end

	-- 35. ẢI VÔ TẬN (2/11) — 9 khoá `G_EndlessChapterLogic` trên DỮ LIỆU THẬT:
	-- vào trận → kết thúc (thưởng tầng) → sang tầng; quét 2 tầng; đặt lại.
	do
		local fnFight = OfflineRouter:getFor("G_EndlessChapterLogic", "ClientFight")
		local fnEnd = OfflineRouter:getFor("G_EndlessChapterLogic", "ClientCompeleteFight")
		local fnNext = OfflineRouter:getFor("G_EndlessChapterLogic", "ClientGotoNextProsees")
		local fnSwap = OfflineRouter:getFor("G_EndlessChapterLogic", "ClientSwap")
		local fnStop = OfflineRouter:getFor("G_EndlessChapterLogic", "ClientStopSwap")
		local fnReset = OfflineRouter:getFor("G_EndlessChapterLogic", "ClientResetEndlessChapter")

		local okFight, okEnd, okNext, okSwap, okStop, okReset = false, false, false, false, false, false
		local cap0, cap1, cap2, soThuong = "?", "?", "?", -1
		if fnFight then
			local c = ctxGia()
			okFight = pcall(fnFight, c, { 25 }, nil)
			pcall(function ()
				local x = c.calls[1]
				if x and x.f == "OnFight" then cap0 = tostring(x.args[1] and #x.args[1]) end
			end)
		end
		if fnEnd then
			okEnd = pcall(fnEnd, ctxGia(), { IsDestroyAllEnemy = true })
		end
		if fnNext then
			local c = ctxGia()
			okNext = pcall(fnNext, c)
			pcall(function ()
				local _, d = G_EndlessChapterLogic:GetUserEndlessChapterData()
				cap1 = tostring(d.CurrentProsess)
				d.CurrentProsess = 2
				d.BestProsees = 4
				G_EndlessChapterLogic:setUserEndlessChapter(d)
			end)
		end
		if fnSwap then okSwap = pcall(fnSwap, ctxGia()) end
		if fnStop then
			pcall(function ()
				local _, d = G_EndlessChapterLogic:GetUserEndlessChapterData()
				d.SwapBeginTime = os.time() - 130      -- 2 tầng × 60 giây
				G_EndlessChapterLogic:setUserEndlessChapter(d)
			end)
			local c = ctxGia()
			okStop = pcall(fnStop, c)
			pcall(function ()
				local x = c.calls[1]
				if x and x.f == "OnStopSwap" then soThuong = #(x.args[1] or {}) end
				local _, d = G_EndlessChapterLogic:GetUserEndlessChapterData()
				cap2 = tostring(d.CurrentProsess)
			end)
		end
		if fnReset then okReset = pcall(fnReset, ctxGia()) end

		OfflineLog:info(string.format(
			"THU ai vo tan: vao=%s(%s tuong) ketthuc=%s sangtang=%s(%s) quet=%s/%s (%s tang, %s mon) datlai=%s",
			tostring(okFight), tostring(cap0), tostring(okEnd), tostring(okNext), tostring(cap1),
			tostring(okSwap), tostring(okStop), tostring(soThuong), tostring(cap2), tostring(okReset)))
		if not okFight or not okEnd or not okNext or not okSwap or not okStop or not okReset then
			OfflineLog:err("THU ai vo tan: mot buoc KHONG chay")
		end
		if tonumber(soThuong) ~= 2 then
			OfflineLog:err("THU ai vo tan: quet 130 giay KHONG ra 2 tang thuong")
		end
	end

	-- 36. CHIẾN DỊCH ANH HÙNG (2/11) — 5 khoá `G_EpicChapterLogic`:
	-- chọn phe hôm nay → thắng một ải → quét danh vọng → shop EpicCoin → đặt lại ngày.
	do
		local camp = nil
		for c = 1, 4 do
			local ok, mo = pcall(function () return G_ConfigManager:IsEpicOpen(c) end)
			if ok and mo == true then camp = c; break end
		end
		local kq = { camp = tostring(camp) }
		if camp ~= nil then
			local fnSel = OfflineRouter:getFor("G_EpicChapterLogic", "ClientSetTodayChapterDifficult")
			if fnSel then
				local c = ctxGia()
				pcall(fnSel, c, camp, 1)
				pcall(function ()
					local x = c.calls[1]
					kq.chon = x and tostring(x.args[1]) or "?"
				end)
			end

			local cfg = nil
			pcall(function () cfg = G_ConfigManager:GetEpicChapterConfigV2(camp, 1, 1) end)
			local chapterID = cfg and cfg.ChapterID
			local fnEnd = OfflineRouter:getFor("G_EpicChapterLogic", "ClientEpicChapterCompeleteFight")
			if fnEnd and chapterID then
				local c = ctxGia()
				-- CHỮ KÝ THẬT: (bComplete, chapterID, heroList, employHero).
				pcall(fnEnd, c, true, chapterID, { 25 }, nil)
				pcall(function ()
					local x = c.calls[1]
					kq.thang = x and x.f == "OnEpicChapterCompeleteFight"
						and tostring(x.args[1].IsWin) or "?"
					local okD, bD, d = pcall(function ()
						return G_DataManager:GetUserDataWithName("GameUserEpicChapter")
					end)
					local t = (okD and d) or {}
					kq.tang = tostring(t.TodayMaxPassedLevel)
					kq.danhvong = tostring(t.Prestige and t.Prestige[tostring(camp)]
						and t.Prestige[tostring(camp)].Exp)
				end)
			end

			local fnSweep = OfflineRouter:getFor("G_EpicChapterLogic", "ClientSweepEpicChapter")
			if fnSweep then
				local c = ctxGia()
				pcall(fnSweep, c, camp, 1)
				pcall(function ()
					local x = c.calls[1]
					local n = 0
					if x and x.f == "OnSweepEpicChapter" then
						for _ in pairs(x.args[1] or {}) do n = n + 1 end
					end
					kq.quet = tostring(n)
				end)
			end

			local fnShop = OfflineRouter:getFor("G_EpicChapterLogic", "ClientBuyEpicGoods")
			if fnShop then
				pcall(function ()
					local okD, bD, d = pcall(function ()
						return G_DataManager:GetUserDataWithName("GameUserEpicChapter")
					end)
					if okD and type(d) == "table" then
						d.EpicCoin = 20000
						G_DataManager:ChangeUserData("GameUserEpicChapter",
							{ EpicCoin = 20000 }, "Table_Add")
					end
					pcall(fnShop, ctxGia(), 1)
					kq.coin = tostring(d and d.EpicCoin)
				end)
			end

			local fnReset = OfflineRouter:getFor("G_EpicChapterLogic", "ClientEpicResetDaily")
			if fnReset then
				local c = ctxGia()
				pcall(fnReset, c)
				pcall(function ()
					local x = c.calls[1]
					kq.datlai = x and x.f or "?"
				end)
			end
		end

		OfflineLog:info(string.format(
			"THU epic: phe=%s, chon=%s, thang=%s (tang %s, danh vong %s), quet=%s tang, coin=%s, datlai=%s",
			tostring(kq.camp), tostring(kq.chon), tostring(kq.thang), tostring(kq.tang),
			tostring(kq.danhvong), tostring(kq.quet), tostring(kq.coin), tostring(kq.datlai)))
		if kq.chon ~= "0" and kq.camp ~= "nil" then
			OfflineLog:err("THU epic: chon phe KHONG tra 0")
		end
	end

	-- 37. NĂM KHOÁ TOÀN CỤC CÒN SỐNG (2/11): thoại (3902), đánh dấu trang bị,
	-- đội hình đấu trường, liên kết tài khoản (nuốt lặng), về nhà.
	do
		local kq = {}
		local c = ctxGia()
		local fnNoi = OfflineRouter:getFor("", "ClientGetSpeechContent")
		if fnNoi then
			pcall(fnNoi, c, 1)
			pcall(function ()
				local x = c.calls[1]
				kq.thoai = x and x.f == "OnGetSpeechContent" and tostring(x.args[1]) or "?"
			end)
		end
		local fnXem = OfflineRouter:getFor("", "ClientCheckNewEquipment")
		if fnXem then kq.trangbi = tostring(pcall(fnXem, ctxGia(), 1)) end

		local fnHero = OfflineRouter:getFor("G_ArenaLogic", "ClientSetArenaHero")
		if fnHero then
			local c2 = ctxGia()
			pcall(fnHero, c2, { 25 })
			pcall(function ()
				local x = c2.calls[1]
				kq.doidh = x and x.f == "OnSetArenaHero" and tostring(#x.args[1]) or "?"
			end)
		end

		local fnLink = OfflineRouter:getFor("G_Login", "ClientBindingAccount")
		if fnLink then kq.lienket = tostring(pcall(fnLink, ctxGia(), "u", "p", "o", 1)) end

		local fnHome = OfflineRouter:getFor("", "ClientReturnHome")
		if fnHome then
			local c3 = ctxGia()
			kq.venha = tostring(pcall(fnHome, c3))
			pcall(function ()
				local x = c3.calls[1]
				if x then kq.venhaGoi = x.f end
			end)
		end

		OfflineLog:info(string.format(
			"THU toan cuc con song: thoai=%s, trangbi=%s, doihinh=%s, lienket=%s, venha=%s/%s",
			tostring(kq.thoai), tostring(kq.trangbi), tostring(kq.doidh), tostring(kq.lienket),
			tostring(kq.venha), tostring(kq.venhaGoi)))
		if kq.thoai ~= "3902" then
			OfflineLog:err("THU toan cuc con song: thoai KHONG tra 3902")
		end
	end

	-- 38. LỚP CHẮN CUỐI (2/11) — 100 khoá SỐNG còn lại: mỗi nhóm trả mã GỐC và
	-- dừng lớp tải. Mẫu 5 nhóm.
	do
		local DS = {
			{ 'G_TournamentLogic', 'ClientGetContestInfo', 4401 },
			{ 'G_WCSProtocol', 'ClientGetWCSInfo', 5201 },
			{ 'G_ActivityRankLogic', 'ClientGetTop3Payment', 4001 },
			{ 'G_MagicWeaponTreasureBox', 'ClientOpenBoxWithKey', 5002 },
			{ 'G_CloudShopLogic', 'ClientChangeCloudShopStatus', 1 },
		}
		local dat, loi = 0, {}
		for _, m in ipairs(DS) do
			local fn = OfflineRouter:getFor(m[1], m[2])
			if fn == nil then
				loi[#loi + 1] = m[1] .. '.' .. m[2] .. ' (chua dang ky)'
			else
				local c = ctxGia()
				pcall(fn, c)
				local x = c.calls[1]
				if x and x.f == "OnReciveResponse" and tonumber(x.args[3]) == m[3] then
					dat = dat + 1
				else
					loi[#loi + 1] = m[1] .. '.' .. m[2] .. ' (ma ' .. tostring(x and x.args[3]) .. ')'
				end
			end
		end
		OfflineLog:info(string.format("THU lop chan cuoi: %d/%d nhom dung ma goc%s",
			dat, #DS, #loi > 0 and (" — loi: " .. table.concat(loi, ", ")) or ""))
		if dat ~= #DS then
			OfflineLog:err("THU lop chan cuoi: co nhom KHONG dung ma")
		end
	end

	-- 39. THẦN BINH (2/11) — 4 khoá THẬT: lên/giáng sao và cường hoá trên dữ liệu thật.
	do
		local fnUp = OfflineRouter:getFor("G_MagicWeaponProtocol", "ClientStarUp")
		local fnDown = OfflineRouter:getFor("G_MagicWeaponProtocol", "ClientStarDown")
		local fnStr = OfflineRouter:getFor("G_MagicWeaponProtocol", "ClientStrengthen")
		local kq = {}

		-- Chọn một món nguyên liệu cường hoá mà bản lưu CÓ.
		local idMon, expMon = nil, 0
		pcall(function ()
			local cfg = G_ConfigManager:GetCommonConfigWithName("GameMagicWeaponItemExpConfig")
			for k, v in pairs(cfg or {}) do
				local id = tonumber(k)
				local _, n = G_ItemLogic:GetItemCount(id)
				if id and tonumber(n) and tonumber(n) > 0 and tonumber(v.Exp) and tonumber(v.Exp) > 0 then
					idMon, expMon = id, tonumber(v.Exp)
					break
				end
			end
		end)

		if fnUp then
			local ok, saoTruoc, ma
			pcall(function ()
				saoTruoc = tonumber(G_MagicWeaponLogic:GetEquipmentStarLevel(25, 7)) or 0
			end)
			local c = ctxGia()
			ok = pcall(fnUp, c, { heroId = 25, equipmentType = 7 })
			pcall(function ()
				local x = c.calls[1]
				ma = (x and x.f == "OnReciveResponse") and x.args[3] or 0
				local saoSau = tonumber(G_MagicWeaponLogic:GetEquipmentStarLevel(25, 7)) or 0
				kq.sao = tostring(saoTruoc) .. "->" .. tostring(saoSau) .. " (ma " .. tostring(ma) .. ")"
			end)
			if fnDown and tonumber(ma) == 0 then
				pcall(fnDown, ctxGia(), { heroId = 25, equipmentType = 7 })
			end
		end

		if fnStr and idMon ~= nil then
			local ok, c = pcall(fnStr, ctxGia(), { heroId = 25, equipmentType = 7,
				costItem = { { id = idMon, count = 1 } } })
			local exp = "?"
			pcall(function ()
				local _, d = G_DataManager:GetUserDataWithName("GameMagicWeapon")
				local e = d and d.STRENGTHEN and d.STRENGTHEN["25"] and d.STRENGTHEN["25"]["7"]
				exp = tostring(e and e.exp)
			end)
			kq.cuonghoa = tostring(ok) .. "/" .. tostring(idMon) .. " (exp " .. tostring(exp) .. ")"
		else
			kq.cuonghoa = "bo qua (khong co nguyen lieu)"
		end

		OfflineLog:info(string.format("THU than binh: sao=%s, cuong hoa=%s",
			tostring(kq.sao), tostring(kq.cuonghoa)))
	end

	-- 40. DOANH TRẠI BANG HỘI (2/11) — 8 khoá `G_GuildCampLogic` (mô hình một người).
	do
		local fnEnter = OfflineRouter:getFor("G_GuildCampLogic", "ClientEnterGuildCamp")
		local fnData = OfflineRouter:getFor("G_GuildCampLogic", "ClientGetGuildCampData")
		local fnWater = OfflineRouter:getFor("G_GuildCampLogic", "ClientWaterTree")
		local fnFire = OfflineRouter:getFor("G_GuildCampLogic", "ClientFirewood")
		local kq = {}

		if fnEnter then
			local c = ctxGia()
			pcall(fnEnter, c, {})
			pcall(function ()
				local x = c.calls[1]
				kq.vao = x and x.f == "OnEnterGuildCamp" and tostring(x.args[1]) or "?"
			end)
		end
		if fnData then
			local c = ctxGia()
			pcall(fnData, c)
			pcall(function ()
				local x = c.calls[1]
				local d = x and x.args[2]
				kq.cay = d and tostring(d.CampData and d.CampData.Tree and d.CampData.Tree.GrowUpStateCount) or "?"
			end)
		end
		if fnWater then
			local c = ctxGia()
			pcall(fnWater, c)
			pcall(function ()
				local x = c.calls[1]
				kq.tuoi = x and (x.f == "OnSelfWaterTree" and ("ma " .. tostring(x.args[1]))
					or (x.f == "OnReciveResponse" and ("ma " .. tostring(x.args[3])))) or "?"
			end)
		end
		if fnFire then
			pcall(fnFire, ctxGia())
			local gu = nil
			pcall(function () local _, d = G_DataManager:GetUserDataWithName("GameUserGuildData"); gu = d end)
			kq.cui = gu and tostring(gu.UserFireWoodCount) or "?"
		end

		OfflineLog:info(string.format(
			"THU doanh trai: vao=%s, cay=%s, tuoi=%s, cui=%s (gio server %s)",
			tostring(kq.vao), tostring(kq.cay), tostring(kq.tuoi), tostring(kq.cui),
			tostring(os.date("%H:%M"))))
		if kq.vao ~= "0" and kq.vao ~= "3501" then
			OfflineLog:err("THU doanh trai: vao KHONG dung ma")
		end
	end

	-- 41. ĐẤU TRƯỜNG PHẦN CÒN (2/11) — 4 khoá: làm mới bằng danh vọng, tướng trên
	-- bảng hạng, đánh dấu chiến báo, tên cũ chi tiết đối thủ.
	do
		local kq = {}
		pcall(function ()
			local _, u = G_ArenaDataManager:GetUserArena()
			if type(u) == "table" then
				u.UserHonnor = math.max(tonumber(u.UserHonnor) or 0, 500)
				u.RefreshGoodsCount = 0
			end
		end)
		local fnHonor = OfflineRouter:getFor("G_ArenaLogic", "ClientRefreshArenaGoodsWithHonor")
		if fnHonor then
			local c = ctxGia()
			pcall(fnHonor, c)
			pcall(function ()
				local x = c.calls[1]
				if x and x.f == "OnRefreshArenaGoodsWithHonor" then
					kq.hang = tostring(#(x.args[1] or {}))
				else
					kq.hang = "ma " .. tostring(x and x.args[3])
				end
				local _, u = G_ArenaDataManager:GetUserArena()
				kq.danhvong = tostring(u and u.UserHonnor)
			end)
		end
		local fnHero = OfflineRouter:getFor("G_ArenaLogic", "ClientGetArenaHeroInfo")
		if fnHero then
			local c = ctxGia()
			pcall(fnHero, c, 1, 25)
			pcall(function ()
				local x = c.calls[1]
				kq.tuong = (x and x.f == "OnGetArenaHeroInfo"
					and tostring(x.args[1] and x.args[1].HeroData and x.args[1].HeroData.UserHeroID))
					or ("ma " .. tostring(x and x.args[3]))
			end)
		end
		OfflineLog:info(string.format("THU dau truong (con): lam moi=%s mon (danh vong %s), tuong=%s",
			tostring(kq.hang), tostring(kq.danhvong), tostring(kq.tuong)))
	end

	OfflineLog:info("THU ===== het tu kiem =====")
end

function OfflineThuNhomMoi:tick()
	if self.DA_CHAY or self.TAT then return end
	self.DEM = self.DEM + 1
	if self.DEM < self.CHO then return end
	if not (Offline and Offline.LAN_VAO_GAME and Offline.LAN_VAO_GAME > 0) then
		return
	end
	self.DA_CHAY = true
	local ok, err = pcall(function () self:chay() end)
	if not ok then
		OfflineLog:err("THU: tum lum loi: " .. tostring(err))
	end
end

function OfflineThuNhomMoi:batDau()
	if not coTepCo() then
		return
	end
	OfflineLog:info("THU: thay tep co " .. self.TEP_CO .. " — se tu kiem sau khi vao Main")
	if S_CCSchedule == nil then
		OfflineLog:err("THU: khong co S_CCSchedule")
		return
	end
	pcall(function () S_CCSchedule:schedule(self, "tick", 1) end)
end

return OfflineThuNhomMoi
