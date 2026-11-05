--[[
	offline/handlers/chua_ho_tro.lua — LỚP CHẮN CUỐI cho các RPC CÒN SỐNG chưa có dữ liệu.

	Sinh từ `_phan_loai_toancuc.py --tat-ca`: các khoá SỐNG còn lại (sau khi rút
	hai khoá trang bị độc quyền đã làm thật 4/11 tiếp 11).
	Mỗi khoá ĐƯỢC ĐĂNG KÝ (chuỗi HẰNG, không ghép) để:
	  1. KHÔNG còn dòng `THIEU` và KHÔNG còn panel quay mãi;
	  2. trả ĐÚNG mã GỐC của nhóm khi có (`ActivityNotOpen 4001`,
	     `TournamentCode.Closed 4401`, `WCSCode.Closed 5201`,
	     `MagicWeapon.SystemIsClosed 5002`, `Arenal.GetUserArenaDataFaild 2306`),
	     còn lại **1** (UnknowError);
	  3. ghi log một dòng nói RÕ vì sao nhóm ấy chưa làm — KHÔNG bịa dữ liệu.

	ĐÂY KHÔNG PHẢI "ĐÃ LÀM XONG": đây là lớp chắn để UI không treo. Việc làm THẬT từng
	nhóm (tournament bracket, WCS, guild camp, họ activity, magic weapon …) vẫn còn
	nguyên — xem README mục 2/11 (tiếp 9).

	Hai khoá nuốt LẶNG (mã 0, không toast) vì client không chờ / hệ đã chết:
	`G_Login.ClientBindingChannelAccount`, `G_PotionLogic.ClientCompleteUpgradePotion`.
]]

require("offline.log")
require("offline.store")
require("offline.router")

OfflineChuaHoTro = OfflineChuaHoTro or {}

local R = OfflineRouter
local TEN_FILE = "chua ho tro"

local function chuaHoTro(strObj, strFunc, nMa, strViSao)
	return function (ctx)
		OfflineLog:info(string.format("%s: %s.%s -> ma %d (%s)", TEN_FILE,
			tostring(strObj), tostring(strFunc), nMa, strViSao))
		pcall(function ()
			ctx:call("g_CUIGameRPCManager", "OnReciveResponse", "", "", nMa, {})
		end)
	end
end

