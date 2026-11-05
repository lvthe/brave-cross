--[[
	offline/init.lua — điểm vào của lớp giả lập server.

	Được nạp từ cuối sc/user/require.lua (bản đè), tức là sau khi toàn bộ lớp
	client đã định nghĩa xong — cần thế vì ta phải vá vào CUIRPCManager và
	đọc S_CCSchedule.

	Cách nạp: package.path của game ưu tiên external storage rồi download path
	trước assets (sc/game.lua:60), nên chỉ cần đặt file vào đó là đè được, không
	phải đóng gói lại APK.
]]

require("offline.log")
require("offline.store")
require("offline.router")
require("offline.bootstrap")
require("offline.thong_ke")
require("offline.luc_chien")
require("offline.net")
-- LỊCH HOẠT ĐỘNG (31/10): nguồn DUY NHẤT cho trạng thái + cấu hình hoạt động mà
-- `ClientGetActivityList` trả về. Phải nạp TRƯỚC các handler dùng `OfflineHoatDong`.
require("offline.hoat_dong")

-- các nhóm handler; thêm file mới thì require thêm ở đây
require("offline.handlers.login")
require("offline.handlers.chapter")
-- ẢI VÔ TẬN (2/11): 9 khoá `G_EndlessChapterLogic` — vào trận/kết thúc/sang tầng/
-- chúc phúc/đặt lại/mua lượt/quét. Dựng lại bằng hằng số + hàm ĐỌC có thật của
-- `share/EndlessChapterLogic.lua`; ghi đè 9 dòng `chua_lam` cũ trong `endless.lua`.
require("offline.handlers.vong_vo_tan")
-- Mua lượt đánh lại ải bằng kim cương (30/10): luật gốc `costDiamondToResetBattleCount`
-- còn sống trong `share_ChapterLogic.lua:1106-1175` — xem `handlers/mua_luot_ai.lua`.
require("offline.handlers.mua_luot_ai")
-- Nhận thưởng thư (30/10): bốn lệnh client trước đây không có handler; luật là mã gốc
-- `MailLogic:saveMailPrizeAndStatus/saveMailPrizeList/setMailReadWithMailID`.
require("offline.handlers.hop_thu")
require("offline.handlers.achieve")
require("offline.handlers.statewar")
require("offline.handlers.mysterious")
require("offline.handlers.lottery")
require("offline.handlers.guild")
require("offline.handlers.cavern")
require("offline.handlers.endless")
require("offline.handlers.he_thong")
require("offline.handlers.trang_bi")
require("offline.handlers.binh_chung")
require("offline.handlers.vat_pham")
require("offline.handlers.tinh_nang")
-- Cường hoá trang bị (30/10): PHẢI nạp SAU `tinh_nang` — tệp ấy đăng ký ĐÈ hai khoá
-- này (`:138/:148`) bằng bản KHÔNG cộng cấp; ta ghi đè để cộng cấp + trả đủ tham số.
require("offline.handlers.trang_bi_cuong_hoa")
-- Nâng phẩm + tẩy luyện (30/10): luật gốc bỏ sót phần thuộc tính phụ — xem `handlers/trang_bi_pham.lua`.
require("offline.handlers.trang_bi_pham")
-- Trang bị độc quyền — đúc + tinh luyện (4/11 tiếp 11): `KDBGameExclusiveEquipConfig`.
require("offline.handlers.trang_bi_doc_quyen")
-- Cánh — tiến cấp (chúc phúc) + cường hoá (5/11): luật chép từ bản Axmol đã chốt 19/10.
require("offline.handlers.canh")
-- Dịch vụ ngoài thay SDK chết (5/11): mã đổi thưởng · bình luận · nhận khoản nạp.
require("offline.handlers.ma_doi")
require("offline.handlers.binh_luan")
require("offline.nap_api")
require("offline.hanh_dong")
require("offline.handlers.vong_quay")
require("offline.handlers.nhiem_vu_ngay")
require("offline.handlers.dau_truong")
-- Trận đấu trường offline (30/10): cấp FightData robot + kết toán — PHẢI nạp SAU
-- `dau_truong` (tệp ấy đăng ký 2306 cho cả nhóm trận).
require("offline.handlers.dau_truong_tran")
-- BXH đấu trường + dữ liệu đấu trường (30/10) — cũng phải SAU `dau_truong`.
require("offline.handlers.dau_truong_bxh")
-- Chi tiết đối thủ (30/10) — cùng nguồn FightData robot, cũng SAU `dau_truong`.
require("offline.handlers.dau_truong_chi_tiet")
-- ĐẤU TRƯỜNG PHẦN CÒN (2/11): làm mới cửa hàng bằng danh vọng, thông tin tướng trên
-- bảng hạng, đánh dấu đã xem chiến báo, tên cũ `GetArenaDetailByUid` — xem
-- `handlers/dau_truong_con.lua`. PHẢI nạp SAU `dau_truong_chi_tiet` (chuyển tiếp sang
-- handler chi tiết đối thủ ở đó).
require("offline.handlers.dau_truong_con")
-- Đổi tên + ảnh đại diện (30/10): ba lệnh cũ không có handler — xem `handlers/ca_nhan.lua`.
require("offline.handlers.ca_nhan")
-- Mua thể lực (30/10): luật gốc `UserLogic:buyFatigue` — xem `handlers/the_luc.lua`.
require("offline.handlers.the_luc")
-- Thần Bí / cửa hàng thần bí (30/10): sáu khoá, luật chép từ máy chủ giả — xem `handlers/than_bi.lua`.
require("offline.handlers.than_bi")
-- Nạp liên tục (30/10): ba khoá; offline KHÔNG có đường nạp tiền ⇒ từ chối trung thực — xem `handlers/nap_lien_tuc.lua`.
require("offline.handlers.nap_lien_tuc")
-- Quà tân thủ (30/10): ba khoá; offline không có đường nạp tiền ⇒ 4301 trung thực — xem `handlers/tan_thu.lua`.
require("offline.handlers.tan_thu")
-- THẺ THÁNG (31/10): `ClientGetReward` gọi luật gốc `MonthlyCardLogic:GetReward`;
-- `OfflineTheThang:kichHoat` mở đường kích hoạt qua lệnh GM `thethang` — PHẢI nạp
-- TRƯỚC `nap_gia_lap` (tệp ấy dùng tới `OfflineTheThang`).
require("offline.handlers.the_thang")
-- Nạp tiền GIẢ LẬP (30/10): mở đường cho Nạp liên tục / Quà tân thủ / mua thể lực.
require("offline.nap_gia_lap")
-- THỜI TRANG (31/10): ghép + nhận thưởng + đánh dấu đã mặc — xem `handlers/thoi_trang.lua`.
require("offline.handlers.thoi_trang")
-- TRẬN PHÁP (31/10): nâng cấp / kích hoạt Rare / chọn Advanced — xem `handlers/tran_phap.lua`.
require("offline.handlers.tran_phap")
-- LUYỆN HERO (31/10): gán tướng vào ô / lĩnh thưởng / truy vấn — xem `handlers/luyen_hero.lua`.
require("offline.handlers.luyen_hero")
-- QUỸ CẤP / QUỸ THỜI GIAN (31/10): ba khoá `G_ActivityFund`, dựa trên lịch `offline/hoat_dong.lua`.
require("offline.handlers.quy_hoat_dong")
-- HOẠT ĐỘNG TÍCH LUỸ (31/10): nạp / tiêu — 4 khoá; chạy được ngay khi chủ dự án
-- điền `OfflineHoatDong.MO_THEM` (xem đầu `handlers/hoat_dong_tich_luy.lua`).
require("offline.handlers.hoat_dong_tich_luy")
-- TINH HỒN (31/10): 13 khoá `G_StarSoulProtocol`; `ClientGetReq` trả dữ liệu THẬT,
-- 12 khoá thao tác trả 5400 Closed (chưa có thân hàm trong `share/`).
require("offline.handlers.tinh_hon")
-- NHÓM objName RỖNG "bắn rồi quên" (31/10): 7 khoá không chờ phản hồi.
require("offline.handlers.toan_cuc")
-- NĂM KHOÁ TOÀN CỤC CÒN SỐNG (2/11): thoại (3902), đánh dấu trang bị, đội hình đấu
-- trường, liên kết tài khoản (nuốt lặng có lý do), về nhà — xem `toan_cuc_con.lua`.
require("offline.handlers.toan_cuc_con")
-- Chat thường + lệnh `nap <tien>` (30/10) — đường kích hoạt KHÔNG cần GM console.
require("offline.handlers.chat")
-- QUÀ ĐĂNG NHẬP 7 NGÀY (1/11): `ClientSevenDaysGift` gọi luật gốc
-- `SevenDaysGiftLogic:saveSevenDaysGiftWithDay`. Cần `OfflineQua7Ngay:kiem_ngay` — xem
-- `handlers/qua_7_ngay.lua`.
require("offline.handlers.qua_7_ngay")
-- ĐIỂM KIM THỦ (1/11): `ClientRunMidasTouchWithCount` gọi luật gốc
-- `MidasTouchLogic:runMidasTouchWithCount`; máy chủ chỉ sinh `tRandomList` — xem
-- `handlers/kim_thu.lua`.
require("offline.handlers.kim_thu")
-- MỤC TIÊU ẢI (1/11): rương ở màn chọn ải; luật gốc `ChapterLogic:getChapterTargetReward`
-- + cấu hình `GameChapterConfig.TargetReward` — xem `handlers/muc_tieu_ai.lua`.
require("offline.handlers.muc_tieu_ai")
-- BẢNG XẾP HẠNG (1/11): bốn tab `G_RankLogic` (chiến lực 5 tướng + ba bảng PvE). Offline
-- một người ⇒ bảng rỗng + hạng 1, chính UI tự vá dòng của mình — xem
-- `handlers/bang_xep_hang.lua`.
require("offline.handlers.bang_xep_hang")
-- BXH CỦA CHẾ ĐỘ ẢI ĐẶC BIỆT (2/11): 14 khoá `G_RankLogic` (7 chế độ ải + phòng thủ
-- đấu trường + hổ phù bang hội). Offline một người ⇒ một dòng của mình, hạng 1; điểm
-- lấy từ thống kê THẬT (`MaxHJRQBatchCount`, `TGZZ/DKChapter…`) — xem
-- `handlers/bang_xep_hang_che_do.lua`.
require("offline.handlers.bang_xep_hang_che_do")
-- MUA VẬT PHẨM (1/11): `ClientBuyItem` / `ClientBuyItemBatch` gọi luật gốc
-- `ShopLogic:BuyGoods` + bảng giá `KDBGameGoodsConfig` — xem `handlers/mua_vat_pham.lua`.
require("offline.handlers.mua_vat_pham")
-- TINH LUYỆN TRANG BỊ (1/11): `ClientRefineEquip` — luật suy từ mã lỗi 1109/1110 + cấu
-- hình `EquipRefineConfig`; xem `handlers/tinh_luyen_trang_bi.lua`.
require("offline.handlers.tinh_luyen_trang_bi")
-- LUYỆN VẬT PHẨM RA TINH HOA (1/11): `ClientRefineItem` — tỉ lệ là trường `Concentrate`
-- của `KDBGameItemConfig`; xem `handlers/luyen_vat_pham.lua`.
require("offline.handlers.luyen_vat_pham")
-- CÁNH ĐANG HIỂN THỊ (1/11): `ClientShowWing` / `ClientShowMagicWing` — chỉ đổi cờ hiển thị
-- bằng hai hàm ghi có sẵn của `HeroDataManager`; xem `handlers/canh_hien_thi.lua`.
require("offline.handlers.canh_hien_thi")
-- THIÊN MỆNH CỦA TƯỚNG (1/11): `ClientUpdateHeroSkyFate` / `ClientResetHeroSkyFate` — giá
-- và cấp lấy từ `KDBGameHeroSkyFateConfig`; xem `handlers/thien_menh.lua`.
require("offline.handlers.thien_menh")
-- MẢNH VẠN NĂNG (1/11): `ClientConvertUniversalFragment` — danh sách trắng 90 tướng trong
-- `GameUniversalFragmentConfig`, đổi 1:1; xem `handlers/manh_van_nang.lua`.
require("offline.handlers.manh_van_nang")
-- VÕ HỒN (1/11): `ClientUpHeroFightSoul` — giá/tỉ lệ lấy từ `KDBGameFightSoulConfig`, công
-- thức tỉ lệ đọc từ UI (`20 + 10×Lv`); xem `handlers/vo_hon.lua`.
require("offline.handlers.vo_hon")
-- PHỤ ĐỀ THEO ẢI (1/11): `ClientSetUserCopySubtitle` / `ClientGetCopySubtitle` — lưu trong
-- client common data; xem `handlers/phu_de.lua`.
require("offline.handlers.phu_de")
-- TÊN NGẪU NHIÊN (1/11): `ClientGetRandomName` gọi `CharacterNameLogic:GetName` với cấu hình
-- tên THẬT; xem `handlers/ten_ngau_nhien.lua`.
require("offline.handlers.ten_ngau_nhien")
-- CÔNG THÀNH (1/11, mô hình nhiều người tối thiểu): 15 khoá `G_GuildWarLogic` trả "chưa mở"
-- bằng mã gốc 3538; xem `handlers/cong_thanh.lua`.
require("offline.handlers.cong_thanh")
-- COG / CÔNG THÀNH XUYÊN MÁY CHỦ (2/11): 25 khoá của `G_COGProtocol` +
-- `G_COGCityDefendMission` — mùa CHƯA MỞ (`Step = 0`), lệnh đọc trả dữ liệu thật
-- (28 thành từ cấu hình), thao tác trả mã gốc `ErrorCode.COGCode`; shop dùng điểm
-- COG thật. ⚠ Phản hồi phải đi qua `g_COGProtocol` (chữ thường) — xem đầu
-- `handlers/cog.lua`.
require("offline.handlers.cog")
-- BẠN BÈ (1/11, mô hình nhiều người tối thiểu): 14 khoá `G_FriendLogic` — đọc trả danh sách
-- rỗng, thao tác từ chối trung thực; xem `handlers/ban_be.lua`.
require("offline.handlers.ban_be")
-- BANG HỘI TỐI THIỂU (1/11, chủ dự án chọn): người chơi tự lập một bang, là bang chủ DUY NHẤT;
-- 8 khoá (lập/thông tin/thông báo/nhật ký/đơn xin/rời/giải tán/đóng góp) — xem
-- `handlers/bang_hoi.lua`. PHẢI nạp SAU `handlers/guild.lua` (tệp ấy trả "không có bang" cho
-- khoá toàn cục — nay chỉ còn là đường dự phòng).
require("offline.handlers.bang_hoi")
-- BANG HỘI PHẦN NÂNG CAO (2/11): 23 khoá — quản lý thành viên (một người ⇒ mã gốc
-- 3507/3523/3555), thiết lập bang, tìm/join/apply, THUẾ CÔNG NGHỆ (thật:
-- `KDBGameTchecknologyDonateConfig`), XÚC XẮC "我要神将" (thật: `DiceGameConfig` +
-- `GameUserLottery`), ĐIỀU TƯỚNG (thật: `GameUserGuildData.MapDispatchHero`).
-- PHẢI nạp SAU `bang_hoi` (dùng `OfflineBangHoi:doc/ghi/uid`).
require("offline.handlers.bang_hoi_nang_cao")
-- PHÓ BẢN BANG HỘI (2/11): 18 khoá `G_GuildChapterLogic` — mở/chuẩn bị/đánh/kết
-- toán + thưởng chung (xin & chia) + bảng sát thương. Dữ liệu THẬT: 4 phó bản
-- `ChapterType 9993`, máu boss `ChapterLogic:CalcGuildChapterBossHp`, thưởng
-- `GuildInjureConfig`, bể rơi `GuildChapterCommonDropData`. PHẢI nạp SAU `bang_hoi`.
require("offline.handlers.guild_chapter")
-- CHIẾN DỊCH ANH HÙNG (2/11): 5 khoá `G_EpicChapterLogic` — chọn phe/độ khó, đặt
-- lại ngày, kết thúc trận, quét danh vọng, shop EpicCoin. Dữ liệu `GameUserEpicChapter`
-- + cấu hình Epic 180 dòng; xem `handlers/epic.lua`.
require("offline.handlers.epic")
-- CHẾ ĐỘ ẢI ĐẶC BIỆT (2/11): 16 khoá `G_ChapterLogic` — 7 kết thúc (dùng NGUYÊN
-- `activityChapterComplete` của share), 4 càn quét (`chapterSweepHandle`), 5 tiện ích
-- (xem trước rơi, NPC SCS, phe ĐK, hồi sinh, sóng HJRQ). PHẢI nạp SAU `chapter`
-- (dùng `OfflineDrop_build`) — xem `handlers/ai_dac_biet.lua`.
require("offline.handlers.ai_dac_biet")
-- ĐẤU TRƯỜNG ĐIỂM (2/11): 13 khoá `G_ScoreCompetitivePlayProtocol` — mở được panel,
-- danh sách đối thủ/BXH/xem đối thủ từ **1000 robot** của cấu hình THẬT (luật sinh
-- robot còn nguyên trong `share/ScoreCompetitivePlay/`), đội phòng thủ THẬT, thưởng
-- thăng bậc + phục hồi điểm THẬT. BỐN khoá trận trả 5500 (không có bộ mô phỏng trận
-- phía máy chủ) — xem đầu `handlers/apr.lua`.
require("offline.handlers.apr")
-- NHỊP "VIỆC MÁY CHỦ LÀM MỖI NGÀY" (1/11): mở ngày quà 7 ngày + đặt lại lượt điểm kim
-- thủ. PHẢI nạp SAU hai tệp trên (nó gọi `kiem_ngay` của chúng). Xem `offline/qua_ngay.lua`.
require("offline.qua_ngay")
-- NHÀ CỬA (30/10): tạo `g_BuildingLogic` + `GetBuilding` + luật nâng nhà. Ba khoá
-- xây dựng ở `handlers/tinh_nang.lua` đã đăng ký từ trước nhưng gọi vào đối tượng
-- CHƯA TỪNG được tạo ⇒ luôn trả mã 1; xem đầu `offline/nha_cua.lua`.
require("offline.nha_cua")
-- LỚP CHẮN CUỐI (2/11): 100 khoá SỐNG còn lại của 34 module chưa có dữ liệu/luật.
-- Đăng ký để KHÔNG treo panel + trả mã GỐC của nhóm (4001/4401/5201/5002/2306/1).
-- ĐÂY KHÔNG PHẢI đã làm thật — xem `handlers/chua_ho_tro.lua`.
require("offline.handlers.chua_ho_tro")
-- THẦN BINH (2/11): 4 khoá `G_MagicWeaponProtocol` LÀM THẬT — lên/giáng sao, cường
-- hoá bằng exp nguyên liệu, đột phá; cấu hình `GameMagicWeaponRefineConfig` +
-- `GameMagicWeaponItemExpConfig` + `GameMagicWeaponStrengthConfig` — xem
-- `handlers/than_binh.lua`. (4 khoá này đã được gỡ khỏi lớp chắn.)
require("offline.handlers.than_binh")
-- DOANH TRẠI BANG HỘI (2/11): 8 khoá G_GuildCampLogic — mô hình MỘT NGƯỜI với đúng
-- cửa giờ/hồi của bản gốc (tưới 9–21, hồi 120 phút, 25 lần; củi 20–21, 3 lần/ngày,
-- hồi 120 giây). Thưởng cây KHÔNG có bảng (config rỗng) — xem `handlers/guild_camp.lua`.
require("offline.handlers.guild_camp")

