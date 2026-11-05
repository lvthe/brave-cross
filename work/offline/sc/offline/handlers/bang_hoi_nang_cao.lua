--[[
	offline/handlers/bang_hoi_nang_cao.lua — BANG HỘI (PHẦN NÂNG CAO), 23 khoá.

	Vì sao có tệp này: `handlers/bang_hoi.lua` (1/11) lo phần SỐNG CÒN của một bang
	một người (lập bang / thông tin / thông báo / nhật ký / đơn xin / rời / giải tán /
	đóng góp). Tệp này lo phần CÒN LẠI mà client gọi: quản lý thành viên, thiết lập
	bang, tìm/join/apply, thuế công nghệ, xúc xắc ("我要神将"), và điều tướng.

	BA NHÓM — mỗi khoá chọn đúng một trong ba, KHÔNG gộp:

	A. THẬT (có dữ liệu + luật trong client/cấu hình):
	   · `ClientModifyGuildSetting`  — ghi `Type / PictrueId / AcceptLevel` vào bảng bang.
	   · `ClientUploadWeChatGroup`   — lưu URL nhóm WeChat.
	   · `ClientIsHaveGuildRedPoint` — chấm đỏ = còn lượt xúc xắc hôm nay.
	   · `ClientDonateGuildTechnology` — cấu hình THẬT `KDBGameTchecknologyDonateConfig`
	     (5 bậc: 15.000 vàng hoặc 50/100/250/800 kim cương, VIP 0/0/3/6/8) + bảng cấp
	     `KDBGameGuildTchecknologyConfig` (12 tuyến × 15..50 cấp, `Exp` luỹ tiến).
	   · `ClientGetDiceGameData` / `ClientPlayDiceGame` / `ClientGetDiceGameReward` —
	     cấu hình THẬT `DiceGameConfig` (5 lượt/ngày, `StartPlan` 3 kế hoạch chọn theo
	     `Rate`, `GodTimesData` = số mặt 6 của từng lượt) + `DiceGameConfigEx`
	     (bảng thưởng theo `GodHeroId`). Trạng thái ở `GameUserLottery` — ĐÚNG bảng mà
	     UI đọc (`CUIShakeDice.lua:728-745`).
	   · `ClientDispatchHero` / `ClientQuerySelfDispatchList` / `ClientPickGuildHero` —
	     lưu `GameUserGuildData.MapDispatchHero` — ĐÚNG bảng mà client đọc
	     (`ClientGuildDispatchLogic.lua:317`). Thu nhập tính theo công thức CHÍNH client
	     dùng (`GetHasGenerateCoin`, `:411-456`), [GHIM].

	B. MỘT NGƯỜI ⇒ TỪ CHỐI/TRỐNG, dùng MÃ GỐC (`share/error.lua:445-507`):
	   duyệt/từ chối đơn (3523 GuildNotApply), đá (3507), đặt/bỏ phó bang chủ (3507),
	   đặt bang chủ (tự mình = đã là bang chủ ⇒ 0), tìm bang (3501), danh sách bang
	   (rỗng), join/apply (3502 vì đã ở bang; chưa ở bang thì 3501 vì không có bang
	   nào khác), thuê tướng (3514), điều tướng lần 2 (3513), quá 3 tướng (3512),
	   thu hồi trước 30 phút (3517), đòi luận tội (3555 — bang chủ còn sống).

	C. KHÔNG LÀM ĐƯỢC, khai rõ: `ClientEmployDispatchHero` cần TƯỚNG CỦA NGƯỜI KHÁC
	   (`StHeroInfo/StHeroEquip/StHeroMagicWeapon` của người kia) — offline không có ai.

	⚠ HAI BẪY ĐÃ VẤP Ở TỆP NÀY:
	1. NHIỀU HÀM NHẬN KHÔNG CÓ THAM SỐ MÃ LỖI (`OnPlayDiceGame(tData)`,
	   `OnGetDiceGameReward(tData)`, `ClientJoinGuild()`, `OnApplyGuild()`,
	   `OnPickGuildHero(tData)` …). Không thể báo lỗi qua chúng — báo bằng
	   `g_CUIGameRPCManager:OnReciveResponse("", "", mã, {})` (đúng đường của
	   `CUIRPCManager.lua:166`: dừng lớp tải rồi hiện toast).
	2. `GetUserDataWithName` trả `(bRetCode, bảng)`; `GetHeroWithID` và
	   `GetPrizeWithID` trả `(bResult, đối tượng)`. Bọc `pcall` thì phải đọc BA giá
	   trị, không thì nhận BOOLEAN làm dữ liệu (bẫy họ `GetItemCount`, README 1/11).
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineBangHoiNangCao = OfflineBangHoiNangCao or {}

local R = OfflineRouter
local TEN_FILE = "bang hoi (nang cao)"
local MOC_NGAY = 5                      -- cùng mốc `DialyRefreshHour` với `offline/qua_ngay.lua`
local MAX_DIEU_TUONG = 3                -- client: `GetHasDispatchHeroCount` nMaxDispatchCount = 3

------------------------------------------------------------------- tiện ích

local function ma(ten, macDinh)
	local ok, v = pcall(function ()
		local E = _G.ErrorCode
		return E and E.Guild and E.Guild[ten]
	end)
	return (ok and tonumber(v)) or macDinh
end

local function maChung(ten, macDinh)
	local ok, v = pcall(function ()
		local E = _G.ErrorCode
		return E and E.Common and E.Common[ten]
	end)
	return (ok and tonumber(v)) or macDinh
end

local function maXucXac(ten, macDinh)
	local ok, v = pcall(function ()
		local E = _G.ErrorCode
		return E and E.DiceGame and E.DiceGame[ten]
	end)
	return (ok and tonumber(v)) or macDinh
end

local function goi(ctx, hamNhan, ...)
	local a = { n = select("#", ...), ... }
	local ok, e = pcall(function ()
		return ctx:call("G_GuildLogic", hamNhan, unpack(a, 1, a.n))
	end)
	if not ok then
		OfflineLog:err(string.format("%s: khong goi duoc G_GuildLogic.%s -> %s",
			TEN_FILE, tostring(hamNhan), tostring(e)))
	end
end

--[[ Báo lỗi cho khoá KHÔNG có hàm nhận mang mã lỗi: dừng lớp tải + hiện toast.
	`OnReciveResponse(callbackObj, callbackFunc, nErrCode, eventList, ...)`
	(`CUIRPCManager.lua:166`). ]]
local function baoLoi(ctx, nMa, lyDo)
	OfflineLog:info(string.format("%s: tu choi -> ma %d (%s)", TEN_FILE, nMa, lyDo or ""))
	local ok, e = pcall(function ()
		ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", nMa, {})
	end)
	if not ok then
		OfflineLog:err(TEN_FILE .. ": khong bao duoc loi -> " .. tostring(e))
	end
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

local function uid()
	local ok, v = pcall(function () return OfflineBangHoi:uid() end)
	return (ok and tonumber(v)) or 1
end

local function bang()
	local ok, b = pcall(function () return OfflineBangHoi:doc() end)
	return (ok and type(b) == "table") and b or nil
end

local function ghiBang(b)
	local ok, r = pcall(function () return OfflineBangHoi:ghi(b) end)
	return ok and r == true
end

local function laChuBang(b)
	return b ~= nil and tonumber(b.HeadUid) == uid()
end

--[[ Bảng dữ liệu người chơi theo tên. `GetUserDataWithName` trả `(bRetCode, bảng)`;
	KHÔNG có bảng thì trả nil (không bịa bảng rỗng, vì client phân biệt hai thứ ấy). ]]
local function layBangDuLieu(ten)
	local ok, maLoi, t = pcall(function ()
		return G_DataManager:GetUserDataWithName(ten)
	end)
	if ok and maLoi == 0 and type(t) == "table" then return t end
	return nil
end

------------------------------------------------------------------- quản lý thành viên
--[[ Một người: mọi "đơn xin vào bang" đều KHÔNG CÓ. Mã gốc 3523 "未申请该军团"
	đúng nghĩa "đơn này không tồn tại". ]]
R:on("G_GuildLogic.ClientAcceptApply", function (ctx, nUid)
	local m = ma("GuildNotApply", 3523)
	goi(ctx, "OnAcceptApply", m)
end)

R:on("G_GuildLogic.ClientRejectApply", function (ctx, nUid)
	local m = ma("GuildNotApply", 3523)
	goi(ctx, "OnRejectApply", m)
end)

--[[ Không có thành viên nào khác để trao chức. `GuildAuthLess 3507` là mã gốc cho
	"权限不够" — đúng tình huống "không có quyền/thành viên để làm việc ấy".
	Tự trao chức cho CHÍNH MÌNH thì đã là bang chủ ⇒ trả 0 (idempotent), không bịa
	thêm chức danh. ]]
R:on("G_GuildLogic.ClientSetHead", function (ctx, nTargetUid)
	local b = bang()
	if b == nil then
		goi(ctx, "OnSetHead", ma("GuildNotExist", 3501))
		return
	end
	local target = tonumber(nTargetUid)
	if target == tonumber(b.HeadUid) then
		OfflineLog:info(TEN_FILE .. ": dat bang chu = nguoi dang lam bang chu -> 0")
		goi(ctx, "OnSetHead", 0)
		return
	end
	if target == uid() then
		b.HeadUid = target
		ghiBang(b)
		dongBo()
		goi(ctx, "OnSetHead", 0)
		return
	end
	goi(ctx, "OnSetHead", ma("GuildAuthLess", 3507))
end)

R:on("G_GuildLogic.ClientSetManager", function (ctx, nTargetUid)
	local m = (bang() == nil) and ma("GuildNotExist", 3501) or ma("GuildAuthLess", 3507)
	goi(ctx, "OnSetManager", m)
end)

R:on("G_GuildLogic.ClientCancelManager", function (ctx, nTargetUid)
	local m = (bang() == nil) and ma("GuildNotExist", 3501) or ma("GuildAuthLess", 3507)
	goi(ctx, "OnCancelManager", m)
end)

--[[ Đá thành viên: không có ai để đá; tự đá mình là đá bang chủ — cả hai đều 3507. ]]
R:on("G_GuildLogic.ClientKickGuild", function (ctx, nKickUid)
	local m = (bang() == nil) and ma("GuildNotExist", 3501) or ma("GuildAuthLess", 3507)
	goi(ctx, "OnKickGuild", m)
end)

--[[ THẬT: bang chủ đổi ba trường thiết lập. Hàm nhận tên `ClientModifyGuildSetting`
	(trùng tên hàm GỬI — `ClientGuildManageLogic.lua:522`), không phải `On...`. ]]
R:on("G_GuildLogic.ClientModifyGuildSetting", function (ctx, nGuildId, nType, strPictrueId, nAcceptLevel)
	local b = bang()
	if b == nil then
		goi(ctx, "ClientModifyGuildSetting", ma("GuildNotExist", 3501))
		return
	end
	if not laChuBang(b) then
		goi(ctx, "ClientModifyGuildSetting", ma("GuildAuthLess", 3507))
		return
	end
	if nType ~= nil then b.Type = tonumber(nType) or b.Type end
	if strPictrueId ~= nil then b.PictrueId = tostring(strPictrueId) end
	if nAcceptLevel ~= nil then b.AcceptLevel = tonumber(nAcceptLevel) or b.AcceptLevel end
	ghiBang(b)
	dongBo()
	OfflineLog:info(string.format("%s: thiet lap bang -> Type=%s, PictrueId=%s, AcceptLevel=%s",
		TEN_FILE, tostring(b.Type), tostring(b.PictrueId), tostring(b.AcceptLevel)))
	goi(ctx, "ClientModifyGuildSetting", 0)
end)

--[[ THẬT: chấm đỏ bang hội. Client tự tính hai nguồn khác (`g_CUIShakeDice:IsRed()`
	và `g_GuildContestData`); nguồn DUY NHẤT offline có dữ liệu là còn lượt xúc xắc.
	`trangThaiXucXac` được KHAI BÁO TRƯỚC rồi gán ở dưới — nếu để `local function`
	ở dưới thì chỗ này đọc phải BIẾN TOÀN CỤC nil (không phải lỗi cú pháp). ]]
local trangThaiXucXac
R:on("G_GuildLogic.ClientIsHaveGuildRedPoint", function (ctx, nGuildId)
	local con = false
	pcall(function ()
		local t, cfg = trangThaiXucXac()
		if t and cfg then
			con = (tonumber(cfg.PlayTimes) or 0) - (tonumber(t.DiceGamePlayTimes) or 0) > 0
		end
	end)
	goi(ctx, "onIsHaveGuildRedPoint", con)
end)

--[[ Lưu URL nhóm WeChat của bang. Hàm nhận chỉ có mã lỗi và UI hiện toast theo đó.
	KHÔNG có đường gọi UI nào trong Lua (grep 0 chỗ `UpdateWeChatGroup`), nhưng lưu
	được thì rẻ hơn từ chối. ]]
R:on("G_GuildLogic.ClientUploadWeChatGroup", function (ctx, nGuildId, strUrl)
	local b = bang()
	if b == nil then
		goi(ctx, "OnUploadWeChatGroup", ma("GuildNotExist", 3501))
		return
	end
	b.WeChatGroup = tostring(strUrl or "")
	ghiBang(b)
	dongBo()
	OfflineLog:info(TEN_FILE .. ": luu link nhom WeChat cua bang")
	goi(ctx, "OnUploadWeChatGroup", 0)
end)

--[[ Luận tội bang chủ: người duy nhất chính là bang chủ, và đang online ⇒ mã gốc
	`GuildHeadManIsAlive 3555` ("您的军团长是活跃的"). Hàm nhận `OnImpeachHeadman(tData)`
	không có mã lỗi ⇒ báo bằng toast, KHÔNG gọi hàm nhận (gọi là UI hiện thành công). ]]
R:on("G_GuildLogic.ClientImpeachHeadman", function (ctx, nHeadUid, nGuildId)
	local b = bang()
	local m
	if b == nil then
		m = ma("GuildNotExist", 3501)
	elseif tonumber(nHeadUid) ~= tonumber(b.HeadUid) then
		m = ma("GuildTargetNotHeadman", 3553)
	else
		m = ma("GuildHeadManIsAlive", 3555)
	end
	OfflineLog:info(string.format("%s: luan toi bang chu -> ma %d", TEN_FILE, m))
	thongBao(m)
end)

------------------------------------------------------------------- tìm / xin vào bang
--[[ Danh sách bang ngẫu nhiên: offline chỉ có bang CỦA MÌNH và bạn đã ở trong nó ⇒
	không có bang nào để xin vào. Khoá này ĐÃ có handler từ 28/10 trong
	`handlers/he_thong.lua:194` (cùng câu trả lời: mã 0 + danh sách rỗng) — KHÔNG
	đăng ký lại ở đây, đăng ký hai chỗ chỉ sinh cảnh báo "dang ky de handler". ]]

--[[ Tìm bang theo id: chỉ tìm thấy CHÍNH bang của mình. Trả đủ trường mà danh sách
	và màn xin vào đọc (`CUIGuildApply.lua:1542-1633`): GuildId/PictrueId/Name/
	StrNotice/MemberNum/Type. ]]
R:on("G_GuildLogic.ClientSearchGuild", function (ctx, nGuildId)
	local b = bang()
	if b ~= nil and tonumber(nGuildId) == tonumber(b.GuildId) then
		local d = {
			GuildId = tonumber(b.GuildId),
			Name = b.Name or "",
			PictrueId = b.PictrueId or "1",
			StrNotice = b.StrNotice or "",
			Type = tonumber(b.Type) or 1,
			AcceptLevel = tonumber(b.AcceptLevel) or 1,
			MemberNum = type(b.memberList) == "table" and #b.memberList or 1,
			HeadUid = tonumber(b.HeadUid) or uid(),
		}
		OfflineLog:info(TEN_FILE .. ": tim thay bang cua minh")
		goi(ctx, "OnSearchGuild", 0, d)
		return
	end
	OfflineLog:info(TEN_FILE .. ": tim bang " .. tostring(nGuildId) .. " -> khong co")
	goi(ctx, "OnSearchGuild", ma("GuildNotExist", 3501), nil)
end)

--[[ Vào bang / xin vào bang: hàm nhận KHÔNG có mã lỗi. Hai nhánh:
	· đã ở trong bang ⇒ 3502 GuildIsIn — đúng mã gốc;
	· chưa ở bang ⇒ không có bang nào khác để vào ⇒ 3501 GuildNotExist. ]]
R:on("G_GuildLogic.ClientJoinGuild", function (ctx, nGuildId)
	local m = (bang() ~= nil) and ma("GuildIsIn", 3502) or ma("GuildNotExist", 3501)
	baoLoi(ctx, m, "khong co bang khac de vao")
end)

R:on("G_GuildLogic.ClientApplyGuild", function (ctx, nGuildId)
	local m = (bang() ~= nil) and ma("GuildIsIn", 3502) or ma("GuildNotExist", 3501)
	baoLoi(ctx, m, "khong co bang khac de xin vao")
end)

--[[ Huỷ đơn xin: không có đơn nào, nhưng hàm nhận `OnCancelApply()` không có mã lỗi
	và UI chỉ dọn danh sách — gọi nó là hành vi trung thực (không có gì để huỷ). ]]
R:on("G_GuildLogic.ClientCancelApply", function (ctx, nGuildId)
	OfflineLog:info(TEN_FILE .. ": huy don xin -> khong co don nao")
	goi(ctx, "OnCancelApply")
end)

------------------------------------------------------------------- THUẾ CÔNG NGHỆ
--[[ Cấu hình THẬT — `KDBGameTchecknologyDonateConfig` (5 bậc):

	Index  ResourceType  ResourceCount  TechnologyCount  VipLimite
	  1         1 (vàng)      15000            20            0
	  2        20 (ngọc)         50            50            0
	  3        20 (ngọc)        100           120            3
	  4        20 (ngọc)        250           200            6
	  5        20 (ngọc)        800           800            8

	`ResourceType = 1` là VÀNG, `20` là KIM CƯƠNG — đúng enum `ResourceType`
	(`Protocol.lua:184-202`). `TechnologyCount` cộng vào BA chỗ:
	  · kinh nghiệm của tuyến công nghệ (`GameGuildTechnology[strName].Exp`),
	  · cá nhân đóng góp (`GameUserGuildData.GuildContribution`) — `ResourceType 5`,
	  · tài nguyên bang (`GameUserGuildData.Resouce`) — `ResourceType 6`.
	Hai chỗ sau là chính nội dung `PrizeID 11..15` của bảng `KDBGamePrizeConfig`
	(mỗi PrizeID chứa đúng `{GuildContribution +N, GuildResource +N}`).

	[GHIM] CÁCH LÊN CẤP: config có `Exp` LUỸ TIẾN theo từng cấp (Lv1 200, Lv2 400,
	Lv3 600 … — chênh 200/cấp ở các tuyến 50 cấp). Chọn cách "trừ dần" — mỗi cấp
	tiêu `Exp` của cấp KẾ, dư chuyển tiếp — vì đó là cách duy nhất làm thanh kinh
	nghiệm UI (`data.Exp .. "/" .. nextCfg.Exp`, `CUIGuildScienceDlg.lua:250-255`)
	không vượt 100%. Máy chủ gốc đã chết nên KHÔNG có nguồn thứ hai để đối chiếu.
]]
local function cauHinhQuyenGop(nIndex)
	local ok, cfg = pcall(function ()
		return G_ConfigManager:GetGameTchecknologyDonateConfig(tonumber(nIndex) or 0)
	end)
	if ok and type(cfg) == "table" then return cfg end
	return nil
end

local function cauHinhCongNghe(strName, nLevel)
	local ok, cfg = pcall(function ()
		return G_ConfigManager:GetGameGuildTchecknologyConfig(tostring(strName), tonumber(nLevel) or 0)
	end)
	if ok and type(cfg) == "table" then return cfg end
	return nil
end

local function vipCuaMinh()
	local ok, r, b = pcall(function () return G_UserLogic:GetBaseInfo() end)
	if ok then
		local t = (type(b) == "table") and b or ((type(r) == "table") and r or nil)
		if t then return tonumber(t.VipLevel) or 0 end
	end
	return 0
end

R:on("G_GuildLogic.ClientDonateGuildTechnology", function (ctx, strName, nIndex)
	local b = bang()
	if b == nil then
		goi(ctx, "OnDonateGuildTechnology")
		thongBao(ma("GuildNotExist", 3501))
		return
	end

	local cfg = cauHinhQuyenGop(nIndex)
	if cfg == nil then
		thongBao(2)     -- ArgError: chỉ số đóng góp không có trong cấu hình
		goi(ctx, "OnDonateGuildTechnology")
		return
	end

	-- ⚠ BA giá trị: `GetUserGuildTechnology` trả `(bResult, entry)`.
	local okTech, bTech, tech = pcall(function () return G_GuildLogic:GetUserGuildTechnology(tostring(strName)) end)
	if not okTech or bTech == false or type(tech) ~= "table" then
		thongBao(2)
		goi(ctx, "OnDonateGuildTechnology")
		return
	end
	local cap = tonumber(tech.Level) or 0
	local exp = tonumber(tech.Exp) or 0
	local keTiep = cauHinhCongNghe(strName, cap + 1)
	if keTiep == nil then
		-- Đã cấp cao nhất (UI cũng chặn nút). Không có mã riêng ⇒ ArgError.
		OfflineLog:info(TEN_FILE .. ": cong nghe " .. tostring(strName) .. " da cap cao nhat")
		thongBao(2)
		goi(ctx, "OnDonateGuildTechnology")
		return
	end

	local vipCan = tonumber(cfg.VipLimite) or 0
	if vipCuaMinh() < vipCan then
		local okVip, mVip = pcall(function ()
			return _G.ErrorCode and ErrorCode.VIP and ErrorCode.VIP.NoEnoughVipLevel
		end)
		thongBao((okVip and tonumber(mVip)) or 3401)
		goi(ctx, "OnDonateGuildTechnology")
		return
	end

	-- Trừ tiền bằng hàm GỐC (nó tự bắn sự kiện OnCostGold/OnCostDiamond).
	local loai = tonumber(cfg.ResourceType) or 1
	local gia = tonumber(cfg.ResourceCount) or 0
	local okTru, daTru
	if loai == 1 then
		okTru, daTru = pcall(function () return G_UserLogic:CostGold(gia, "GuildTechnology") end)
	else
		okTru, daTru = pcall(function () return G_UserLogic:CostDiamond(gia, "GuildTechnology") end)
	end
	if not okTru or daTru ~= true then
		local m = (loai == 1) and maChung("NotEnoughGold", 500) or maChung("NotEnoughDiamond", 504)
		OfflineLog:info(string.format("%s: dong gop cong nghe thieu tien (%s %d)", TEN_FILE,
			loai == 1 and "vang" or "ngoc", gia))
		thongBao(m)
		goi(ctx, "OnDonateGuildTechnology")
		return
	end

	-- Cộng kinh nghiệm + lên cấp (trừ dần theo `Exp` của cấp kế).
	local them = tonumber(cfg.TechnologyCount) or 0
	exp = exp + them
	local lenCap = false
	while true do
		local cfgKe = cauHinhCongNghe(strName, cap + 1)
		if cfgKe == nil or exp < (tonumber(cfgKe.Exp) or math.huge) then break end
		exp = exp - (tonumber(cfgKe.Exp) or 0)
		cap = cap + 1
		lenCap = true
	end
	tech.Level = cap
	tech.Exp = exp
	tech.Name = tech.Name or tonumber(strName) or strName

	-- Cá nhân đóng góp + tài nguyên bang (đúng hai tài nguyên trong PrizeID 11..15).
	local gu = layBangDuLieu("GameUserGuildData")
	if gu ~= nil then
		gu.GuildContribution = (tonumber(gu.GuildContribution) or 0) + them
		gu.Resouce = (tonumber(gu.Resouce) or 0) + them
	end
	dongBo()

	OfflineLog:info(string.format(
		"%s: dong gop cong nghe '%s' bac %d (%s %d) -> +%d exp, cap %d, exp %d",
		TEN_FILE, tostring(strName), tonumber(nIndex) or 0,
		loai == 1 and "vang" or "ngoc", gia, them, cap, exp))

	-- Hàm nhận không đối số; UI đổi số liệu khi nhận sự kiện `DonateGuildTechnology`.
	if lenCap then
		goi(ctx, "OnGuildTechnologyLevelUp", tostring(strName), cap, exp)
	end
	pcall(function ()
		G_EventManager:PostLogicEvent(nil, EventManagerLogicEvent.Guild.OnDonateGuildTechnology)
	end)
	goi(ctx, "OnDonateGuildTechnology")
end)

------------------------------------------------------------------- XÚC XẮC ("我要神将")
--[[ Trạng thái nằm trong `GameUserLottery`, ĐÚNG các trường UI đọc:
	DiceGameData (6 mặt), DiceGamePlayTimes, DiceGameFreeChange, DiceGamePayChange,
	DiceGameValue (quy ước "số mặt 6 × 10^số mặt 6": `100` = một lần 2 mặt 6,
	`2000` = hai lần 3 mặt 6 — `CUIShakeDice.lua:806-815`).

	[MOI] `DiceGameDay` + `DiceGamePlan`: máy chủ gốc đặt lại mỗi ngày và chọn một
	kế hoạch trong `StartPlan` theo `Rate`. Không lưu thì lượt cộng dồn vĩnh viễn.
	Mốc 5 giờ dùng CHUNG với `offline/qua_ngay.lua`.
]]
local function khoaNgay()
	local now = os.time()
	local t = os.date("*t", now)
	if t.hour < MOC_NGAY then now = now - 86400 end
	local d = os.date("*t", now)
	return d.year * 10000 + d.month * 100 + d.day
end

local function cauHinhXucXac()
	local ok, cfg = pcall(function ()
		return G_ConfigManager:GetCommonConfigWithName("DiceGameConfig")
	end)
	if ok and type(cfg) == "table" then return cfg end
	return nil
end

-- Chọn kế hoạch theo `Rate`; trả dãy số mặt 6 cho 5 lượt.
local function chonKeHoach(cfg)
	local ds = cfg and cfg.StartPlan
	if type(ds) ~= "table" then return { 0, 0, 0, 0, 0 } end
	local tong = 0
	for _, p in ipairs(ds) do tong = tong + (tonumber(p.Rate) or 0) end
	if tong <= 0 then return ds[1] and ds[1].GodTimesData or { 0 } end
	local r = math.random() * tong
	local acc = 0
	for _, p in ipairs(ds) do
		acc = acc + (tonumber(p.Rate) or 0)
		if r <= acc and type(p.GodTimesData) == "table" then return p.GodTimesData end
	end
	return ds[1] and ds[1].GodTimesData or { 0 }
end

trangThaiXucXac = function ()
	local cfg = cauHinhXucXac()
	if cfg == nil then return nil, nil end
	local t = layBangDuLieu("GameUserLottery")
	if t == nil then
		t = {}
		pcall(function () G_DataManager:SetUserDataWithName("GameUserLottery", t) end)
	end
	local key = khoaNgay()
	if tonumber(t.DiceGameDay) ~= key then
		t.DiceGameDay = key
		t.DiceGamePlayTimes = 0
		t.DiceGameFreeChange = 0
		t.DiceGamePayChange = 0
		t.DiceGameValue = 0
		t.DiceGameData = nil
		t.DiceGamePlan = chonKeHoach(cfg)
		OfflineLog:info(string.format("%s: xuc xac sang ngay moi (khoa %d)", TEN_FILE, key))
	end
	return t, cfg
end

-- Dựng 6 mặt: `soSau` mặt là 6, còn lại 1..5, rồi xáo.
local function taoXucXac(soSau)
	local d = {}
	for i = 1, 6 do d[i] = (i <= soSau) and 6 or math.random(1, 5) end
	for i = 6, 2, -1 do
		local j = math.random(i)
		d[i], d[j] = d[j], d[i]
	end
	return d
end

-- Quy ước giá trị: `nCount × 10^nMaxNum` (xem `GetMaxNumByValue`, CUIShakeDice.lua:818).
local function giaiMaGiaTri(v)
	if v <= 0 then return 0, 0 end
	local maxNum = math.floor(math.log10(v))
	local nCount = math.floor(v / (10 ^ maxNum))
	return maxNum, nCount
end

local function capNhatGiaTri(t, soSau)
	local cu = tonumber(t.DiceGameValue) or 0
	local maxCu = 0
	if cu > 0 then maxCu = math.floor(math.log10(cu)) end
	if soSau > maxCu then
		t.DiceGameValue = 10 ^ soSau
	elseif soSau == maxCu then
		t.DiceGameValue = cu + (10 ^ soSau)
	end
end

local function nguoiChoi()
	local ok, bRet, tHot = pcall(function () return G_RankLogic:GetUserHotData() end)
	local d = {}
	if ok and bRet == true and type(tHot) == "table" then
		for k, v in pairs(tHot) do d[k] = v end
	else
		local ok2, ten = pcall(function () return G_UserLogic:GetCharacterName() end)
		d.CharacterName = (ok2 and tostring(ten)) or "Offline"
	end
	d.CharacterName = d.CharacterName or "Offline"
	return d
end

--[[ `ClientGetDiceGameData` → `OnGetDiceGameData(tData)`. UI đọc
	`tData.BestPlayer.{DiceGameValue, HotData}` và `tData.RewardInfo.{PrizeData, GodHeroId}`
	để đổi bảng thưởng theo vị thần hộ mệnh (`CUIShakeDice.lua:140-155`). ]]
R:on("G_GuildLogic.ClientGetDiceGameData", function (ctx)
	local t, cfg = trangThaiXucXac()
	if t == nil then
		baoLoi(ctx, 2, "thieu DiceGameConfig")
		return
	end
	local value = tonumber(t.DiceGameValue) or 0
	local maxNum, nCount = giaiMaGiaTri(value)
	local best = {
		DiceGameValue = value,
		HotData = nguoiChoi(),
		MaxNum = maxNum,
		nCount = nCount,
	}
	goi(ctx, "OnGetDiceGameData", {
		BestPlayer = best,
		RewardInfo = { PrizeData = cfg.PrizeData, GodHeroId = cfg.GodHeroId },
	})
	OfflineLog:info(string.format("%s: xuc xac — da dung %s/%s luot, ky luc %s",
		TEN_FILE, tostring(t.DiceGamePlayTimes or 0), tostring(cfg.PlayTimes or 0), tostring(value)))
end)

--[[ `ClientPlayDiceGame` → `OnPlayDiceGame(tData)`. Mỗi lượt SINH MỚI 6 mặt theo
	kế hoạch của ngày. Offline KHÔNG có "改投" vì config này thiếu
	`FreeChangeTimes`/`PayChangeTimes` (UI đọc ra 0 ⇒ nút đổi bị ẩn). ]]
R:on("G_GuildLogic.ClientPlayDiceGame", function (ctx)
	local t, cfg = trangThaiXucXac()
	if t == nil then
		baoLoi(ctx, 2, "thieu DiceGameConfig")
		return
	end
	local daDung = tonumber(t.DiceGamePlayTimes) or 0
	local toiDa = tonumber(cfg.PlayTimes) or 0
	if daDung >= toiDa then
		baoLoi(ctx, maXucXac("NotEnoughPlayTimes", 4700), "het luot xuc xac")
		return
	end

	local ke = t.DiceGamePlan
	if type(ke) ~= "table" then
		ke = chonKeHoach(cfg)
		t.DiceGamePlan = ke
	end
	local soSau = tonumber(ke[daDung + 1]) or tonumber(ke[#ke]) or 0
	t.DiceGameData = taoXucXac(soSau)
	t.DiceGamePlayTimes = daDung + 1
	dongBo()

	OfflineLog:info(string.format("%s: xuc xac luot %d/%d — %d mat 6",
		TEN_FILE, daDung + 1, toiDa, soSau))
	goi(ctx, "OnPlayDiceGame", { DiceGameData = t.DiceGameData })
end)

--[[ `ClientGetDiceGameReward` → `OnGetDiceGameReward(tData)`. Thưởng theo SỐ MẶT 6
	trong `PrizeData` (các cặp số-mặt-6 → PrizeID, 0..6), phát bằng đường THƯỞNG GỐC
	`ChapterLogic:SetDataWithPrizeData`. Nhận xong xoá 6 mặt để lượt sau đổ lại. ]]
R:on("G_GuildLogic.ClientGetDiceGameReward", function (ctx)
	local t, cfg = trangThaiXucXac()
	if t == nil then
		baoLoi(ctx, 2, "thieu DiceGameConfig")
		return
	end
	local d = t.DiceGameData
	if type(d) ~= "table" or #d == 0 then
		baoLoi(ctx, maXucXac("NoReward", 4703), "chua do xuc xac")
		return
	end

	local soSau = 0
	for _, v in ipairs(d) do
		if tonumber(v) == 6 then soSau = soSau + 1 end
	end

	local nPrizeID = nil
	if type(cfg.PrizeData) == "table" then
		for _, cap in ipairs(cfg.PrizeData) do
			if type(cap) == "table" and tonumber(cap[1]) == soSau then
				nPrizeID = tonumber(cap[2])
				break
			end
		end
	end
	if nPrizeID == nil then
		baoLoi(ctx, maXucXac("NoReward", 4703), "khong co thuong cho " .. tostring(soSau) .. " mat 6")
		return
	end

	-- Bẩy họ `GetItemCount`: `pcall` cho BA giá trị (ok, bResult, prize).
	local okLay, bLay, prize = pcall(function ()
		return G_PrizeLogic:GetPrizeWithID(nPrizeID)
	end)
	if not okLay or bLay == false or type(prize) ~= "table" then
		baoLoi(ctx, 2, "khong doc duoc PrizeID " .. tostring(nPrizeID))
		return
	end
	local okPhat, daPhat = pcall(function ()
		return G_ChapterLogic:SetDataWithPrizeData(prize, 1, "DiceGame")
	end)
	if not okPhat or daPhat ~= true then
		baoLoi(ctx, 2, "khong phat duoc thuong xuc xac")
		return
	end

	capNhatGiaTri(t, soSau)
	t.DiceGameData = nil
	dongBo()

	OfflineLog:info(string.format("%s: nhan thuong xuc xac — %d mat 6, PrizeID %d, ky luc %s",
		TEN_FILE, soSau, nPrizeID, tostring(t.DiceGameValue)))
	goi(ctx, "OnGetDiceGameReward", {})
end)

------------------------------------------------------------------- ĐIỀU TƯỚNG
--[[ Dữ liệu: `GameUserGuildData.MapDispatchHero` — ĐÚNG bảng client đọc
	(`ClientGuildDispatchLogic.lua:309-340`). Mỗi phần tử:
	{HeroId, HeroPower, DispatchTime, BeEmployTimes, HostUid}.
	Thu nhập khi thu hồi tính ĐÚNG công thức client hiển thị
	(`GetHasGenerateCoin`: 15 vàng/phút giữ + HeroPower × 1.5 / 10 × số lần được thuê) [GHIM].
]]
local function duLieuBang()
	return layBangDuLieu("GameUserGuildData")
end

local function danhSachDieuTuong()
	local gu = duLieuBang()
	local ra = {}
	if gu == nil or type(gu.MapDispatchHero) ~= "table" then return ra end
	for _, v in pairs(gu.MapDispatchHero) do
		if type(v) == "table" and tonumber(v.HeroId) then
			ra[#ra + 1] = v
		end
	end
	table.sort(ra, function (a, b) return (tonumber(a.DispatchTime) or 0) < (tonumber(b.DispatchTime) or 0) end)
	return ra
end

local function ghiDieuTuong(gu, map)
	if gu == nil then return false end
	gu.MapDispatchHero = map
	dongBo()
	return true
end

-- Dừng lớp tải của màn điều tướng (UI dùng khoá "CUIGuildDispatch").
local function dungTaiDieuTuong()
	pcall(function ()
		G_EventManager:PostLogicEvent("CUIGuildDispatch", EventManagerLogicEvent.OnReceiveResponse)
	end)
end

--[[ Điều một tướng sang bang. Kiểm đúng thứ tự UI + mã gốc:
	chưa có bang 3501 · không phải tướng của mình → 3507 · là CHỦ CÔNG 3534 ·
	trùng tướng 3513 · quá 3 tướng 3512. ]]
R:on("G_GuildLogic.ClientDispatchHero", function (ctx, nGuildId, nHeroId)
	local b = bang()
	if b == nil then
		dungTaiDieuTuong()
		thongBao(ma("GuildNotExist", 3501))
		return
	end

	local heroId = tonumber(nHeroId)
	local okHero, bHero, tHero = pcall(function ()
		return G_HeroLogic:GetHeroWithID(heroId)
	end)
	if not okHero or bHero == false or type(tHero) ~= "table" then
		dungTaiDieuTuong()
		thongBao(ma("GuildAuthLess", 3507))
		return
	end
	local okChar, laChuCong = pcall(function () return G_HeroLogic:IsCharacter(tHero) end)
	if okChar and laChuCong == true then
		dungTaiDieuTuong()
		thongBao(ma("GuildCantMainRole", 3534))
		return
	end

	local gu = duLieuBang()
	if gu == nil then
		dungTaiDieuTuong()
		thongBao(ma("GuildNotExist", 3501))
		return
	end
	local map = type(gu.MapDispatchHero) == "table" and gu.MapDispatchHero or {}
	if map[tostring(heroId)] ~= nil then
		dungTaiDieuTuong()
		thongBao(ma("GuildRedisptach", 3513))
		return
	end
	local dem = 0
	for _ in pairs(map) do dem = dem + 1 end
	if dem >= MAX_DIEU_TUONG then
		dungTaiDieuTuong()
		thongBao(ma("GuildDisptachFull", 3512))
		return
	end

	local okFight, bFight, nFight = pcall(function ()
		return G_HeroLogic:GetHeroAllFightCapacityWithHero(tHero)
	end)
	map[tostring(heroId)] = {
		HeroId = heroId,
		HeroPower = (okFight and bFight ~= false and tonumber(nFight)) or 0,
		DispatchTime = os.time(),
		BeEmployTimes = 0,
		HostUid = uid(),
	}
	ghiDieuTuong(gu, map)
	OfflineLog:info(string.format("%s: dieu tuong %d sang bang (luc chien %s)",
		TEN_FILE, heroId, tostring(map[tostring(heroId)].HeroPower)))

	-- Không có hàm nhận `onDispatchHero` (bị chú thích trong client) ⇒ trả bằng
	-- đúng gói mà màn điều tướng đang chờ: danh sách của mình.
	goi(ctx, "onQuerySelfDispatchList", { RetData = danhSachDieuTuong() })
end)

R:on("G_GuildLogic.ClientQuerySelfDispatchList", function (ctx, nGuildId)
	goi(ctx, "onQuerySelfDispatchList", { RetData = danhSachDieuTuong() })
end)

--[[ Danh sách tướng CHO THUÊ của cả bang. Offline chỉ có tướng của CHÍNH MÌNH, mà
	`CUIBattleDeploy:initGuildHeroListView` tự bỏ qua `NHostUid == uid` ⇒ danh sách
	rỗng là câu trả lời đúng, không phải dữ liệu bịa. ]]
R:on("G_GuildLogic.ClientGetDispatchHeroList", function (ctx, nGuildId)
	OfflineLog:info(TEN_FILE .. ": danh sach tuong cho thue -> rong (chi co tuong cua minh)")
	goi(ctx, "OnGetDispatchHeroList", 0, {})
end)

--[[ Thu hồi tướng đã điều. Yêu cầu của client: phải giữ ÍT NHẤT 30 phút
	(`CheckHeroIsCanPick`, 3517), rồi cộng vàng theo công thức trên. ]]
R:on("G_GuildLogic.ClientPickGuildHero", function (ctx, nHeroId)
	local heroId = tonumber(nHeroId)
	local gu = duLieuBang()
	local map = (gu and type(gu.MapDispatchHero) == "table") and gu.MapDispatchHero or nil
	local muc = map and map[tostring(heroId)]
	if muc == nil then
		dungTaiDieuTuong()
		thongBao(ma("GuildNotExist", 3501))
		return
	end

	local now = os.time()
	local giu = now - (tonumber(muc.DispatchTime) or now)
	if giu <= 30 * 60 then
		dungTaiDieuTuong()
		thongBao(ma("GuildNotEnoughTime", 3517))
		return
	end

	local luc = tonumber(muc.HeroPower) or 0
	local soLanThue = tonumber(muc.BeEmployTimes) or 0
	local tienThue = math.floor(luc * 1.5 / 10 * soLanThue)
	local tienGiu = math.ceil((giu / 60) * 15)
	local tong = math.floor(tienThue + tienGiu)

	map[tostring(heroId)] = nil
	ghiDieuTuong(gu, map)
	if tong > 0 then
		pcall(function () G_UserLogic:AddGold(tong, "GuildDispatch") end)
	end

	OfflineLog:info(string.format("%s: thu hoi tuong %d sau %d phut -> +%d vang",
		TEN_FILE, heroId, math.floor(giu / 60), tong))
	goi(ctx, "OnPickGuildHero", { RetData = tong })
end)

--[[ Thuê tướng của NGƯỜI KHÁC: offline không có ai. Mã gốc 3514
	"你雇佣的英雄已经变动" là mã gần nhất cho "không còn tướng ấy để thuê". ]]
R:on("G_GuildLogic.ClientEmployDispatchHero", function (ctx, nHeroId, nHostUid, nGuildId, nFightType)
	baoLoi(ctx, ma("GuildDisptchInfoChange", 3514), "khong co tuong cua nguoi khac")
end)

OfflineLog:info("bang hoi (nang cao): da noi 23 khoa (thanh vien/thiet lap/cong nghe/xuc xac/dieu tuong)")

return true