-- G_TournamentLogic — giai dau do may chu van hanh theo vong — offline khong co bracket
R:on("G_TournamentLogic.ClientGetContestInfo", chuaHoTro("G_TournamentLogic", "ClientGetContestInfo", 4401, "giai dau do may chu van hanh theo vong — offline khong co bracket"))
R:on("G_TournamentLogic.ClientGetBattleReport", chuaHoTro("G_TournamentLogic", "ClientGetBattleReport", 4401, "giai dau do may chu van hanh theo vong — offline khong co bracket"))
R:on("G_TournamentLogic.ClientGetFinalsInfo", chuaHoTro("G_TournamentLogic", "ClientGetFinalsInfo", 4401, "giai dau do may chu van hanh theo vong — offline khong co bracket"))
R:on("G_TournamentLogic.ClientGetBattleArray", chuaHoTro("G_TournamentLogic", "ClientGetBattleArray", 4401, "giai dau do may chu van hanh theo vong — offline khong co bracket"))
R:on("G_TournamentLogic.ClientSaveBattleArray", chuaHoTro("G_TournamentLogic", "ClientSaveBattleArray", 4401, "giai dau do may chu van hanh theo vong — offline khong co bracket"))
R:on("G_TournamentLogic.ClientGetChampionInfo", chuaHoTro("G_TournamentLogic", "ClientGetChampionInfo", 4401, "giai dau do may chu van hanh theo vong — offline khong co bracket"))
R:on("G_TournamentLogic.ClientDoQuiz", chuaHoTro("G_TournamentLogic", "ClientDoQuiz", 4401, "giai dau do may chu van hanh theo vong — offline khong co bracket"))
R:on("G_TournamentLogic.ClientGetQuizInfo", chuaHoTro("G_TournamentLogic", "ClientGetQuizInfo", 4401, "giai dau do may chu van hanh theo vong — offline khong co bracket"))
R:on("G_TournamentLogic.ClientGetBattleDetailsReport", chuaHoTro("G_TournamentLogic", "ClientGetBattleDetailsReport", 4401, "giai dau do may chu van hanh theo vong — offline khong co bracket"))
R:on("G_TournamentLogic.ClientGetPlayback", chuaHoTro("G_TournamentLogic", "ClientGetPlayback", 4401, "giai dau do may chu van hanh theo vong — offline khong co bracket"))
R:on("G_TournamentLogic.ClientSendBenefitReward", chuaHoTro("G_TournamentLogic", "ClientSendBenefitReward", 4401, "giai dau do may chu van hanh theo vong — offline khong co bracket"))
R:on("G_TournamentLogic.ClientGetOtherInfo", chuaHoTro("G_TournamentLogic", "ClientGetOtherInfo", 4401, "giai dau do may chu van hanh theo vong — offline khong co bracket"))
R:on("G_TournamentLogic.ClientGetFinal32Info", chuaHoTro("G_TournamentLogic", "ClientGetFinal32Info", 4401, "giai dau do may chu van hanh theo vong — offline khong co bracket"))
R:on("G_TournamentLogic.ClientRequestFightTest", chuaHoTro("G_TournamentLogic", "ClientRequestFightTest", 4401, "giai dau do may chu van hanh theo vong — offline khong co bracket"))
R:on("G_TournamentLogic.ClientBuyTournamentGoods", chuaHoTro("G_TournamentLogic", "ClientBuyTournamentGoods", 4401, "giai dau do may chu van hanh theo vong — offline khong co bracket"))
R:on("G_TournamentLogic.ClientBuyWorldChampionshipGoods", chuaHoTro("G_TournamentLogic", "ClientBuyWorldChampionshipGoods", 4401, "giai dau do may chu van hanh theo vong — offline khong co bracket"))

-- G_RechargeLogic — SDK thanh toan da chet; offline khong co duong mua that
R:on("G_RechargeLogic.ClientGetPaymentConfig", chuaHoTro("G_RechargeLogic", "ClientGetPaymentConfig", 1, "SDK thanh toan da chet; offline khong co duong mua that"))
R:on("G_RechargeLogic.ClientGetFirstRechargeUserAndCount", chuaHoTro("G_RechargeLogic", "ClientGetFirstRechargeUserAndCount", 1, "SDK thanh toan da chet; offline khong co duong mua that"))
R:on("G_RechargeLogic.ClientGetIsHaveQQFeedBack", chuaHoTro("G_RechargeLogic", "ClientGetIsHaveQQFeedBack", 1, "SDK thanh toan da chet; offline khong co duong mua that"))
R:on("G_RechargeLogic.ClientGetQQPayFeedBack", chuaHoTro("G_RechargeLogic", "ClientGetQQPayFeedBack", 1, "SDK thanh toan da chet; offline khong co duong mua that"))
R:on("G_RechargeLogic.ClientIsHaveAndroidFeedBack", chuaHoTro("G_RechargeLogic", "ClientIsHaveAndroidFeedBack", 1, "SDK thanh toan da chet; offline khong co duong mua that"))
R:on("G_RechargeLogic.ClientGetAndoirdFeedBack", chuaHoTro("G_RechargeLogic", "ClientGetAndoirdFeedBack", 1, "SDK thanh toan da chet; offline khong co duong mua that"))