Offline = {}
Offline.VERSION = "0.1"

--[[ Bịt tầng chạm database.

	Bản client để trống hàm này (sc/share/share_CDataManager.lua:207) vì phần
	thân là của server. Trả về bảng rỗng thay vì nil để các đường dẫn gọi
	GetUserDataWithName cho một bảng chưa có không vỡ.

	NGOẠI LỆ (TU_DUNG): vài bảng có DataManager riêng TỰ DỰNG hình dạng gốc,
	nhưng CHỈ khi bảng là NIL — ví dụ CavernDataManager:GetUserCavern
	(share/CavernDataManager.lua:42) kiểm `== nil` rồi gọi CraeteUserCavern().
	Trả {} rỗng thì client tưởng đã có dữ liệu, bỏ qua bước dựng, rồi màn hình
	đọc trường nil (`CurrentProgress`) và vỡ (CUICavern.lua:971). Với các bảng
	đó trả NIL để client tự dựng ĐÚNG hình dạng gốc — không bịa.

	Danh sách nằm ở `OfflineStore.TU_DUNG` (store.lua) chứ không ở đây: cả
	bootstrap lẫn chỗ này đều phải đọc CÙNG một danh sách. ]]
--[[ 4/11 (tiếp 6) — VÒNG LẶP `initUserDataFromDB` LÀM ĐỨNG GAME.

	ĐO: mở panel `CUITourMerchant` ("Bộ Thao", chính kịch bản hướng dẫn mở ở
	`CGuideScheme.lua:3149`) ⇒ mỗi KHUNG HÌNH panel gọi `getLeftStandingTime` →
	`GetUserDataWithName("GameUserCloudShop")`. Bản vá cũ trả `0, {}` và để CHỖ GỌI
	tự gán lại vào `userData`; lần gọi sau vẫn thấy `nil` ⇒ lặp **~50 dòng/giây**,
	file log phình **+500 KB/phút**, game đứng.

	Hai vá:
	  (1) GHI THẲNG khoá vào `mgr.userData` ngay trong hàm vá — không trông vào
	      chỗ gọi (đường `CClientDataManager` đi qua PROXY lớp cha `self[CDataManager]`,
	      nên chỗ gọi và đối tượng nhận có thể khác nhau).
	  (2) Giới hạn nhật ký: chỉ một dòng mỗi giây cho mỗi tên; nếu lặp ≥ 20 lần/giây
	      thì ghi MỘT traceback để lần sau biết ai gọi (chẩn đoán, không phải hành vi).
]]
local demInit = {}

