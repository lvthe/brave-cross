--[[
	offline/handlers/toan_cuc.lua — nhóm `objName` RỖNG: phần "bắn rồi quên".

	BỐI CẢNH: `_phu_rpc.py` đếm **56 khoá** client gọi với `CallServer(SERVER.GAME_LOGIC,
	"", "ClientX", …)` mà lớp offline chưa có handler. Không phải khoá nào cũng cần một
	handler — nhiều khoá KHÔNG CHỜ phản hồi, và vài khoá có chỗ gọi ĐÃ BỊ CHÚ THÍCH
	(đo trên 973 tệp: `grep -rn "\"ClientGetMissionData\""` và `"ClientSystemLog"`
	chỉ ra ĐÚNG một dòng, cả hai nằm trong `--`).

	TỆP NÀY CHỈ KHAI BAO "nuốt lặng" cho nhóm ấy — KHÔNG bịa luật nào. Mỗi mục ghi rõ
	vì sao nuốt được, để lượt sau không tưởng là đã nối.

	ĐO ĐƯỢC (chỗ gọi + có chờ phản hồi hay không):
	  · `ClientBeginGuide(guideId)` / `ClientCompeleGuide(guideId)` —
	    `CServerRequestLogic.lua:369-375` chỉ `CallServer`, KHÔNG bắn
	    `OnWaitingForRequest` ⇒ client không chờ gì. Lớp offline đã TẮT hướng dẫn
	    (`tu_dong` gọi `FinishGudie`), nên ghi nhận bước hướng dẫn là vô nghĩa.
	  · `ClientSystemLog` — `system/rpc.lua:238` là dòng ĐÃ CHÚ THÍCH; không ai gửi.
	  · `ClientGetMissionData` — `CUIChapterList.lua:955` ĐÃ CHÚ THÍCH; không ai gửi.
	  · `ClientTestAddMail` / `ClientTestFullLevelResouces` / `ClientTestFullWorker` —
	    lệnh THỬ của bản dev, không có nút nào trên bản phát hành.

	11 khoá còn lại của nhóm này (bạn bè, potion, ải, đăng ký/đăng nhập…) CHƯA làm:
	mỗi khoá cần đọc đúng hình phản hồi riêng — xem `CON-LAI.md`.
]]

require("offline.log")
require("offline.router")

local R = OfflineRouter

-- HỆ THUỐC (potion) — CHẾT TRONG BẢN GỐC. Đo: bốn chỗ gọi
-- (`CServerRequestLogic.lua:84/89/95/101`) nằm TRONG `--`; bốn hàm nhận cũng bị chú thích
-- (`CServerResponseLogic.lua:522+`); hai lệnh còn sống (`:112`, `:124`) chỉ CallServer,
-- KHÔNG bắn OnWaitingForRequest; `PotionConfig` bị chú thích trong ConfigTableName ⇒
-- gọi luật là nổ class.lua:66.
-- (Chú thích phải nằm NGOÀI ngoặc: bộ quét _phu_rpc cắt tại dấu ")" ĐẦU TIÊN.)
R:ignore(
    "ClientBeginGuide",
    "ClientCompeleGuide",
    "ClientSystemLog",
    "ClientGetMissionData",
    "ClientTestAddMail",
    "ClientTestFullLevelResouces",
    "ClientTestFullWorker",
    "ClientBuildPotion",
    "ClientCancelBuildPotion",
    "ClientCompleteBuildPotion",
    "ClientCompleteBuildPotionWithDiomaon",
    "ClientCancelUpgradePotion",
    "ClientCompleteUpgradePotionWithDiomaon"
)


------------------------------------------------------------------ QUy DOI KIM CUONG -> VANG
--[[ `ClientReduceDiamondToGold(nGoldNum)` (`CServerRequestLogic.lua:361-364`) →
	`OnReduceDiamondToGold(tData)` (`CServerResponseLogic.lua:992-1002`).

	LUẬT LÀ MÃ GỐC CÒN SỐNG: `CDataManager:reduceDiamondToGold(nGoldNum)`
	(`share_CDataManagerPrivate.lua:710-724`):
	    nDiamond = math.ceil(nGoldNum ^ 0.89 / 100)
	    nếu getDiamond() > nDiamond (NGẶT, không phải >=) thì trừ và cộng vàng.

	AI ÁP THAY ĐỔI: CHÍNH CLIENT — `OnReduceDiamondToGold` tự gọi
	`G_DataManager:ReduceDiamond(NeedDiamond)` + `AddResource(Gold, NeedGold)`.
	Vì thế handler này CHỈ TÍNH VÀ TRẢ LỜI, KHÔNG trừ lần nữa (trừ nữa là trừ ĐÔI).

	Mã lỗi: **4** tham số hỏng · **1702** `Resource.NoEnoughResource` khi không đủ
	kim cương (bản gốc không có mã riêng cho hàm này). ]]
R:on("ClientReduceDiamondToGold", function (ctx, nGoldNum)
	local n = tonumber(nGoldNum)
	if n == nil or n <= 0 or n ~= math.floor(n) then
		return ctx:reply({ err = 4 }, "OnReduceDiamondToGold", "")
	end

	local nDiamond = math.ceil((n ^ 0.89) / 100)
	local nCo = 0
	pcall(function ()
		local _, b = G_UserLogic:GetBaseInfo()
		nCo = tonumber(b and b.Diamond) or 0
	end)
	-- Bản gốc dùng `>` NGẶT: bằng đúng thì vẫn từ chối.
	if nCo <= nDiamond then
		OfflineLog:info(string.format("toan cuc: doi %d vang can %d kim cuong, dang co %d -> 1702",
			n, nDiamond, nCo))
		return ctx:reply({ err = 1702 }, "OnReduceDiamondToGold", "")
	end

	OfflineLog:info(string.format("toan cuc: doi %d vang = %d kim cuong", n, nDiamond))
	ctx:reply({ err = 0, data = { NeedDiamond = nDiamond, NeedGold = n } },
		"OnReduceDiamondToGold", "")
end)

OfflineLog:info("toan cuc: nuot lang 13 khoa 'ban roi quen' (huong dan / log / lenh dev)")

return true