-- G_WCSProtocol — giai dau xuyen may chu — offline khong co may chu khac
R:on("G_WCSProtocol.ClientGetWCSInfo", chuaHoTro("G_WCSProtocol", "ClientGetWCSInfo", 5201, "giai dau xuyen may chu — offline khong co may chu khac"))
R:on("G_WCSProtocol.ClientGetBattleReport", chuaHoTro("G_WCSProtocol", "ClientGetBattleReport", 5201, "giai dau xuyen may chu — offline khong co may chu khac"))
R:on("G_WCSProtocol.ClientGetFinalsInfo", chuaHoTro("G_WCSProtocol", "ClientGetFinalsInfo", 5201, "giai dau xuyen may chu — offline khong co may chu khac"))
R:on("G_WCSProtocol.ClientGetBattleArray", chuaHoTro("G_WCSProtocol", "ClientGetBattleArray", 5201, "giai dau xuyen may chu — offline khong co may chu khac"))
R:on("G_WCSProtocol.ClientSaveBattleArray", chuaHoTro("G_WCSProtocol", "ClientSaveBattleArray", 5201, "giai dau xuyen may chu — offline khong co may chu khac"))
R:on("G_WCSProtocol.ClientDoQuiz", chuaHoTro("G_WCSProtocol", "ClientDoQuiz", 5201, "giai dau xuyen may chu — offline khong co may chu khac"))
R:on("G_WCSProtocol.ClientGetQuizInfo", chuaHoTro("G_WCSProtocol", "ClientGetQuizInfo", 5201, "giai dau xuyen may chu — offline khong co may chu khac"))
R:on("G_WCSProtocol.ClientGetAuditionDetailsReport", chuaHoTro("G_WCSProtocol", "ClientGetAuditionDetailsReport", 5201, "giai dau xuyen may chu — offline khong co may chu khac"))
R:on("G_WCSProtocol.ClientGetBattleDetailsReport", chuaHoTro("G_WCSProtocol", "ClientGetBattleDetailsReport", 5201, "giai dau xuyen may chu — offline khong co may chu khac"))
R:on("G_WCSProtocol.ClientGetPlayback", chuaHoTro("G_WCSProtocol", "ClientGetPlayback", 5201, "giai dau xuyen may chu — offline khong co may chu khac"))
R:on("G_WCSProtocol.ClientGetOtherInfo", chuaHoTro("G_WCSProtocol", "ClientGetOtherInfo", 5201, "giai dau xuyen may chu — offline khong co may chu khac"))
R:on("G_WCSProtocol.ClientGetFinal32Info", chuaHoTro("G_WCSProtocol", "ClientGetFinal32Info", 5201, "giai dau xuyen may chu — offline khong co may chu khac"))
R:on("G_WCSProtocol.ClientRequestFightTest", chuaHoTro("G_WCSProtocol", "ClientRequestFightTest", 5201, "giai dau xuyen may chu — offline khong co may chu khac"))

-- G_ArenaLogic — 4 khoá THẬT nay ở `handlers/dau_truong_con.lua`

-- G_GuildCampLogic — 8 khoá THẬT nay ở `handlers/guild_camp.lua` (mô hình một người)

-- G_FriendLogic — can tai khoan QQ/WeChat SDK (da chet)
R:on("G_FriendLogic.ClientGetQQWXFriendDetail", chuaHoTro("G_FriendLogic", "ClientGetQQWXFriendDetail", 1, "can tai khoan QQ/WeChat SDK (da chet)"))
R:on("G_FriendLogic.ClientGetQqWxFriendFatigue", chuaHoTro("G_FriendLogic", "ClientGetQqWxFriendFatigue", 1, "can tai khoan QQ/WeChat SDK (da chet)"))
R:on("G_FriendLogic.ClientSendQqWxFriendFatigue", chuaHoTro("G_FriendLogic", "ClientSendQqWxFriendFatigue", 1, "can tai khoan QQ/WeChat SDK (da chet)"))
R:on("G_FriendLogic.ClientBatchSendriendFatigue", chuaHoTro("G_FriendLogic", "ClientBatchSendriendFatigue", 1, "can tai khoan QQ/WeChat SDK (da chet)"))
R:on("G_FriendLogic.ClientBatchReceiveFriendFatigue", chuaHoTro("G_FriendLogic", "ClientBatchReceiveFriendFatigue", 1, "can tai khoan QQ/WeChat SDK (da chet)"))