--[[ HÌNH AN TOÀN cho vài bảng mà client đọc SỐ HỌC / CHUỖI ngay khi panel mở.

	`GameUserCloudShop` (panel "Bộ Thao" / `CUITourMerchant`): hàm đếm ngược
	`getLeftStandingTime` (`ClientTourMerchantLogic.lua:57`) cộng thẳng
	`tUserCloudShop.ComeTime`; `{}` ⇒ "attempt to perform arithmetic on a nil value"
	**mỗi khung hình**. `ComeTime = 0` = "chưa có thương nhân đứng", đúng nhánh
	`tUserCloudShop == nil` của chính client (`:54-56`, trả 0). Các trường khác
	(`GoodsList`, `Status`, `MapBuyTimes`) client đã tự gác nil. ]]
local HINH_AN_TOAN = {
	GameUserCloudShop = { ComeTime = 0 },
}

--[[ 4/11 (tiếp 7) — MA ĐỘNG: `CurrentDefender` VẮNG ⇒ panel ném lỗi.

	ĐO: `luot_panel` mở 21 panel, 20 OK, panel 06 `MaDong` ném
	`CUICavern.lua:330: attempt to index field 'CurrentDefender' (a nil value)`.
	Vì: `GameUserCavern` do server/cầu dựng có `ProgressState = 0` (Fight) nên UI đi
	nhánh `:325-331` và đọc `self.tCavernData.CurrentDefender`; hàm tạo gốc
	`CavernDataManager:CraeteUserCavern` (`share/CavernDataManager.lua:116-133`)
	CŨNG KHÔNG có trường này — nó là trạng thái trận do MÁY CHỦ sinh (đội phòng thủ
	của lượt đang đánh).

	Vá ở ĐÚNG chỗ đọc: bọc `CavernDataManager:GetUserCavern` để bảo đảm
	`CurrentDefender` là BẢNG (rỗng khi chưa có lượt đánh). UI gặp `[1] = nil` thì
	`ProcessNotTable` cho qua và `goto Exit0` — panel vẽ được, không ném. ]]
