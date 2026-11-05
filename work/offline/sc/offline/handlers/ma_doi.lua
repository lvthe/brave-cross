--[[
	offline/handlers/ma_doi.lua — MÃ ĐỔI THƯỞNG (兑换码) qua API của server riêng.

	Trước lượt này khoá `G_RedeemCodeLogic|ClientUseRedeemCode` nằm trong lớp chắn
	`chua_ho_tro.lua` (mã 1): bản gốc cần **kho mã toàn máy chủ** do vận hành phát,
	mà máy chủ ấy đã chết. Nay server riêng có bảng `redeem_codes` + endpoint
	`POST /api/redeem` (xem `bravecross-server/src/http_api.ts`).

	LUỒNG: client gửi mã → lớp offline gọi HTTP → server khoá dòng mã, kiểm hạn/trần/
	đã-dùng, ghi `redeem_uses`, trả `{ok, diamonds, items}` → lớp offline TỰ CỘNG
	kim cương + phát danh sách vật phẩm bằng `G_ChapterLogic:SetDataWithPrizeList`
	(chính hàm client dùng để áp thưởng), rồi báo UI bằng sự kiện `OnServerUseRedeemCode`
	với đúng hình `{nServerErrCode, nClientErrCode, RetData}` mà `CUIRedeemCode:OnUseRedeemCode`
	đang đọc (`user/UI/CUIRedeemCode.lua:132-190`).

	MÃ LỖI: server trả đúng nhóm `ErrorCode.RedeemCode` — 2405 không tồn tại · 2406 đã dùng ·
	2407 hết hạn · 2410 hết lượt. Không gọi được server ⇒ 2403 `GetRedeemCodeFail` (đúng nghĩa
	"không lấy được dữ liệu mã"); máy không có HTTP (bộ thử PC) ⇒ 2405 trung thực như bản cũ.
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineMaDoi = OfflineMaDoi or {}

local R = OfflineRouter
local TEN_FILE = "ma doi"

local function dongLopTai(ctx, nMa)
	pcall(function ()
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", nMa or 0, {})
	end)
	pcall(function ()
		G_EventManager:PostLogicEvent("ClientRedeemCodeLogic", EventManagerLogicEvent.OnReceiveResponse)
	end)
end

local function baoUI(nMaServer)
	pcall(function ()
		G_EventManager:PostLogicEvent({
			nServerErrCode = tonumber(nMaServer) or 0,
			nClientErrCode = 0,
			RetData = {},
		}, "OnServerUseRedeemCode")
	end)
end

R:on("G_RedeemCodeLogic.ClientUseRedeemCode", function (ctx, strMa)
	local strCode = tostring(strMa or "")

	local tk = rawget(_G, "OfflineTaiKhoan")
	if tk == nil or tk.uid == nil then
		OfflineLog:warn(TEN_FILE .. ": chua dang nhap")
		dongLopTai(ctx, 2403)
		baoUI(2403)
		return
	end
	if type(rawget(_G, "sngHttpRequestWithString")) ~= "function" then
		-- Không có đường HTTP ⇒ không có kho mã. Trả "không tồn tại" như bản gốc,
		-- KHÔNG bịa là đổi được.
		dongLopTai(ctx, 2405)
		baoUI(2405)
		return
	end
	if strCode == "" then
		dongLopTai(ctx, 0)
		baoUI(2405)
		return
	end

	tk:goi("/api/redeem", { uid = tonumber(tk.uid), code = strCode }, function (ok, tl)
		local nMa = 0
		if not ok then
			nMa = tonumber(tl and tl.code) or 2403
		end

		if ok then
			local nKC = tonumber(tl.diamonds) or 0
			if nKC > 0 then
				pcall(function () G_UserLogic:AddDiamond(nKC, "UseRedeemCode") end)
			end
			local tItems = tl.items
			if type(tItems) == "table" and #tItems > 0 then
				local okPhat, bPhat = pcall(function ()
					return G_ChapterLogic:SetDataWithPrizeList(tItems, 1, "UseRedeemCode")
				end)
				if not okPhat or bPhat ~= true then
					OfflineLog:warn(TEN_FILE .. ": phat vat pham that bai (KC van da cong)")
				end
			end
			pcall(function () OfflineStore:syncFromClient() end)
			OfflineLog:info(string.format("%s: %s -> +%d KC, %d mon",
				TEN_FILE, strCode, nKC, type(tItems) == "table" and #tItems or 0))
			pcall(function ()
				if OfflineHanhDong ~= nil then
					OfflineHanhDong:ghi("redeem", strCode, { diamonds = nKC })
				end
			end)
		else
			OfflineLog:info(string.format("%s: %s -> ma %d", TEN_FILE, strCode, nMa))
		end

		dongLopTai(ctx, 0)
		baoUI(nMa)
	end)
end)

OfflineLog:info("ma doi: da noi 1 khoa (qua /api/redeem)")