-- G_HeroLogic: hai khoá cánh ĐÃ LÀM THẬT (5/11 — `handlers/canh.lua`), đã rút khỏi
-- lớp chắn. `ClientGetHeroExclusiveSkin` giữ chắn: nút kích hoạt trong client bị
-- `do return end` (`CUIHeroInfoExclusiveUI.lua:236`) ⇒ đường chết.
R:on("G_HeroLogic.ClientGetHeroExclusiveSkin", chuaHoTro("G_HeroLogic", "ClientGetHeroExclusiveSkin", 1, "canh/ky nang — nut kich hoat bi do return end (ma chet)"))

-- G_ActivityGodHero — chua co du lieu/luat trong ban offline
R:on("G_ActivityGodHero.ClientGetScorePrize", chuaHoTro("G_ActivityGodHero", "ClientGetScorePrize", 4001, "chua co du lieu/luat trong ban offline"))

-- G_ActivityRankLogic — chua co du lieu/luat trong ban offline
R:on("G_ActivityRankLogic.ClientGetPlayerDiamondConsume", chuaHoTro("G_ActivityRankLogic", "ClientGetPlayerDiamondConsume", 4001, "chua co du lieu/luat trong ban offline"))
R:on("G_ActivityRankLogic.ClientGetTop3DiamondConsume", chuaHoTro("G_ActivityRankLogic", "ClientGetTop3DiamondConsume", 4001, "chua co du lieu/luat trong ban offline"))
R:on("G_ActivityRankLogic.ClientGetPlayerPayment", chuaHoTro("G_ActivityRankLogic", "ClientGetPlayerPayment", 4001, "chua co du lieu/luat trong ban offline"))
R:on("G_ActivityRankLogic.ClientGetTop3Payment", chuaHoTro("G_ActivityRankLogic", "ClientGetTop3Payment", 4001, "chua co du lieu/luat trong ban offline"))

-- G_MagicWeaponProtocol — 4 khoá THẬT nay ở `handlers/than_binh.lua` (không đăng ký ở đây)

-- G_UserLogic — moi goi VIP / chia se / mua EXP — du lieu van hanh, khong co trong cau hinh ship
R:on("G_UserLogic.ClientBuyVipPackage", chuaHoTro("G_UserLogic", "ClientBuyVipPackage", 1, "moi goi VIP / chia se / mua EXP — du lieu van hanh, khong co trong cau hinh ship"))
R:on("G_UserLogic.ClientCompelateShareMessage", chuaHoTro("G_UserLogic", "ClientCompelateShareMessage", 1, "moi goi VIP / chia se / mua EXP — du lieu van hanh, khong co trong cau hinh ship"))
R:on("G_UserLogic.ClientBuyExpGoods", chuaHoTro("G_UserLogic", "ClientBuyExpGoods", 1, "moi goi VIP / chia se / mua EXP — du lieu van hanh, khong co trong cau hinh ship"))

-- G_ActivityWushuang — chua co du lieu/luat trong ban offline
R:on("G_ActivityWushuang.ClientGetWushuangRankList", chuaHoTro("G_ActivityWushuang", "ClientGetWushuangRankList", 4001, "chua co du lieu/luat trong ban offline"))
R:on("G_ActivityWushuang.ClientGetHistoryWushuangRankList", chuaHoTro("G_ActivityWushuang", "ClientGetHistoryWushuangRankList", 4001, "chua co du lieu/luat trong ban offline"))

-- G_ActivityShoppingLogic — chua co du lieu/luat trong ban offline
R:on("G_ActivityShoppingLogic.ClientActivityShopping", chuaHoTro("G_ActivityShoppingLogic", "ClientActivityShopping", 4001, "chua co du lieu/luat trong ban offline"))
R:on("G_ActivityShoppingLogic.ClientQueryActivityShoppingLimit", chuaHoTro("G_ActivityShoppingLogic", "ClientQueryActivityShoppingLimit", 4001, "chua co du lieu/luat trong ban offline"))