local function patchCavern()
	--[[ BẪY: `class.lua` giữ phương thức trong `vtbl` ẨN — `CavernDataManager.GetUserCavern`
	là **nil** trên bảng LỚP (bảng lớp chỉ có `ctor/super/new`). Phải bọc trên
	THỰC THỂ `G_CavernDataManager` (lớp thật là `ClientCavernDataManager`). ]]
	local inst = rawget(_G, "G_CavernDataManager")
	if inst == nil then
		OfflineLog:err("khong thay G_CavernDataManager — bo qua va Ma Dong")
		return
	end
	local goc = nil
	pcall(function () goc = inst.GetUserCavern end)
	if type(goc) ~= "function" then
		OfflineLog:err("khong thay G_CavernDataManager:GetUserCavern — bo qua va Ma Dong")
		return
	end
	inst.GetUserCavern = function(self, ...)
		local a, b = goc(self, ...)
		if type(b) == "table" and b.CurrentDefender == nil then
			b.CurrentDefender = {}
		end
		return a, b
	end
	OfflineLog:info("da boc G_CavernDataManager:GetUserCavern (CurrentDefender an toan)")
end

local function patchDataManager()
	if not CDataManager then
		OfflineLog:err("khong tim thay CDataManager — nap sai thu tu?")
		return
	end
	CDataManager.initUserDataFromDB = function(mgr, strModuleName)
		local k = tostring(strModuleName)
		local giay = os.time()
		local c = demInit[k]
		if c == nil or c.giay ~= giay then
			demInit[k] = { giay = giay, n = 1 }
			OfflineLog:info("initUserDataFromDB: " .. k)
		else
			c.n = c.n + 1
			if c.n == 20 then
				OfflineLog:warn("initUserDataFromDB LAP >=20 lan/giay: " .. k
					.. " | userData=" .. tostring(mgr ~= nil and type(mgr.userData))
					.. "\n" .. tostring(debug.traceback("", 2)))
			end
		end
		--[[ 4/11 (tiếp 9) — `HINH_AN_TOAN` PHẢI ĐỨNG TRƯỚC `TU_DUNG`.

			ĐO trong `offline.log` lượt 22:53: cảnh Main gọi
			`initUserDataFromDB("GameUserCloudShop")` **mỗi khung hình**, ≥20 lần/giây
			suốt 13 giây (mỗi giây một dòng log + một `debug.traceback`). Nguyên nhân:
			`GameUserCloudShop` nằm trong `TU_DUNG`, nhánh này `return 0, nil` TRƯỚC
			nên `HINH_AN_TOAN` (bản vá tiếp 6) không bao giờ chạy. Mà
			`GetUserDataWithName` chỉ cache khi giá trị KHÁC nil
			(`share_CDataManager.lua:225`) ⇒ khung hình sau lại thấy nil, lại gọi
			init. Đó đúng là vòng lặp mà tiếp 6 định chặn.

			`HINH_AN_TOAN` đã được kiểm với CẢ NĂM chỗ đọc `GameUserCloudShop`:
			`getLeftStandingTime` (:50, có sẵn nhánh nil), `getTourMerchantStatus`
			(:110, gác `Status == nil`), `isGoodsSoldOut` (:174, gác
			`MapBuyTimes ~= nil`), `CUITourMerchant:_initData` (:179,
			`ProcessNotString(GoodsList)` → thoát). Trả bảng có `ComeTime = 0` cho
			kết quả Y HỆT nhánh nil của client ("chưa có thương nhân đứng"), nhưng
			KHÁC nil ở chỗ CACHE ĐƯỢC ⇒ hết lặp. ]]
		local hinh = strModuleName ~= nil and HINH_AN_TOAN[strModuleName] or nil
		if hinh == nil and strModuleName ~= nil and OfflineStore.TU_DUNG[strModuleName] then
			return 0, nil
		end
		local t = {}
		if hinh ~= nil then
			for k, v in pairs(hinh) do t[k] = v end
		end
		pcall(function ()
			if mgr ~= nil and type(mgr.userData) == "table" and strModuleName ~= nil then
				t = mgr.userData[strModuleName] or t
				mgr.userData[strModuleName] = t
			end
		end)
		return 0, t
	end
