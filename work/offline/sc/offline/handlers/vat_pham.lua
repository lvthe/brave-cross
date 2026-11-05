--[[
	offline/handlers/vat_pham.lua — dùng vật phẩm (nút "Dùng" trong Túi).

	ĐƯỜNG ĐI (đọc từ mã client):
	  CUIBackpack "Dùng" -> G_ItemLogic:UseItem(id, count)
	  (ClientItemLogic.lua:176) -> CallServer("G_ItemLogic", "ClientUseItem", id, count)
	  Ta trả G_ItemLogic:OnServerUseItem(id, count, tPrizeList)
	  (ClientItemLogic.lua:197) — chính hàm ấy phát `OnReceiveResponse` (tắt lớp
	  đang tải), `OnUseItemCallback` và notification `OnUseItem`.

	LUẬT LÀ CỦA BẢN GỐC: `ItemLogic:UseItem(itemID, nCount, tPrizeList)`
	(`share/share_ItemLogic.lua:348`) — khai báo vật phẩm theo ItemType
	(GiftPack / TreasureBox / Portrait) rồi gọi `callUseItem`, hàm này tra
	BẢNG HÀM theo ID: `"useItem_" .. itemID` (`:491-527`). Bản gốc ship sẵn các
	hàm ấy — `useItem_1` (vàng theo `Value`), `useItem_3` (kim cương),
	`useItem_6` (thể lực), `useItem_11/12`, `useItem_113..116`, `useItem_GiftPack`,
	`useItem_TreasureBox`, `useItem_Portrait` — nên ở đây chỉ GỌI, không chép luật.

	⚠ Vật phẩm KHÔNG có bảng hàm tương ứng (ví dụ **ID 4 — Đại Kinh Nghiệm Đan**,
	loại EXP: không có `useItem_4`) thì `callUseItem` trả false và bản thân
	UseItem trả false → ta KHÔNG báo thành công, chỉ tắt lớp đang tải. Không
	bịa đường "dùng" cho vật phẩm mà bản gốc không có.

	⚠ `tPrizeList`: chỉ GiftPack/TreasureBox mới cần (máy chủ gốc đọc PrizeID
	của vật phẩm rồi gửi kèm). Bảng PrizeID ở config chưa được ship đầy đủ nên
	tạm truyền {} — hai loại đó sẽ từ chối ở `useItem_GiftPack`, đúng tinh thần
	"không bịa".
]]

require("offline.log")
require("offline.store")
require("offline.router")

local R = OfflineRouter

R:on("G_ItemLogic.ClientUseItem", function(ctx, nItemID, nCount)
	local nErr = 0
	local bOk = false
	local tPrize = {}

	if G_ItemLogic == nil or ItemLogic == nil then
		nErr = 1
	else
		local goc = G_ItemLogic[ItemLogic]     -- lối lớp cha, tránh bản client gọi CallServer
		if goc == nil then
			nErr = 1
		else
			local ok, bRet = pcall(function ()
				return goc:UseItem(nItemID, nCount, tPrize)
			end)
			if ok and bRet == true then
				bOk = true
			elseif not ok then
				OfflineLog:warn("ClientUseItem loi: " .. tostring(bRet))
				nErr = 1
			end
		end
	end

	OfflineLog:info(string.format("dung vat pham %s x%s -> %s",
		tostring(nItemID), tostring(nCount), tostring(bOk)))

	if bOk then
		OfflineStore:syncFromClient()
		ctx:call("G_ItemLogic", "OnServerUseItem", nItemID, nCount, tPrize)
	else
		-- Không có hàm dùng cho vật phẩm này (bản gốc cũng từ chối): chỉ tắt
		-- lớp đang tải, KHÔNG phát OnUseItem để UI không hiện "đã dùng".
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", nErr, {})
	end
end)

--[[ BÁN vật phẩm (nút "Bán" trong Túi).

	`ClientItemLogic:SellItem` (`ClientItemLogic.lua:125`) → `ClientSellItem`;
	trả `OnServerSellItem(nItemID, nCount)` (:146) — chính hàm ấy phát
	`OnReceiveResponse` rồi `OnServerSellItem` cho UI.

	Luật gốc: `ItemLogic:SellItem` (`share_ItemLogic.lua:291`) cộng vàng
	`ItemInfo.Price * nCount` rồi `ReduceItem`. Vật phẩm `Price = 0` thì bán
	không ra đồng nào — đúng dữ liệu, không phải lỗi. ]]
