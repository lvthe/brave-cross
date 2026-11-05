--[[
	offline/handlers/bang_hoi.lua — BANG HỘI (quân đoàn) TỐI THIỂU.

	MÔ HÌNH: máy chủ giả này chỉ có MỘT người chơi, nên bang hội "nhiều người" không thể có
	thật. Ở đây dựng mô hình TỐI THIỂU: người chơi TỰ LẬP một bang, là BANG CHỦ và là THÀNH
	VIÊN DUY NHẤT. [MOI] — đây là quyết định sản phẩm của chủ dự án (chọn hướng "mô hình
	như���u người tối thiểu"), KHÔNG phải dữ liệu gốc.

	HÌNH DỮ LIỆU lấy từ chỗ CLIENT ĐỌC, không đoán:
	  · `ClientGuildLogic:GetGuildData()` (`ClientGuildApplyLogic.lua:393-420`) đọc bảng
	    `GameUserGuildData`; chỉ cần `GuildId > 0` là client coi như ĐANG Ở TRONG bang
	    (`CheckIsCanJoinGuild`, `:423-445`).
	  · `OnGetGuildInfo(nErrCode, tGuildInfo)` (`ClientGuildManageLogic.lua:283-330`) đưa
	    `tGuildInfo` cho UI. `CUIGuildInformation:refreshUI` đọc **`Name`, `GuildId`,
	    `StrNotice`, `PictrueId`, `memberList`**; tiêu đề thành viên đọc **`HeadUid`** và
	    **`Manager`** (`CUIGuildManage:GetGuildMemberTitilByUID`).

	ĐĂNG KÝ TRONG TỪNG LƯỢT (mỗi khoá đúng hình phản hồi của nó — KHÔNG gộp):
	  `ClientCreateGuild(pictrueId, name, notice)`            → `OnCreateGuild(tData)`
	  `ClientGetGuildInfo(pageNo, pageSize, guildId)`         → `OnGetGuildInfo(err, tGuildInfo)`
	  `ClientModifyNotice(guildId, notice, wechat, qq)`       → `OnModifyNotice(err)`
	  `ClientGetGuildLogList(guildId)`                        → `OnGetGuildLogList(err, tLogList)`
	  `ClientGetGuildApplyList(guildId)`                      → `OnGetGuildApplyList(err, tApplyList)`
	  `ClientExitGuild(guildId)`                              → `OnExitGuild()`
	  `ClientCancelGuild(guildId)`                            → `OnCancelGuild(err)`
	  `ClientDonateGuild(guildId, strType, amount)`           → `OnDonateGuild(err)`

	CHƯA LÀM (khai rõ, không bịa): xin vào bang khác / duyệt đơn / đá thành viên / phân quyền
	/ đổi chức / đóng thuế công nghệ / xúc xắc / điều tướng — những khoá ấy cần dữ liệu nhiều
	người mới có nghĩa; chúng vẫn nằm trong CON-LAI.
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineBangHoi = OfflineBangHoi or {}

local R = OfflineRouter
local TEN_FILE = "bang hoi"
local KHOA_LUU = "OfflineGuild"

local function dongBo()
	pcall(function () OfflineStore:syncFromClient() end)
end

local function baseInfo()
	local ok, r, b = pcall(function () return G_UserLogic:GetBaseInfo() end)
	if ok then
		if type(b) == "table" then return b end
		if type(r) == "table" then return r end
	end
	return nil
end

local function uid()
	local b = baseInfo()
	local n = b and tonumber(b.Uid)
	if n and n > 0 then return n end
	local ok, u = pcall(function () return OfflineStore:uid() end)
	return (ok and tonumber(u)) or 1
end

--[[ Bang đang có (nil nếu chưa lập). Lưu trong client common data -> vào file lưu. ]]
local function docBang()
	local ok, v = pcall(function ()
		local _, x = G_UserLogic:GetClientCommonData(KHOA_LUU)
		return x
	end)
	if ok and type(v) == "table" and tonumber(v.GuildId) then
		return v
	end
	return nil
end

local function ghiBang(b)
	local ok, r = pcall(function ()
		return G_UserLogic:SetClientCommonData(KHOA_LUU, b)
	end)
	if not ok or r ~= true then
		OfflineLog:err(TEN_FILE .. ": khong ghi duoc du lieu bang")
		return false
	end
	-- Đồng bộ cờ "đang ở trong bang" cho client — `GetGuildData` chỉ đọc `GuildId`.
	pcall(function ()
		local _, d = G_DataManager:GetUserDataWithName("GameUserGuildData")
		if type(d) == "table" then
			G_DataManager:ChangeUserData("GameUserGuildData",
				{ GuildId = b and b.GuildId or 0 }, "Table_Add")
		end
	end)
	return true
end

--[[ Một dòng thành viên — các trường lấy từ bản ghi người chơi thật. ]]
local function dongThanhVien(nUid)
	local b = baseInfo() or {}
	return {
		Uid = nUid,
		Nick = b.CharacterName or "Offline",
		Level = tonumber(b.Level) or 1,
		VipLevel = tonumber(b.VipLevel) or 0,
		FightPower = tonumber(b.UserFightCapacity) or 0,
		LastLoginTime = os.time(),
		Gender = b.Gender,
		Portrait = b.Portrait,
	}
end

local function taoBang(pictrueId, szTen, szNotice)
	local nUid = uid()
	local id = math.max(1, math.floor(os.time() % 1000000))
	return {
		GuildId = id,
		Name = tostring(szTen),
		PictrueId = tostring(pictrueId or "1"),
		StrNotice = tostring(szNotice or ""),
		StrWeChatGroup = "",
		StrQQGroup = "",
		HeadUid = nUid,
		Manager = "",
		-- Trường của bảng bang trong danh sách/tìm kiếm/thiết lập (`CUIGuildApply.lua:1542-1633`,
		-- `CUIGuildManage.lua:419-432`): `Type` 1 = cần duyệt, `AcceptLevel` = cấp tối thiểu.
		Type = 1,
		AcceptLevel = 1,
		MemberNum = 1,
		CreateTime = os.time(),
		memberList = { dongThanhVien(nUid) },
	}
end

local function thongBao(nMa)
	if nMa == nil or nMa == 0 then return end
	pcall(function ()
		g_CUINotificationCenter:PostNotification(
			CUINotificationEvent.OnServerRequestError, nMa)
	end)
end

--------------------------------------------------------------- lập bang
R:on("G_GuildLogic.ClientCreateGuild", function (ctx, pictrueId, szTen, szNotice)
	if type(szTen) ~= "string" or szTen == "" then
		OfflineLog:warn(TEN_FILE .. ": ten bang rong")
		ctx:call("G_GuildLogic", "OnCreateGuild", { err = ErrorCode.ArgError })
		return
	end
	if docBang() ~= nil then
		OfflineLog:info(TEN_FILE .. ": da o trong mot bang — tu choi lap them")
		ctx:call("G_GuildLogic", "OnCreateGuild", { err = ErrorCode.ArgError })
		return
	end

	local b = taoBang(pictrueId, szTen, szNotice)
	ghiBang(b)
	dongBo()
	OfflineLog:info(string.format("%s: lap bang '%s' (id %d), bang chu uid %d",
		TEN_FILE, b.Name, b.GuildId, b.HeadUid))
	ctx:call("G_GuildLogic", "OnCreateGuild", b)
end)

--------------------------------------------------------------- thông tin bang
R:on("G_GuildLogic.ClientGetGuildInfo", function (ctx, pageNo, pageSize, guildId)
	local b = docBang()
	if b == nil then
		-- Chưa có bang: trả ĐÚNG mã gốc `GuildNotExist = 3501` (cùng mã mà
		-- `handlers/guild.lua` đã dùng cho đường khoá toàn cục), KHÔNG bịa một bang rỗng.
		local nMa = (ErrorCode.Guild and ErrorCode.Guild.GuildNotExist) or 3501
		ctx:call("G_GuildLogic", "OnGetGuildInfo", nMa, nil)
		return
	end
	-- Cập nhật dòng của mình theo bản ghi hiện tại (cấp/chiến lực có thể đã đổi).
	b.memberList = { dongThanhVien(tonumber(b.HeadUid) or uid()) }
	-- Bản lưu tạo trước 2/11 chưa có ba trường dưới — điền mặc định để danh sách
	-- bang / màn thiết lập không đọc nil (`CUIGuildApply.lua:1586` đọc MemberNum).
	if type(b.Type) ~= "number" then b.Type = 1 end
	if type(b.AcceptLevel) ~= "number" then b.AcceptLevel = 1 end
	b.MemberNum = #b.memberList
	--[[ Tài nguyên bang + số lượt phân phát: client đọc ở `tGuildInfo.Resouce` /
		`tGuildInfo.ChapterDispatchTimes` (`ClientGuildManageLogic.lua:42-93`), còn
		nguồn THẬT là `GameUserGuildData`. Chép sang để màn bang + màn phân phát
		trùng số với `G_UserLogic:GetResourceWithType(GuildResource)`. ]]
	pcall(function ()
		local _, d = G_DataManager:GetUserDataWithName("GameUserGuildData")
		if type(d) == "table" then
			b.Resouce = tonumber(d.Resouce) or 0
			b.ChapterDispatchTimes = tonumber(d.ChapterDispatchTimes) or 0
		end
	end)
	ctx:call("G_GuildLogic", "OnGetGuildInfo", 0, b)
end)

--------------------------------------------------------------- đổi thông báo
R:on("G_GuildLogic.ClientModifyNotice", function (ctx, guildId, sNotice, sWeChat, sQQ)
	local b = docBang()
	if b == nil then
		thongBao(ErrorCode.ArgError)
		ctx:call("G_GuildLogic", "OnModifyNotice", ErrorCode.ArgError)
		return
	end
	b.StrNotice = tostring(sNotice or "")
	b.StrWeChatGroup = tostring(sWeChat or "")
	b.StrQQGroup = tostring(sQQ or "")
	ghiBang(b)
	dongBo()
	-- Client có hàm "đổi thông báo tại máy" đúng ba trường này — gọi cho UI khỏi chờ.
	pcall(function ()
		G_GuildLogic:OnGuildNoticeInfoChange(b.StrNotice, b.StrWeChatGroup, b.StrQQGroup)
	end)
	OfflineLog:info(TEN_FILE .. ": da doi thong bao")
	ctx:call("G_GuildLogic", "OnModifyNotice", 0)
end)

--------------------------------------------------------------- nhật ký / đơn xin / rời
R:on("G_GuildLogic.ClientGetGuildLogList", function (ctx)
	-- Một mình thì chưa có sự kiện nào để ghi; trả DANH SÁCH RỖNG (không phải nil).
	ctx:call("G_GuildLogic", "OnGetGuildLogList", 0, {})
end)

R:on("G_GuildLogic.ClientGetGuildApplyList", function (ctx)
	-- Không có ai để xin vào; trả DANH SÁCH RỖNG.
	ctx:call("G_GuildLogic", "OnGetGuildApplyList", 0, {})
end)

R:on("G_GuildLogic.ClientExitGuild", function (ctx)
	local b = docBang()
	if b == nil then
		ctx:call("G_GuildLogic", "OnExitGuild")
		return
	end
	--[[ Còn tướng đang ĐIỀU sang bang thì không được rời (mã gốc
		`GuildExitWithDispatch 3532`). `OnExitGuild()` KHÔNG có tham số mã lỗi nên
		báo qua đúng đường `OnReciveResponse` (dừng lớp tải + toast). ]]
	local gu = nil
	pcall(function ()
		local _, d = G_DataManager:GetUserDataWithName("GameUserGuildData")
		gu = d
	end)
	if type(gu) == "table" and type(gu.MapDispatchHero) == "table" then
		for _ in pairs(gu.MapDispatchHero) do
			local nMa = (ErrorCode and ErrorCode.Guild and ErrorCode.Guild.GuildExitWithDispatch) or 3532
			OfflineLog:info(TEN_FILE .. ": con tuong dang dieu -> khong cho roi bang (ma " .. tostring(nMa) .. ")")
			pcall(function ()
				ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", nMa, {})
			end)
			return
		end
	end
	ghiBang(nil)
	dongBo()
	OfflineLog:info(string.format("%s: roi bang '%s'", TEN_FILE, tostring(b.Name)))
	ctx:call("G_GuildLogic", "OnExitGuild")
end)

R:on("G_GuildLogic.ClientCancelGuild", function (ctx)
	local b = docBang()
	if b == nil then
		ctx:call("G_GuildLogic", "OnCancelGuild", ErrorCode.ArgError)
		return
	end
	ghiBang(nil)
	dongBo()
	OfflineLog:info(string.format("%s: giai tan bang '%s'", TEN_FILE, tostring(b.Name)))
	ctx:call("G_GuildLogic", "OnCancelGuild", 0)
end)

--------------------------------------------------------------- đóng góp
--[[ `ClientDonateGuild(guildId, strType, amount)`. Loại đóng góp và tỉ lệ nằm ở cấu hình
	`GameGuildGoodsConfig`/`GuildImpeachConfig` không chứa bảng quy đổi ⇒ CHƯA nối tiền thật;
	ở đây chỉ trả ĐÚNG "không có gì để đóng" thay vì đoán giá. Ghi rõ để lượt sau khỏi tưởng
	đã làm. ]]
R:on("G_GuildLogic.ClientDonateGuild", function (ctx, guildId, strType, amount)
	OfflineLog:warn(TEN_FILE .. ": ClientDonateGuild chua co bang gia — tra loi 'khong lam gi'")
	ctx:call("G_GuildLogic", "OnDonateGuild", ErrorCode.ArgError)
end)

--[[ Cho tệp khác (BXH bang hội) đọc CÙNG một bảng — không chép lại đường đọc. ]]
function OfflineBangHoi:bang()
	local b = docBang()
	if b == nil then return nil end
	return {
		GuildId = tonumber(b.GuildId),
		Name = b.Name,
		PictrueId = b.PictrueId,
		StrNotice = b.StrNotice,
		HeadUid = tonumber(b.HeadUid),
		MemberCount = type(b.memberList) == "table" and #b.memberList or 1,
	}
end

--[[ Xuất cho `handlers/bang_hoi_nang_cao.lua` (2/11) dùng CHUNG một nguồn ghi/đọc:
	bản đầy đủ (có memberList), hàm ghi, uid, và khuôn một dòng thành viên. Không
	xuất thì tệp kia phải chép lại khoá `OfflineGuild` + đường đồng bộ cờ GuildId —
	đúng kiểu đã sinh ra bẫy "hai bản lệch nhau". ]]
function OfflineBangHoi:doc()
	return docBang()
end

function OfflineBangHoi:ghi(b)
	return ghiBang(b)
end

function OfflineBangHoi:uid()
	return uid()
end

function OfflineBangHoi:dongThanhVien(nUid)
	return dongThanhVien(nUid)
end

OfflineLog:info("bang hoi: da noi 8 khoa (tao/thong tin/thong bao/nhat ky/don xin/roi/giai tan/dong gop)")

return true