end

function Offline:start()
	OfflineLog:info(string.format("khoi dong lop offline v%s", self.VERSION))

	patchDataManager()
	patchCavern()
	OfflineNet:install()

	--[[ Bọc phễu thể lực. `init.lua` được nạp từ cuối `sc/user/require.lua`,
	    tức SAU khi toàn bộ lớp client đã định nghĩa xong — chỗ này vá được
	    `CDataManager` thì cũng thấy được `G_UserLogic`. Vẫn kiểm và NÓI RA nếu
	    không thấy, đừng để mốc "quà mốc chương" chết im lặng. ]]
	if OfflineThongKe:dam_bao() then
		OfflineLog:info("da boc G_UserLogic:AddFatigueValue — thong ke "
			.. OfflineThongKe.KHOA .. " duoc ghi theo the luc da tieu")
	else
		OfflineLog:err("KHONG boc duoc G_UserLogic:AddFatigueValue — "
			.. OfflineThongKe.KHOA .. " se khong tang, moc 3000 dung yen")
	end

	--[[ Lực chiến: nối vào sự kiện `OnEnterGame` của client chứ không gọi thẳng
	    từ handler đăng nhập — vì `ctx:call` chỉ ĐẨY vào hàng đợi, khung hình sau
	    mới chạy, nên gọi thẳng ở đó là chạy trước khi dữ liệu vào tới client.
	    Đo được và giải thích đầy đủ ở `offline/luc_chien.lua`. ]]
	if OfflineLucChien:noi_su_kien() then
		OfflineLog:info("da noi OfflineLucChien vao su kien OnEnterGame")
	else
		OfflineLog:err("KHONG noi duoc OfflineLucChien vao OnEnterGame — "
			.. "luc chien se dung nguyen so 0 cua bang Reset")
	end

	-- NHÀ CỬA: cài SAU khi `OfflineNet:install()` + bọc G_UserLogic đã xong (cần cả hai).
	pcall(function () OfflineNhaCua:cai() end)

	-- VIỆC MỖI NGÀY: nối vào `OnEnterGame` (dữ liệu người chơi chỉ nạp khi handler
	-- `ClientEnterGame` tới, KHÔNG phải lúc `Offline:start()` — xem `offline/qua_ngay.lua`).
	if OfflineQuaNgay and OfflineQuaNgay:noi_su_kien() then
		OfflineLog:info("da noi OfflineQuaNgay vao su kien OnEnterGame")
	else
		OfflineLog:err("KHONG noi duoc OfflineQuaNgay — qua 7 ngay / luot kim thu se dung yen")
	end

	-- ĐẾM TIÊU (31/10): bọc CostGold/CostDiamond để hoạt động "tích luỹ tiêu" có nguồn số.
	-- Cây KHÔNG có hàm `GetUserConsumeCount` nào (grep 0) — xem đầu `handlers/hoat_dong_tich_luy.lua`.
	if OfflineTichLuy and OfflineTichLuy:dam_bao() then
		OfflineLog:info("da boc G_UserLogic:CostGold/CostDiamond — dem tien da tieu")
	else
		OfflineLog:err("KHONG boc duoc CostGold/CostDiamond — hoạt động tích luỹ tiêu sẽ đứng ở 0")
	end

	OfflineLog:info(string.format(
		"san sang — %d handler, file luu: %s",
		OfflineRouter:count(), OfflineStore:path()))