-- G_ActivityObjExchange — chua co du lieu/luat trong ban offline
R:on("G_ActivityObjExchange.ClientGetObjectExchangeList", chuaHoTro("G_ActivityObjExchange", "ClientGetObjectExchangeList", 4001, "chua co du lieu/luat trong ban offline"))
R:on("G_ActivityObjExchange.ClientObjectExchange", chuaHoTro("G_ActivityObjExchange", "ClientObjectExchange", 4001, "chua co du lieu/luat trong ban offline"))

-- G_EquipmentLogic: HAI khoá trang bị độc quyền ĐÃ LÀM THẬT (4/11 tiếp 11) —
-- xem `handlers/trang_bi_doc_quyen.lua`; đã rút khỏi lớp chắn này.

-- G_GuildStoreLogic — cua hang bang hoi — share khong co phan ket toan
R:on("G_GuildStoreLogic.ClientRefreshWithContribution", chuaHoTro("G_GuildStoreLogic", "ClientRefreshWithContribution", 1, "cua hang bang hoi — share khong co phan ket toan"))

-- G_MagicWeaponTreasureBox — chua co du lieu/luat trong ban offline
R:on("G_MagicWeaponTreasureBox.ClientOpenBoxWithKey", chuaHoTro("G_MagicWeaponTreasureBox", "ClientOpenBoxWithKey", 5002, "chua co du lieu/luat trong ban offline"))
R:on("G_MagicWeaponTreasureBox.ClientOpenBoxWithDiamond", chuaHoTro("G_MagicWeaponTreasureBox", "ClientOpenBoxWithDiamond", 5002, "chua co du lieu/luat trong ban offline"))

-- G_RechargeSignLogic — hoat dong diem danh nap do may chu van hanh
R:on("G_RechargeSignLogic.ClientGetRechargeSignMonthConfig", chuaHoTro("G_RechargeSignLogic", "ClientGetRechargeSignMonthConfig", 1, "hoat dong diem danh nap do may chu van hanh"))
R:on("G_RechargeSignLogic.ClientRechargeSignReward", chuaHoTro("G_RechargeSignLogic", "ClientRechargeSignReward", 1, "hoat dong diem danh nap do may chu van hanh"))

-- G_CloudShopLogic — cua hang dam may nhieu nguoi
R:on("G_CloudShopLogic.ClientChangeCloudShopStatus", chuaHoTro("G_CloudShopLogic", "ClientChangeCloudShopStatus", 1, "cua hang dam may nhieu nguoi"))
R:on("G_CloudShopLogic.ClientExchangePrize", chuaHoTro("G_CloudShopLogic", "ClientExchangePrize", 1, "cua hang dam may nhieu nguoi"))

-- G_ActivityWealthGod — chua co du lieu/luat trong ban offline
R:on("G_ActivityWealthGod.ClientGetInfoReq", chuaHoTro("G_ActivityWealthGod", "ClientGetInfoReq", 4001, "chua co du lieu/luat trong ban offline"))
R:on("G_ActivityWealthGod.ClientPushReq", chuaHoTro("G_ActivityWealthGod", "ClientPushReq", 4001, "chua co du lieu/luat trong ban offline"))

-- G_ActivityGuildRedPack — chua co du lieu/luat trong ban offline
R:on("G_ActivityGuildRedPack.ClientGetConfigReq", chuaHoTro("G_ActivityGuildRedPack", "ClientGetConfigReq", 4001, "chua co du lieu/luat trong ban offline"))
R:on("G_ActivityGuildRedPack.ClientGetRewardReq", chuaHoTro("G_ActivityGuildRedPack", "ClientGetRewardReq", 4001, "chua co du lieu/luat trong ban offline"))

