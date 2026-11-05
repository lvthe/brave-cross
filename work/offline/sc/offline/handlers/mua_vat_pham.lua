--[[
	offline/handlers/mua_vat_pham.lua — MUA VẬT PHẨM Ở CỬA HÀNG THƯỜNG.

	Hai khoá `G_ItemLogic` (`ClientItemLogic`, thực thể `G_ItemLogic`):

	  · `ClientBuyItem(nItemID, nCount, nResourceType)`        (`CallBuyItem`, `:296-305`)
	  · `ClientBuyItemBatch(buyList)`                          (`CallBuyItemBatch`, `:325-331`)

	Bên gọi: `CUIBuyDialogEx` (hộp thoại "mua N cái" dùng chung cho mọi cửa hàng) và
	`CUIWingLackMaterial` (mua nguyên liệu cánh còn thiếu bằng kim cương). Trước lượt
	này KHÔNG có handler nào ⇒ bấm "Mua" là lớp tải quay mãi.

	LUẬT LÀ MÃ GỐC CÒN SỐNG: `ShopLogic:BuyGoods(nGoodsId, nCount)`
	(`share/ShopLogic.lua:26-96`, thực thể `G_ShopLogic`): kiểm đủ tiền
	(`IsEnoughCurrencyToBugGood` → 1901), kiểm hạn mức ngày (`GetUserTodayCanBuyGoodsNumber`
	→ 1902), trừ tiền (`AddCurrencyCount`), cấp hàng (`CheckOutGoods`), ghi lượt mua.
	Bảng giá là DỮ LIỆU THẬT `KDBGameGoodsConfig` (65 dòng: `ItemId`, `CurrencyType`,
	`Price`, `GoodsCount`, `MaxBuyCountPerDay`, `GoodsId`).

	ĐỔI TỪ (ItemId, CurrencyType) SANG GoodsId bằng chính hàm cấu hình mà UI dùng để HIỂN
	THỊ giá: `G_ConfigManager:GetGoodsConfigWithType(itemId, currencyType)`
	(`CUIBuyDialogEx.lua:184`). Nhờ vậy số tiền ta trừ ĐÚNG BẰNG số UI đã in ra.

	⚠ HAI CHỖ VIẾT TAY, có lý do ĐO ĐƯỢC ([MOI]):
	  1. Client BẢN NÀY KHÔNG có hàm nhận phản hồi cho `ClientBuyItem`: khối mã mô tả hình
	     dạng (`ClientItemLogic.lua:307-315`) đã bị CHÚ THÍCH TOÀN BỘ, và `Item.OnBuyItem`
	     không có chỗ nào phát (grep cả cây = 1 dòng, nằm trong chính khối chú thích ấy).
	     Không phát thì `CallBuyItem` bật lớp tải (`OnWaitingForRequest`) mà KHÔNG ai tắt.
	     Nên handler tự phát đúng hai sự kiện mà khối chú thích mô tả:
	     `OnReceiveResponse` (tắt lớp tải) rồi `Item.OnBuyItem` với
	     `{ItemID, BuyCount, ResourceType}` — chính hình mà `CUIBuyDialogEx:onPtlBuyItem`
	     chờ để hiện "Mua thành công".
	  2. Đường BATCH: `CheckIsEnoughResourceBuyItems` (`share_ItemLogic.lua:231-280`) chỉ
	     KIỂM đủ tiền, không mua; phải gọi `BuyGoods` cho từng món — đúng thứ tự client
	     gửi lên, dừng ở món hỏng đầu tiên và báo mã của nó.
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineMuaVatPham = OfflineMuaVatPham or {}

local R = OfflineRouter
local TEN_FILE = "mua vat pham"

local function dongBo()
	pcall(function () OfflineStore:syncFromClient() end)
end

--[[ Tắt lớp tải + báo lỗi nếu có. `g_CUINotificationCenter` là đường chuẩn để client
	hiện toast lỗi (`onActionError` trong `CServerResponseLogic.lua` dùng đúng nó). ]]
local function baoKetQua(nMa)
	pcall(function ()
		G_EventManager:PostLogicEvent("ClientBuyItem", EventManagerLogicEvent.OnReceiveResponse)
	end)
	if nMa ~= nil and nMa ~= 0 then
		pcall(function ()
			g_CUINotificationCenter:PostNotification(
				CUINotificationEvent.OnServerRequestError, nMa)
		end)
	end
end

--[[ (ItemId, CurrencyType) -> dòng cấu hình hàng. `GetGoodsConfigWithType` trả
	`allGoods[itemId][currencyType]`; cả hai khoá đều là CHUỖI (config manager đánh lại
	khoá khi nạp — cùng bẫy `star_soul_id` 31/10). ]]
local function hangCua(nItemID, nResourceType)
	local ok, cfg = pcall(function ()
		return G_ConfigManager:GetGoodsConfigWithType(nItemID, nResourceType)
	end)
	if ok and type(cfg) == "table" and tonumber(cfg.GoodsId) then
		return cfg
	end
	return nil
end

--[[ DỰNG LẠI `G_ConfigManager:GetGoodsConfigWithId(nGoodsId)`.

	Hàm ấy bị **CHÚ THÍCH** trong bản gốc (`share_configManager.lua:2235-2238`) nhưng
	`ShopLogic:BuyGoods` gọi nó ở DÒNG 49 ⇒ nếu không dựng lại thì mua luôn ném lỗi.
	ĐO 1/11 trong game: `attempt to call method 'GetGoodsConfigWithId' (a nil value)`.

	Chỉ ĐÁNH LẠI KHOÁ từ bảng có sẵn `GetGoodsConfig()` — cấu trúc
	`[tostring(ItemId)][tostring(CurrencyType)] = {GoodsId, Price, …}`
	(xem `GetGoodsConfigWithType`, `:2938-2950`). Không bịa dòng giá nào.

	Gắn vào THỰC THỂ `G_ConfigManager` (không phải lớp): gán trên thực thể là nó CHE
	phương thức tra qua metatable, đúng cách `class()` cho phép. ]]
local function caiDanhMucGoods()
	if type(_G.G_ConfigManager) ~= "table" then
		return false
	end
	if type(G_ConfigManager.GetGoodsConfigWithId) == "function" then
		return true
	end
	local ok, theoItem = pcall(function () return G_ConfigManager:GetGoodsConfig() end)
	if not ok or type(theoItem) ~= "table" then
		return false
	end
	local theoId, n = {}, 0
	for _, theoTien in pairs(theoItem) do
		if type(theoTien) == "table" then
			for _, cfg in pairs(theoTien) do
				if type(cfg) == "table" and cfg.GoodsId ~= nil then
					theoId[tostring(cfg.GoodsId)] = cfg
					n = n + 1
				end
			end
		end
	end
	G_ConfigManager.GetGoodsConfigWithId = function (self, nGoodsId)
		return theoId[tostring(nGoodsId)]
	end
	OfflineLog:info(string.format("%s: da dung lai GetGoodsConfigWithId (%d dong gia)",
		TEN_FILE, n))
	return n > 0
end

--[[ THỰC THỂ CỦA LUẬT MUA. ⚠ KHÔNG dùng `G_ShopLogic` được: bản client này
	`ClientShopLogic = class(ShopLogic)` nhưng chính `require("share.ShopLogic")` bị
	**CHÚ THÍCH** (`share/share_gameLogic_require.lua:67`) ⇒ lúc dựng lớp, `ShopLogic`
	là nil ⇒ `class(nil)` ⇒ `G_ShopLogic` KHÔNG thừa kế gì, `G_ShopLogic.BuyGoods` = nil.
	ĐO 1/11 trong game: `attempt to call method 'BuyGoods' (a nil value)`.

	Nên nạp thẳng `share.ShopLogic` (chỉ định nghĩa lớp, không tác dụng phụ) rồi tự tạo một
	thực thể của LỚP GỐC. Không gọi trên LỚP (bẫy `class()` giữ phương thức trong vtbl ẨN —
	`ShopLogic.BuyGoods` cũng là nil). `ShopLogic:new()` an toàn: lớp này chỉ có `itor`
	(viết sai chính tả của `ctor`) nên `new` không chạy khởi tạo nào.
	`G_ShopLogicDataManager` thÌ ĐÃ nạp (`share_gameLogic_require.lua:68`). ]]
local function thucTheShop()
	if type(_G.ShopLogic) ~= "table" then
		pcall(function () require("share.ShopLogic") end)
	end
	if type(_G.ShopLogic) ~= "table" then
		return nil
	end
	if _G.OfflineShopThucThe == nil then
		local ok, s = pcall(function () return ShopLogic:new() end)
		if ok and type(s) == "table" then
			_G.OfflineShopThucThe = s
			caiDanhMucGoods()
		end
	end
	return _G.OfflineShopThucThe
end

-- Mua một món. Trả mã lỗi (0 = xong).
local function muaMot(nItemID, nCount, nResourceType)
	local shop = thucTheShop()
	if shop == nil then
		OfflineLog:err(TEN_FILE .. ": khong dung duoc ShopLogic (thieu share.ShopLogic?)")
		return ErrorCode.UnknowError
	end
	local cfg = hangCua(nItemID, nResourceType)
	if cfg == nil then
		OfflineLog:warn(string.format("%s: khong co dong gia cho vat pham %s / tien %s",
			TEN_FILE, tostring(nItemID), tostring(nResourceType)))
		return ErrorCode.Shop.NotEnoughCurrency   -- dùng mã gốc "không mua được"; xem ghi chú đầu tệp
	end
	local ok, nMa = pcall(function ()
		return shop:BuyGoods(tonumber(cfg.GoodsId), nCount)
	end)
	if not ok then
		OfflineLog:err(TEN_FILE .. ": luat goc nem loi: " .. tostring(nMa))
		return ErrorCode.UnknowError
	end
	return tonumber(nMa) or ErrorCode.UnknowError
end

R:on("G_ItemLogic.ClientBuyItem", function (ctx, nItemID, nCount, nResourceType)
	local nSoLuong = tonumber(nCount) or 0
	if type(nItemID) ~= "number" or nSoLuong < 1 then
		OfflineLog:warn(TEN_FILE .. ": tham so sai")
		baoKetQua(ErrorCode.ArgError)
		return
	end

	local nMa = muaMot(nItemID, nSoLuong, nResourceType)
	dongBo()

	if nMa ~= 0 then
		OfflineLog:info(string.format("%s: mua %s x%d bi tu choi, ma %s",
			TEN_FILE, tostring(nItemID), nSoLuong, tostring(nMa)))
		baoKetQua(nMa)
		return
	end

	OfflineLog:info(string.format("%s: da mua %s x%d", TEN_FILE, tostring(nItemID), nSoLuong))

	-- Hai sự kiện client chờ — xem ghi chú [MOI] đầu tệp.
	baoKetQua(nil)
	pcall(function ()
		G_EventManager:PostLogicEvent({
			ItemID = nItemID,
			BuyCount = nSoLuong,
			ResourceType = nResourceType,
		}, EventManagerLogicEvent.Item.OnBuyItem)
	end)
end)

--[[ BATCH: `buyList` = mảng `{ItemId, CurrencyType, BuyCount}` (client chia sẵn —
	`CUIEquipment_Forge.lua:1073`). Kiểm đủ tiền bằng luật gốc TRƯỚC, rồi mua từng món. ]]
R:on("G_ItemLogic.ClientBuyItemBatch", function (ctx, buyList)
	local function traLoi(nMa)
		pcall(function ()
			G_EventManager:PostLogicEvent("ClientBuyItemBatch", EventManagerLogicEvent.OnReceiveResponse)
		end)
		if nMa ~= nil and nMa ~= 0 then
			pcall(function ()
				g_CUINotificationCenter:PostNotification(
					CUINotificationEvent.OnServerRequestError, nMa)
			end)
		else
			pcall(function ()
				G_EventManager:PostLogicEvent(buyList, EventManagerLogicEvent.Item.OnBuyItemBatch)
			end)
		end
	end

	if type(buyList) ~= "table" or #buyList == 0 then
		OfflineLog:warn(TEN_FILE .. ": danh sach mua rong/sai")
		traLoi(ErrorCode.ArgError)
		return
	end

	local okKiem, bKiemDuoc, bDu, nTienThieu = pcall(function ()
		return G_ItemLogic:CheckIsEnoughResourceBuyItems(buyList)
	end)
	if not okKiem or bKiemDuoc ~= true then
		OfflineLog:err(TEN_FILE .. ": khong kiem duoc tien: " .. tostring(bKiemDuoc))
		traLoi(ErrorCode.UnknowError)
		return
	end
	if bDu ~= true then
		OfflineLog:info(string.format("%s: khong du tien loai %s", TEN_FILE, tostring(nTienThieu)))
		traLoi(ErrorCode.Shop.NotEnoughCurrency)
		return
	end

	local nDaMua = 0
	for _, muc in ipairs(buyList) do
		local nMa = muaMot(tonumber(muc.ItemId), tonumber(muc.BuyCount) or 1,
			tonumber(muc.CurrencyType))
		if nMa ~= 0 then
			OfflineLog:info(string.format("%s: batch dung o vat pham %s, ma %s (da mua %d)",
				TEN_FILE, tostring(muc.ItemId), tostring(nMa), nDaMua))
			dongBo()
			traLoi(nMa)
			return
		end
		nDaMua = nDaMua + 1
	end

	dongBo()
	OfflineLog:info(string.format("%s: da mua lo %d mon", TEN_FILE, nDaMua))
	traLoi(0)
end)

OfflineLog:info("mua vat pham: da noi 2 khoa (ClientBuyItem / ClientBuyItemBatch)")

return true