end

-- Tiện cho việc thử: xoá tiến trình chơi rồi khởi động lại game.
function Offline:wipe()
	OfflineStore:reset()
end

Offline:start()

-- CẦU RPC SANG SERVER THẬT (3/11) — phải nạp SAU `OfflineNet:install()` vì nó bọc
-- `OfflineNet.dispatch`. Chỉ các objName trong `OfflineNoiServer.NHOM` đi qua cầu.
require("offline.noi_server")

-- Đồ thử CẦU RPC (cờ `cau_rpc_test.flag`): gọi CallServer cho nhóm đã nối để đo
-- hai nhật ký (client `noi_server:` + server `[rpc]`) và mốc trong file lưu.
require("offline.thu_cau_rpc")
OfflineThuCauRpc:batDau()

-- Đồ thử panel "Bộ Thao" (`CUITourMerchant`, cờ `thu_merchant.flag`): mở đúng
-- đường hướng dẫn mở để đo vòng lặp `initUserDataFromDB` (4/11).
require("offline.thu_merchant")
OfflineThuMerchant:batDau()

-- Harness trace: tự đăng nhập (nếu màn đăng nhập hiện ra) rồi tự vào MỘT trận
-- khi cảnh Main dựng xong — để gắn Frida mà không phải bấm màn hình.
-- Đặt `OfflineTuDong.TAT` / `OfflineVaoTran.TAT` TRƯỚC khi nạp nếu không muốn.
require("offline.tu_dong")
OfflineTuDong:batDau()