R:on("G_ItemLogic.ClientSellItem", function(ctx, nItemID, nCount)
	local bOk = false
	local nErr = 0
	if G_ItemLogic ~= nil and ItemLogic ~= nil then
		local goc = G_ItemLogic[ItemLogic]
		if goc ~= nil then
			local ok, bRet = pcall(function ()
				return goc:SellItem(nItemID, nCount)
			end)
			bOk = ok and bRet == true
			if not ok then
				OfflineLog:warn("ClientSellItem loi: " .. tostring(bRet))
			end
		end
	end
	OfflineLog:info(string.format("ban vat pham %s x%s -> %s",
		tostring(nItemID), tostring(nCount), tostring(bOk)))
	if bOk then
		OfflineStore:syncFromClient()
		ctx:call("G_ItemLogic", "OnServerSellItem", nItemID, nCount)
	else
		nErr = 1
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", nErr, {})
	end
end)

--[[ GHÉP vật phẩm / cuộn (nút "Ghép" trong Túi).

	`ClientItemLogic:UI_SynthesisItem` (:81) → `ClientSynthesisItem`;
	trả `OnServerSynthesisItem(nItemID)` (:102).

	Luật gốc: `ItemLogic:SynthesisItem` (`share_ItemLogic.lua:451`) đọc công thức
	qua `G_EquipmentLogic:GetScrollSynthesisConfig`, kiểm đủ nguyên liệu, trừ
	nguyên liệu rồi `AddItem`. Lớp offline KHÔNG tự tính công thức — thiếu
	nguyên liệu thì luật gốc từ chối và UI chỉ thấy lớp đang tải tắt. ]]
R:on("G_ItemLogic.ClientSynthesisItem", function(ctx, nItemID)
	local bOk = false
	if G_ItemLogic ~= nil and ItemLogic ~= nil then
		local goc = G_ItemLogic[ItemLogic]
		if goc ~= nil then
			local ok, bRet = pcall(function ()
				return goc:SynthesisItem(nItemID)
			end)
			bOk = ok and bRet == true
			if not ok then
				OfflineLog:warn("ClientSynthesisItem loi: " .. tostring(bRet))
			end
		end
	end
	OfflineLog:info(string.format("ghep vat pham %s -> %s",
		tostring(nItemID), tostring(bOk)))
	if bOk then
		OfflineStore:syncFromClient()
		ctx:call("G_ItemLogic", "OnServerSynthesisItem", nItemID)
	else
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 1, {})
	end
end)

--[[ DÙNG HẾT (nút OK của hộp thoại "Có muốn bán vài thứ cho tiệm").

	ĐO 28/10: mở Cửa hàng bí ẩn ⇒ hiện hộp thoại đó (KHÔNG phải tính năng mới —
	`CUIMysteriousStoreQuickSell`, `CUIMysteriousStoreQuickSell.lua:199`), danh
	sách lấy từ `UseAllItemConfig` = **[1, 2, 3, 11, 12]**; nút OK gọi
	`G_ItemLogic:BatchUseItem()` (`ClientItemLogic.lua:279`) ⇒
	`ClientBatchUseItem` (KHÔNG tham số). Trước bản vá này log ghi
	`THIEU G_ItemLogic.ClientBatchUseItem`, lớp "đang tải" không tắt.

	Luật máy chủ: DÙNG (`UseItem`) từng món trong `UseAllItemConfig` còn số
	lượng > 0 — đúng như hộp thoại tính: item 1 (Khối Vàng) Value 1000 ⇒ 7 món
	= 7000 vàng. Phát xong gọi `G_ItemLogic:OnServerBatchUseItem()`
	(`ClientItemLogic.lua:288`) — chính nó tắt lớp tải và phát `OnQuickSell`. ]]