-- G_ServerStateWarProtocol — chien truong trang thai nhieu nguoi
R:on("G_ServerStateWarProtocol.ClientEnterStateWarScene", chuaHoTro("G_ServerStateWarProtocol", "ClientEnterStateWarScene", 1, "chien truong trang thai nhieu nguoi"))
R:on("G_ServerStateWarProtocol.ClientGetMovingHistory", chuaHoTro("G_ServerStateWarProtocol", "ClientGetMovingHistory", 1, "chien truong trang thai nhieu nguoi"))

-- G_FreeStrengthLogic — chua co du lieu/luat trong ban offline
R:on("G_FreeStrengthLogic.ClientGetFreeStrength", chuaHoTro("G_FreeStrengthLogic", "ClientGetFreeStrength", 4001, "chua co du lieu/luat trong ban offline"))

-- G_GameCommentLogic: DA LAM THAT (5/11 — `handlers/binh_luan.lua`, ghi qua /api/comment).

-- G_AdventureLogic — kich hoat ky ngo do may chu van hanh
R:on("G_AdventureLogic.ClientShowTrigger", chuaHoTro("G_AdventureLogic", "ClientShowTrigger", 1, "kich hoat ky ngo do may chu van hanh"))

-- G_ServerTournamentPrizeLogic — giai dau do may chu van hanh — offline khong co bracket
R:on("G_ServerTournamentPrizeLogic.ClientGetWelfare", chuaHoTro("G_ServerTournamentPrizeLogic", "ClientGetWelfare", 4401, "giai dau do may chu van hanh — offline khong co bracket"))

-- G_ItemLogic — ban vat pham du thua — 0 than ham trong share/
R:on("G_ItemLogic.ClientSellRedundantExclusiveItem", chuaHoTro("G_ItemLogic", "ClientSellRedundantExclusiveItem", 1, "ban vat pham du thua — 0 than ham trong share/"))

-- G_Login — lien ket kenh — offline khong co he tai khoan
R:on("G_Login.ClientBindingChannelAccount", chuaHoTro("G_Login", "ClientBindingChannelAccount", 0, "lien ket kenh — offline khong co he tai khoan"))

-- G_PotionLogic — he thuoc da chet trong ban goc (PotionConfig bi chu thich)
R:on("G_PotionLogic.ClientCompleteUpgradePotion", chuaHoTro("G_PotionLogic", "ClientCompleteUpgradePotion", 0, "he thuoc da chet trong ban goc (PotionConfig bi chu thich)"))

-- G_RedeemCodeLogic: DA LAM THAT (5/11 — `handlers/ma_doi.lua`, kho mã ở server: /api/redeem).

-- G_TimeHeroLogic — tuong thoi gian — do may chu van hanh
R:on("G_TimeHeroLogic.ClientBuyTimeHero", chuaHoTro("G_TimeHeroLogic", "ClientBuyTimeHero", 1, "tuong thoi gian — do may chu van hanh"))

-- G_WeeklyFunLogic — hoat dong tuan do may chu van hanh
R:on("G_WeeklyFunLogic.ClientGetWeeklyFunPrize", chuaHoTro("G_WeeklyFunLogic", "ClientGetWeeklyFunPrize", 1, "hoat dong tuan do may chu van hanh"))

-- G_ServerActivityFightCap — hoat dong do may chu van hanh
R:on("G_ServerActivityFightCap.ClientGetInfoReq", chuaHoTro("G_ServerActivityFightCap", "ClientGetInfoReq", 4001, "hoat dong do may chu van hanh"))

-- G_ActivitySingleRecharge — chua co du lieu/luat trong ban offline
R:on("G_ActivitySingleRecharge.ClientGetSingleRechargePrize", chuaHoTro("G_ActivitySingleRecharge", "ClientGetSingleRechargePrize", 4001, "chua co du lieu/luat trong ban offline"))

OfflineLog:info("chua ho tro: da dang ky 78 khoa (lop chan, chua lam that)")

return true
