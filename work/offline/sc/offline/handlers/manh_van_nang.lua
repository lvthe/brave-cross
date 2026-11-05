--[[
	offline/handlers/manh_van_nang.lua — ĐỔI MẢNH VẠN NĂNG RA MẢNH TƯỚNG.

	Khoá `G_HeroLogic|ClientConvertUniversalFragment(nHeroID, nCount)`
	(`ClientHeroLogic.lua:1088-1091`), gọi từ `CDigUseUniversalFragment`
	(`CUIUniversalFragment.lua:328`) — hộp thoại mở từ **Túi** khi bấm vật phẩm mảnh vạn năng.
	Trước lượt này KHÔNG có handler ⇒ bấm "Dùng" là lớp tải quay mãi.

	DỮ LIỆU LÀ CẤU HÌNH THẬT:

	  · Vật phẩm đổi: `G_HeroLogic.UniversalFragmentID = 20` (`share_HeroLogic.lua:83`).
	  · `GameUniversalFragmentConfig` = **DANH SÁCH TRẮNG** tướng đổi được — 90 tướng, giá trị
	    đều `1`. Chỗ dùng DUY NHẤT trong client là kiểm `tFragmentConfig[tostring(heroID)] ~= nil`
	    (`CUISubDialog.lua:1608-1618`, `CUIFragmentHeroList.lua:160-178`) — tức nó KHÔNG phải
	    hệ số quy đổi, chỉ là "tướng này có cho đổi không".
	  · `nCount` là SỐ MẢNH VẠN NĂNG tiêu (UI lấy trần = số đang có: `nItemMaxCount =
	    item.ItemCount`, `CUIUniversalFragment.lua:140`). Mảnh tướng nhận = đúng `nCount`
	    (1 đổi 1). Khẳng định chéo: khối mô tả phản hồi trong `ClientHeroLogic.lua:1105-1114`
	    trả `{HeroID, Count}` và `CUIBackpack.lua:656-676` hiện thưởng `Count` mảnh tướng.

	Trả lời: client KHÔNG có hàm nhận (khối mô tả bị chú thích); UI nghe thẳng sự kiện
	`Hero.OnConvertUniversalFragment`. Nên handler phát `OnReceiveResponse` trên ĐÚNG khoá mà
	hàm gửi đã bật — hàm gửi dùng khoá `"ClientIntensifyWing"` (sai chỗ, nhưng phải tắt đúng
	khoá ấy) — rồi phát sự kiện kia với `{HeroID, Count}`.
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineManhVanNang = OfflineManhVanNang or {}

local R = OfflineRouter
local TEN_FILE = "manh van nang"
local KHOA_TAT_TAI = "ClientIntensifyWing"   -- đúng khoá hàm gửi đã bật (xem đầu tệp)

local function dongBo()
	pcall(function () OfflineStore:syncFromClient() end)
end

local function phatKetQua(nMa, tData)
	pcall(function ()
		G_EventManager:PostLogicEvent(KHOA_TAT_TAI, EventManagerLogicEvent.OnReceiveResponse)
	end)
	if nMa ~= nil and nMa ~= 0 then
		pcall(function ()
			g_CUINotificationCenter:PostNotification(
				CUINotificationEvent.OnServerRequestError, nMa)
		end)
		return
	end
	pcall(function ()
		G_EventManager:PostLogicEvent(tData, EventManagerLogicEvent.Hero.OnConvertUniversalFragment)
	end)
end

R:on("G_HeroLogic.ClientConvertUniversalFragment", function (ctx, nHeroID, nCount)
	local nHero, nSo = tonumber(nHeroID), tonumber(nCount)
	if nHero == nil or nSo == nil or nSo < 1 then
		OfflineLog:warn(TEN_FILE .. ": tham so sai")
		phatKetQua(ErrorCode.ArgError)
		return
	end

	-- 1. Tướng phải có thật.
	local okT, bT, hero = pcall(function ()
		return G_HeroLogic:GetHeroWithID(nHero)
	end)
	if not okT or bT ~= true or type(hero) ~= "table" then
		OfflineLog:info(string.format("%s: khong co tuong %d", TEN_FILE, nHero))
		phatKetQua(ErrorCode.Hero.NotFindHero)
		return
	end

	-- 2. Tướng phải nằm trong DANH SÁCH TRẮNG của cấu hình.
	local okC, cfg = pcall(function ()
		return G_ConfigManager:GetCommonConfigWithName("GameUniversalFragmentConfig")
	end)
	--[[ `GameUniversalFragmentConfig` có thể VẮNG trong cache cấu hình của bản client này —
	    ĐO 1/11 trong game: `GetCommonConfigWithName` trả **nil** (cùng lúc
	    `EquipRefineConfig`/`VipConfig` vẫn đọc được). Không vì thế mà chặn người chơi: UI
	    chọn tướng (`CUIUniversalFragmentSelectHero`) ĐÃ chỉ liệt kê tướng nằm trong bảng ấy,
	    nên thiếu bảng chỉ là thiếu một lớp gác. Có bảng thì GÁC, không có thì đi tiếp và ghi
	    log đúng một dòng. ]]
	if okC and type(cfg) == "table" then
		-- Khoá của bảng có thể là CHUỖI hoặc SỐ (config manager đánh lại khoá khi nạp —
		-- cùng bẫy `star_soul_id` 31/10). Phải thử cả hai, nếu không sẽ từ chối oan.
		if cfg[tostring(nHero)] == nil and cfg[nHero] == nil then
			OfflineLog:info(string.format("%s: tuong %d khong cho doi manh van nang",
				TEN_FILE, nHero))
			phatKetQua(ErrorCode.Hero.NotFindHeroConfig)
			return
		end
	else
		if not OfflineManhVanNang.DA_BAO_THIEU then
			OfflineManhVanNang.DA_BAO_THIEU = true
			OfflineLog:warn(TEN_FILE .. ": khong doc duoc GameUniversalFragmentConfig — "
				.. "bo qua buoc gac danh sach trang (UI da tu gac)")
		end
	end

	-- 3. Đủ mảnh vạn năng không.
	local idVanNang = tonumber(G_HeroLogic.UniversalFragmentID) or 20
	local co = 0
	pcall(function ()
		local _, n = G_ItemLogic:GetItemCount(idVanNang)
		co = tonumber(n) or 0
	end)
	if co < nSo then
		OfflineLog:info(string.format("%s: can %d manh van nang, co %d", TEN_FILE, nSo, co))
		phatKetQua(ErrorCode.Item.NotEnoughItem)
		return
	end

	-- 4. Trừ mảnh vạn năng TRƯỚC; hỏng thì dừng, chưa cộng gì.
	local okTru, bTru = pcall(function ()
		return G_ItemDataManager:ReduceItem(idVanNang, nSo, "ClientConvertUniversalFragment")
	end)
	if not okTru or bTru ~= true then
		OfflineLog:err(TEN_FILE .. ": tru manh van nang that bai")
		phatKetQua(ErrorCode.Item.ReduceItemError)
		return
	end

	-- 5. Cộng mảnh tướng; hỏng thì HOÀN mảnh vạn năng.
	local okCong, bCong = pcall(function ()
		return G_HeroLogic:AddHeroFragment(nHero, nSo, "ClientConvertUniversalFragment")
	end)
	if not okCong or bCong ~= true then
		OfflineLog:err(TEN_FILE .. ": cong manh tuong that bai — hoan manh van nang")
		pcall(function () G_ItemLogic:AddItem(idVanNang, nSo, "ClientConvertUniversalFragment.hoan") end)
		phatKetQua(ErrorCode.Hero.SetHeroFragmentFail)
		return
	end

	dongBo()
	OfflineLog:info(string.format("%s: %d manh van nang -> %d manh tuong %d",
		TEN_FILE, nSo, nSo, nHero))
	phatKetQua(0, { HeroID = nHero, Count = nSo })
end)

OfflineLog:info("manh van nang: da noi 1 khoa (ClientConvertUniversalFragment)")

return true
