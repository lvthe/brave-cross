--[[
	offline/handlers/tinh_hon.lua — TINH HỒN / 星魂 (`G_StarSoulProtocol`, 13 khoá).

	VÌ SAO CÓ TỆP NÀY — đo được TRONG GAME 31/10: mở panel Chiêm Tinh thì logcat
	ghi `THIEU G_StarSoulProtocol.ClientGetReq`; không có phản hồi nên
	`g_XingHunData._isServerInited` KHÔNG BAO GIỜ thành true (`CUIXingHun.lua:494`
	đặt nó trong `ClientGetRsp`), mà `CUIXiangQian:init` thoát ngay ở
	`if KDebug.ProcessError(getIsServerInited())` — panel mở ra NỬA VỜI, im lặng.

	TÊN CALLBACK SINH LÚC CHẠY, không có trong `api.lua`: `XingHunData.lua:159`
	gọi `CUIAssist.bindRpcToEvent(..., "G_StarSoulProtocol", XingHun,
	"Client%sReq", "Client%sRsp")` ⇒ mỗi yêu cầu `Client<X>Req` có phản hồi
	`Client<X>Rsp` là PHƯƠNG THỨC trên thực thể `g_StarSoulProtocol`
	(`XingHunData.lua:161`), nhận ĐÚNG MỘT tham số.

	PHÂN LOẠI — khai rõ khoá nào làm thật, khoá nào chưa:
	  · **1 khoá ĐỌC**: `ClientGetReq` → dữ liệu THẬT của người chơi.
	  · **6 khoá LÀM THẬT**: sắp kho · bán một · bán hết · khảm · tháo · CHIÊM BỐC
	    đơn. Mọi con số lấy từ cấu hình THẬT (`StarSoulStaticConf.price`,
	    `StarSoulDivineConf.price`, `StarSoulDivineChanceConf`); lớp offline không
	    đặt giá nào.
	  · **6 khoá CHƯA LÀM** → **5400 `StarSoul.Closed`**, mỗi khoá một lý do đo
	    được (xem bảng `CHUA_LAM` bên dưới). Không gộp lý do.

	DỮ LIỆU là CHÍNH bảng `GameUserStarSoul` trong `G_DataManager`
	(`StarSoulDataManager:GetUserStarSoulData` trả đúng bảng ấy), nên sửa tại chỗ
	rồi `syncFromClient()` là UI thấy ngay. Hình bảng:
	    pack[i]            = { star_soul_id, level, exp }
	    career[career_id]  = { [cell_id] = { … } }      -- `career` có ĐÚNG 5 phần tử
	(`InitData`, `share_StarSoulDataManager.lua:52-57`).

	`GameUserStarSoul` phải VẮNG MẶT lúc khởi động (thêm vào `OfflineStore.TU_DUNG`):
	`GetUserStarSoulData` chỉ tự lành khi bảng là **nil**, KHÔNG lành khi `{}`
	(`:76-95`) — mà `initUserDataFromDB` trả `{}` cho bảng không thuộc `TU_DUNG`.
]]

require("offline.log")
require("offline.store")
require("offline.router")

local R = OfflineRouter
local TEN_FILE = "tinh hon"
local MA_DONG = 5400        -- ErrorCode.StarSoul.Closed
local MA_ARG = 2            -- ErrorCode.System.ParamError
local MA_PACK_FULL = 5403   -- ErrorCode.StarSoul.PackFull

--[[ SÁU khoá CHƯA LÀM ĐƯỢC — mỗi khoá một lý do ĐO ĐƯỢC, không gộp. ]]
local CHUA_LAM = {
	["ClientBatchDivineReq"]   = "batch lay MinGold/nTimes tu bang khac chua do (CUIZhanXing.lua:150-157)",
	["ClientConjureZiwenReq"]  = "khong doi so; luat trieu hoan Tu Vi chi co helper doc/ghi, khong co cong thuc",
	["ClientBuyPackReq"]       = "khong co bang gia mua o (StaticConf chi co gia BAN cua tung hon)",
	["ClientBatchUpgradeReq"]  = "khong doi so => may chu phai tu chon cap nao gop voi cap nao",
}

