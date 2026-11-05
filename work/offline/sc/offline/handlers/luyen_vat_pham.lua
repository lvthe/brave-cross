--[[
	offline/handlers/luyen_vat_pham.lua — LUYỆN (NẤU) VẬT PHẨM RA TINH HOA / 熔炼.

	Khoá `G_ItemLogic|ClientRefineItem(tAddEssenceList)` (`ClientItemLogic.lua`, gọi từ
	`CUIRefineItem:onTouchEnd_OnRefineItemClick`, panel mở được từ Túi VÀ từ màn tinh
	luyện trang bị). Trước lượt này KHÔNG có handler nào ⇒ bấm "Luyện" là lớp tải quay mãi.

	LUẬT suy từ BA nguồn ĐỘC LẬP, không phải đoán:

	  1. **DANH SÁCH GỬI LÊN** (`CUIRefineItem.lua:879`): mảng `{ItemId, Count}`, chỉ gồm
	     vật phẩm `ItemType.Material` mà người chơi đã chọn.
	  2. **TỈ LỆ CÓ SẴN TRONG CẤU HÌNH**: `KDBGameItemConfig` có trường **`Concentrate`**;
	     chính UI cộng dồn `itemConfig.Concentrate * RefineSelect` để hiện "sẽ được N tinh
	     hoa" (`:877`). Nên máy chủ chỉ cần cộng đúng số ấy — số người chơi ĐÃ THẤY.
	  3. **MÃ LỖI ĐÃ KHAI SẴN** (`share/error.lua:97-101`): `NotEnoughItem = 1201`,
	     `ReduceItemError = 1202`, `GetItemConfigFail = 1203` — đúng ba cửa của việc này.

	XỬ LÝ NGUYÊN TỬ: KIỂM HẾT rồi mới TRỪ (không trừ dở rồi bỏ). Nếu trừ tới giữa mà một
	món hỏng thì HOÀN LẠI các món đã trừ — không nuốt của người chơi.

	Trả lời: client KHÔNG có hàm nhận cho lệnh này (`ClientItemLogic` chỉ có hàm gửi);
	`CUIRefineItem` đăng ký thẳng SỰ KIỆN tên `"ClientRefineItem"` (`:79`). Nên handler phát
	đúng hai sự kiện ấy — `OnReceiveResponse` (tắt lớp tải) rồi chính `"ClientRefineItem"`
	(chạy hoạt ảnh + đọc lại số tinh hoa từ `BaseInfo`).
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineLuyenVatPham = OfflineLuyenVatPham or {}

local R = OfflineRouter
local TEN_FILE = "luyen vat pham"

local function dongBo()
	pcall(function () OfflineStore:syncFromClient() end)
end

local function phatKetQua(nMa)
	pcall(function ()
		G_EventManager:PostLogicEvent("ClientRefineItem", EventManagerLogicEvent.OnReceiveResponse)
	end)
	if nMa ~= nil and nMa ~= 0 then
		pcall(function ()
			g_CUINotificationCenter:PostNotification(
				CUINotificationEvent.OnServerRequestError, nMa)
		end)
		return
	end
	pcall(function ()
		G_EventManager:PostLogicEvent(nil, "ClientRefineItem")
	end)
end

R:on("G_ItemLogic.ClientRefineItem", function (ctx, tData)
	if type(tData) ~= "table" or #tData == 0 then
		OfflineLog:warn(TEN_FILE .. ": danh sach rong/sai")
		phatKetQua(ErrorCode.ArgError)
		return
	end

	-- BƯỚC 1 — KIỂM HẾT, chưa trừ gì.
	local keHoach, tongTinhHoa = {}, 0
	for _, muc in ipairs(tData) do
		local nId = tonumber(muc and muc.ItemId)
		local nSo = tonumber(muc and muc.Count)
		if nId == nil or nSo == nil or nSo < 1 then
			OfflineLog:warn(TEN_FILE .. ": muc sai trong danh sach")
			phatKetQua(ErrorCode.ArgError)
			return
		end

		local okCfg, cfg = pcall(function ()
			return G_ConfigManager:GetItemConfigWithId(nId)
		end)
		if not okCfg or type(cfg) ~= "table" then
			OfflineLog:warn(TEN_FILE .. ": thieu cau hinh vat pham " .. tostring(nId))
			phatKetQua(ErrorCode.Item.GetItemConfigFail)
			return
		end
		local nMot = tonumber(cfg.Concentrate)
		if nMot == nil then
			OfflineLog:warn(TEN_FILE .. ": vat pham " .. tostring(nId) .. " khong co Concentrate")
			phatKetQua(ErrorCode.Item.GetItemConfigFail)
			return
		end

		-- ⚠ `ItemLogic:GetItemCount` trả (bResult, nCount) — đọc thẳng thì nhận BOOLEAN
		-- ⇒ `tonumber(true)` = nil ⇒ luôn báo "không đủ". ĐO TRONG GAME 1/11:
		-- `vat pham 88 can 1, co 0` dù món ấy có trong túi.
		local coHien = 0
		pcall(function ()
			local _, n = G_ItemLogic:GetItemCount(nId)
			coHien = tonumber(n) or 0
		end)
		if coHien < nSo then
			OfflineLog:info(string.format("%s: vat pham %d can %d, co %d",
				TEN_FILE, nId, nSo, coHien))
			phatKetQua(ErrorCode.Item.NotEnoughItem)
			return
		end

		keHoach[#keHoach + 1] = { id = nId, so = nSo }
		tongTinhHoa = tongTinhHoa + nMot * nSo
	end

	if tongTinhHoa <= 0 then
		OfflineLog:info(TEN_FILE .. ": tong tinh hoa = 0 — tu choi")
		phatKetQua(ErrorCode.Item.GetItemConfigFail)
		return
	end

	-- BƯỚC 2 — TRỪ, có đường lùi.
	local daTru = {}
	for _, k in ipairs(keHoach) do
		local okTru, bTru = pcall(function ()
			return G_ItemDataManager:ReduceItem(k.id, k.so, "ClientRefineItem")
		end)
		if not okTru or bTru ~= true then
			OfflineLog:err(string.format("%s: tru vat pham %d that bai — hoan lai %d mon da tru",
				TEN_FILE, k.id, #daTru))
			for _, lui in ipairs(daTru) do
				pcall(function () G_ItemLogic:AddItem(lui.id, lui.so, "ClientRefineItem.hoan") end)
			end
			phatKetQua(ErrorCode.Item.ReduceItemError)
			return
		end
		daTru[#daTru + 1] = k
	end

	-- BƯỚC 3 — CỘNG tinh hoa (hàm gốc).
	local okCong, bCong = pcall(function ()
		return G_UserLogic:AddConcentrate(tongTinhHoa, "ClientRefineItem")
	end)
	if not okCong or bCong ~= true then
		OfflineLog:err(TEN_FILE .. ": cong tinh hoa that bai — hoan lai vat pham")
		for _, lui in ipairs(daTru) do
			pcall(function () G_ItemLogic:AddItem(lui.id, lui.so, "ClientRefineItem.hoan") end)
		end
		phatKetQua(ErrorCode.UnknowError)
		return
	end

	dongBo()
	OfflineLog:info(string.format("%s: %d mon -> +%d tinh hoa", TEN_FILE, #daTru, tongTinhHoa))
	phatKetQua(0)
end)

OfflineLog:info("luyen vat pham: da noi 1 khoa (ClientRefineItem)")

return true