require("offline.vao_tran")
OfflineVaoTran:batDau()

-- TỰ KIỂM trong game (31/10): chỉ chạy khi có tệp cờ `selftest.flag` cạnh file lưu.
-- Gọi THẲNG handler với ctx giả sau khi vào cảnh Main — xem `offline/thu_nhom_moi.lua`.
require("offline.thu_nhom_moi")
OfflineThuNhomMoi:batDau()

-- Đồ thử trang bị độc quyền (đúc/tinh luyện) — cờ `thu_doc_quyen.flag`.
require("offline.thu_doc_quyen")
OfflineThuDocQuyen:batDau()

-- Đồ thử CÁNH (tiến cấp/cường hoá) — cờ `thu_canh.flag`.
require("offline.thu_canh")
OfflineThuCanh:batDau()

-- Đồ thử: mở panel Cửa hàng bí ẩn + Hộp hồn rồi gọi đúng đường RPC (hai lối
-- vào bị khoá theo cấp/tài khoản nên bấm UI không tới). MẶC ĐỊNH TẮT.
require("offline.thu_hai_muc")
OfflineThuHaiMuc:batDau()

-- Đồ thử: nâng cấp + mở khoá mọi chức năng (chạy MỘT lượt, mặc định TẮT).
require("offline.nang_cap")
OfflineNangCap:batDau()

