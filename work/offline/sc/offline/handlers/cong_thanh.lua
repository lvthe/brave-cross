--[[
	offline/handlers/cong_thanh.lua — CÔNG THÀNH (军团讨伐 / GuildWar) — mô hình "chưa mở".

	15 khoá `G_GuildWarLogic` (`ClientGuildWarLogic`, thực thể `G_GuildWarLogic`) mà client
	gọi khi mở màn Công Thành. Trước lượt này KHÔNG có handler nào ⇒ mở màn là lớp tải quay mãi.

	VÌ SAO "CHƯA MỞ" LÀ CÂU TRẢ LỜI ĐÚNG, KHÔNG PHẢI ĐỐI PHÓ:
	công thành là **hai bang đánh nhau** (tuyên chiến, đánh boss chung, bảng điểm). Máy chủ giả
	này chỉ có MỘT người chơi trong MỘT bang, nên không có trận nào để mở. Mã lỗi GỐC cho đúng
	tình huống này đã có sẵn: **`GuildWarNoFightData = 3538`** — "không đủ bang hội để mở hoạt
	động" (`share/error.lua`). Dùng nó thay vì bịa một trận giả.

	HÌNH GỌI: MỌI hàm nhận của họ này có chữ ký `(eventList, nErrCode, ...)` — tham số ĐẦU là
	một BẢNG (client kiểm `ProcessNotTable` rồi thoát), nên phải truyền `{}` chứ không phải nil.
	Mỗi hàm có đuôi tham số khác nhau → bảng `DS` dưới đây ghi đúng đuôi của từng hàm.

	KHÔNG đăng ký 3 khoá chết (`KickGuildWarMember`-họ đo được 0 chỗ gọi) — chúng nằm trong
	CON-LAI kèm lý do.
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineCongThanh = OfflineCongThanh or {}

local R = OfflineRouter
local TEN_FILE = "cong thanh"

--[[ khoá client gửi → { tên hàm nhận, các tham số ĐUÔI sau (nErrCode) }.
	`eventList` luôn là `{}`. ]]
local DS = {
	-- { khoá, hàm nhận, đuôi tham số, SỐ đuôi (ghi rõ để giữ được nil ở CUỐI) }
	{ "QueryScore",               "OnQueryScore",               {}, 0 },
	{ "QueryGuildWarRank",        "OnQueryGuildWarRank",        {}, 0 },
	{ "SetGuildWarFightHero",     "OnSetGuildWarFightHero",     {}, 0 },
	{ "QueryAccnList",            "OnQueryAccnList",            {}, 0 },
	{ "AnnounceWar",              "OnAnnounceWar",              {}, 0 },
	{ "GetGuildWarInfo",          "OnGetGuildWarInfo",          { nil }, 1 },
	{ "GetGuildWarMockFightData", "OnGetGuildWarMockFightData", {}, 0 },
	{ "AttackWarBoss",            "OnAttackWarBoss",            { 0, 0 }, 2 },
	{ "AngerAttackWarBoss",       "OnAngerAttackWarBoss",       { {} }, 1 },
	{ "CheckCanChangeTeam",       "OnCheckCanChangeTeam",       { false }, 1 },
	{ "GetCanBeAttackUser",       "OnGetCanBeAttackUser",       { nil, "", "", 0 }, 4 },
	{ "QueryAttckCanBeAttack",    "OnQueryAttckCanBeAttack",    { false }, 1 },
	{ "GuildWarFightBegin",       "OnGuildWarFightBegin",       { nil }, 1 },
	{ "GuildWarCompeleteFight",   "OnGuildWarCompeleteFight",   { 0 }, 1 },
	{ "QueryGuildWarEndInfo",     "OnQueryGuildWarEndInfo",     { nil }, 1 },
}

-- Mã GỐC `GuildWarNoFightData = 3538` nằm trong bảng `ErrorCode.Guild` (`share/error.lua:485`).
-- ⚠ Đọc LÚC CHẠY, không phải lúc nạp tệp: bộ thử PC nạp lớp offline khi `ErrorCode` chưa có
-- ⇒ đọc ở phạm vi tệp sẽ nổ `attempt to index global 'ErrorCode'` và làm đỏ CẢ bộ thử.
local function ma()
	return (_G.ErrorCode and ErrorCode.Guild and ErrorCode.Guild.GuildWarNoFightData) or 3538
end

--[[ Đăng ký TỪNG khoá bằng CHUỖI HẰNG (không ghép chuỗi lúc nạp):
	bộ quét `_phu_rpc.dang_ky()` chỉ đọc `R:on("...")`, ghép chuỗi thì nó KHÔNG
	thấy khoá nào và CON-LAI đếm thiếu. Dùng `noi()` để khỏi lặp thân hàm. ]]
local function noi(khoa, hamNhan, duoi, nDuoi)
	return function (ctx)
		local nMa = ma()
		OfflineLog:info(string.format("%s: %s -> ma %d (chi mot bang, khong co tran)",
			TEN_FILE, khoa, nMa))
		-- (eventList, nErrCode, <đuôi riêng>) — gán theo CHỈ SỐ để giữ nil ở cuối.
		local goi = { {}, nMa }
		for i = 1, nDuoi do
			goi[i + 2] = duoi[i]
		end
		ctx:call("G_GuildWarLogic", hamNhan, unpack(goi, 1, 2 + nDuoi))
	end
end

R:on("G_GuildWarLogic.QueryScore", noi("QueryScore", "OnQueryScore", {}, 0))
R:on("G_GuildWarLogic.QueryGuildWarRank", noi("QueryGuildWarRank", "OnQueryGuildWarRank", {}, 0))
R:on("G_GuildWarLogic.SetGuildWarFightHero", noi("SetGuildWarFightHero", "OnSetGuildWarFightHero", {}, 0))
R:on("G_GuildWarLogic.QueryAccnList", noi("QueryAccnList", "OnQueryAccnList", {}, 0))
R:on("G_GuildWarLogic.AnnounceWar", noi("AnnounceWar", "OnAnnounceWar", {}, 0))
R:on("G_GuildWarLogic.GetGuildWarInfo", noi("GetGuildWarInfo", "OnGetGuildWarInfo", {nil}, 1))
R:on("G_GuildWarLogic.GetGuildWarMockFightData", noi("GetGuildWarMockFightData", "OnGetGuildWarMockFightData", {}, 0))
R:on("G_GuildWarLogic.AttackWarBoss", noi("AttackWarBoss", "OnAttackWarBoss", {0, 0}, 2))
R:on("G_GuildWarLogic.CheckCanChangeTeam", noi("CheckCanChangeTeam", "OnCheckCanChangeTeam", {false}, 1))
R:on("G_GuildWarLogic.AngerAttackWarBoss", noi("AngerAttackWarBoss", "OnAngerAttackWarBoss", { {} }, 1))
R:on("G_GuildWarLogic.GetCanBeAttackUser", noi("GetCanBeAttackUser", "OnGetCanBeAttackUser", {nil, "", "", 0}, 4))
R:on("G_GuildWarLogic.QueryAttckCanBeAttack", noi("QueryAttckCanBeAttack", "OnQueryAttckCanBeAttack", {false}, 1))
R:on("G_GuildWarLogic.GuildWarFightBegin", noi("GuildWarFightBegin", "OnGuildWarFightBegin", {nil}, 1))
R:on("G_GuildWarLogic.GuildWarCompeleteFight", noi("GuildWarCompeleteFight", "OnGuildWarCompeleteFight", {0}, 1))
R:on("G_GuildWarLogic.QueryGuildWarEndInfo", noi("QueryGuildWarEndInfo", "OnQueryGuildWarEndInfo", {nil}, 1))

OfflineLog:info(string.format("cong thanh: da noi %d khoa (mo hinh 'chua mo')", #DS))

return true
