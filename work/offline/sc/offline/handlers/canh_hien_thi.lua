--[[
	offline/handlers/canh_hien_thi.lua — CHỌN CÁNH ĐANG HIỂN THỊ cho tướng.

	Hai khoá `G_HeroLogic` (thực thể `G_HeroLogic` = `ClientHeroLogic`):

	  · `ClientShowWing(nHeroID, nWingLevel)`        (`ClientHeroLogic.lua:1071-1074`)
	  · `ClientShowMagicWing(nHeroID, nMagicWingID)` (`:1079-1082`)

	Bên gọi: `CUIWingShow` (`:377`), tức màn xem/chọn cánh. Trước lượt này KHÔNG có handler
	⇒ bấm chọn cánh là lớp tải quay mãi.

	ĐÂY KHÔNG PHẢI LUẬT CHƠI — nó chỉ ĐỔI MỘT CỜ HIỂN THỊ trên bản ghi tướng, và hàm ghi
	đã có sẵn trong `share/`:

	  · `HeroDataManager:SetHeroShowWingLevel(tướng, cấp)`      (`share_HeroDataManager.lua:934`)
	  · `HeroDataManager:SetHeroShowMagicWingID(tướng, id)`     (`:959`)

	Hai hàm ấy ghi `ShowWingLevel` / `ShowMagicWingID` (mỗi hàm XOÁ trường kia — chọn cánh
	thường thì bỏ cánh ảo và ngược lại) qua `PostDataEvent` nhắm bảng `GameUserHero`, nên
	dữ liệu ĐANG SỐNG đổi ngay và `OfflineStore:syncFromClient()` giữ lại khi lưu.
	Bộ vẽ đọc đúng trường ấy: `share/HeroSkinLogic.lua:439`
	(`ShowWingLevel or WingLevel or 0`).

	CỔNG KIỂM (suy từ dữ liệu tướng, không bịa): cấp cánh chọn phải nằm trong số ĐANG CÓ
	(`tướng.WingLevel`); cánh ảo phải nằm trong `tướng.MagicWingList`. Chọn 0 = bỏ hiện.

	Trả lời: client KHÔNG có hàm nhận cho hai lệnh này (chỉ có hàm gửi); UI đăng ký thẳng
	sự kiện `Hero.OnShowWing` (`CUIWingShow.lua:59`) để vẽ lại sprite. Nên handler phát
	`OnReceiveResponse` (tắt lớp tải, đúng khoá mà hàm gửi đã bật) rồi `Hero.OnShowWing`.
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineCanhHienThi = OfflineCanhHienThi or {}

local R = OfflineRouter
local TEN_FILE = "canh hien thi"

local function dongBo()
	pcall(function () OfflineStore:syncFromClient() end)
end

local function thongBao(nMa)
	if nMa == nil or nMa == 0 then return end
	pcall(function ()
		g_CUINotificationCenter:PostNotification(
			CUINotificationEvent.OnServerRequestError, nMa)
	end)
end

--[[ `khoaTai` là khoá mà hàm gửi đã dùng để BẬT lớp tải ("ClientShowWing" /
	"ClientShowMagicWing") — phải tắt đúng khoá ấy. ]]
local function traLoi(ctx, khoaTai, nMa)
	pcall(function ()
		G_EventManager:PostLogicEvent(khoaTai, EventManagerLogicEvent.OnReceiveResponse)
	end)
	if nMa ~= nil and nMa ~= 0 then
		thongBao(nMa)
		return
	end
	pcall(function ()
		G_EventManager:PostLogicEvent(nil, EventManagerLogicEvent.Hero.OnShowWing)
	end)
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

R:on("G_HeroLogic.ClientShowWing", function (ctx, nHeroID, nWingLevel)
	local nHero, nCap = tonumber(nHeroID), tonumber(nWingLevel)
	if nHero == nil or nCap == nil or nCap < 0 then
		OfflineLog:warn(TEN_FILE .. ": tham so sai (canh)")
		traLoi(ctx, "ClientShowWing", ErrorCode.ArgError)
		return
	end

	local hero = layTuong(nHero)
	if hero == nil then
		OfflineLog:info(string.format("%s: khong co tuong %d", TEN_FILE, nHero))
		traLoi(ctx, "ClientShowWing", ErrorCode.Hero.NotFindHero)
		return
	end

	local coCao = tonumber(hero.WingLevel) or 0
	if nCap > coCao then
		OfflineLog:info(string.format("%s: tuong %d chi co canh cap %d, doi hien cap %d",
			TEN_FILE, nHero, coCao, nCap))
		traLoi(ctx, "ClientShowWing", ErrorCode.ArgError)
		return
	end

	--[[ ⚠ Hàm gốc CHỈ `PostDataEvent`, nó KHÔNG ghi vào bản ghi tướng — bên GHI là một
	    handler dữ liệu phía MÁY CHỦ (cùng hình với `SetEquipIntensifyLevel`, nhưng hàm ấy
	    tự gán trước rồi mới post). ĐO 1/11 trong game: `SetHeroShowWingLevel` chạy OK mà
	    `ShowWingLevel` 0 -> 0, KHÔNG đổi.

	    Nên gán thẳng hai trường ĐÚNG NHƯ PAYLOAD của chính hàm ấy mô tả
	    (`ShowWingLevel = <cấp>`, `ShowMagicWingID = 0`) rồi mới gọi hàm gốc để nó phát
	    event bình thường. Không bịa trường nào. ]]
	hero.ShowWingLevel = nCap
	hero.ShowMagicWingID = 0

	local ok, bRet = pcall(function ()
		return G_HeroDataManager:SetHeroShowWingLevel(hero, nCap)
	end)
	if not ok or bRet ~= true then
		OfflineLog:err(TEN_FILE .. ": SetHeroShowWingLevel that bai")
		traLoi(ctx, "ClientShowWing", ErrorCode.UnknowError)
		return
	end

	dongBo()
	OfflineLog:info(string.format("%s: tuong %d hien canh cap %d", TEN_FILE, nHero, nCap))
	traLoi(ctx, "ClientShowWing", 0)
end)

R:on("G_HeroLogic.ClientShowMagicWing", function (ctx, nHeroID, nMagicWingID)
	local nHero, nId = tonumber(nHeroID), tonumber(nMagicWingID)
	if nHero == nil or nId == nil or nId < 0 then
		OfflineLog:warn(TEN_FILE .. ": tham so sai (canh ao)")
		traLoi(ctx, "ClientShowMagicWing", ErrorCode.ArgError)
		return
	end

	local hero = layTuong(nHero)
	if hero == nil then
		OfflineLog:info(string.format("%s: khong co tuong %d", TEN_FILE, nHero))
		traLoi(ctx, "ClientShowMagicWing", ErrorCode.Hero.NotFindHero)
		return
	end

	-- Cánh ảo phải nằm trong danh sách ĐANG CÓ của tướng. `0` = bỏ hiện.
	if nId ~= 0 then
		local co = false
		if type(hero.MagicWingList) == "table" then
			-- Mỗi phần tử có thể là SỐ hoặc BẢNG `{MagicWingID = …}` tuỳ bản lưu.
			-- ⚠ Không viết `tonumber(v) == id or tonumber(v.MagicWingID) == id`: khi `v`
			-- là SỐ, vế phải vẫn được tính và `v.MagicWingID` NÉM LỖI
			-- (`attempt to index local 'v' (a number value)`) — đo 1/11 trong bộ thử.
			for _, v in pairs(hero.MagicWingList) do
				local nMot = nil
				if type(v) == "table" then
					nMot = tonumber(v.MagicWingID)
				else
					nMot = tonumber(v)
				end
				if nMot == nId then
					co = true
				end
			end
		end
		if not co then
			OfflineLog:info(string.format("%s: tuong %d khong co canh ao %d", TEN_FILE, nHero, nId))
			traLoi(ctx, "ClientShowMagicWing", ErrorCode.ArgError)
			return
		end
	end

	-- Cùng lý do như `ClientShowWing`: payload của hàm gốc là
	-- `{ShowWingLevel = 0, ShowMagicWingID = <id>}` — bên GHI nằm ở máy chủ.
	hero.ShowWingLevel = 0
	hero.ShowMagicWingID = nId

	local ok, bRet = pcall(function ()
		return G_HeroDataManager:SetHeroShowMagicWingID(hero, nId)
	end)
	if not ok or bRet ~= true then
		OfflineLog:err(TEN_FILE .. ": SetHeroShowMagicWingID that bai")
		traLoi(ctx, "ClientShowMagicWing", ErrorCode.UnknowError)
		return
	end

	dongBo()
	OfflineLog:info(string.format("%s: tuong %d hien canh ao %d", TEN_FILE, nHero, nId))
	traLoi(ctx, "ClientShowMagicWing", 0)
end)

--[[ TRANG PHỤC ĐỘC QUYỀN — bật/tắt hiển thị (`CUIHeroInfoExclusiveUI:onTouchEnd_...`, `:211-224`).
	`ClientSetExclusiveSkinState(nHeroID, isCancel)`; `isCancel = true` nghĩa là HUỶ hiển thị.

	Hàm ghi đã có sẵn và TỰ GÁN trường rồi mới phát event:
	`HeroDataManager:SetIsCancelExclusive(tướng, isCancel)` (`share_HeroDataManager.lua:1071-1088`,
	tự đặt `tHeroData.IsCancelExclusive = isCancel` ở dòng 1082). Bộ vẽ đọc đúng trường ấy
	(`share/HeroSkinLogic.lua:378`, `share_HeroLogic.lua:2611`).

	Trả lời: client CÓ hàm nhận `OnSetExclusiveSkinState(nHeroID, isCancel)` — nhưng nó KHÔNG
	tắt lớp tải (hàm gửi đã bật `OnWaitingForRequest` trên khoá "ClientSetExclusiveSkinState"
	mà không ai tắt). Nên handler tự phát `OnReceiveResponse` trên đúng khoá ấy rồi mới gọi
	hàm nhận. ]]
R:on("G_HeroLogic.ClientSetExclusiveSkinState", function (ctx, nHeroID, isCancel)
	local nHero = tonumber(nHeroID)
	local function tatTai()
		pcall(function ()
			G_EventManager:PostLogicEvent("ClientSetExclusiveSkinState",
				EventManagerLogicEvent.OnReceiveResponse)
		end)
	end

	if nHero == nil then
		OfflineLog:warn(TEN_FILE .. ": tham so sai (trang phuc doc quyen)")
		tatTai()
		thongBao(ErrorCode.ArgError)
		return
	end

	local hero = layTuong(nHero)
	if hero == nil then
		OfflineLog:info(string.format("%s: khong co tuong %d", TEN_FILE, nHero))
		tatTai()
		thongBao(ErrorCode.Hero.NotFindHero)
		return
	end

	local bHuy = isCancel == true
	local ok, bRet = pcall(function ()
		return G_HeroDataManager:SetIsCancelExclusive(hero, bHuy)
	end)
	tatTai()
	if not ok or bRet ~= true then
		OfflineLog:err(TEN_FILE .. ": SetIsCancelExclusive that bai")
		thongBao(ErrorCode.UnknowError)
		return
	end

	dongBo()
	OfflineLog:info(string.format("%s: tuong %d %s trang phuc doc quyen",
		TEN_FILE, nHero, bHuy and "HUY hien" or "hien"))
	ctx:call("G_HeroLogic", "OnSetExclusiveSkinState", nHero, bHuy)
end)

OfflineLog:info("canh hien thi: da noi 3 khoa (ClientShowWing / ClientShowMagicWing / ClientSetExclusiveSkinState)")

return true