-- Đồ thử: mở lần lượt mọi lối vào ở cảnh Main (kiểm panel nào mở được).
require("offline.luot_panel")
OfflineLuotPanel:batDau()

-- Đồ thử: gọi các lệnh vừa nối vào luật gốc (handlers/tinh_nang.lua).
require("offline.thu_tinh_nang")
OfflineThuTinhNang:batDau()

-- CHẨN ĐOÁN TẠM (2/11): ai bật lớp "đang tải" không tắt. Chỉ chạy khi có
-- `chan_doan.flag` cạnh file lưu — xem đầu tệp.
require("offline.chan_doan")

-- TÀI KHOẢN (2/11): form đăng nhập/đăng ký gmail + mật khẩu, tài khoản lưu ở
-- Postgres của `bravecross-server` qua HTTP — xem đầu tệp.
require("offline.tai_khoan")

-- TỰ KIỂM LUỒNG TÀI KHOẢN (chỉ chạy khi có `taikhoan_test.flag`): gọi thẳng
-- handler, không cần bàn phím — xem đầu tệp. Đây là đồ thử, mặc định TẮT.
require("offline.thu_tai_khoan")

-- Tự kiểm ĐƯỜNG GIAO DIỆN (điền ô + bấm nút thật) — chỉ chạy khi có
-- `taikhoan_ui_test.flag`. Đồ thử, mặc định TẮT.
require("offline.thu_tai_khoan_ui")

-- Tự kiểm HAI LỆNH CHAT TÀI KHOẢN (`doimk` / `dangxuat`) — chỉ chạy khi có
-- `chat_tk_test.flag`. Gõ chat cần bàn phím (IME từng làm chết `system_server`),
-- nên đồ thử gọi THẲNG handler `ClientNotifyMessage` — xem đầu tệp ấy.
require("offline.thu_chat_tk")
OfflineThuChatTk:batDau()

-- Đăng nhập lại bằng tài khoản CŨ qua form thật (cờ `dangnhap_cu_test.flag` +
-- `dangnhap_cu.txt`) — để khép vòng "đăng xuất rồi đăng nhập tài khoản khác".
require("offline.thu_dang_nhap_cu")
OfflineThuDangNhapCu:batDau()

-- Tự kiểm `ClientPlayLottery` loại 5 (DIAMOND_FREE) + loại lạ — cờ `vongquay_test.flag`.
-- Lỗi 3/11: loại 5 không có nhánh ⇒ handler im lặng ⇒ lớp "đang tải" kẹt.
require("offline.thu_vong_quay")
OfflineThuVongQuay:batDau()

return Offline