R:on("G_ItemLogic.ClientBatchUseItem", function(ctx)
	local cfg = nil
	local ok1, v = pcall(function ()
		return G_ConfigManager:GetCommonConfigWithName("UseAllItemConfig")
	end)
	if ok1 and type(v) == "table" then
		cfg = v
	end

	local soMon, soLoai = 0, 0
	if cfg ~= nil and G_ItemLogic ~= nil and ItemLogic ~= nil then
		local goc = G_ItemLogic[ItemLogic]
		if goc ~= nil then
			for _, id in ipairs(cfg) do
				local okC, n = pcall(function ()
					local _, c = G_ItemLogic:GetItemCount(id)
					return tonumber(c) or 0
				end)
				if okC and n > 0 then
					local ok, bRet = pcall(function ()
						return goc:UseItem(id, n, {})
					end)
					if ok and bRet == true then
						soLoai = soLoai + 1
						soMon = soMon + n
					else
						OfflineLog:warn(string.format(
							"ClientBatchUseItem: dung mon %s x%s khong duoc (%s)",
							tostring(id), tostring(n), tostring(bRet)))
					end
				end
			end
		end
	end

	OfflineLog:info(string.format("dung het vat pham: %d loai / %d mon", soLoai, soMon))
	OfflineStore:syncFromClient()
	ctx:call("G_ItemLogic", "OnServerBatchUseItem")
end)

--[[ DÙNG NHIỀU VẬT PHẨM MỘT LƯỢT — `ClientBatchUseItemWithItemList(tUseItemList)`.

	Lệnh `ClientItemLogic.lua:231`; nút "Dùng" của Túi gửi nó khi SỐ DÙNG VƯỢT SỐ
	TRONG MỘT NGĂN (`CUIBackpack.lua:718-723` + `checkUseItemDataList`:1029) — danh
	sách do CHÍNH CLIENT chia sẵn, mỗi mục `{ItemID, UserCount}`. Callback PHƯƠNG
	THỨC `OnBatchUseItemWithItemList(tRetData)` (`ClientItemLogic.lua:252`); UI
	`CUIBackpack:OnBatchUseItemWithItemList` (`:563`) đọc `tUseData.ItemID` và —
	với hộp quà — `tUseData.RetData` (danh sách thưởng).

	LUẬT: dùng lại ĐÚNG `ItemLogic:UseItem` của từng mục (cùng đường `ClientUseItem`
	đã chạy) — không có hàm batch nào trong `share/` (ĐO: `BatchUseItemWithItemList`
	0 thân trên cả cây). Tham số thứ ba `tPrizeList` là BẢNG RỖNG do ta tạo; `UseItem`
	ĐỔ vào đó danh sách thưởng, và đó chính là `RetData` client cần.

	[MOI] MỘT MỤC HỎNG KHÔNG LÀM HỎNG CẢ LƯỢT: dùng tuần tự, mục nào `UseItem` trả
	false thì BỎ và ghi log; trả danh sách các mục ĐÃ dùng. Nếu KHÔNG mục nào dùng
	được thì trả mã **1** (bản gốc không có mã riêng cho batch).
]]
R:on("G_ItemLogic.ClientBatchUseItemWithItemList", function (ctx, tUseItemList)
	if type(tUseItemList) ~= "table" or #tUseItemList == 0 then
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 4, {})
		return
	end
	local goc = (G_ItemLogic ~= nil and ItemLogic ~= nil) and G_ItemLogic[ItemLogic] or nil
	if goc == nil then
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 1, {})
		return
	end
	local daDung = {}
	for _, muc in ipairs(tUseItemList) do
		local id = type(muc) == "table" and tonumber(muc.ItemID) or nil
		local n = type(muc) == "table" and tonumber(muc.UserCount) or nil
		if id ~= nil and n ~= nil and n > 0 then
			local prize = {}
			local ok, bRet = pcall(function () return goc:UseItem(id, n, prize) end)
			if ok and bRet == true then
				daDung[#daDung + 1] = { ItemID = id, UserCount = n, RetData = prize }
			else
				OfflineLog:warn(string.format("dung loat: bo muc %s x%s (%s)",
					tostring(id), tostring(n), tostring(bRet)))
			end
		end
	end
	if #daDung == 0 then
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", 1, {})
		return
	end
	pcall(function () OfflineStore:syncFromClient() end)
	OfflineLog:info(string.format("dung loat: %d/%d muc thanh cong", #daDung, #tUseItemList))
	ctx:call("G_ItemLogic", "OnBatchUseItemWithItemList", daDung)
end)

return true