-- LuaJIT dùng ngữ nghĩa Lua 5.1: biến vòng lặp là MỘT biến, closure giữ nó ⇒
-- phải chép ra biến cục bộ của từng lượt, nếu không mọi handler cùng trỏ tới
-- tên cuối cùng.
for ten, viSao in pairs(CHUA_LAM) do
	local tenReq, lyDo = ten, viSao
	R:on("G_StarSoulProtocol." .. tenReq, function (ctx)
		OfflineLog:info(string.format("%s: %s -> %d (%s)", TEN_FILE, tenReq, MA_DONG, lyDo))
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", MA_DONG, {})
	end)
end

------------------------------------------------------------------ tiện ích chung

local function dong(ctx, tenReq, viSao)
	OfflineLog:info(string.format("%s: %s -> %d (%s)", TEN_FILE, tenReq, MA_DONG,
		tostring(viSao)))
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", MA_DONG, {})
end

local function loiThamSo(ctx, tenReq, viSao)
	OfflineLog:info(string.format("%s: %s -> %d (%s)", TEN_FILE, tenReq, MA_ARG, tostring(viSao)))
	ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", MA_ARG, {})
end

local function layDuLieu()
	if type(_G.G_StarSoulDataManager) ~= "table" then return nil end
	local ok, _, d = pcall(function () return G_StarSoulDataManager:GetUserStarSoulData() end)
	if not ok or type(d) ~= "table" then return nil end
	d.pack = d.pack or {}
	d.career = d.career or { {}, {}, {}, {}, {} }
	return d
end

local function tra(ctx, tenRsp)
	pcall(function () OfflineStore:syncFromClient() end)
	ctx:call("g_StarSoulProtocol", tenRsp)
end

--[[ ĐI QUA MỌI DÒNG CẤU HÌNH, chịu được CẢ HAI hình mà config manager trả về.

	ĐO TRONG GAME 31/10: `StarSoulDivineChanceConf` KHÔNG phải mảng — `updateStarSoul
	DivineChanceConf` (`share_configManager.lua:4196+`) đánh lại thành **bản đồ
	LỒNG** `[divine_id][quality] = dòng`, còn `updateStarSoulStaticConf` đánh lại
	theo **`star_soul_str_id`** (chuỗi). `ipairs` trên bản đồ trả RỖNG, nên bản
	đầu tiên của handler báo nhầm "thieu bang ti le cho loai 1" dù bảng có đủ.

	`fn(dong, khoa)` được gọi cho mỗi bảng CON có trường nhận dạng (`id`,
	`quality`, `divine_id` hoặc `chance`) — lồng tối đa ba tầng là đủ cho cả ba
	bảng của hệ này. ]]
local function quet(ds, fn, sau)
	local dem = (sau or 0) + 1
	if dem > 4 or type(ds) ~= "table" then return end
	for k, v in pairs(ds) do
		if type(v) == "table" then
			if v.id ~= nil or v.quality ~= nil or v.divine_id ~= nil or v.chance ~= nil
				or v.star_soul_id ~= nil then
				fn(v, k)
			else
				quet(v, fn, dem)
			end
		end
	end
end

--[[ Một dòng `StarSoulStaticConf` theo id (khoá có thể là chuỗi `"1001"`). ]]
local function cauHinhHon(nId)
	local ds = nil
	pcall(function ()
		ds = G_ConfigManager:GetConfigWithNameArg(G_ConfigManager.configCacheName.StarSoulStaticConf)
	end)
	if type(ds) ~= "table" then return nil end
	if ds[nId] ~= nil then return ds[nId] end
	if ds[tostring(nId)] ~= nil then return ds[tostring(nId)] end
	local tim = nil
	quet(ds, function (r, k)
		if tim == nil and (tonumber(r.id) == tonumber(nId) or tonumber(k) == tonumber(nId)) then
			tim = r
		end
	end)
	return tim
end

--------------------------------------------------------------- 1. SẮP KHO
--[[ Chất lượng GIẢM DẦN → cấp → exp; hoà thì `star_soul_id` nhỏ trước (thứ tự
	tất định, không phụ thuộc `pairs`). ]]
