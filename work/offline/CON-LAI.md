# CON-LAI — khoá RPC lớp offline CHƯA có handler

Sinh tự động bằng `python -I _con_lai.py`. Đừng sửa tay.

| | |
|---|---|
| Tổng số TÊN hàm client gọi | **511** |
| Có handler (theo tên hàm) | **440** |
| **Còn thiếu (theo tên)** | **71** |
| Còn thiếu (theo cặp module+tên) | **73** |

## chua phan loai — 48 khoá

| module | số | ghi chú |
|---|---:|---|
| `(toan cuc)` | 32 |  |
| `G_ActivityGodHero` | 3 |  |
| `G_ActivityTongque` | 3 |  |
| `G_SysExchangeProtocol` | 2 |  |
| `G_ServerGuildWarScoreProtocol` | 2 |  |
| `G_ActivityLogic` | 1 |  |
| `G_WonderfulActivityLogic` | 1 |  |
| `G_ActivityLevelCapacity` | 1 |  |
| `G_StatisticsLog` | 1 |  |
| `G_GameWorld` | 1 |  |
| `G_Anniversary` | 1 |  |

## nhieu nguoi — 11 khoá

| module | số | ghi chú |
|---|---:|---|
| `G_ArenaLogic` | 7 | con lai chu yeu can doi thu that |
| `G_GuildWarLogic` | 3 | cong thanh: can bang hoi |
| `G_GuildStoreLogic` | 1 | cua hang bang hoi; share KHONG co phan ket toan |

## SDK chet — 10 khoá

| module | số | ghi chú |
|---|---:|---|
| `G_RechargeLogic` | 10 | thanh toan: ClientDealPayment bi chu thich ca hai cho |

## 0 than ham — 4 khoá

| module | số | ghi chú |
|---|---:|---|
| `G_HeroLogic` | 2 | canh/ky nang: 12 khoa 0 than trong share/ (do 30/10) |
| `G_TournamentLogic` | 1 | giai dau: 0 than ham trong 973 tep |
| `G_WCSProtocol` | 1 | giai dau the gioi: 0 than ham |

## Khoá lẻ (mỗi khoá phải phân tích riêng)

`(toan cuc)` — 32 khoá: ClientAgreeFriendApply, ClientAwardAhieve, ClientCancelBuildingUpgrade, ClientCancelUpgradeArmy, ClientChangeHeroEquipment, ClientCollectResouce, ClientCompleteUpgradeArmy, ClientCompleteUpgradeArmyWithDiomaon, ClientDecomposeEquipment, ClientDeleteMailWithMailId, ClientForgeEquipment, ClientGetAllUserData, ClientGetBattleReportsWithDate, ClientGetPassMissionCountList, ClientGetRecommendedUserList, ClientGetUserRelation, ClientGuestLogin, ClientGuestRegister, ClientHeroExpedition, ClientNormalLogin, ClientNormalRegister, ClientPotionExpedition, ClientReachAchieveWithEvent, ClientRefuseFriendApply, ClientRemoveFriendApply, ClientRemoveFriendRelation, ClientSaveMailPrizeWithMailId, ClientSearchUserWithUserName, ClientSellEquipment, ClientSetMailReadWithMailId, ClientSignIn, ClientStartLottery