R:on("G_StarSoulProtocol.ClientSortPackReq", function (ctx)
	local d = layDuLieu()
	if d == nil then return dong(ctx, "ClientSortPackReq", "khong doc duoc du lieu") end

	local function chatLuong(x)
		local c = cauHinhHon(x.star_soul_id)
		return tonumber(c and c.quality) or 0
	end
	table.sort(d.pack, function (a, b)
		local qa, qb = chatLuong(a), chatLuong(b)
		if qa ~= qb then return qa > qb end
		local la, lb = tonumber(a.level) or 0, tonumber(b.level) or 0
		if la ~= lb then return la > lb end
		local ea, eb = tonumber(a.exp) or 0, tonumber(b.exp) or 0
		if ea ~= eb then return ea > eb end
		return (tonumber(a.star_soul_id) or 0) < (tonumber(b.star_soul_id) or 0)
	end)

	OfflineLog:info(string.format("%s: sap kho %d mon", TEN_FILE, #d.pack))
	tra(ctx, "ClientSortPackRsp")
end)

--------------------------------------------------------------- 2. BÁN MỘT
--[[ `ClientSellReq(index, star_soul_id)` (`CUIXingHunItem.lua:384`). Giá = `price`. ]]
R:on("G_StarSoulProtocol.ClientSellReq", function (ctx, nIndex, nId)
	local d = layDuLieu()
	if d == nil then return dong(ctx, "ClientSellReq", "khong doc duoc du lieu") end
	local i = tonumber(nIndex)
	local mon = i and d.pack[i]
	if type(mon) ~= "table" then
		return dong(ctx, "ClientSellReq", "khong co mon o vi tri " .. tostring(nIndex))
	end
	if nId ~= nil and tonumber(nId) ~= tonumber(mon.star_soul_id) then
		return dong(ctx, "ClientSellReq", "vi tri khong dung mon")
	end
	local c = cauHinhHon(mon.star_soul_id)
	local gia = tonumber(c and c.price) or 0
	if gia <= 0 then
		return dong(ctx, "ClientSellReq", "mon nay khong ban duoc (price=0)")
	end

	table.remove(d.pack, i)
	pcall(function () G_UserLogic:AddGold(gia, "StarSoulSell") end)
	OfflineLog:info(string.format("%s: ban 1 mon (id %s) duoc %d vang",
		TEN_FILE, tostring(mon.star_soul_id), gia))
	tra(ctx, "ClientSellRsp")
end)

--------------------------------------------------------------- 3. BÁN HẾT
--[[ `ClientBatchSellReq()` — nút "bán hết" (`CUIXingHun.lua:176`) đã tự cộng giá để
	bật/tắt nút, nên lớp offline làm đúng nghĩa cái nút: bán MỌI món bán được.
	`[MOI]` món `price = 0` được GIỮ LẠI (bán nó là mất đồ mà không được gì). ]]
R:on("G_StarSoulProtocol.ClientBatchSellReq", function (ctx)
	local d = layDuLieu()
	if d == nil then return dong(ctx, "ClientBatchSellReq", "khong doc duoc du lieu") end

	local giu, tong, soMon = {}, 0, 0
	for _, mon in ipairs(d.pack) do
		local c = cauHinhHon(mon.star_soul_id)
		local gia = tonumber(c and c.price) or 0
		if gia > 0 then
			tong = tong + gia
			soMon = soMon + 1
		else
			giu[#giu + 1] = mon
		end
	end
	if soMon == 0 then
		return dong(ctx, "ClientBatchSellReq", "khong co mon nao ban duoc")
	end

	d.pack = giu
	pcall(function () G_UserLogic:AddGold(tong, "StarSoulBatchSell") end)
	OfflineLog:info(string.format("%s: ban het %d mon, duoc %d vang", TEN_FILE, soMon, tong))
	tra(ctx, "ClientBatchSellRsp")
end)

--------------------------------------------------------------- 4. KHẢM
--[[ Mỗi mục `{career_id, cell_id, pack_item = {pack_idx, star_soul_id, level, exp}}`
	(`CUIXingHunItem.lua:351-356`). Ô đang có món thì món CŨ về kho — không mất đồ. ]]
R:on("G_StarSoulProtocol.ClientMountReq", function (ctx, tDanhSach)
	if type(tDanhSach) ~= "table" or #tDanhSach == 0 then
		return loiThamSo(ctx, "ClientMountReq", "danh sach rong")
	end
	local d = layDuLieu()
	if d == nil then return dong(ctx, "ClientMountReq", "khong doc duoc du lieu") end

	local nKham = 0
	for _, muc in ipairs(tDanhSach) do
		local cid = tonumber(type(muc) == "table" and muc.career_id)
		local cell = tonumber(type(muc) == "table" and muc.cell_id)
		local pi = tonumber(type(muc) == "table" and muc.pack_item and muc.pack_item.pack_idx)
		local mon = pi and d.pack[pi]
		if cid ~= nil and cell ~= nil and type(mon) == "table" and d.career[cid] ~= nil then
			local cu = d.career[cid][cell]
			table.remove(d.pack, pi)
			d.career[cid][cell] = mon
			if type(cu) == "table" then d.pack[#d.pack + 1] = cu end
			nKham = nKham + 1
		else
			OfflineLog:warn(string.format("%s: bo qua muc kham (career=%s, cell=%s, idx=%s)",
				TEN_FILE, tostring(cid), tostring(cell), tostring(pi)))
		end
	end

	if nKham == 0 then return dong(ctx, "ClientMountReq", "khong muc nao kham duoc") end
	OfflineLog:info(string.format("%s: kham %d mon", TEN_FILE, nKham))
	tra(ctx, "ClientMountRsp")
end)

--------------------------------------------------------------- 5. THÁO
--[[ Mỗi mục `{career_id, cell_id}` (`CUIXiangQian.lua:120-154`). ]]
R:on("G_StarSoulProtocol.ClientDemountReq", function (ctx, tDanhSach)
	if type(tDanhSach) ~= "table" or #tDanhSach == 0 then
		return loiThamSo(ctx, "ClientDemountReq", "danh sach rong")
	end
	local d = layDuLieu()
	if d == nil then return dong(ctx, "ClientDemountReq", "khong doc duoc du lieu") end

	local nThao = 0
	for _, muc in ipairs(tDanhSach) do
		local cid = tonumber(type(muc) == "table" and muc.career_id)
		local cell = tonumber(type(muc) == "table" and muc.cell_id)
		local o = (cid and cell and d.career[cid]) and d.career[cid][cell] or nil
		if type(o) == "table" then
			d.career[cid][cell] = nil
			d.pack[#d.pack + 1] = o
			nThao = nThao + 1
		end
	end

	if nThao == 0 then return dong(ctx, "ClientDemountReq", "khong o nao co mon") end
	OfflineLog:info(string.format("%s: thao %d mon", TEN_FILE, nThao))
	tra(ctx, "ClientDemountRsp")
end)

--------------------------------------------------------------- 6. CHIÊM BỐC (đơn)
--[[ `ClientDivineReq()` **KHÔNG đối số** — nhưng không cần đối số: loại chiêm bốc
	chính là `cur_divide` trong bảng người chơi (`InitData` có `cur_divide = 1`;
	`AddToBagByDivine` tăng nó sau mỗi lượt, quay vòng 1..`MAX_DIVIVE_POS` = 5).

	Luật ghép từ ba mẩu ĐO ĐƯỢC, không có mẩu nào tự nghĩ:
	  · GIÁ = `DivineConf[cur_divide].price` **VÀNG** — UI đọc đúng trường ấy rồi gọi
	    `g_CUIBuyDialog:BuyWithGold(price, …)` (`CUIZhanXing.lua:114-116`).
	  · CHẤT LƯỢNG = bốc theo `StarSoulDivineChanceConf` của CÙNG `divine_id`, chỉ
	    dùng các dòng `use_diamond == 0` (nhánh MIỄN PHÍ; nhánh trả kim cương là
	    `[GHIM]` CHƯA làm — divine 4/5 có thêm một bộ dòng như thế).
	  · CẤT VÀO TÚI + TĂNG `cur_divide` = `StarSoulDataManager:AddToBagByDivine(strId,
	    quality, true)` — hàm GỐC có sẵn trong `share/`, tự kiểm `PackFull` và tự
	    quay vòng `cur_divide`.

	`star_soul_id` PHẢI là CHUỖI (config manager đánh lại khoá theo `star_soul_str_id`).
]]
local function layConfig(cacheName)
	local v = nil
	pcall(function () v = G_ConfigManager:GetConfigWithNameArg(cacheName) end)
	return type(v) == "table" and v or nil
end

R:on("G_StarSoulProtocol.ClientDivineReq", function (ctx)
	local d = layDuLieu()
	if d == nil then return dong(ctx, "ClientDivineReq", "khong doc duoc du lieu") end

	local nLoai = tonumber(d.cur_divide) or 1

	local dsDivine = layConfig(G_ConfigManager.configCacheName.StarSoulDivineConf)
	local conf = dsDivine and dsDivine[nLoai] or nil
	if type(conf) ~= "table" or conf.price == nil then
		conf = nil
		quet(dsDivine, function (r) if conf == nil and tonumber(r.id) == nLoai then conf = r end end)
	end
	if type(conf) ~= "table" then
		return dong(ctx, "ClientDivineReq", "thieu DivineConf cho loai " .. tostring(nLoai))
	end

	local nGia = tonumber(conf.price) or 0
	local nVang = 0
	pcall(function ()
		local _, b = G_UserLogic:GetBaseInfo()
		nVang = tonumber(b and b.Gold) or 0
	end)
	if nVang < nGia then
		OfflineLog:info(string.format("%s: chiem boc can %d vang, dang co %d -> 5405",
			TEN_FILE, nGia, nVang))
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 5405, {})
		return
	end

	-- Bốc chất lượng ĐÚNG theo hình config manager dựng sẵn
	-- (updateStarSoulDivineChanceConf, share_configManager.lua:4196-4248):
	--   DS[divine_id] = { no_use_diamond = { max_chance, chances = {{quality,max_chance},...} },
	--                     use_diamond    = {...} }
	-- max_chance da la LUY KE => boc deu trong [1, max_chance] roi lay o dau tien
	-- co x <= max_chance. Nhanh use_diamond (tra kim cuong) la [GHIM] CHUA lam.
	local dsTiLe = layConfig(G_ConfigManager.configCacheName.StarSoulDivineChanceConf)
	local nChatLuong = nil
	local nhom = (type(dsTiLe) == "table") and dsTiLe[nLoai] or nil
	if type(nhom) == "table" and type(nhom.no_use_diamond) == "table" then
		local c = nhom.no_use_diamond
		local tong = tonumber(c.max_chance) or 0
		if tong > 0 then
			local x = math.random(1, tong)
			for _, r in ipairs(c.chances or {}) do
				if x <= (tonumber(r.max_chance) or 0) then
					nChatLuong = tonumber(r.quality)
					break
				end
			end
		end
	end
	-- Du phong: cau hinh con o dang MANG THO (bo thu dung nhu vay).
	if nChatLuong == nil and type(dsTiLe) == "table" then
		local tong, dsDong = 0, {}
		for _, r in ipairs(dsTiLe) do
			local c = tonumber(r.chance) or 0
			if tonumber(r.divine_id) == nLoai and c > 0 and (tonumber(r.use_diamond) or 0) == 0 then
				tong = tong + c
				dsDong[#dsDong + 1] = { q = tonumber(r.quality) or 0, c = c }
			end
		end
		if tong > 0 then
			local x = math.random() * tong
			nChatLuong = dsDong[#dsDong].q
			for _, r in ipairs(dsDong) do
				x = x - r.c
				if x <= 0 then nChatLuong = r.q; break end
			end
		end
	end
	if nChatLuong == nil then
		OfflineLog:info(string.format("%s: khong boc duoc chat luong (loai %d, hinh %s)",
			TEN_FILE, nLoai, tostring(type(nhom))))
		return dong(ctx, "ClientDivineReq", "thieu bang ti le cho loai " .. tostring(nLoai))
	end

	-- Chọn một hồn CÙNG chất lượng từ cấu hình thật.
	local dsHon = layConfig(G_ConfigManager.configCacheName.StarSoulStaticConf)
	local ungVien = {}
	quet(dsHon, function (r, k)
		if tonumber(r.quality) == nChatLuong then
			local id = r.id
			if id == nil then id = k end
			if id ~= nil then ungVien[#ungVien + 1] = tostring(id) end
		end
	end)
	if #ungVien == 0 then
		return dong(ctx, "ClientDivineReq", "khong co hon nao o chat luong " .. tostring(nChatLuong))
	end
	local strId = ungVien[math.random(#ungVien)]

	-- Trừ vàng rồi cất vào túi bằng HÀM GỐC (hàm ấy cũng tăng `cur_divide`).
	local okTru, daTru = pcall(function () return G_UserLogic:CostGold(nGia, "StarSoulDivine") end)
	if not okTru or daTru ~= true then
		return dong(ctx, "ClientDivineReq", "tru vang hong")
	end
	local okCat, maCat = pcall(function ()
		return G_StarSoulDataManager:AddToBagByDivine(strId, nChatLuong, true)
	end)
	if not okCat or tonumber(maCat) ~= 0 then
		pcall(function () G_UserLogic:AddGold(nGia, "StarSoulDivine") end)   -- hoàn vàng
		OfflineLog:info(string.format("%s: cua hang day (ma %s) -> hoan vang",
			TEN_FILE, tostring(maCat)))
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", tonumber(maCat) or 5403, {})
		return
	end

	pcall(function () OfflineStore:syncFromClient() end)
	OfflineLog:info(string.format("%s: chiem boc loai %d (-%d vang) -> hon %s (chat luong %d)",
		TEN_FILE, nLoai, nGia, strId, nChatLuong))
	-- `XingHunData:setZhanXingResult` lấy `data[1]` ⇒ phải gói trong MẢNG.
	ctx:call("g_StarSoulProtocol", "ClientDivineRsp",
		{ { star_soul_id = strId, quality = nChatLuong, level = 1, exp = 0 } })
end)

--------------------------------------------------------------- 7. NÂNG CẤP (gộp)
--[[ Luật gộp NẰM TRONG CLIENT, không phải máy chủ chết:
	  · `XingHunData:getXingHunLevelExpAbsolute(xh)` (`XingHunData.lua:522-546`)
	    = Σ_{i=1..level} cfg(i).exp + xh.exp  — quy đổi một món về TỔNG exp tuyệt đối.
	  · `XingHunData:getXingHunLevelAndExpRelative(typeId, expAbs)` (`:549-570`)
	    = cấp/exp tương đối từ tổng ấy (duyệt `i = 2..MAX_STAR_SOUL_LEVEL`, trừ dần).
	Ghép hai hàm lại là xong: tổng của ĐÍCH + mọi món tiêu ⇒ cấp/exp mới của đích.

	DANH SÁCH MÓN TIÊU DO CHÍNH CLIENT CHỌN và gửi kèm (`CUIXingHunDetail.lua:396-427`):
	    `ClientUpgradeInPackReq(pack_idx, xhData, arr)`  — đích ở KHO
	    `ClientUpgradeInCellReq(career_id, cell_id, xhData, arr)` — đích ở Ô
	với `arr[i] = {pack_idx, star_soul_id, level, exp}`. Máy chủ KHÔNG tự chọn.

	`[GHIM]` Cấp tối đa lấy `G_ShareStarSoulLogic.MAX_STAR_SOUL_LEVEL`; bảng cấp đọc
	qua `StarSoulLevelConf`, chịu cả bản đồ `[id][level]` lẫn mảng thô. ]]
local function dongCauHinh(nId, nLevel)
	local ds = nil
	pcall(function ()
		ds = G_ConfigManager:GetConfigWithNameArg(G_ConfigManager.configCacheName.StarSoulLevelConf)
	end)
	if type(ds) ~= "table" then return nil end
	local theoCau = ds[nId] or ds[tostring(nId)]
	if type(theoCau) == "table" then
		local r = theoCau[nLevel] or theoCau[tostring(nLevel)]
		if type(r) == "table" then return r end
	end
	local tim = nil
	quet(ds, function (r)
		if tim == nil and tonumber(r.id) == tonumber(nId) and tonumber(r.level) == tonumber(nLevel) then
			tim = r
		end
	end)
	return tim
end

local function expTuyetDoi(mon)
	local nId = mon.star_soul_id
	local tong = tonumber(mon.exp) or 0
	for i = 1, tonumber(mon.level) or 1 do
		local r = dongCauHinh(nId, i)
		if type(r) ~= "table" then break end
		tong = tong + (tonumber(r.exp) or 0)
	end
	return tong
end

local function capVaExp(nId, nTong)
	local nMax = 1
	pcall(function () nMax = G_ShareStarSoulLogic.MAX_STAR_SOUL_LEVEL or 1 end)
	local level, exp = 1, nTong
	for i = 2, nMax do
		local r = dongCauHinh(nId, i)
		if type(r) ~= "table" then break end
		local can = tonumber(r.exp) or 0
		if exp < can then break end
		exp = exp - can
		level = level + 1
	end
	return level, exp
end

--[[ Áp một lượt gộp lên bảng người chơi. `monDich` là BẢNG THẬT trong `pack` hoặc
	trong `career[...]` (sửa tại chỗ). Trả số món đã tiêu. ]]
local function gop(d, monDich, arr)
	if type(monDich) ~= "table" or type(arr) ~= "table" then return 0 end
	local nTong = expTuyetDoi(monDich)
	local idxXoa, nTieu = {}, 0
	for _, m in ipairs(arr) do
		local pi = tonumber(m.pack_idx)
		local mon = pi and d.pack[pi]
		if type(mon) == "table" then
			nTong = nTong + expTuyetDoi(mon)
			idxXoa[#idxXoa + 1] = pi
			nTieu = nTieu + 1
		end
	end
	if nTieu == 0 then return 0 end

	local lv, exp = capVaExp(monDich.star_soul_id, nTong)
	monDich.level, monDich.exp = lv, exp

	-- Xoá TỪ LỚN XUỐNG để chỉ số không trôi.
	table.sort(idxXoa, function (a, b) return a > b end)
	for _, pi in ipairs(idxXoa) do table.remove(d.pack, pi) end
	return nTieu
end

R:on("G_StarSoulProtocol.ClientUpgradeInPackReq", function (ctx, nIndex, xhData, arr)
	local d = layDuLieu()
	if d == nil then return dong(ctx, "ClientUpgradeInPackReq", "khong doc duoc du lieu") end
	local i = tonumber(nIndex)
	if type(d.pack[i]) ~= "table" then
		return loiThamSo(ctx, "ClientUpgradeInPackReq", "khong co mon dich o vi tri " .. tostring(nIndex))
	end
	local n = gop(d, d.pack[i], arr)
	if n == 0 then return loiThamSo(ctx, "ClientUpgradeInPackReq", "khong co mon nao de gop") end
	OfflineLog:info(string.format("%s: gop %d mon vao mon o kho %d (-> cap %d, exp %d)",
		TEN_FILE, n, i, d.pack[i].level, d.pack[i].exp))
	tra(ctx, "ClientUpgradeInPackRsp")
end)

R:on("G_StarSoulProtocol.ClientUpgradeInCellReq", function (ctx, nCareer, nCell, xhData, arr)
	local d = layDuLieu()
	if d == nil then return dong(ctx, "ClientUpgradeInCellReq", "khong doc duoc du lieu") end
	local cid, cell = tonumber(nCareer), tonumber(nCell)
	local o = (cid and cell and d.career[cid]) and d.career[cid][cell] or nil
	if type(o) ~= "table" then
		return loiThamSo(ctx, "ClientUpgradeInCellReq", "o khong co mon")
	end
	local n = gop(d, o, arr)
	if n == 0 then return loiThamSo(ctx, "ClientUpgradeInCellReq", "khong co mon nao de gop") end
	OfflineLog:info(string.format("%s: gop %d mon vao o [%s][%s] (-> cap %d, exp %d)",
		TEN_FILE, n, tostring(cid), tostring(cell), o.level, o.exp))
	tra(ctx, "ClientUpgradeInCellRsp")
end)

--------------------------------------------------------------- 7. ĐỌC DỮ LIỆU
--[[ `ClientGetReq` — trả dữ liệu THẬT để panel khởi tạo (`_isServerInited`). ]]
R:on("G_StarSoulProtocol.ClientGetReq", function (ctx)
	local duLieu = nil
	if type(_G.G_StarSoulDataManager) == "table" then
		local okGoi, _, d = pcall(function ()
			return G_StarSoulDataManager:GetUserStarSoulData()
		end)
		if okGoi then duLieu = d end
	end

	if type(duLieu) ~= "table" then
		-- Không có dữ liệu thì vẫn phải TRẢ LỜI (nếu không panel đứng im), nhưng
		-- là câu trả lời TRUNG THỰC: hình dạng gốc của client.
		local okHinh, hinh = pcall(function () return G_StarSoulDataManager:InitData() end)
		duLieu = (okHinh and type(hinh) == "table") and hinh or {}
		OfflineLog:warn(TEN_FILE .. ": khong doc duoc du lieu, tra hinh dang InitData()")
	end

	pcall(function () OfflineStore:syncFromClient() end)
	local nMon = (type(duLieu.pack) == "table") and #duLieu.pack or 0
	OfflineLog:info(string.format("%s: ClientGetReq -> tra du lieu (pack=%d mon)", TEN_FILE, nMon))
	ctx:call("g_StarSoulProtocol", "ClientGetRsp", duLieu)
end)

OfflineLog:info("tinh hon: da noi 13 khoa (1 doc + 6 that + 6 dong co ly do)")

return true
