# Đặc tả API server — Búa Tạ (`com.xh.dachui.xsj 1.25.78923`)

Trích tự động từ 952 file Lua client đã giải mã. Mọi số liệu dưới đây đến từ chính mã nguồn, không suy đoán.

| | |
|---|---|
| Hàm server được client gọi | **584** (672 chỗ gọi) |
| — khai báo trực tiếp `CallServer("Tên", …)` | 484 |
| — sinh lúc chạy qua `bindRpcToEvent` ⟳ | 100 |
| Trong đó dò được handler trả về | 392 |
| Callback được API ở §3 dùng tới | 388 |
| Tổng hàm `On*` có trong client | 919 |
| Tên hàm dựng động (phải đọc tay) | 2 |

## 1. Giao thức

Vận chuyển: TCP, envelope **protobuf**, payload **JSON thuần** (`cjson`). Định nghĩa gốc ở `conf/kGameRequestData.proto`.

```protobuf
message GameActionData {
  optional int32  module   = 1;  // nhóm server, xem bảng §2
  optional string funcName = 2;  // TÊN HÀM server sẽ gọi
  optional int64  uid      = 3;
  optional string sessionId= 4;
  optional string data     = 5;  // mảng JSON chứa tham số
  optional uint32 connId   = 6;
  optional uint64 IP       = 7;
  optional string objName  = 8;  // đối tượng chứa hàm ("" = hàm toàn cục)
  optional uint64 serialID = 9;  // id giao dịch, dùng để khớp req/resp
  optional uint32 serverID = 10;
}
```

**Mô hình bất đồng bộ.** Client gọi xong không chờ kết quả. Server xử lý rồi *chủ động phát một RPC ngược lại* để trả kết quả — xem `sc/system/rpc.lua:5-8`.

Định tuyến hai chiều đều theo tên:

```lua
-- client -> server (rpc.lua:155)
CallServer(nModule, strObjName, strFunction, ...)
  --> data = cjson.encode({...})            -- mảng JSON các tham số

-- server -> client (rpc.lua:39, 84)
CallLocal(szObjName, szFunName, szData)
  --> obj = _G[szObjName];  func = obj and obj[szFunName] or _G[szFunName]
  --> func(obj, unpack(cjson.decode(szData)))
```

Server phải triển khai đúng tên hàm ở §3 và gọi ngược đúng tên handler ở §4. Payload trả về theo quy ước `{ err = <mã lỗi>, data = <nội dung> }` — mọi handler đều kiểm tra `tData.err ~= 0` trước tiên.

## 2. Các server con

`SERVER` định nghĩa tại `sc/share/Protocol.lua`. Cột cuối là số API client thực sự gọi.

| id | hằng số | số API dùng |
|---:|---|---:|
| 0 | `SERVER.WATCH_DOG` | — |
| 1 | `SERVER.LOGIN` | 8 |
| 2 | `SERVER.LOGIN_GATEWAY` | 1 |
| 3 | `SERVER.GAME_GATEWAY` | 3 |
| 4 | `SERVER.MESSAGE_CENTER` | — |
| 5 | `SERVER.GAME_LOGIC` | 501 |
| 6 | `SERVER.CHAT_FRIEND` | 15 |
| 7 | `SERVER.DATA_CENTER` | — |
| 8 | `SERVER.BATTLE` | — |
| 9 | `SERVER.DATABASE_SVR` | — |
| 10 | `SERVER.PAY` | — |
| 11 | `SERVER.LOG` | — |
| 12 | `SERVER.SERVER_MANAGER` | — |
| 13 | `SERVER.TOKEN` | — |
| 14 | `SERVER.ARENA_SERVER` | 30 |
| 15 | `SERVER.GLOBAL_GM` | — |
| 16 | `SERVER.GUILD` | 23 |
| 17 | `SERVER.RANK_SERVER` | — |
| 18 | `SERVER.LOGIN_ROLE` | 1 |

> **Lưu ý.** `SERVER.STATISTIC_ACHIEVEMENT` được client tham chiếu nhưng **không có trong enum `SERVER`** — tức là `nil` lúc chạy, nên `CallServer` rơi vào nhánh mặc định và đẩy qua game gateway. Đây là API cũ còn sót: `ClientAwardAhieve`, `ClientReachAchieveWithEvent`.

## 3. API client → server

Hàm đánh dấu **⟳** không có tên dưới dạng chuỗi ở bất kỳ đâu trong mã nguồn: `CUIAssist.bindRpcToEvent` sinh chúng lúc chạy bằng `string.format(reqFormat, eventName)` từ bảng sự kiện trong `sc/share/EventManager.lua` (xem `sc/user/UI/CUIAssist.lua:335`). Cột *Nguồn* của chúng trỏ tới chỗ `bindRpcToEvent`, còn tham số lấy từ nơi gọi thật.

Chữ ký tham số suy ra từ quy ước Hungarian của chính codebase (`n`/`dw` = số, `sz`/`str` = chuỗi, `t` = bảng, `b` = boolean). Cột *Mô tả* là comment gốc (tiếng Trung) của hàm client bọc lời gọi.

### 3.1 `SERVER.ARENA_SERVER` — 30 API


#### ClientArenalLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_ArenaLogic`.**`ArenaFightRanking`** | `(fightData: any)` | `OnArenaFightRanking` | 开始挑战-------------------- | `sc/user/Logical/ClientArenalLogic.lua:194` |
| `G_ArenaLogic`.**`ArenaFightTest`** | `(fightData: any)` | `OnArenaFightTest` | test | `sc/user/Logical/ClientArenalLogic.lua:239` |
| `G_ArenaLogic`.**`CompeleteArenaFight`** | `(resultData: any)` | `OnCompeleteArenaFight` | 结算挑战-------------------- | `sc/user/Logical/ClientArenalLogic.lua:220` |
| `G_ArenaLogic`.**`CompeleteArenaFightTest`** | `(resultData: any)` | `OnCompeleteArenaFightTest` |  | `sc/user/Logical/ClientArenalLogic.lua:317` |
| `G_ArenaLogic`.**`GetArenaDetailByUid`** | `(Uid: any, nRobotId: number)` | `OnGetArenaDetailByUid` | 获取玩家竞技场数据-------------------- | `sc/user/Logical/ClientArenalLogic.lua:801` |
| `G_ArenaLogic`.**`GetArenaRankWithYesterday`** | `(1: number = 1, 50: number = 50)` | `OnGetArenaRankWithYesterday` | 获取玩家竞技场排行榜数据-------------------- | `sc/user/Logical/ClientArenalLogic.lua:19` |
| `G_ArenaLogic`.**`GetSearchList`** | `()` | `OnGetSearchList` | 获取对战列表-------------------- | `sc/user/Logical/ClientArenalLogic.lua:172` |
| `G_ArenaLogic`.**`GetUserArenaFightRecord`** | `()` | `OnGetUserArenaFightRecord` | 获取战报-------------------- | `sc/user/Logical/ClientArenalLogic.lua:336` |
| `G_ArenaLogic`.**`GetUserArenaFightReplay`** | `(uid: any, targetId: any, time: any)` | `OnGetUserArenaFightReplay` | 获取回放记录-------------------- | `sc/user/Logical/ClientArenalLogic.lua:356` |
| `G_ArenaLogic`.**`GetUserArenaFightReplayNew`** | `(uid: any, ReplaySerial: any)` | `OnGetUserArenaFightReplayNew` |  | `sc/user/Logical/ClientArenalLogic.lua:373` |
| `G_ArenaLogic`.**`GetUserArenal`** | `()` | `OnGetUserArenal` | 获取玩家竞技场数据-------------------- | `sc/user/Logical/ClientArenalLogic.lua:106` |
| `G_ArenaLogic`.**`GetWorldArenalRanking`** | `(min: any, max: any)` | `OnGetWorldArenalRanking` | 获取排行榜-------------------- | `sc/user/Logical/ClientArenalLogic.lua:126` |

#### ClientGuildWarLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_GuildWarLogic`.**`AngerAttackWarBoss`** | `()` | `OnAngerAttackWarBoss` | ]] | `sc/user/Logical/ClientGuildWarLogic.lua:746` |
| `G_GuildWarLogic`.**`AnnounceWar`** | `(nTargetGuildId: number)` | `OnAnnounceWar` | ]] | `sc/user/Logical/ClientGuildWarLogic.lua:509` |
| `G_GuildWarLogic`.**`AttackWarBoss`** | `()` | `OnAttackWarBoss` | ]] | `sc/user/Logical/ClientGuildWarLogic.lua:682` |
| `G_GuildWarLogic`.**`CheckCanChangeTeam`** | `()` | `OnCheckCanChangeTeam` | 是否能更换阵容 | `sc/user/Logical/ClientGuildWarLogic.lua:796` |
| `G_GuildWarLogic`.**`GetCanBeAttackUser`** | `(nGuildId: number)` | `OnGetCanBeAttackUser` | ]] | `sc/user/Logical/ClientGuildWarLogic.lua:845` |
| `G_GuildWarLogic`.**`GetGuildWarInfo`** | `()` | `OnGetGuildWarInfo` | ]] | `sc/user/Logical/ClientGuildWarLogic.lua:564` |
| `G_GuildWarLogic`.**`GetGuildWarMockFightData`** | `()` | `OnGetGuildWarMockFightData` | ]] | `sc/user/Logical/ClientGuildWarLogic.lua:625` |
| `G_GuildWarLogic`.**`GuildWarCompeleteFight`** | `(bWin: boolean, targetUid: any, tNpcNpcResidue: table)` | `OnGuildWarCompeleteFight` | ]] | `sc/user/Logical/ClientGuildWarLogic.lua:1006` |
| `G_GuildWarLogic`.**`GuildWarFightBegin`** | `(heroList: any)` | `OnGuildWarFightBegin` | ]] | `sc/user/Logical/ClientGuildWarLogic.lua:949` |
| `G_GuildWarLogic`.**`GuildWarIsOpen`** | `()` | `OnGuildWarIsOpen` | ]] | `sc/user/Logical/ClientGuildWarLogic.lua:395` |
| `G_GuildWarLogic`.**`IsHaveGuildWarRankReward`** | `()` | `OnIsHaveGuildWarRankReward` | 奖励结算 | `sc/user/Logical/ClientGuildWarLogic.lua:1053` |
| `G_GuildWarLogic`.**`QueryAccnList`** | `()` | `OnQueryAccnList` | ]] | `sc/user/Logical/ClientGuildWarLogic.lua:451` |
| `G_GuildWarLogic`.**`QueryAttckCanBeAttack`** | `(nTarget: number)` | `OnQueryAttckCanBeAttack` | 是否可挑战 | `sc/user/Logical/ClientGuildWarLogic.lua:900` |
| `G_GuildWarLogic`.**`QueryGetJoinWarData`** | `()` | `—` | 获取战斗结算阶段的数据 | `sc/user/Logical/ClientGuildWarLogic.lua:1119` |
| `G_GuildWarLogic`.**`QueryGuildWarEndInfo`** | `()` | `OnQueryGuildWarEndInfo` | 获取战斗结算阶段的数据 | `sc/user/Logical/ClientGuildWarLogic.lua:1076` |
| `G_GuildWarLogic`.**`QueryGuildWarRank`** | `(nQueryType: number, nGuildId: number)` | `OnQueryGuildWarRank` | ]] | `sc/user/Logical/ClientGuildWarLogic.lua:261` |
| `G_GuildWarLogic`.**`QueryScore`** | `()` | `OnQueryScore` | ]] | `sc/user/Logical/ClientGuildWarLogic.lua:196` |
| `G_GuildWarLogic`.**`SetGuildWarFightHero`** | `(heroIdList: any)` | `OnSetGuildWarFightHero` | ]] | `sc/user/Logical/ClientGuildWarLogic.lua:320` |

### 3.2 `SERVER.CHAT_FRIEND` — 15 API


#### CServerRequestLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| **`ClientAgreeFriendApply`** | `(uId: number (uid))` | `OnAgreeFriendApply` | 同意好友申请 | `sc/user/Logical/CServerRequestLogic.lua:304` |
| **`ClientApplyForFriend`** | `(uId: number (uid))` | `OnApplyForFriend` | 好友申请 | `sc/user/Logical/CServerRequestLogic.lua:292` |
| **`ClientGetRecommendedUserList`** | `(nCount: number)` | `OnGetRecommendedUserList` | 获得推荐用户列表 | `sc/user/Logical/CServerRequestLogic.lua:280` |
| **`ClientGetUserRelation`** | `()` | `OnGetUserRelation` | 得到用户关系 | `sc/user/Logical/CServerRequestLogic.lua:274` |
| **`ClientRefuseFriendApply`** | `(uId: number (uid))` | `OnRefuseFriendApply` | 拒绝好友申请 | `sc/user/Logical/CServerRequestLogic.lua:310` |
| **`ClientRemoveFriendApply`** | `(uId: number (uid))` | `OnRemoveFriendApply` | 删除好友申请 | `sc/user/Logical/CServerRequestLogic.lua:298` |
| **`ClientRemoveFriendRelation`** | `(uId: number (uid))` | `OnRemoveFriendRelation` | 删除好友 | `sc/user/Logical/CServerRequestLogic.lua:316` |
| **`ClientSearchUserWithUserName`** | `(userName: any)` | `—` | 搜索用户名 | `sc/user/Logical/CServerRequestLogic.lua:286` |

#### ClientChattingLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| **`ClientEnterChannel`** | `(nGuildId: number, nChannelId: number)` | `OnEnterChannel` | EnterChannel 进入频道 | `sc/user/Logical/ClientChattingLogic.lua:34` |
| **`ClientEnterChatGame`** | `()` | `OnEnterChatGame` | EnterChatGame 进入聊天服务器 | `sc/user/Logical/ClientChattingLogic.lua:14` |
| **`ClientExitChannel`** | `(nChannelId: number)` | `OnExitChannel` | ExitChannel 退出频道 | `sc/user/Logical/ClientChattingLogic.lua:71` |
| **`ClientGetFriendChatRecord`** | `(nTargetUid: number)` | `OnGetFriendChatRecord` | 获取好友聊天记录 | `sc/user/Logical/ClientChattingLogic.lua:167` |
| **`ClientGetSpeechContent`** | `(nSpeechId: number)` | `OnGetSpeechContent` | LoadSpeech 读取语音数据 | `sc/user/Logical/ClientChattingLogic.lua:119` |
| **`ClientNotifyMessage`** | `(tMessage: table)` | `OnNotifyMessage` | SendChatMessage 发送聊天 | `sc/user/Logical/ClientChattingLogic.lua:91` |
| **`ClientReadFriendMessage`** | `(nTargetUid: number)` | `—` |  | `sc/user/Logical/ClientChattingLogic.lua:192` |

### 3.3 `SERVER.GAME_GATEWAY` — 3 API


#### CUILoginRPCManager

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `nil`.**`Heartbeat`** | `()` | `—` |  | `sc/user/Logical/CUILoginRPCManager.lua:34` |

#### CUIMain

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| **`TickFromClient`** | `()` | `—` | tick to game gateway server | `sc/user/UI/CUIMain.lua:1138` |

#### ClientGameGateway

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| **`Handshake`** | `(strKey: string, tInfo: table)` | `—` |  | `sc/user/Logical/ClientGameGateway.lua:277` |

### 3.4 `SERVER.GAME_LOGIC` — 501 API


#### APRProtocol

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_ScoreCompetitivePlayProtocol`.**`ClientAdjustDefTeamReq`** | `(tData: table)` | `—` | 调整防守阵容 | `sc/user/UI/apr/APRProtocol.lua:149` |
| `G_ScoreCompetitivePlayProtocol`.**`ClientBeginFightReq`** | `(tAttack: table, nIdx: number, strId: string)` | `—` | 请求战斗 | `sc/user/UI/apr/APRProtocol.lua:99` |
| `G_ScoreCompetitivePlayProtocol`.**`ClientBeginPlayReq`** | `()` | `—` | 获取主界面信息 | `sc/user/UI/apr/APRProtocol.lua:47` |
| `G_ScoreCompetitivePlayProtocol`.**`ClientEndFightReq`** | `(nBeginFightIdx: number, tData: table)` | `—` | 战斗结算 | `sc/user/UI/apr/APRProtocol.lua:128` |
| `G_ScoreCompetitivePlayProtocol`.**`ClientFailRecoverReq`** | `()` | `—` | 积分恢复 | `sc/user/UI/apr/APRProtocol.lua:308` |
| `G_ScoreCompetitivePlayProtocol`.**`ClientGetOpenInfoReq`** | `()` | `—` | 获取当前状态 | `sc/user/UI/apr/APRProtocol.lua:21` |
| `G_ScoreCompetitivePlayProtocol`.**`ClientGetRankListReq`** | `(nStartIdx: number, nCount: number)` | `—` | 排行榜 | `sc/user/UI/apr/APRProtocol.lua:236` |
| `G_ScoreCompetitivePlayProtocol`.**`ClientGetRankRewardReq`** | `(nPointLevel: number)` | `—` | 领取晋级奖励 | `sc/user/UI/apr/APRProtocol.lua:167` |
| `G_ScoreCompetitivePlayProtocol`.**`ClientGetReplayReq`** | `(strRecordId: string)` | `—` | 回放 | `sc/user/UI/apr/APRProtocol.lua:213` |
| `G_ScoreCompetitivePlayProtocol`.**`ClientGetReportReq`** | `()` | `—` | 查看战报 | `sc/user/UI/apr/APRProtocol.lua:188` |
| `G_ServerInfoProtocol`.**`ClientGetServerInfoReq`** | `()` | `—` | 服务器相关信息 | `sc/user/UI/apr/APRProtocol.lua:321` |
| `G_ScoreCompetitivePlayProtocol`.**`ClientRevengeBeginReq`** | `(tAttack: table, strRecordId: string)` | `—` | 复仇 | `sc/user/UI/apr/APRProtocol.lua:262` |
| `G_ScoreCompetitivePlayProtocol`.**`ClientRevengeEndReq`** | `(strRevengeRecordId: string, tData: table)` | `—` | 复仇结算 | `sc/user/UI/apr/APRProtocol.lua:289` |
| `G_ScoreCompetitivePlayProtocol`.**`ClientViewPlayerReq`** | `(strId: string)` | `—` | 查看对手信息 | `sc/user/UI/apr/APRProtocol.lua:76` |

#### COGProtocol

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_COGProtocol`.**`ClientAddTeam`** | `(tTeamList: table)` | `OnAddTeam` | 添加队伍 | `sc/user/UI/cog/COGProtocol.lua:350` |
| `G_COGCityDefendMission`.**`ClientAttackCity`** | `(nCityId or 0: number)` | `OnAttackCity` | 破坏城防 | `sc/user/UI/cog/COGProtocol.lua:109` |
| `G_COGProtocol`.**`ClientDispatchTeam`** | `(tMapDispatch: table)` | `OnDispatchTeam` | 派遣队伍 | `sc/user/UI/cog/COGProtocol.lua:394` |
| `G_COGProtocol`.**`ClientGetBriefInfo`** | `()` | `OnGetBriefInfo` | 获取攻城战简要信息 | `sc/user/UI/cog/COGProtocol.lua:21` |
| `G_COGProtocol`.**`ClientGetCOGInfo`** | `()` | `OnGetCOGInfo` | 获取攻城战信息 | `sc/user/UI/cog/COGProtocol.lua:39` |
| `G_COGCityDefendMission`.**`ClientGetCityDefendMission`** | `()` | `OnGetCityDefendMission` | 获得城防任务 | `sc/user/UI/cog/COGProtocol.lua:141` |
| `G_COGProtocol`.**`ClientGetCityInfo`** | `(nCityId or 0: number)` | `OnGetCityInfo` | 获取攻城战信息 | `sc/user/UI/cog/COGProtocol.lua:58` |
| `G_COGProtocol`.**`ClientGetCityPlayback`** | `(nCityId: number, bBattle: boolean)` | `OnGetCityPlayback` | 获取城市战报，战斗回放数据 / bBattle	[true 攻城战 \| false 资格战] | `sc/user/UI/cog/COGProtocol.lua:485` |
| `G_COGProtocol`.**`ClientGetCityReport`** | `(nCityId: number)` | `OnGetCityReport` | 获取城市战报信息 | `sc/user/UI/cog/COGProtocol.lua:465` |
| `G_COGCityDefendMission`.**`ClientGetDailyOccupyPrize`** | `()` | `OnGetDailyOccupyPrize` | 领取城池每日占领奖励 | `sc/user/UI/cog/COGProtocol.lua:280` |
| `G_COGProtocol`.**`ClientGetGuildBattleReport`** | `()` | `OnGetGuildBattleReport` | 获取军团战报 | `sc/user/UI/cog/COGProtocol.lua:295` |
| `G_COGProtocol`.**`ClientGetGuildTeamList`** | `(tUidList: table)` | `OnGetGuildTeamList` | [1] = {Uid = Number, TeamID = Number} / .... / } | `sc/user/UI/cog/COGProtocol.lua:436` |
| `G_COGProtocol`.**`ClientGetGuildTeamProfile`** | `(nType: number)` | `OnGetGuildTeamProfile` | 获取军团其他玩家队伍的简要信息，分页用 | `sc/user/UI/cog/COGProtocol.lua:413` |
| `G_COGProtocol`.**`ClientGetMyTeamList`** | `()` | `OnGetMyTeamList` | 获取我的队伍列表 | `sc/user/UI/cog/COGProtocol.lua:313` |
| `G_COGProtocol`.**`ClientGetPlayerBattleReport`** | `()` | `OnGetPlayerBattleReport` | 获取玩家战报 | `sc/user/UI/cog/COGProtocol.lua:204` |
| `G_COGProtocol`.**`ClientGetPlayerPlayback`** | `(tDefine: table, tResultDetail: table, nAttackUid: number, tAttackList: table, nDefendUid: number, tDefendList: table, bBattle: boolean, nWinIndex: number)` | `OnGetPlayerPlayback` | 获取单场的战斗数据回放用 | `sc/user/UI/cog/COGProtocol.lua:504` |
| `G_COGCityDefendMission`.**`ClientManualRefreshMission`** | `()` | `OnManualRefreshMission` | 刷新城防任务 | `sc/user/UI/cog/COGProtocol.lua:174` |
| `G_COGProtocol`.**`ClientRemoveTeam`** | `(nTeamId: number)` | `OnRemoveTeam` | 删除队伍 | `sc/user/UI/cog/COGProtocol.lua:368` |
| `G_COGCityDefendMission`.**`ClientRepairCity`** | `(nCityId or 0: number)` | `OnRepairCity` | 修复城防 | `sc/user/UI/cog/COGProtocol.lua:77` |
| `G_COGProtocol`.**`ClientSetGuildMsg`** | `(strMsg or "": string)` | `OnSetGuildMsg` | 设置军团留言 | `sc/user/UI/cog/COGProtocol.lua:261` |
| `G_COGProtocol`.**`ClientSetTargetCity`** | `(nCityId or 0: number, bIsAttack or false: boolean)` | `OnSetTargetCity` | 设置目标城池 | `sc/user/UI/cog/COGProtocol.lua:223` |
| `G_COGProtocol`.**`ClientSignUp`** | `(nCityId or 0: number)` | `OnSignUp` | 报名, nCityId == nil or nCityId ==0 时，为取消报名 | `sc/user/UI/cog/COGProtocol.lua:242` |
| `G_COGProtocol`.**`ClientUpdateTeam`** | `(nTeamId: number, tTeamList: table)` | `OnUpdateTeam` | 调整队伍 | `sc/user/UI/cog/COGProtocol.lua:332` |

#### CServerRequestLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| **`ClientAwardDailyTask`** | `(taskId: any)` | `OnAwardDailyTask` | 领取任务奖励 | `sc/user/Logical/CServerRequestLogic.lua:416` |
| **`ClientBeginGuide`** | `(guideId: any)` | `—` | 新手指引---------------------------------------------- | `sc/user/Logical/CServerRequestLogic.lua:370` |
| **`ClientBuyGoods`** | `(goodsId: any, count: any)` | `OnBuyGoods` | 商品---------------------------------------------- / 购买商品 | `sc/user/Logical/CServerRequestLogic.lua:324` |
| **`ClientBuyPotion`** | `(nPotion: number)` | `OnBuyPotion` | 购买药水 | `sc/user/Logical/CServerRequestLogic.lua:130` |
| **`ClientCancelBuildingUpgrade`** | `(nBuildingId: number)` | `OnCancelBuildingUpgrade` | 建筑物取消升级 | `sc/user/Logical/CServerRequestLogic.lua:37` |
| **`ClientCancelUpgradeArmy`** | `(nArmyId: number)` | `OnCancelUpgradeArmy` | 取消兵种升级 | `sc/user/Logical/CServerRequestLogic.lua:65` |
| **`ClientCancelUpgradePotion`** | `()` | `—` | 取消药水升级 | `sc/user/Logical/CServerRequestLogic.lua:112` |
| **`ClientChangeHeroEquipment`** | `(nHeroId: number, newEquipmentId: any, takeOffPosition: any)` | `OnChangeHeroEquipment` |  | `sc/user/Logical/CServerRequestLogic.lua:169` |
| **`ClientChapterCompleteSuccess`** | `(nChapterID: number, tData: table)` | `OnChapterCompleteSuccess` | 完成章节--------------------------------- | `sc/user/Logical/CServerRequestLogic.lua:224` |
| **`ClientChapterSweepOnce`** | `(nChapterID: number)` | `OnChapterSweepOnce` | 扫荡一次 | `sc/user/Logical/CServerRequestLogic.lua:241` |
| **`ClientChapterSweepTen`** | `(nChapterID: number)` | `OnChapterSweepTen` | 扫荡十次 | `sc/user/Logical/CServerRequestLogic.lua:245` |
| **`ClientCollectResouce`** | `(nBuildingId: number)` | `—` | 矿场相关---------------------------------------------- / 收集资源 | `sc/user/Logical/CServerRequestLogic.lua:53` |
| **`ClientCompeleGuide`** | `(guideId: any)` | `—` |  | `sc/user/Logical/CServerRequestLogic.lua:374` |
| **`ClientComplelteDailyTask`** | `(taskId: any)` | `—` | 每日任务--------------------------- / 达成任务 | `sc/user/Logical/CServerRequestLogic.lua:411` |
| **`ClientCompleteBuildingUpgrade`** | `(nBuildingId: number)` | `OnCompleteBuildingUpgrade` | 建筑物完成升级 | `sc/user/Logical/CServerRequestLogic.lua:42` |
| **`ClientCompleteBuildingUpgradeWithDiomaon`** | `(nBuildingId: number)` | `—` | 建筑物秒升 | `sc/user/Logical/CServerRequestLogic.lua:47` |
| **`ClientCompleteUpgradeArmy`** | `(nArmyId: number)` | `OnCompleteUpgradeArmy` | 兵种升级完成 | `sc/user/Logical/CServerRequestLogic.lua:70` |
| **`ClientCompleteUpgradeArmyWithDiomaon`** | `(nArmyId: number)` | `—` | 兵种秒升 | `sc/user/Logical/CServerRequestLogic.lua:76` |
| **`ClientCompleteUpgradePotion`** | `()` | `OnCompleteUpgradePotion` | 药水完成升级 | `sc/user/Logical/CServerRequestLogic.lua:118` |
| **`ClientCompleteUpgradePotionWithDiomaon`** | `()` | `—` | 药水秒升级 | `sc/user/Logical/CServerRequestLogic.lua:124` |
| **`ClientDeleteMailWithMailId`** | `(nMailID: number)` | `—` | 删除邮件,邮件Id | `sc/user/Logical/CServerRequestLogic.lua:346` |
| **`ClientGetAllUserData`** | `()` | `—` | 得到所有数据 | `sc/user/Logical/CServerRequestLogic.lua:23` |
| **`ClientGetBattleReportsWithDate`** | `(time: any)` | `—` | 战报---------------------------------------------- | `sc/user/Logical/CServerRequestLogic.lua:212` |
| **`ClientGetChapterDropData`** | `(nChapterID: number)` | `OnGetChapterDropData` | 获取奖励和掉落数据--------------------------------- | `sc/user/Logical/CServerRequestLogic.lua:216` |
| **`ClientGetLoginReward`** | `()` | `OnGetLoginReward` |  | `sc/user/Logical/CServerRequestLogic.lua:387` |
| **`ClientGetLotteryData`** | `()` | `OnGetLotteryData` | 扭蛋系统---------------------------------------------- / 获取信息 | `sc/user/Logical/CServerRequestLogic.lua:148` |
| **`ClientGetMailList`** | `()` | `OnGetMailList` | 得到邮件列表 | `sc/user/Logical/CServerRequestLogic.lua:331` |
| **`ClientGetPassMissionCountList`** | `(tChapterIDList: table)` | `OnGetPassMissionCountList` | 根据关卡ID列表获取关卡每日闯关次数 | `sc/user/Logical/CServerRequestLogic.lua:220` |
| **`ClientGetUserArenaData`** | `(nil: nil)` | `OnGetUserArenaData` | 竞技场------------------------------------------------- | `sc/user/Logical/CServerRequestLogic.lua:394` |
| **`ClientGetUserArenaFightData`** | `(uid: any)` | `OnGetUserArenaFightData` | 用uid获得玩家竞技场战斗属性 | `sc/user/Logical/CServerRequestLogic.lua:405` |
| **`ClientHeroExpedition`** | `(nHeroId: number, isExpedition: any)` | `OnHeroExpedition` | 英雄系统---------------------------------------------- | `sc/user/Logical/CServerRequestLogic.lua:165` |
| **`ClientIntensifyEquipment`** | `(nHeroID: number, nHeroPartID: number)` | `OnIntensifyEquipment` | 装备系统---------------------------------------------- / 强化 | `sc/user/Logical/CServerRequestLogic.lua:177` |
| **`ClientPotionExpedition`** | `(nPotion: number, isExpedition: any)` | `OnPotionExpedition` | 药水出战 | `sc/user/Logical/CServerRequestLogic.lua:141` |
| **`ClientReduceDiamondToGold`** | `(nGoldNum: number)` | `OnReduceDiamondToGold` | 资源相关---------------------------------------------- / 钻石变为金币请求 | `sc/user/Logical/CServerRequestLogic.lua:363` |
| **`ClientSaveAllMailPrize`** | `()` | `OnSaveAllMailPrize` | 保存所有邮件奖励附件 | `sc/user/Logical/CServerRequestLogic.lua:356` |
| **`ClientSaveMailPrizeWithMailId`** | `(nMailID: number)` | `—` | 保存邮件奖与邮件Id | `sc/user/Logical/CServerRequestLogic.lua:336` |
| **`ClientSellItem`** | `(nItemId: number, nCount: number)` | `OnSellItem` | 出售 | `sc/user/Logical/CServerRequestLogic.lua:254` |
| **`ClientSetMailReadWithMailId`** | `(nMailID: number)` | `—` | 设置邮件阅读邮件Id | `sc/user/Logical/CServerRequestLogic.lua:341` |
| **`ClientSignIn`** | `()` | `OnSignIn` | 登陆与签到--------------------------- / 每日签到领取奖励 | `sc/user/Logical/CServerRequestLogic.lua:382` |
| **`ClientStartLottery`** | `(nLotteryType: number)` | `OnStartLottery` | 抽奖.nLotteryType:0免费，1钻石抽一次，2钻石抽十次 | `sc/user/Logical/CServerRequestLogic.lua:153` |
| `G_EquipmentLogic`.**`ClientSynthesisEquipment`** | `(nHeroID: number, nHeroPartID: number)` | `—` | 出售 | `sc/user/Logical/CServerRequestLogic.lua:208` |
| **`ClientTestAddMail`** | `()` | `OnTestAddMail` | 测试添加邮件 | `sc/user/Logical/CServerRequestLogic.lua:351` |
| **`ClientUpgradeArmy`** | `(nArmyId: number)` | `OnUpgradeArmy` | 兵种---------------------------------------------- / 兵种升级 | `sc/user/Logical/CServerRequestLogic.lua:60` |
| **`ClientUpgradeBuilding`** | `(nBuildingId: number)` | `—` | 建筑物---------------------------------------------- / 建筑物升级 | `sc/user/Logical/CServerRequestLogic.lua:32` |
| **`ClientUpgradePotion`** | `(nPotionId: number)` | `OnUpgradePotion` | 药水升级 | `sc/user/Logical/CServerRequestLogic.lua:107` |
| **`ClientUseItem`** | `(nItemId: number, nCount: number, nID: number)` | `OnUseItem` | 物品---------------------------------------------- / 使用 | `sc/user/Logical/CServerRequestLogic.lua:250` |

#### CUIActivityBattleRank

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_ServerActivityFightCap`.**`ClientGetInfoReq`** | `()` | `—` |  | `sc/user/UI/CUIActivityBattleRank.lua:741` |

#### CUIActivityCost

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_ActivityRankLogic`.**`ClientGetPlayerDiamondConsume`** | `()` | `OnGetPlayerDiamondConsume` |  | `sc/user/UI/CUIActivityCost.lua:16` |
| `G_ActivityRankLogic`.**`ClientGetTop3DiamondConsume`** | `()` | `OnGetTop3DiamondConsume` |  | `sc/user/UI/CUIActivityCost.lua:17` |

#### CUIActivityGodOfWealth

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_ActivityWealthGod`.**`ClientPushReq`** | `()` | `—` |  | `sc/user/UI/CUIActivityGodOfWealth.lua:738` |

#### CUIActivityRecharge

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_ActivityRankLogic`.**`ClientGetPlayerPayment`** | `()` | `OnGetPlayerPayment` |  | `sc/user/UI/CUIActivityRecharge.lua:16` |
| `G_ActivityRankLogic`.**`ClientGetTop3Payment`** | `()` | `OnGetTop3Payment` |  | `sc/user/UI/CUIActivityRecharge.lua:17` |

#### CUIActivitySingleRecharge_cs

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_ActivitySingleRecharge`.**`ClientGetSingleRechargePrize`** | `(dwGoodsID: number)` | `—` |  | `sc/user/UI/CUIActivitySingleRecharge_cs.lua:1` |

#### CUIAnniversaryThankLetter

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_Anniversary`.**`ClientGetAnniversaryAward`** | `()` | `OnGetAnniversaryAward` |  | `sc/user/UI/anniversary/CUIAnniversaryThankLetter.lua:247` |

#### CUICashRedPacketData

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_ActivityGuildRedPack`.**`ClientGetConfigReq`** | `()` | `—` |  | `sc/user/UI/CUICashRedPacketData.lua:177` |
| `G_ActivityGuildRedPack`.**`ClientGetRewardReq`** | `()` | `—` |  | `sc/user/UI/CUICashRedPacketData.lua:190` |

#### CUIChapterList

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| **`ClientReturnHome`** | `()` | `OnReturnHome` | 返回主界面 | `sc/user/UI/CUIChapterList.lua:894` |

#### CUIDKData

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_ChapterLogic`.**`ClientChapterDKComplete`** | `(tClientData: table)` | `—` | ]] | `sc/user/UI/dk/CUIDKData.lua:86` |
| `G_ChapterLogic`.**`ClientChapterDKSweep`** | `()` | `—` | ]] | `sc/user/UI/dk/CUIDKData.lua:122` |
| `G_ChapterLogic`.**`ClientGetDKChapterFaction`** | `()` | `—` | ]] | `sc/user/UI/dk/CUIDKData.lua:142` |
| `G_RankLogic`.**`ClientGetDKRank`** | `()` | `—` | ]] | `sc/user/UI/dk/CUIDKData.lua:64` |

#### CUIEquipmentList

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| **`ClientCheckNewEquipment`** | `(EquipID: any)` | `OnCheckNewEquipment` | 设置选中状态 | `sc/user/UI/CUIEquipmentList.lua:164` |

#### CUIExchangeShop

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_EpicChapterLogic`.**`ClientBuyEpicGoods`** | `(tonumber: any)` | `—` |  | `sc/user/UI/CUIExchangeShop.lua:172` |
| `G_GuildStoreLogic`.**`ClientBuyGuildWarGoods`** | `(tonumber: any)` | `—` |  | `sc/user/UI/CUIExchangeShop.lua:169` |

#### CUIGM

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| **`ClientTestFullLevelResouces`** | `()` | `—` |  | `sc/user/UI/CUIGM.lua:307` |
| **`ClientTestFullWorker`** | `()` | `—` | ũ | `sc/user/UI/CUIGM.lua:284` |

#### CUIGame

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_ChapterLogic`.**`ClientCheck`** | `(tData: table)` | `—` |  | `sc/user/Battle/CUIGame.lua:838` |

#### CUIGuildContestRankDlg

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_ServerGuildWarScoreProtocol`.**`ClientGetGuildRankList`** ⟳ | `(nContestId: number, 1: number = 1, MaxRankCount: any, CUIAssist: any)` | `OnGetGuildRankList` |  | `sc/user/UI/GuildContest/CUIGuildContestRankDlg.lua:387` |
| `G_ServerGuildWarScoreProtocol`.**`ClientGetRoleRankList`** ⟳ | `(nContestId: number, 1: number = 1, MaxRankCount: any)` | `OnGetRoleRankList` |  | `sc/user/UI/GuildContest/CUIGuildContestRankDlg.lua:391` |

#### CUILogin2

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| **`ClientGMCommond`** | `({"channeldemouser"}: table)` | `OnGMCommond` | 创建昵称回调 | `sc/user/UI/CUILogin2.lua:2867` |
| `G_GameWorld`.**`ClientUpdateToken`** | `(tInfo: table)` | `—` | ]] | `sc/user/UI/CUILogin2.lua:586` |

#### CUINewHandPrivilege

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_NewHandPrivilegeLogic`.**`ClientSendRewardV2`** | `()` | `—` |  | `sc/user/UI/CUINewHandPrivilege.lua:138` |

#### CUIPerks

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_NewHandPrivilegeLogic`.**`ClientSendReward`** | `()` | `OnSendReward` | ”前往“按钮点击 | `sc/user/UI/CUIPerks.lua:212` |

#### CUIRechargeStore

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_RechargeLogic`.**`ClientGetUserBalance`** | `()` | `OnGetUserBalance` |  | `sc/user/UI/CUIRechargeStore.lua:230` |
| `G_RechargeLogic`.**`ClientViRechargeCompleteDealPayment`** | `(tVIData: table)` | `—` |  | `sc/user/UI/CUIRechargeStore.lua:2447` |

#### CUIShuaShuaLeDlg

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_ActivityShuashuale`.**`ClientGetShuashualeList`** ⟳ | `()` | `OnGetShuashualeList` | 获取记录数据 | `sc/user/UI/CUIShuaShuaLeDlg.lua:11` |
| `G_ActivityShuashuale`.**`ClientShuashualeExchange`** ⟳ | `(strCurExchangeKey: string, nTimes: number)` | `OnShuashualeExchange` | 执行兑换 | `sc/user/UI/CUIShuaShuaLeDlg.lua:11` |

#### CUITongqueDlg

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_ActivityTongque`.**`ClientExchangeTongqueItem`** ⟳ | `(nTimes: number)` | `OnExchangeTongqueItem` | 购买 | `sc/user/UI/CUITongqueDlg.lua:13` |
| `G_ActivityTongque`.**`ClientGetLevelTongqueReward`** ⟳ | `(i: any)` | `OnGetLevelTongqueReward` | 领奖 | `sc/user/UI/CUITongqueDlg.lua:13` |
| `G_ActivityTongque`.**`ClientGetTongqueData`** ⟳ | `()` | `OnGetTongqueData` | 获取数据 | `sc/user/UI/CUITongqueDlg.lua:13` |

#### ClientAchieveLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_GameCommentLogic`.**`ClientCommentGame`** | `()` | `—` | 用户评价游戏 | `sc/user/Logical/ClientAchieveLogic.lua:964` |
| `G_FreeStrengthLogic`.**`ClientGetFreeStrength`** | `()` | `OnGetFreeStrength` |  | `sc/user/Logical/ClientAchieveLogic.lua:946` |
| `G_AchieveLogic`.**`ClientGetLivenessPrize`** | `()` | `OnGetLivenessPrize` |  | `sc/user/Logical/ClientAchieveLogic.lua:810` |
| `G_AchieveLogic`.**`ClientReachAchieve`** | `(nAchieveType: number)` | `OnReachAchieve` |  | `sc/user/Logical/ClientAchieveLogic.lua:544` |
| `G_AchieveLogic`.**`ClientSkipAchieve`** | `(nAchieveType: number)` | `OnSkipAchieve` |  | `sc/user/Logical/ClientAchieveLogic.lua:719` |
| `G_AchieveLogic`.**`ClientUpdateFreeStrengthState`** | `()` | `OnUpdateFreeStrengthState` |  | `sc/user/Logical/ClientAchieveLogic.lua:287` |

#### ClientAcivityWushuang

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_ActivityWushuang`.**`ClientGetHistoryWushuangRankList`** | `(nRewardStep: number)` | `OnGetHistoryWushuangRankList` | 请求天下无双历史排行数据 | `sc/user/Logical/ClientAcivityWushuang.lua:198` |
| `G_ActivityWushuang`.**`ClientGetWushuangRankList`** | `()` | `OnGetWushuangRankList` | 请求天下无双排行榜数据 | `sc/user/Logical/ClientAcivityWushuang.lua:128` |

#### ClientActivitiesLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_ActivityShoppingLogic`.**`ClientActivityShopping`** | `(TimeLimitDiscountSale: any, szGoods: string, dwBuyNum: number)` | `OnActivityShopping` | 购买 | `sc/user/Logical/ClientActivitiesLogic.lua:382` |
| `G_ActivityFund`.**`ClientBuyActivityFund`** | `(strFundType: string)` | `OnBuyActivityFund` | 购买活动基金 | `sc/user/Logical/ClientActivitiesLogic.lua:276` |
| `G_ActivityLogic`.**`ClientGetActivityConfig`** | `(strType: string)` | `OnGetActivityConfig` | 请求获取新的活动配置 | `sc/user/Logical/ClientActivitiesLogic.lua:123` |
| `G_ActivityLogic`.**`ClientGetActivityList`** | `()` | `—` | 获取活动状态、配置 | `sc/user/Logical/ClientActivitiesLogic.lua:94` |
| `G_ActivityFund`.**`ClientGetLevelFundPrize`** | `()` | `—` | 获取等级基金奖励 | `sc/user/Logical/ClientActivitiesLogic.lua:290` |
| `G_MonthlyCardLogic`.**`ClientGetReward`** | `(sCardType: string)` | `OnGetReward` | 获得每日奖励 | `sc/user/Logical/ClientActivitiesLogic.lua:363` |
| `G_ActivityFund`.**`ClientGetTimeFundPrize`** | `()` | `—` | 获取时间基金奖励 | `sc/user/Logical/ClientActivitiesLogic.lua:305` |
| `G_ActivityShoppingLogic`.**`ClientQueryActivityShoppingLimit`** | `(TimeLimitDiscountSale: any)` | `OnQueryActivityShoppingLimit` | 查询 | `sc/user/Logical/ClientActivitiesLogic.lua:393` |

#### ClientActivityContinuousRecharge

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_ActivityContinuousRecharge`.**`ClientGetContinuousPrize`** | `()` | `—` | 获取大礼包 | `sc/user/Logical/ClientActivityContinuousRecharge.lua:40` |
| `G_ActivityContinuousRecharge`.**`ClientGetDayPrize`** | `(nIndex: number)` | `—` | 获取每日的奖励 | `sc/user/Logical/ClientActivityContinuousRecharge.lua:31` |

#### ClientActivityCumulativeConsume

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_ActivityCumulativeConsume`.**`ClientGetPrize`** | `(nIndex: number)` | `OnGetPrize` | 获取累计消耗数据 | `sc/user/Logical/ClientActivityCumulativeConsume.lua:18` |
| `G_ActivityCumulativeConsume`.**`ClientGetUserState`** | `()` | `OnGetUserState` | 获取累计消耗数据 | `sc/user/Logical/ClientActivityCumulativeConsume.lua:28` |

#### ClientActivityGodHeroLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_ActivityGodHero`.**`ClientFreeLotteryDrawOnce`** | `()` | `—` |  | `sc/user/Logical/ClientActivityGodHeroLogic.lua:86` |
| `G_ActivityGodHero`.**`ClientGetScorePrize`** | `(Index: any)` | `OnGetScorePrize` |  | `sc/user/Logical/ClientActivityGodHeroLogic.lua:176` |
| `G_ActivityGodHero`.**`ClientLotteryDrawOnce`** | `()` | `—` |  | `sc/user/Logical/ClientActivityGodHeroLogic.lua:91` |
| `G_ActivityGodHero`.**`ClientLotteryDrawTenTimes`** | `()` | `—` |  | `sc/user/Logical/ClientActivityGodHeroLogic.lua:96` |

#### ClientActivityLevelCapacity

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_ActivityLevelCapacity`.**`ClientGetLevelCapacityPrize`** | `(nIndex: number)` | `—` |  | `sc/user/Logical/ClientActivityLevelCapacity.lua:14` |

#### ClientActivityLoginRewardLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_LoginRewardLogic`.**`ClientGetLoginRewardData`** | `()` | `OnGetLoginRewardData` | 获得数据 | `sc/user/Logical/ClientActivityLoginRewardLogic.lua:16` |

#### ClientActivityObjExchangeLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_ActivityObjExchange`.**`ClientGetObjectExchangeList`** | `()` | `OnGetObjectExchangeList` | 获得活动 | `sc/user/Logical/ClientActivityObjExchangeLogic.lua:16` |
| `G_ActivityObjExchange`.**`ClientObjectExchange`** | `(exchangeKey: any, dwExchangeNum: number)` | `OnObjectExchange` | 兑换 | `sc/user/Logical/ClientActivityObjExchangeLogic.lua:39` |

#### ClientAdventureLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_AdventureLogic`.**`ClientShowTrigger`** | `()` | `—` |  | `sc/user/Logical/ClientAdventureLogic.lua:17` |

#### ClientArenalLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_ArenaLogic`.**`ClientAddArenaFightCount`** | `()` | `OnAddArenaFightCount` | 增加挑战次数------------------- | `sc/user/Logical/ClientArenalLogic.lua:505` |
| `G_ArenaLogic`.**`ClientBuyArenaGoods`** | `(goodsIndex: any)` | `OnBuyArenaGoods` | 购买荣誉商品-------------------- | `sc/user/Logical/ClientArenalLogic.lua:486` |
| `G_ArenaLogic`.**`ClientCheckArenaRecord`** | `()` | `—` | 已经检视过新的呗挑战纪录 | `sc/user/Logical/ClientArenalLogic.lua:744` |
| `G_ArenaLogic`.**`ClientGetArenaHeroInfo`** | `(ranking: any, heroId: any)` | `OnGetArenaHeroInfo` | 获取英雄数据 | `sc/user/Logical/ClientArenalLogic.lua:615` |
| `G_ArenaLogic`.**`ClientRefreshArenaGoodsWithHonor`** | `()` | `OnRefreshArenaGoodsWithHonor` |  | `sc/user/Logical/ClientArenalLogic.lua:433` |
| `G_ArenaLogic`.**`ClientRefreshFightTime`** | `()` | `OnRefreshFightTime` | 刷新挑战cd------------------- | `sc/user/Logical/ClientArenalLogic.lua:548` |
| `G_ArenaLogic`.**`ClientRefreshUserArenaGoods`** | `()` | `OnRefreshUserArenaGoods` | 刷新荣誉商店-------------------- | `sc/user/Logical/ClientArenalLogic.lua:393` |
| `G_ArenaLogic`.**`ClientSetArenaHero`** | `(heroIdList: any)` | `OnSetArenaHero` | 获取排行榜-------------------- | `sc/user/Logical/ClientArenalLogic.lua:146` |

#### ClientArmyLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_ArmyLogic`.**`ClientIntoLineup`** | `(nIndex: number, nArmyID: number)` | `OnIntoLineup` | 设置兵种出战 | `sc/user/Logical/ClientArmyLogic.lua:64` |
| `G_ArmyLogic`.**`ClientOutOffLineup`** | `(nIndex: number, nArmyID: number)` | `OnOutOffLineup` | 设置兵种出战 | `sc/user/Logical/ClientArmyLogic.lua:94` |
| `G_ArmyLogic`.**`ClientSetLastArmyLineup`** | `(nIndex: number)` | `—` | 设置最后的出战阵容 | `sc/user/Logical/ClientArmyLogic.lua:122` |
| `G_ArmyLogic`.**`ClientUnlockArmy`** | `(nArmyId: number)` | `OnUnlockArmy` |  | `sc/user/Logical/ClientArmyLogic.lua:36` |

#### ClientCavernLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_CavernLogic`.**`ClientBuyCavernGoods`** | `(goodsIndex: any)` | `—` | 购买荣誉商品-------------------- | `sc/user/Logical/ClientCavernLogic.lua:230` |
| `G_CavernLogic`.**`ClientCavernDirectSweep`** | `()` | `—` |  | `sc/user/Logical/ClientCavernLogic.lua:275` |
| `G_CavernLogic`.**`ClientCavernGetReward`** | `(nIndex: number)` | `—` | 获得奖励 | `sc/user/Logical/ClientCavernLogic.lua:15` |
| `G_CavernLogic`.**`ClientCavernSweepAll`** | `()` | `OnCavernSweepAll` | 发送一键通关协议 | `sc/user/Logical/ClientCavernLogic.lua:239` |
| `G_CavernLogic`.**`ClientCompeleteFight`** | `(bFightResult: boolean, fightHeroStateMap: any, defenderState: any, tEmployHero: table, tEmployHeroState: table)` | `—` |  | `sc/user/Logical/ClientCavernLogic.lua:24` |
| `G_CavernLogic`.**`ClientCompeleteProgress`** | `()` | `OnCompeleteProgress` |  | `sc/user/Logical/ClientCavernLogic.lua:32` |
| `G_CavernLogic`.**`ClientRefreshGoodsList`** | `()` | `OnRefreshGoodsList` | 获得奖励 | `sc/user/Logical/ClientCavernLogic.lua:213` |
| `G_CavernLogic`.**`ClientRefreshGoodsWithCurrency`** | `()` | `—` |  | `sc/user/Logical/ClientCavernLogic.lua:220` |
| `G_CavernLogic`.**`ClientResetCavern`** | `()` | `OnResetCavern` | 获得奖励 | `sc/user/Logical/ClientCavernLogic.lua:205` |
| `G_CavernLogic`.**`ClientRevive`** | `()` | `—` |  | `sc/user/Logical/ClientCavernLogic.lua:196` |

#### ClientChapterLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_ChapterLogic`.**`ClientBuyChapterBattleResetCount`** | `(strChapterKey: string)` | `OnBuyChapterBattleResetCount` | ]] | `sc/user/Logical/ClientChapterLogic.lua:440` |
| `G_ChapterLogic`.**`ClientBuyChapterSweepCount`** | `(nSweepCount: number)` | `OnBuyChapterSweepCount` | ]] | `sc/user/Logical/ClientChapterLogic.lua:395` |
| `G_ChapterLogic`.**`ClientChapterBegin`** | `(tData: table)` | `—` | ]] | `sc/user/Logical/ClientChapterLogic.lua:309` |
| `G_ChapterLogic`.**`ClientChapterCompleteFaild`** | `(strChapterKey: string, tClientData: table)` | `OnChapterCompleteFaild` | ]] | `sc/user/Logical/ClientChapterLogic.lua:1211` |
| `G_ChapterLogic`.**`ClientChapterDJSJFComplete`** | `(strChapterKey: string, tClientData: table)` | `—` | ]] | `sc/user/Logical/ClientChapterLogic.lua:626` |
| `G_ChapterLogic`.**`ClientChapterHJRQComplete`** | `(strChapterKey: string, tClientData: table)` | `—` | ]] | `sc/user/Logical/ClientChapterLogic.lua:971` |
| `G_ChapterLogic`.**`ClientChapterHJRQSweep`** | `(strChapterKey: string)` | `—` | ]] | `sc/user/Logical/ClientChapterLogic.lua:1061` |
| `G_ChapterLogic`.**`ClientChapterPetBossComplete`** | `(strChapterKey: string, tClientData: table)` | `OnChapterPetBossComplete` | ]] | `sc/user/Logical/ClientChapterLogic.lua:903` |
| `G_ChapterLogic`.**`ClientChapterSCSComplete`** | `(strChapterKey: string, tClientData: table)` | `OnChapterSCSComplete` | ]] | `sc/user/Logical/ClientChapterLogic.lua:762` |
| `G_ChapterLogic`.**`ClientChapterSYZLBAndXZWCSweep`** | `(chapterKey: any)` | `OnChapterSYZLBAndXZWCSweep` | add by caidongquan / 发送三英战吕布 和 血战宛城 扫荡协议@auther chapterKey :副本类型（"FB_E_SYZLB or FB_E_XZWC" | `sc/user/Logical/ClientChapterLogic.lua:3280` |
| `G_ChapterLogic`.**`ClientChapterTGZZComplete`** | `(strChapterKey: string, tClientData: table)` | `OnChapterTGZZComplete` | ]] | `sc/user/Logical/ClientChapterLogic.lua:833` |
| `G_ChapterLogic`.**`ClientChapterTGZZSweep`** | `()` | `OnChapterTGZZSweep` | ]] | `sc/user/Logical/ClientChapterLogic.lua:1029` |
| `G_ChapterLogic`.**`ClientChapterXZWCComplete`** | `(strChapterKey: string, tClientData: table)` | `—` | ]] | `sc/user/Logical/ClientChapterLogic.lua:695` |
| `G_ChapterLogic`.**`ClientGetChapterTargetReward`** | `(tData: table)` | `—` | ]] | `sc/user/Logical/ClientChapterLogic.lua:141` |
| `G_ChapterLogic`.**`ClientGetSCSChapterNPCData`** | `(tLevelList: table)` | `—` | ]] | `sc/user/Logical/ClientChapterLogic.lua:34` |
| `G_ChapterLogic`.**`ClientReviveInBattle`** | `()` | `OnReviveInBattle` | ]] | `sc/user/Logical/ClientChapterLogic.lua:3320` |
| `G_ChapterLogic`.**`ClientUserOverHJRQ`** | `(nCount: number, strChapterKey: string)` | `OnUserOverHJRQ` | 提交黄巾入侵波数 | `sc/user/Logical/ClientChapterLogic.lua:3050` |

#### ClientClothingLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_ClothingLogic`.**`ClientComposeClothing`** | `(heroId: any, clothId: any)` | `OnComposeClothing` |  | `sc/user/Logical/ClientClothingLogic.lua:219` |
| `G_ClothingLogic`.**`ClientGetCharacterChargeWing`** | `()` | `—` | ]] | `sc/user/Logical/ClientClothingLogic.lua:31` |
| `G_ClothingLogic`.**`ClientGetCharacterFreeWing`** | `()` | `—` | ]] | `sc/user/Logical/ClientClothingLogic.lua:22` |
| `G_ClothingLogic`.**`ClientGetClothingPrize`** | `(strIndex: string)` | `OnGetClothingPrize` | ]] | `sc/user/Logical/ClientClothingLogic.lua:77` |
| `G_ClothingLogic`.**`ClientGetClothingPrizeCount`** | `(strIndex: string)` | `OnGetClothingPrizeCount` | ]] | `sc/user/Logical/ClientClothingLogic.lua:121` |
| `G_ClothingLogic`.**`ClientRefreshLeftWingCount`** | `()` | `OnRefreshLeftWingCount` | 刷新剩余翅膀数量 | `sc/user/Logical/ClientClothingLogic.lua:38` |
| `G_ClothingLogic`.**`ClientSetClothingPrizeUseStatus`** | `(strIndex: string)` | `—` | ]] | `sc/user/Logical/ClientClothingLogic.lua:168` |

#### ClientContestLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_TournamentLogic`.**`ClientBuyTournamentGoods`** | `(nIndex: number, nCount: number)` | `—` |  | `sc/user/Logical/ClientContestLogic.lua:393` |
| `G_TournamentLogic`.**`ClientDoQuiz`** | `(nRound: number, tSeatsIndex: table)` | `OnDoQuiz` | 助威 | `sc/user/Logical/ClientContestLogic.lua:170` |
| `G_TournamentLogic`.**`ClientGetBattleArray`** | `()` | `OnGetBattleArray` | 获取阵容 | `sc/user/Logical/ClientContestLogic.lua:107` |
| `G_TournamentLogic`.**`ClientGetBattleReport`** | `(bGroupMatchFlag: boolean)` | `OnGetBattleReport` | 获取武道会战报数据 | `sc/user/Logical/ClientContestLogic.lua:44` |
| `G_TournamentLogic`.**`ClientGetChampionInfo`** | `()` | `OnGetChampionInfo` | 获取冠军信息 | `sc/user/Logical/ClientContestLogic.lua:150` |
| `G_TournamentLogic`.**`ClientGetContestInfo`** | `()` | `OnGetContestInfo` | 查询武道会赛程信息 | `sc/user/Logical/ClientContestLogic.lua:20` |
| `G_TournamentLogic`.**`ClientGetFightTestResult`** | `(strTestSequence: string)` | `OnGetFightTestResult` |  | `sc/user/Logical/ClientContestLogic.lua:340` |
| `G_TournamentLogic`.**`ClientGetFinal32Info`** | `()` | `OnGetFinal32Info` | **武道32强数据请求 | `sc/user/Logical/ClientContestLogic.lua:305` |
| `G_TournamentLogic`.**`ClientGetFinalsInfo`** | `()` | `OnGetFinalsInfo` | 获取武道会决赛阶段的数据 | `sc/user/Logical/ClientContestLogic.lua:85` |
| `G_TournamentLogic`.**`ClientGetOtherInfo`** | `(nUserLevel: number)` | `OnGetOtherInfo` | 武道会简要信息查询（用于天降鸿福、红点等） | `sc/user/Logical/ClientContestLogic.lua:287` |
| `G_TournamentLogic`.**`ClientGetQuizInfo`** | `()` | `OnGetQuizInfo` | 获取我的助威信息 | `sc/user/Logical/ClientContestLogic.lua:191` |
| `G_ServerTournamentPrizeLogic`.**`ClientGetWelfare`** | `(nID: number)` | `OnGetWelfare` | **武道会撒钱 - 领取 | `sc/user/Logical/ClientContestLogic.lua:440` |
| `G_TournamentLogic`.**`ClientRequestFightTest`** | `()` | `OnRequestFightTest` | **武道会测试请求计算 | `sc/user/Logical/ClientContestLogic.lua:334` |
| `G_TournamentLogic`.**`ClientSaveBattleArray`** | `(tData: table)` | `OnSaveBattleArray` | 保存阵容 | `sc/user/Logical/ClientContestLogic.lua:129` |
| `G_TournamentLogic`.**`ClientSendBenefitReward`** | `(bDiamond: boolean)` | `OnSendBenefitReward` | 发放冠军福利 | `sc/user/Logical/ClientContestLogic.lua:271` |

#### ClientDestinyLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_DestinyLogic`.**`ClientActiveProgress`** | `()` | `OnActiveProgress` | 逐个请求 | `sc/user/Logical/ClientDestinyLogic.lua:16` |
| `G_DestinyLogic`.**`ClientActiveProgressWithCount`** | `(nCount: number)` | `OnActiveProgressWithCount` | 批量请求 | `sc/user/Logical/ClientDestinyLogic.lua:28` |

#### ClientEndlessChapterLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_EndlessChapterLogic`.**`ClientBuyChallengesCount`** | `()` | `—` |  | `sc/user/Logical/ClientEndlessChapterLogic.lua:364` |
| `G_EndlessChapterLogic`.**`ClientFight`** | `(heroIdList: any, tEmployHero: table)` | `OnFight` | 开始战斗 | `sc/user/Logical/ClientEndlessChapterLogic.lua:38` |
| `G_EndlessChapterLogic`.**`ClientGetEndlessChapterFirstPrize`** | `(nIndex: number)` | `—` | 获取首次通关奖励 | `sc/user/Logical/ClientEndlessChapterLogic.lua:372` |
| `G_EndlessChapterLogic`.**`ClientGetEndlessChapterRank`** | `()` | `OnGetEndlessChapterRank` | G_EventManager:PostLogicEvent(nil,EventManagerLogicEvent.EndlessChapter.OnGotoNextProsess) | `sc/user/Logical/ClientEndlessChapterLogic.lua:305` |
| `G_EndlessChapterLogic`.**`ClientGotoNextProsees`** | `()` | `—` |  | `sc/user/Logical/ClientEndlessChapterLogic.lua:297` |
| `G_EndlessChapterLogic`.**`ClientInspire`** | `(nResourceType: number)` | `OnInspire` |  | `sc/user/Logical/ClientEndlessChapterLogic.lua:276` |
| `G_EndlessChapterLogic`.**`ClientResetEndlessChapter`** | `()` | `OnResetEndlessChapter` | 重置无限关 | `sc/user/Logical/ClientEndlessChapterLogic.lua:283` |
| `G_EndlessChapterLogic`.**`ClientStopSwap`** | `()` | `OnStopSwap` | 停止扫荡 | `sc/user/Logical/ClientEndlessChapterLogic.lua:342` |
| `G_EndlessChapterLogic`.**`ClientSwap`** | `()` | `OnSwap` | 开始扫荡 | `sc/user/Logical/ClientEndlessChapterLogic.lua:327` |
| `G_EndlessChapterLogic`.**`ClientSwapImmediately`** | `()` | `—` | 立刻扫荡 | `sc/user/Logical/ClientEndlessChapterLogic.lua:350` |

#### ClientEpicBattleLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_EpicChapterLogic`.**`ClientEpicChapterBeginFight`** | `(CUIEpicData: any, tFightHeroIDList: table, tEmployHero: table)` | `—` |  | `sc/user/Logical/ClientEpicBattleLogic.lua:45` |
| `G_EpicChapterLogic`.**`ClientEpicChapterCompeleteFight`** | `(strChapterID: string, tHeroIdList: table, tEmployHero: table)` | `OnEpicChapterCompeleteFight` | 结算 | `sc/user/Logical/ClientEpicBattleLogic.lua:60` |
| `G_EpicChapterLogic`.**`ClientEpicChapterOpenBox`** | `(nLevelId: number, nOpenNum: number, bIsFree: boolean)` | `OnClientEpicChapterOpenBox` |  | `sc/user/Logical/ClientEpicBattleLogic.lua:10` |
| `G_EpicChapterLogic`.**`ClientEpicResetDaily`** | `()` | `OnEpicResetDaily` |  | `sc/user/Logical/ClientEpicBattleLogic.lua:81` |
| `G_EpicChapterLogic`.**`ClientSetTodayChapterDifficult`** | `(nFaction: number, nDifficult: number)` | `OnClientSetTodayChapterDifficult` |  | `sc/user/Logical/ClientEpicBattleLogic.lua:73` |
| `G_EpicChapterLogic`.**`ClientSweepEpicChapter`** | `(dwCampType: number, dwDifficultID: number)` | `OnSweepEpicChapter` |  | `sc/user/Logical/ClientEpicBattleLogic.lua:89` |

#### ClientEquipmentLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_EquipmentLogic`.**`ClientAutoIntensifyEquipment`** | `(nHeroID: number, nEquipPartID: number)` | `—` | ]] | `sc/user/Logical/ClientEquipmentLogic.lua:145` |
| `G_EquipmentLogic`.**`ClientForgingExclusiveEquip`** | `(nHeroID: number, nEquipPartID: number)` | `OnForgingExclusiveEquip` | ]] | `sc/user/Logical/ClientEquipmentLogic.lua:521` |
| `G_EquipmentLogic`.**`ClientPromoteQualityEquipment`** | `(nHeroID: number, nHeroPartID: number)` | `OnPromoteQualityEquipment` | ]] | `sc/user/Logical/ClientEquipmentLogic.lua:395` |
| `G_EquipmentLogic`.**`ClientPurifyExclusiveEquip`** | `(nHeroID: number, nEquipPartID: number)` | `OnPurifyExclusiveEquip` | ]] | `sc/user/Logical/ClientEquipmentLogic.lua:540` |
| `G_EquipmentLogic`.**`ClientRecastEquipment`** | `(nHeroID: number, nHeroPartID: number, nResourceType: number)` | `OnRecastEquipment` | ]] | `sc/user/Logical/ClientEquipmentLogic.lua:487` |
| `G_EquipmentLogic`.**`ClientRefineEquip`** | `(nHeroID: number, nEquipPartID: number)` | `OnRefineEquip` | ]] | `sc/user/Logical/ClientEquipmentLogic.lua:64` |

#### ClientFormationLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_FormationLogic`.**`ClientActiveRareFormation`** | `(strName: string)` | `OnActiveRareFormation` | 客户端接口：激活稀有阵法 | `sc/user/Logical/ClientFormationLogic.lua:20` |
| `G_FormationLogic`.**`ClientSelectAdvancedFormation`** | `(strName: string)` | `OnSelectAdvancedFormation` | 客户端接口：选择进阶阵法 | `sc/user/Logical/ClientFormationLogic.lua:31` |
| `G_FormationLogic`.**`ClientUpgrade`** | `(strName: string)` | `OnUpgrade` | 客户端接口：升级阵法 | `sc/user/Logical/ClientFormationLogic.lua:9` |

#### ClientFortuneWheelLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_FortuneWheelLogic`.**`ClientFreeRoll`** | `()` | `—` |  | `sc/user/Logical/ClientFortuneWheelLogic.lua:24` |
| `G_FortuneWheelLogic`.**`ClientGetNewServerDailyWheelPrizeList`** | `()` | `—` | ]] | `sc/user/Logical/ClientFortuneWheelLogic.lua:109` |
| `G_FortuneWheelLogic`.**`ClientRefreshFortuneWheelList`** | `()` | `—` |  | `sc/user/Logical/ClientFortuneWheelLogic.lua:13` |
| `G_FortuneWheelLogic`.**`ClientRunNewServerDailyWheel`** | `()` | `—` | ]] | `sc/user/Logical/ClientFortuneWheelLogic.lua:50` |
| `G_FortuneWheelLogic`.**`ClientVipRoll`** | `()` | `OnVipRoll` |  | `sc/user/Logical/ClientFortuneWheelLogic.lua:33` |

#### ClientFriendLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_FriendLogic`.**`ClientApplyForFriend`** | `(nTargetUid: number)` | `OnApplyForFriend` | ]] | `sc/user/Logical/ClientFriendLogic.lua:282` |
| `G_FriendLogic`.**`ClientBatchReceiveFriendFatigue`** | `(tData: table)` | `OnBatchReceiveFriendFatigue` | ]] | `sc/user/Logical/ClientFriendLogic.lua:824` |
| `G_FriendLogic`.**`ClientBatchSendriendFatigue`** | `(tData: table)` | `OnBatchSendriendFatigue` | ]] | `sc/user/Logical/ClientFriendLogic.lua:794` |
| `G_FriendLogic`.**`ClientFightFriend`** | `(uid: any, fightHeroList: any)` | `OnFightFriend` |  | `sc/user/Logical/ClientFriendLogic.lua:68` |
| `G_FriendLogic`.**`ClientGetQQWXFriendDetail`** | `(tData: table)` | `OnGetQQWXFriendDetail` | ]] | `sc/user/Logical/ClientFriendLogic.lua:697` |
| `G_FriendLogic`.**`ClientGetQqWxFriendFatigue`** | `(fromOpenId: any)` | `OnGetQqWxFriendFatigue` | ]] | `sc/user/Logical/ClientFriendLogic.lua:732` |
| `G_FriendLogic`.**`ClientGetRecommendedFriend`** | `()` | `OnGetRecommendedFriend` | ]] | `sc/user/Logical/ClientFriendLogic.lua:519` |
| `G_FriendLogic`.**`ClientGetUserDetailByUid`** | `(nTargetUid: number)` | `OnGetUserDetailByUid` | ]] | `sc/user/Logical/ClientFriendLogic.lua:251` |
| `G_FriendLogic`.**`ClientGetUserFriends`** | `()` | `OnGetUserFriends` | ]] | `sc/user/Logical/ClientFriendLogic.lua:222` |
| `G_FriendLogic`.**`ClientGetUserRelations`** | `()` | `OnGetUserRelations` | ]] | `sc/user/Logical/ClientFriendLogic.lua:39` |
| `G_FriendLogic`.**`ClientReceiveGift`** | `(nTargetUid: number)` | `OnReceiveGift` | ]] | `sc/user/Logical/ClientFriendLogic.lua:475` |
| `G_FriendLogic`.**`ClientReceiveGiftAll`** | `()` | `OnReceiveGiftAll` | ]] | `sc/user/Logical/ClientFriendLogic.lua:588` |
| `G_FriendLogic`.**`ClientRefuseAllApply`** | `()` | `OnRefuseAllApply` | ]] | `sc/user/Logical/ClientFriendLogic.lua:359` |
| `G_FriendLogic`.**`ClientRemoveFriend`** | `(nTargetUid: number)` | `OnRemoveFriend` | ]] | `sc/user/Logical/ClientFriendLogic.lua:395` |
| `G_FriendLogic`.**`ClientSearchUserWithName`** | `(strSearchName: string)` | `OnSearchUserWithName` | ]] | `sc/user/Logical/ClientFriendLogic.lua:193` |
| `G_FriendLogic`.**`ClientSendGift`** | `(nTargetUid: number)` | `OnSendGift` | ]] | `sc/user/Logical/ClientFriendLogic.lua:440` |
| `G_FriendLogic`.**`ClientSendGiftAll`** | `()` | `OnSendGiftAll` | ]] | `sc/user/Logical/ClientFriendLogic.lua:555` |
| `G_FriendLogic`.**`ClientSendQqWxFriendFatigue`** | `(friendOpenId: any)` | `OnSendQqWxFriendFatigue` | ]] | `sc/user/Logical/ClientFriendLogic.lua:762` |

#### ClientGameWorld

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_GameWorld`.**`ClientEnterGame`** | `()` | `OnEnterGame` |  | `sc/user/Logical/ClientGameWorld.lua:262` |
| `G_GameWorld`.**`ClientGetRandomName`** | `(b: any)` | `OnGetRandomName` |  | `sc/user/Logical/ClientGameWorld.lua:280` |
| `G_NewHandPrivilegeLogic`.**`ClientGetUserNewHandPrivilegeInfo`** | `()` | `OnGetUserNewHandPrivilegeInfo` |  | `sc/user/Logical/ClientGameWorld.lua:78` |
| `G_GameWorld`.**`ClientUpdateServerTimeEx`** | `()` | `OnUpdateServerTimeEx` | ]] | `sc/user/Logical/ClientGameWorld.lua:253` |

#### ClientGodSecret

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_GodSecret`.**`ClientExchange`** | `(nIndex: number)` | `OnExchange` | 兑换 | `sc/user/Logical/ClientGodSecret.lua:373` |
| `G_GodSecret`.**`ClientFreeRefresh`** | `()` | `OnFreeRefresh` | 免费刷新 | `sc/user/Logical/ClientGodSecret.lua:351` |
| `G_GodSecret`.**`ClientGetGloblePrize`** | `(nIndex: number)` | `OnGetGloblePrize` | 获取全服奖励 | `sc/user/Logical/ClientGodSecret.lua:419` |
| `G_GodSecret`.**`ClientGetGlobleScore`** | `()` | `OnGetGlobleScore` | 获取全服积分 | `sc/user/Logical/ClientGodSecret.lua:407` |
| `G_GodSecret`.**`ClientGetRanking`** | `()` | `OnGetRanking` | 获取奖励排行 | `sc/user/Logical/ClientGodSecret.lua:395` |
| `G_GodSecret`.**`ClientRefresh`** | `()` | `OnRefresh` | 钻石刷新 | `sc/user/Logical/ClientGodSecret.lua:362` |

#### ClientGuildApplyLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_GuildLogic`.**`ClientApplyGuild`** | `(nGuildId: number)` | `OnApplyGuild` | ]] | `sc/user/Logical/ClientGuildApplyLogic.lua:223` |
| `G_GuildLogic`.**`ClientCancelApply`** | `(nGuildId: number)` | `OnCancelApply` | ]] | `sc/user/Logical/ClientGuildApplyLogic.lua:272` |
| `G_GuildLogic`.**`ClientCreateGuild`** | `(strPictrueId: string, strGuildName: string, GetStringWithKey: any)` | `OnCreateGuild` | ]] | `sc/user/Logical/ClientGuildApplyLogic.lua:118` |
| `G_GuildLogic`.**`ClientDonateGuildTechnology`** | `(strName: string, nIndex: number)` | `OnDonateGuildTechnology` |  | `sc/user/Logical/ClientGuildApplyLogic.lua:918` |
| `G_GuildLogic`.**`ClientGetRandGuildList`** | `()` | `OnGetRandGuildList` | ]] | `sc/user/Logical/ClientGuildApplyLogic.lua:50` |
| `G_GuildLogic`.**`ClientImpeachHeadman`** | `(headUid: any, guildId: any)` | `OnImpeachHeadman` | 弹劾团长 | `sc/user/Logical/ClientGuildApplyLogic.lua:860` |
| `G_GuildLogic`.**`ClientJoinGuild`** | `(nGuildId: number)` | `—` | ]] | `sc/user/Logical/ClientGuildApplyLogic.lua:170` |
| `G_GuildLogic`.**`ClientSearchGuild`** | `(nGuildId: number)` | `OnSearchGuild` | ]] | `sc/user/Logical/ClientGuildApplyLogic.lua:324` |

#### ClientGuildCampLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_GuildCampLogic`.**`ClientFirewood`** | `()` | `OnFirewood` | 篝火---------------------------------------------------------------------------------------- | `sc/user/Logical/ClientGuildCampLogic.lua:272` |
| `G_GuildCampLogic`.**`ClientGetWaterTreeReward`** | `()` | `OnGetWaterTreeReward` | 获取浇水奖励 | `sc/user/Logical/ClientGuildCampLogic.lua:219` |

#### ClientGuildDispatchLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_GuildLogic`.**`ClientDispatchHero`** | `(nGUildId: number, nHeroId: number)` | `OnDispatchHero` | ]] | `sc/user/Logical/ClientGuildDispatchLogic.lua:81` |
| `G_GuildLogic`.**`ClientEmployDispatchHero`** | `(nHeroId: number, nHostUid: number, nGuildId: number, nFightType: number)` | `—` | ]] | `sc/user/Logical/ClientGuildDispatchLogic.lua:261` |
| `G_GuildLogic`.**`ClientGetDispatchHeroList`** | `(nGuildId: number)` | `OnGetDispatchHeroList` | ]] | `sc/user/Logical/ClientGuildDispatchLogic.lua:182` |
| `G_GuildLogic`.**`ClientPickGuildHero`** | `(nHeroId: number)` | `OnPickGuildHero` | ]] | `sc/user/Logical/ClientGuildDispatchLogic.lua:131` |
| `G_GuildLogic`.**`ClientQuerySelfDispatchList`** | `(nGuildId: number)` | `—` | ]] | `sc/user/Logical/ClientGuildDispatchLogic.lua:29` |

#### ClientGuildINeedHeroLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_GuildLogic`.**`ClientGetDiceGameData`** | `()` | `OnGetDiceGameData` | 获取骰子数据 | `sc/user/Logical/ClientGuildINeedHeroLogic.lua:11` |
| `G_GuildLogic`.**`ClientGetDiceGameReward`** | `()` | `OnGetDiceGameReward` | 领取骰子奖励 | `sc/user/Logical/ClientGuildINeedHeroLogic.lua:48` |
| `G_GuildLogic`.**`ClientPlayDiceGame`** | `()` | `OnPlayDiceGame` | 玩家摇骰子 | `sc/user/Logical/ClientGuildINeedHeroLogic.lua:34` |

#### ClientGuildManageLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_GuildLogic`.**`ClientAcceptApply`** | `(ApplyUid: any, GuildId: any, Nick: any)` | `OnAcceptApply` | ]] | `sc/user/Logical/ClientGuildManageLogic.lua:330` |
| `G_GuildLogic`.**`ClientCancelGuild`** | `(GuildId: any)` | `OnCancelGuild` | ]] | `sc/user/Logical/ClientGuildManageLogic.lua:574` |
| `G_GuildLogic`.**`ClientCancelManager`** | `(ManagerUid: any, GuildId: any, strManagerNick: string)` | `OnCancelManager` | ]] | `sc/user/Logical/ClientGuildManageLogic.lua:454` |
| `G_GuildLogic`.**`ClientDonateGuild`** | `(GuildId: any, strType: string, Amount: any)` | `OnDonateGuild` | ]] | `sc/user/Logical/ClientGuildManageLogic.lua:659` |
| `G_GuildLogic`.**`ClientExitGuild`** | `(GuildId: any)` | `OnExitGuild` | ]] | `sc/user/Logical/ClientGuildManageLogic.lua:547` |
| `G_GuildLogic`.**`ClientGetGuildApplyList`** | `(GuildId: any)` | `OnGetGuildApplyList` | ]] | `sc/user/Logical/ClientGuildManageLogic.lua:725` |
| `G_GuildLogic`.**`ClientGetGuildInfo`** | `(PageNo: any, PageSize: any, GuildId: any)` | `OnGetGuildInfo` | ]] | `sc/user/Logical/ClientGuildManageLogic.lua:272` |
| `G_GuildLogic`.**`ClientGetGuildLogList`** | `(GuildId: any)` | `OnGetGuildLogList` | ]] | `sc/user/Logical/ClientGuildManageLogic.lua:629` |
| `G_GuildLogic`.**`ClientIsHaveGuildRedPoint`** | `(GuildId: any)` | `—` | 军团红点 | `sc/user/Logical/ClientGuildManageLogic.lua:126` |
| `G_GuildLogic`.**`ClientKickGuild`** | `(KickUid: any, GuildId: any, strKickNick: string)` | `OnKickGuild` | ]] | `sc/user/Logical/ClientGuildManageLogic.lua:485` |
| `G_GuildLogic`.**`ClientModifyGuildSetting`** | `(GuildId: any, Type: any, PictrueId: any, AcceptLevel: any)` | `—` | ]] | `sc/user/Logical/ClientGuildManageLogic.lua:516` |
| `G_GuildLogic`.**`ClientModifyNotice`** | `(GuildId: any, sNotice: string, sWeChatGroup: string, sQQGroup: string)` | `OnModifyNotice` | ]] | `sc/user/Logical/ClientGuildManageLogic.lua:693` |
| `G_GuildLogic`.**`ClientRefreshUserGuild`** | `(GuildId: any)` | `OnRefreshUserGuild` | ]] | `sc/user/Logical/ClientGuildManageLogic.lua:604` |
| `G_GuildLogic`.**`ClientRejectApply`** | `(ApplyUid: any, GuildId: any)` | `OnRejectApply` | ]] | `sc/user/Logical/ClientGuildManageLogic.lua:361` |
| `G_GuildLogic`.**`ClientSetHead`** | `(HeadUid: any, GuildId: any, strHeadNick: string)` | `OnSetHead` | ]] | `sc/user/Logical/ClientGuildManageLogic.lua:392` |
| `G_GuildLogic`.**`ClientSetManager`** | `(ManagerUid: any, GuildId: any, strManagerNick: string)` | `OnSetManager` | ]] | `sc/user/Logical/ClientGuildManageLogic.lua:423` |
| `G_GuildLogic`.**`ClientUploadWeChatGroup`** | `(guildId: any, strUrl: string)` | `OnUploadWeChatGroup` | 设置微信群 | `sc/user/Logical/ClientGuildManageLogic.lua:777` |

#### ClientGuildStoreLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_GuildStoreLogic`.**`ClientRefreshWithContribution`** | `()` | `—` |  | `sc/user/Logical/ClientGuildStoreLogic.lua:22` |

#### ClientHeroLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_HeroLogic`.**`ClientAutoIntensifyWing`** | `(nHeroID: number)` | `—` | ]] | `sc/user/Logical/ClientHeroLogic.lua:1065` |
| `G_HeroLogic`.**`ClientBreakthroughHeroMaxLevel`** | `(nHeroID: number)` | `—` | ]] | `sc/user/Logical/ClientHeroLogic.lua:168` |
| `G_HeroLogic`.**`ClientConvertUniversalFragment`** | `(nHeroID: number, nCount: number)` | `OnConvertUniversalFragment` | ]] | `sc/user/Logical/ClientHeroLogic.lua:1090` |
| `G_HeroLogic`.**`ClientEquipHreroSkin`** | `(nHeroID: number, strPartID: string, strSkinID: string)` | `—` | ]] | `sc/user/Logical/ClientHeroLogic.lua:240` |
| `G_HeroLogic`.**`ClientGetHeroExclusiveSkin`** | `(nHeroID: number)` | `—` |  | `sc/user/Logical/ClientHeroLogic.lua:1121` |
| `G_HeroLogic`.**`ClientGetTopFightCapacity`** | `(nCount: number)` | `OnGetTopFightCapacity` | 请求服务器的最高**人战斗力 | `sc/user/Logical/ClientHeroLogic.lua:1096` |
| `G_HeroLogic`.**`ClientIntensifyWing`** | `(nHeroID: number)` | `—` | ]] | `sc/user/Logical/ClientHeroLogic.lua:1044` |
| `G_HeroLogic`.**`ClientRecruitHero`** | `(nHeroID: number)` | `OnRecruitHero` | ]] | `sc/user/Logical/ClientHeroLogic.lua:132` |
| `G_HeroLogic`.**`ClientResetHeroSkyFate`** | `(nHeroID: number)` | `OnResetHeroSkyFate` | 英雄天命重置 | `sc/user/Logical/ClientHeroLogic.lua:1157` |
| `G_HeroLogic`.**`ClientSetExclusiveSkinState`** | `(nHeroID: number, isCancel: any)` | `OnSetExclusiveSkinState` | 切换专属 | `sc/user/Logical/ClientHeroLogic.lua:1168` |
| `G_HeroLogic`.**`ClientShowMagicWing`** | `(nHeroID: number, nMagicWingID: number)` | `—` | ]] | `sc/user/Logical/ClientHeroLogic.lua:1081` |
| `G_HeroLogic`.**`ClientShowWing`** | `(nHeroID: number, nWingLevel: number)` | `OnShowWing` | ]] | `sc/user/Logical/ClientHeroLogic.lua:1073` |
| `G_HeroLogic`.**`ClientTakeOffHreroSkin`** | `(nHeroID: number, strPartID: string, strSkinID: string)` | `—` | ]] | `sc/user/Logical/ClientHeroLogic.lua:249` |
| `G_HeroLogic`.**`ClientUpHeroFightSoul`** | `(nHeroID: number, nCount: number)` | `OnUpHeroFightSoul` | add 2015-05-07 by zhouzhifeng / 提升武魂 | `sc/user/Logical/ClientHeroLogic.lua:977` |
| `G_HeroLogic`.**`ClientUpdateHeroSkyFate`** | `(nHeroID: number, strSkyFateType: string)` | `OnUpdateHeroSkyFate` | 英雄天命升级 | `sc/user/Logical/ClientHeroLogic.lua:1146` |
| `G_HeroLogic`.**`ClientUpgradeHeroGrowthFactor`** | `(nHeroID: number)` | `OnUpgradeHeroGrowthFactor` | ]] | `sc/user/Logical/ClientHeroLogic.lua:66` |
| `G_HeroLogic`.**`ClientUpgradeHeroQualityPromotion`** | `(nHeroID: number)` | `—` | ]] | `sc/user/Logical/ClientHeroLogic.lua:99` |
| `G_HeroLogic`.**`ClientUpgradeWing`** | `(nHeroID: number)` | `OnUpgradeWing` | ]] | `sc/user/Logical/ClientHeroLogic.lua:1013` |
| `G_HeroLogic`.**`ClientUpgradeWingWithDiamond`** | `(nHeroID: number)` | `—` | ]] | `sc/user/Logical/ClientHeroLogic.lua:1021` |
| `G_HeroLogic`.**`ClientUseHeroExperiencePill`** | `(nHeroID: number, nItemID: number, nCount: number)` | `OnUseHeroExperiencePill` | ]] | `sc/user/Logical/ClientHeroLogic.lua:205` |

#### ClientHeroPKLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_PkProtocol`.**`ClientDoGamble`** ⟳ | `(nServerId: number, nUid: number, nGambleFlag: number)` | `—` | 下注 | `sc/user/Logical/ClientHeroPKLogic.lua:4` |
| `G_PkProtocol`.**`ClientGMNextStep`** ⟳ | `()` | `OnClientGMNextStep` | 进入下一阶段的GM命令 | `sc/user/Logical/ClientHeroPKLogic.lua:4` |
| `G_PkProtocol`.**`ClientGetData`** ⟳ | `("ApplyUI": string = "ApplyUI", {"ControlData", "YesterdayTop3"}: table)` | `OnClientGetData` | 获取通用数据 | `sc/user/Logical/ClientHeroPKLogic.lua:4` |
| `G_PkProtocol`.**`ClientGetFightDetail`** ⟳ | `(szFightRecordId: string)` | `OnGetFightDetail` | 获取战斗回放数据 | `sc/user/Logical/ClientHeroPKLogic.lua:4` |
| `G_PkProtocol`.**`ClientGetOtherLineup`** ⟳ | `(nServerId: number, nUid: number)` | `OnGetOtherLineup` | 获取其他玩家阵容数据 | `sc/user/Logical/ClientHeroPKLogic.lua:4` |
| `G_PkProtocol`.**`ClientGetRank`** ⟳ | `(__nStartBetRankNum: any, __nMaxBetRankNum: any)` | `—` | 请求排行榜和下注列表的数据 | `sc/user/Logical/ClientHeroPKLogic.lua:4` |
| `G_PkProtocol`.**`ClientGetYesterdaySelf`** ⟳ | `()` | `—` | 我的昨日赛程 | `sc/user/Logical/ClientHeroPKLogic.lua:4` |
| `G_PkProtocol`.**`ClientSaveLineup`** ⟳ | `({Junior=self.m.lineup.Junior or {}, Final=self.m.lineup.Final or {}}: table)` | `OnClientSaveLineup` | 保存阵容数据 | `sc/user/Logical/ClientHeroPKLogic.lua:4` |
| `G_PkProtocol`.**`ClientSignup`** ⟳ | `()` | `—` | 报名 | `sc/user/Logical/ClientHeroPKLogic.lua:4` |
| `G_PkProtocol`.**`ClientTodayOther`** ⟳ | `(nRound: number)` | `—` | 其他人战况 | `sc/user/Logical/ClientHeroPKLogic.lua:4` |

#### ClientItemLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_ItemLogic`.**`ClientBatchUseItem`** | `()` | `—` | ]] | `sc/user/Logical/ClientItemLogic.lua:279` |
| `G_ItemLogic`.**`ClientBatchUseItemWithItemList`** | `(tUseItemList: table)` | `OnBatchUseItemWithItemList` | ]] | `sc/user/Logical/ClientItemLogic.lua:236` |
| `G_ItemLogic`.**`ClientBuyItem`** | `(nItemID: number, nCount: number, nResourceType: number)` | `—` |  | `sc/user/Logical/ClientItemLogic.lua:300` |
| `G_ItemLogic`.**`ClientBuyItemBatch`** | `(buyList: any)` | `—` |  | `sc/user/Logical/ClientItemLogic.lua:333` |
| `G_ItemLogic`.**`ClientRefineItem`** | `(tData: table)` | `—` | ]] | `sc/user/Logical/ClientItemLogic.lua:43` |
| `G_ItemLogic`.**`ClientSellRedundantExclusiveItem`** | `()` | `—` | 出售多余专属武器卷轴 | `sc/user/Logical/ClientItemLogic.lua:343` |
| `G_ItemLogic`.**`ClientSynthesisItem`** | `(nItemID: number)` | `—` | ]] | `sc/user/Logical/ClientItemLogic.lua:86` |

#### ClientLeaderboard

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_RankLogic`.**`ClientGet5HeroPowerRank`** | `()` | `OnGet5HeroPowerRank` | ]] | `sc/user/Logical/ClientLeaderboard.lua:282` |
| `G_RankLogic`.**`ClientGetArenaDefendPowerRank`** | `()` | `OnGetArenaDefendPowerRank` | ]] | `sc/user/Logical/ClientLeaderboard.lua:231` |
| `G_RankLogic`.**`ClientGetDJSJFRank`** | `()` | `OnGetDJSJFRank` | ]] | `sc/user/Logical/ClientLeaderboard.lua:440` |
| `G_RankLogic`.**`ClientGetGuildRank`** | `(nGuildId: number)` | `OnGetGuildRank` | ]] | `sc/user/Logical/ClientLeaderboard.lua:671` |
| `G_RankLogic`.**`ClientGetGuildWarScoreRank`** | `(nGuildId: number)` | `OnGetGuildWarScoreRank` | ]] | `sc/user/Logical/ClientLeaderboard.lua:723` |
| `G_RankLogic`.**`ClientGetHjrqRank`** | `(strChapterKey: string)` | `OnGetHjrqRank` | ]] | `sc/user/Logical/ClientLeaderboard.lua:339` |
| `G_RankLogic`.**`ClientGetLevelRank`** | `()` | `OnGetLevelRank` | ]] | `sc/user/Logical/ClientLeaderboard.lua:181` |
| `G_RankLogic`.**`ClientGetPveEliteRank`** | `()` | `OnGetPveEliteRank` | ]] | `sc/user/Logical/ClientLeaderboard.lua:564` |
| `G_RankLogic`.**`ClientGetPveNormalRank`** | `()` | `OnGetPveNormalRank` | ]] | `sc/user/Logical/ClientLeaderboard.lua:511` |
| `G_RankLogic`.**`ClientGetPveStarRank`** | `()` | `OnGetPveStarRank` | ]] | `sc/user/Logical/ClientLeaderboard.lua:617` |
| `G_RankLogic`.**`ClientGetSCSZLRank`** | `()` | `OnGetSCSZLRank` | ]] | `sc/user/Logical/ClientLeaderboard.lua:408` |
| `G_RankLogic`.**`ClientGetSYZLBRank`** | `(strChapterKey: string)` | `OnGetSYZLBRank` | ]] | `sc/user/Logical/ClientLeaderboard.lua:375` |
| `G_RankLogic`.**`ClientGetSelfDJSJFRankScore`** | `()` | `OnGetSelfDJSJFRankScore` | ]] | `sc/user/Logical/ClientLeaderboard.lua:124` |
| `G_RankLogic`.**`ClientGetSelfHJRQRankScore`** | `(strChapterKey: string)` | `OnGetSelfHJRQRankScore` | ]] | `sc/user/Logical/ClientLeaderboard.lua:28` |
| `G_RankLogic`.**`ClientGetSelfSCSZLRankScore`** | `()` | `OnGetSelfSCSZLRankScore` | ]] | `sc/user/Logical/ClientLeaderboard.lua:98` |
| `G_RankLogic`.**`ClientGetSelfSYZLBRankScore`** | `(strChapterKey: string)` | `OnGetSelfSYZLBRankScore` | ]] | `sc/user/Logical/ClientLeaderboard.lua:60` |
| `G_RankLogic`.**`ClientGetSelfXZWCRankScore`** | `(strChapterKey: string)` | `OnGetSelfXZWCRankScore` | ]] | `sc/user/Logical/ClientLeaderboard.lua:154` |
| `G_RankLogic`.**`ClientGetTGZZRank`** | `()` | `OnGetTGZZRank` |  | `sc/user/Logical/ClientLeaderboard.lua:78` |
| `G_RankLogic`.**`ClientGetXZWCRank`** | `(strChapterKey: string)` | `OnGetXZWCRank` | ]] | `sc/user/Logical/ClientLeaderboard.lua:477` |

#### ClientLotteryLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_LotteryLogic`.**`ClientGetSoulBoxHeroFragmentList`** | `()` | `—` | ]] | `sc/user/Logical/ClientLotteryLogic.lua:197` |
| `G_LotteryLogic`.**`ClientPlayLottery`** | `(nLotteryType: number, bTest: boolean)` | `—` | ]] | `sc/user/Logical/ClientLotteryLogic.lua:41` |
| `G_LotteryLogic`.**`ClientPlaySoulBox`** | `(bTest: boolean)` | `—` | ]] | `sc/user/Logical/ClientLotteryLogic.lua:137` |

#### ClientMagicWeaponTreasureBox

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_MagicWeaponTreasureBox`.**`ClientOpenBoxWithDiamond`** | `(nCount: number)` | `OnOpenBoxWithDiamond` | 使用钻石开宝箱（nCount == 10为十连抽） | `sc/user/Logical/ClientMagicWeaponTreasureBox.lua:16` |
| `G_MagicWeaponTreasureBox`.**`ClientOpenBoxWithKey`** | `(nCount: number)` | `OnOpenBoxWithKey` | 使用钥匙开宝箱（nCount == 10为十连抽） | `sc/user/Logical/ClientMagicWeaponTreasureBox.lua:5` |

#### ClientMailLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_MailLogic`.**`ClientSaveMailPrizeWithMailID`** | `(strMailID: string)` | `OnSaveMailPrizeWithMailID` | ]] | `sc/user/Logical/ClientMailLogic.lua:196` |
| `G_MailLogic`.**`ClientSaveMailPrizeWithMailIdList`** | `(tMailIdList: table)` | `—` | ]] | `sc/user/Logical/ClientMailLogic.lua:253` |
| `G_MailLogic`.**`ClientSetMailReadWithMailID`** | `(strMailID: string)` | `OnSetMailReadWithMailID` | ]] | `sc/user/Logical/ClientMailLogic.lua:342` |

#### ClientMidasTouchLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_MidasTouchLogic`.**`ClientRunMidasTouchWithCount`** | `(nCount: number)` | `—` | ]] | `sc/user/Logical/ClientMidasTouchLogic.lua:32` |

#### ClientMysteriousStoreLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_MysteriousStoreLogic`.**`ClientRefreshWithDiamond`** | `(strIndex: string)` | `—` | 使用钻石刷新商品列表 | `sc/user/Logical/ClientMysteriousStoreLogic.lua:63` |

#### ClientPaymentLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_RechargeLogic`.**`ClientGetPaymentConfig`** | `()` | `OnGetPaymentConfig` | ]] | `sc/user/Logical/ClientPaymentLogic.lua:23` |

#### ClientPetLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_PetProtocol`.**`ClientAdvanceClassReq`** ⟳ | `(Type: any)` | `—` | 进阶 | `sc/user/Logical/ClientPetLogic.lua:6` |
| `G_PetProtocol`.**`ClientBuyFishQueueReq`** ⟳ | `()` | `OnBuyFishQueue` | 购买养鱼队列 | `sc/user/Logical/ClientPetLogic.lua:6` |
| `G_PetProtocol`.**`ClientCatchFishReq`** ⟳ | `(nIndex<=nFreeCount: number, nIndex>nFreeCount and nIndex-nFreeCount or nIndex: number)` | `OnCatchFish` | 收获鱼苗成道具 | `sc/user/Logical/ClientPetLogic.lua:6` |
| `G_PetProtocol`.**`ClientCollectReq`** ⟳ | `(strType: string, false: boolean = false)` | `OnCollect` | 采集 | `sc/user/Logical/ClientPetLogic.lua:6` |
| `G_PetProtocol`.**`ClientEnterPetRoomReq`** ⟳ | `()` | `OnEnterPetRoom` | 进入林地 | `sc/user/Logical/ClientPetLogic.lua:6` |
| `G_PetProtocol`.**`ClientGetOtherFishDetailReq`** ⟳ | `(Uid: any, nServerId: number)` | `—` | 获取他人的鱼苗信息 | `sc/user/Logical/ClientPetLogic.lua:6` |
| `G_PetProtocol`.**`ClientGetOtherPetDetailReq`** ⟳ | `(__nUid: any, nServerId: number)` | `—` | 获取他人宠物信息 | `sc/user/Logical/ClientPetLogic.lua:6` |
| `G_PetProtocol`.**`ClientGetSealPetReq`** ⟳ | `()` | `—` | 解封宠物，点亮封印 | `sc/user/Logical/ClientPetLogic.lua:6` |
| `G_PetProtocol`.**`ClientGetSocialFishInfoReq`** ⟳ | `()` | `—` | 军团成员鱼苗加速 | `sc/user/Logical/ClientPetLogic.lua:6` |
| `G_PetProtocol`.**`ClientGetSocialPetInfoReq`** ⟳ | `()` | `—` | 军团成员宠物加速 | `sc/user/Logical/ClientPetLogic.lua:6` |
| `G_PetProtocol`.**`ClientGiveupPotentialReq`** ⟳ | `(Type: any)` | `—` | 放弃潜力 | `sc/user/Logical/ClientPetLogic.lua:6` |
| `G_PetProtocol`.**`ClientKeepFishBabyReq`** ⟳ | `()` | `OnKeepFishBaby` | 保留鱼苗 | `sc/user/Logical/ClientPetLogic.lua:6` |
| `G_PetProtocol`.**`ClientKeepPotentialReq`** ⟳ | `(Type: any)` | `—` | 保存潜力 | `sc/user/Logical/ClientPetLogic.lua:6` |
| `G_PetProtocol`.**`ClientPossessReq`** ⟳ | `(rightPetType: any, tostring: any)` | `OnPossess` | 附身 | `sc/user/Logical/ClientPetLogic.lua:6` |
| `G_PetProtocol`.**`ClientRaiseIntimacyReq`** ⟳ | `(tostring: any, {{id = tItemConfig.ItemId,count = self.FeedCount or 0}}: table)` | `—` | 提升亲密度 | `sc/user/Logical/ClientPetLogic.lua:6` |
| `G_PetProtocol`.**`ClientRefreshFishBabyReq`** ⟳ | `()` | `OnRefreshFishBaby` | 刷新鱼苗 | `sc/user/Logical/ClientPetLogic.lua:6` |
| `G_PetProtocol`.**`ClientRefreshFishQueueReq`** ⟳ | `()` | `OnRefreshFishQueue` | 进入水族馆时先通知服务端刷新数据 | `sc/user/Logical/ClientPetLogic.lua:6` |
| `G_PetProtocol`.**`ClientRefreshPetExpReq`** ⟳ | `()` | `—` | 刷新宠物经验，判断升级时调用 | `sc/user/Logical/ClientPetLogic.lua:6` |
| `G_PetProtocol`.**`ClientResetIntelligenceReq`** ⟳ | `(Type: any, IsProtectIntelligence: any)` | `—` | 灵性提升 | `sc/user/Logical/ClientPetLogic.lua:6` |
| `G_PetProtocol`.**`ClientResetPotentialReq`** ⟳ | `(Type: any, Id: number)` | `—` | 洗潜力 | `sc/user/Logical/ClientPetLogic.lua:6` |
| `G_PetProtocol`.**`ClientSetFightReq`** ⟳ | `("": string = "")` | `—` | 出战 | `sc/user/Logical/ClientPetLogic.lua:6` |
| `G_PetProtocol`.**`ClientSpeedFishReq`** ⟳ | `(nUid: number, nServerId: number, strType: string, nIdx: number)` | `—` | 加速他人的鱼苗 | `sc/user/Logical/ClientPetLogic.lua:6` |
| `G_PetProtocol`.**`ClientSpeedPetReq`** ⟳ | `(__nUid: any, nServerId: number, tostring: any)` | `—` | 加速他人的宠物 | `sc/user/Logical/ClientPetLogic.lua:6` |
| `G_PetProtocol`.**`ClientSpeedTrainPetReq`** ⟳ | `()` | `—` | 推进器 | `sc/user/Logical/ClientPetLogic.lua:6` |

#### ClientPotionLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_PotionLogic`.**`ClientCompletePotionUpgradeWithDiamond`** | `()` | `OnCompletePotionUpgradeWithDiamond` |  | `sc/user/Logical/ClientPotionLogic.lua:53` |
| `G_PotionLogic`.**`ClientUpgradeResearch`** | `()` | `OnUpgradeResearch` |  | `sc/user/Logical/ClientPotionLogic.lua:9` |

#### ClientQuestLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_HeroPracticeLogic`.**`ClientGetPracticeInfo`** | `()` | `—` |  | `sc/user/Logical/ClientQuestLogic.lua:39` |
| `G_HeroPracticeLogic`.**`ClientGetPracticePrize`** | `(strArenaID: string)` | `—` | 领取训练奖励 | `sc/user/Logical/ClientQuestLogic.lua:28` |
| `G_HeroPracticeLogic`.**`ClientPracticeHero`** | `(nHeroID: number, strArenaID: string)` | `OnPracticeHero` | 训练英雄 | `sc/user/Logical/ClientQuestLogic.lua:15` |

#### ClientRechargeLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_RechargeLogic`.**`ClientGetAndoirdFeedBack`** | `()` | `OnGetAndoirdFeedBack` | 领取Android充值返还 | `sc/user/Logical/ClientRechargeLogic.lua:230` |
| `G_RechargeLogic`.**`ClientGetFirstRechargePrize`** | `()` | `OnGetFirstRechargePrize` | ]] | `sc/user/Logical/ClientRechargeLogic.lua:28` |
| `G_RechargeLogic`.**`ClientGetFirstRechargeUserAndCount`** | `()` | `OnGetFirstRechargeUserAndCount` | 获取服务器充值人数和名字列表 | `sc/user/Logical/ClientRechargeLogic.lua:76` |
| `G_RechargeLogic`.**`ClientGetIsHaveQQFeedBack`** | `()` | `OnGetIsHaveQQFeedBack` | 获得QQ充值返还奖励数据 | `sc/user/Logical/ClientRechargeLogic.lua:141` |
| `G_RechargeLogic`.**`ClientGetOrderId`** | `(tData: table)` | `OnGetOrderId` | zzf 2015-07-22 | `sc/user/Logical/ClientRechargeLogic.lua:117` |
| `G_RechargeLogic`.**`ClientGetQQBiGift`** | `(nQQNum: number, nType: number)` | `OnGetQQBiGift` |  | `sc/user/Logical/ClientRechargeLogic.lua:281` |
| `G_RechargeLogic`.**`ClientGetQQPayFeedBack`** | `()` | `OnGetQQPayFeedBack` | 领取QQ充值返还 | `sc/user/Logical/ClientRechargeLogic.lua:171` |
| `G_RechargeLogic`.**`ClientIsHaveAndroidFeedBack`** | `()` | `OnIsHaveAndroidFeedBack` | 获得Android充值返还奖励数据 | `sc/user/Logical/ClientRechargeLogic.lua:200` |
| `G_RechargeLogic`.**`ClientQueryQQBiGiftInfo`** | `()` | `OnQueryQQBiGiftInfo` | 送Q币活动 | `sc/user/Logical/ClientRechargeLogic.lua:260` |

#### ClientRechargeSignLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_RechargeSignLogic`.**`ClientGetRechargeSignMonthConfig`** | `()` | `OnGetRechargeSignMonthConfig` | >>请求豪华签到的配置 | `sc/user/Logical/ClientRechargeSignLogic.lua:23` |
| `G_RechargeSignLogic`.**`ClientRechargeSignReward`** | `()` | `—` | >>领取豪华签到奖品，此回调也是OnGetRechargeSignMonthConfig.. | `sc/user/Logical/ClientRechargeSignLogic.lua:61` |

#### ClientRedeemCodeLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_RedeemCodeLogic`.**`ClientUseRedeemCode`** | `(strRedeemCode: string)` | `OnUseRedeemCode` | ]] | `sc/user/Logical/ClientRedeemCodeLogic.lua:36` |

#### ClientSevenDaysGiftLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_SevenDaysGiftLogic`.**`ClientSevenDaysGift`** | `(nDay: number)` | `—` | ]] | `sc/user/Logical/ClientSevenDaysGiftLogic.lua:32` |

#### ClientSubtitleLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_SubtitleLogic`.**`ClientGetCopySubtitle`** | `(copyKey: any)` | `OnGetCopySubtitle` |  | `sc/user/Logical/ClientSubtitleLogic.lua:24` |
| `G_SubtitleLogic`.**`ClientSetUserCopySubtitle`** | `(copyKey: any, subtitle: any, time: any, color: any)` | `—` |  | `sc/user/Logical/ClientSubtitleLogic.lua:16` |

#### ClientSysExchangeLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_SysExchangeProtocol`.**`ClientExchangeReq`** ⟳ | `(strShopType: string, tonumber: any, nCount: number)` | `OnExchange` | 兑换 | `sc/user/Logical/ClientSysExchangeLogic.lua:11` |
| `G_SysExchangeProtocol`.**`ClientGetShopConfReq`** ⟳ | `(strShopType: string)` | `OnGetShopConf` | 获取兑换商店配置 | `sc/user/Logical/ClientSysExchangeLogic.lua:11` |

#### ClientTimeHeroLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_TimeHeroLogic`.**`ClientBuyTimeHero`** | `(bTest: boolean)` | `—` | ]] | `sc/user/Logical/ClientTimeHeroLogic.lua:26` |

#### ClientTourMerchantLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_CloudShopLogic`.**`ClientChangeCloudShopStatus`** | `(nStatus: number)` | `OnChangeCloudShopStatus` |  | `sc/user/Logical/ClientTourMerchantLogic.lua:211` |
| `G_CloudShopLogic`.**`ClientExchangePrize`** | `(strGoodsId: string)` | `OnExchangePrize` | 兑换奖励 | `sc/user/Logical/ClientTourMerchantLogic.lua:244` |

#### ClientUserLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_UserLogic`.**`ClientBuyExpGoods`** | `(nIndex: number)` | `OnBuyExpGoods` | 经验商城 | `sc/user/Logical/ClientUserLogic.lua:343` |
| `G_UserLogic`.**`ClientBuyFatigue`** | `()` | `OnBuyFatigue` | ]] | `sc/user/Logical/ClientUserLogic.lua:108` |
| `G_UserLogic`.**`ClientBuyVipPackage`** | `(nVipLevel: number)` | `OnBuyVipPackage` | 购买VIP礼包 | `sc/user/Logical/ClientUserLogic.lua:12` |
| `G_UserLogic`.**`ClientChangeNickName`** | `(strNickName: string)` | `OnChangeNickName` | 修改昵称 | `sc/user/Logical/ClientUserLogic.lua:185` |
| `G_UserLogic`.**`ClientChangePortrait`** | `(strPortrait: string)` | `OnChangePortrait` | 修改头像 | `sc/user/Logical/ClientUserLogic.lua:213` |
| `G_UserLogic`.**`ClientCompelateShareMessage`** | `()` | `—` |  | `sc/user/Logical/ClientUserLogic.lua:334` |
| `G_UserLogic`.**`ClientCreateCharacter`** | `(szName: string, bGender: boolean, nChannelID: number, nDeviceID: number)` | `OnCreateCharacter` | 创建角色 | `sc/user/Logical/ClientUserLogic.lua:22` |
| `G_UserLogic`.**`ClientIsUniqueNickName`** | `(strNickName: string)` | `OnIsUniqueNickName` | 是否是唯一的昵称 | `sc/user/Logical/ClientUserLogic.lua:153` |
| `G_UserLogic`.**`ClientSetClientCommonData`** | `(strKey: string, valueObj: any)` | `—` | ]] | `sc/user/Logical/ClientUserLogic.lua:76` |
| `G_UserLogic`.**`ClientSetGameFuncUnLockData`** | `(strKey: string, valueObj: any)` | `—` | ]] | `sc/user/Logical/ClientUserLogic.lua:93` |
| `G_UserLogic`.**`ClientSetGuideStepComplete`** | `(szID: string)` | `—` | 新手单步记录 | `sc/user/Logical/ClientUserLogic.lua:144` |
| `G_UserLogic`.**`ClientSetSchemeBegin`** | `(nID: number)` | `—` | 设置新手开始状态 | `sc/user/Logical/ClientUserLogic.lua:139` |
| `G_UserLogic`.**`ClientSetSchemeComplete`** | `(nID: number)` | `—` | 设置新手完成状态 | `sc/user/Logical/ClientUserLogic.lua:133` |

#### ClientWeeklyFunLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_WeeklyFunLogic`.**`ClientGetWeeklyFunPrize`** | `(nActivityId: number)` | `OnGetWeeklyFunPrize` | 领取七天乐奖励 | `sc/user/Logical/ClientWeeklyFunLogic.lua:11` |

#### GooglePayManager

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_RechargeLogic`.**`ClientRechargeCompleteDealPayment`** | `(tGoogleData: table)` | `—` | -- 请求获得Server payload / end | `sc/user/Logical/GooglePayManager.lua:281` |
| `G_RechargeLogic`.**`ClientThRechargeCompleteDealPayment`** | `(tGoogleData: table)` | `—` | -- 请求获得Server payload / end | `sc/user/Logical/GooglePayManager.lua:279` |

#### GuildContestData

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_NewGuildWarLogic`.**`ClientGetFinalMatchInfo`** ⟳ | `()` | `OnGetFinalMatchInfo` | 获取决赛信息 | `sc/user/UI/GuildContest/GuildContestData.lua:13` |
| `G_NewGuildWarLogic`.**`ClientGetGuildLeftMemberByRound`** ⟳ | `(nMatchType: number, nRound: number)` | `OnGetGuildLeftMemberByRound` | 获取存活人数信息 | `sc/user/UI/GuildContest/GuildContestData.lua:13` |
| `G_NewGuildWarLogic`.**`ClientGetMyLineUps`** ⟳ | `(nGuildId: number, nContestId: number)` | `OnGetMyLineUps` | 获取阵容信息 | `sc/user/UI/GuildContest/GuildContestData.lua:13` |
| `G_NewGuildWarLogic`.**`ClientGetNewGuildWarCurrentStatus`** ⟳ | `()` | `OnGetNewGuildWarCurrentStatus` | 获取当前状态 | `sc/user/UI/GuildContest/GuildContestData.lua:13` |
| `G_NewGuildWarLogic`.**`ClientGetOneGuildReportByRound`** ⟳ | `(nGuildId: number, nMatchType: number, nRound: number)` | `OnGetOneGuildReportByRound` | 获取指定军团的战报信息 | `sc/user/UI/GuildContest/GuildContestData.lua:13` |
| `G_NewGuildWarLogic`.**`ClientGetOneGuildSignMembers`** ⟳ | `(nGuildId: number)` | `OnGetOneGuildSignMembers` | 获取已报名的成员 | `sc/user/UI/GuildContest/GuildContestData.lua:13` |
| `G_NewGuildWarLogic`.**`ClientGetOneServerSignInfo`** ⟳ | `(CUIAssist: any, nContestId: number)` | `OnGetOneServerSignInfo` | 获取整服报名信息 | `sc/user/UI/GuildContest/GuildContestData.lua:13` |
| `G_NewGuildWarLogic`.**`ClientGetOneUserReportByRound`** ⟳ | `(nGuildId: number, nMatchType: number, nRound: number)` | `OnGetOneUserReportByRound` | 获取指定玩家的战报信 | `sc/user/UI/GuildContest/GuildContestData.lua:13` |
| `G_NewGuildWarLogic`.**`ClientNewGuildWarRelpayInfo`** ⟳ | `(strReplayKey: string)` | `OnNewGuildWarRelpayInfo` | 战斗回放 | `sc/user/UI/GuildContest/GuildContestData.lua:13` |
| `G_NewGuildWarLogic`.**`ClientOnBattleOver`** ⟳ | `()` | `—` | 战场战斗结束 | `sc/user/UI/GuildContest/GuildContestData.lua:13` |
| `G_NewGuildWarLogic`.**`ClientOnRoundOver`** ⟳ | `()` | `—` | 战场双方打完一轮 | `sc/user/UI/GuildContest/GuildContestData.lua:13` |
| `G_NewGuildWarLogic`.**`ClientSetNewGuildWarLineUps`** ⟳ | `(teamArr: any, nContestId: number)` | `OnSetNewGuildWarLineUps` | 设置阵容 | `sc/user/UI/GuildContest/GuildContestData.lua:13` |
| `G_NewGuildWarLogic`.**`ClientSignInNewGuildWar`** ⟳ | `()` | `OnSignInNewGuildWar` | 报名 | `sc/user/UI/GuildContest/GuildContestData.lua:13` |

#### RedPacketData

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_ActivityRedPack`.**`ClientGetExchangeInfoReq`** ⟳ | `()` | `OnGetExchangeInfo` | 取红包商城信息 | `sc/user/UI/RedPacket/RedPacketData.lua:13` |
| `G_ActivityRedPack`.**`ClientGetPackDetailReq`** ⟳ | `({redpack = data.sId}: table)` | `OnGetPackDetail` | 抢红包排行 | `sc/user/UI/RedPacket/RedPacketData.lua:13` |
| `G_ActivityRedPack`.**`ClientGetPackReq`** ⟳ | `({redpack = sKey}: table)` | `OnGetPack` | 抢一个红包 | `sc/user/UI/RedPacket/RedPacketData.lua:13` |
| `G_ActivityRedPack`.**`ClientGetRedPackListReq`** ⟳ | `()` | `OnGetRedPackList` | 取本服红包列表 | `sc/user/UI/RedPacket/RedPacketData.lua:13` |
| `G_ActivityRedPack`.**`ClientGetUserInfoReq`** ⟳ | `()` | `OnGetUserInfo` | 取玩家可以发的红包列表 | `sc/user/UI/RedPacket/RedPacketData.lua:13` |
| `G_ActivityRedPack`.**`ClientObjectExchangeReq`** ⟳ | `(tonumber: any, nCount: number)` | `OnObjectExchange` | 兑换 | `sc/user/UI/RedPacket/RedPacketData.lua:13` |
| `G_ActivityRedPack`.**`ClientSendPackReq`** ⟳ | `({["type"] = sKey}: table)` | `OnSendPack` | 发送一个红包 | `sc/user/UI/RedPacket/RedPacketData.lua:13` |

#### SBProtocol

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_MagicWeaponProtocol`.**`ClientBreakThrough`** | `({heroId = nHeroID, equipmentType = nPartID}: table)` | `OnBreakThrough` | 突破 | `sc/user/UI/sb/SBProtocol.lua:60` |
| `G_MagicWeaponProtocol`.**`ClientStarDown`** | `({heroId = nHeroID, equipmentType = nPartID}: table)` | `OnStarDown` | 降星 | `sc/user/UI/sb/SBProtocol.lua:34` |
| `G_MagicWeaponProtocol`.**`ClientStarUp`** | `({heroId = nHeroID, equipmentType = nPartID}: table)` | `OnStarUp` | 升星 | `sc/user/UI/sb/SBProtocol.lua:21` |
| `G_MagicWeaponProtocol`.**`ClientStrengthen`** | `({heroId = nHeroID, equipmentType = nPartID, costItem = tCostItemList}: table)` | `OnStrengthen` | 强化 | `sc/user/UI/sb/SBProtocol.lua:47` |

#### StateWarLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_ServerStateWarProtocol`.**`ClientAwardAchieve`** ⟳ | `(starAchieveType: any, nTarget: number)` | `OnAwardAchieve` | 成就领奖 | `sc/user/UI/StateWar/StateWarLogic.lua:5` |
| `G_ServerStateWarProtocol`.**`ClientBeginFightStateWar`** ⟳ | `(nMyCityId: number, nTargetCityId: number, nTargetServerId: number, nTargetUid: number, nTargetFaction: number)` | `OnBeginFightStateWar` | 开始挑战 | `sc/user/UI/StateWar/StateWarLogic.lua:5` |
| `G_ServerStateWarProtocol`.**`ClientBuyPlayerStateWarAttackCount`** ⟳ | `()` | `—` | 国战攻击购买次数 | `sc/user/UI/StateWar/StateWarLogic.lua:5` |
| `G_ServerStateWarProtocol`.**`ClientCancelMove2City`** ⟳ | `(nFromnCityId: number, nToCityId: number)` | `—` | 取消移动 | `sc/user/UI/StateWar/StateWarLogic.lua:5` |
| `G_ServerStateWarProtocol`.**`ClientComplateFightStateWar`** ⟳ | `(strReplay: string, nCityId: number, bComplete: boolean, attackInfo: any, defendInfo: any)` | `OnComplateFightStateWar` | 结束挑战 | `sc/user/UI/StateWar/StateWarLogic.lua:5` |
| `G_ServerStateWarProtocol`.**`ClientDelUserTips`** ⟳ | `()` | `—` | 删除通用消息 | `sc/user/UI/StateWar/StateWarLogic.lua:5` |
| `G_ServerStateWarProtocol`.**`ClientDevelopCity`** ⟳ | `(nCityId: number)` | `—` | 开发城池 | `sc/user/UI/StateWar/StateWarLogic.lua:5` |
| `G_ServerStateWarProtocol`.**`ClientEnterStateWarCity`** ⟳ | `(nGroupId: number, nBattleCityId: number)` | `—` | 进入城池 | `sc/user/UI/StateWar/StateWarLogic.lua:5` |
| `G_ServerStateWarProtocol`.**`ClientEnterStateWarScene`** ⟳ | `()` | `OnEnterStateWarScene` | 获取国战状态 | `sc/user/UI/StateWar/StateWarLogic.lua:13` |
| `G_ServerStateWarProtocol`.**`ClientGetAchievement`** ⟳ | `()` | `OnGetAchievement` | 成就列表 | `sc/user/UI/StateWar/StateWarLogic.lua:5` |
| `G_ServerStateWarProtocol`.**`ClientGetAttackCount`** ⟳ | `()` | `—` | 查看国战攻击次数，当天可购买次数 | `sc/user/UI/StateWar/StateWarLogic.lua:5` |
| `G_ServerStateWarProtocol`.**`ClientGetGuanzhiInfo`** ⟳ | `()` | `OnGetGuanzhiInfo` | 获取玩家当前的功勋值和是否已经领取官职奖励 | `sc/user/UI/StateWar/StateWarLogic.lua:5` |
| `G_ServerStateWarProtocol`.**`ClientGetGuanzhiReward`** ⟳ | `()` | `OnGetGuanzhiReward` | 领取官职奖励的接口 | `sc/user/UI/StateWar/StateWarLogic.lua:5` |
| `G_ServerStateWarProtocol`.**`ClientGetStateWarDefendList`** ⟳ | `(nBattleCityId: number)` | `—` | 进入战场 | `sc/user/UI/StateWar/StateWarLogic.lua:5` |
| `G_ServerStateWarProtocol`.**`ClientGetStateWarMedals`** ⟳ | `()` | `OnGetStateWarMedals` | 获取功勋 | `sc/user/UI/StateWar/StateWarLogic.lua:5` |
| `G_ServerStateWarProtocol`.**`ClientGetStateWarMedalsRankList`** ⟳ | `(nCountry: number, 1: number = 1, 50: number = 50)` | `OnGetStateWarMedalsRankList` | 排行 | `sc/user/UI/StateWar/StateWarLogic.lua:5` |
| `G_ServerStateWarProtocol`.**`ClientGetStateWarReplay`** ⟳ | `(strKey: string)` | `OnGetStateWarReplay` | 战斗回放 | `sc/user/UI/StateWar/StateWarLogic.lua:5` |
| `G_ServerStateWarProtocol`.**`ClientGetStateWarReportList`** ⟳ | `()` | `OnGetStateWarReportList` | 查看阵容 | `sc/user/UI/StateWar/StateWarLogic.lua:5` |
| `G_ServerStateWarProtocol`.**`ClientOnBuyStateWarGoods`** ⟳ | `()` | `—` | 购买国战商店商品 | `sc/user/UI/StateWar/StateWarLogic.lua:5` |
| `G_ServerStateWarProtocol`.**`ClientOnChangeUserStateWarCoin`** ⟳ | `()` | `—` | 国家币变更 | `sc/user/UI/StateWar/StateWarLogic.lua:5` |
| `G_ServerStateWarProtocol`.**`ClientSetStateWarLineUp`** ⟳ | `(nTeamIndex==1: number, keyArr: any)` | `OnSetStateWarLineUp` | 设置阵容 | `sc/user/UI/StateWar/StateWarLogic.lua:5` |
| `G_ServerStateWarProtocol`.**`ClientStateWarBeginTime`** ⟳ | `()` | `—` |  | `sc/user/UI/StateWar/StateWarLogic.lua:5` |
| `G_ServerStateWarProtocol`.**`ClientStateWarCityChanged`** ⟳ | `()` | `—` | 接受服务端推送（不是主动调用协议） | `sc/user/UI/StateWar/StateWarLogic.lua:5` |
| `G_ServerStateWarProtocol`.**`ClientStateWarMove2City`** ⟳ | `(nFromCityId: number, nToCityId: number)` | `—` | 移动到某城池 | `sc/user/UI/StateWar/StateWarLogic.lua:5` |

#### WCSProtocol

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_TournamentLogic`.**`ClientBuyWorldChampionshipGoods`** | `(nIndex: number, nCount: number)` | `—` |  | `sc/user/UI/wcs/WCSProtocol.lua:422` |
| `G_WCSProtocol`.**`ClientGetAuditionDetailsReport`** | `(nRound: number)` | `OnGetAuditionDetailsReport` | 海选战报详细 | `sc/user/UI/wcs/WCSProtocol.lua:237` |
| `G_WCSProtocol`.**`ClientGetBattleDetailsReport`** | `(nRound: number, uid or 0: any, nSvrId or 0: number, isRobot or false: any)` | `OnGetBattleDetailsReport` | 战报详细 | `sc/user/UI/wcs/WCSProtocol.lua:257` |
| `G_WCSProtocol`.**`ClientGetPlayback`** | `(BattleId: any, nSvrId: number)` | `OnGetPlayback` | 回放 | `sc/user/UI/wcs/WCSProtocol.lua:277` |
| `G_WCSProtocol`.**`ClientGetWCSInfo`** | `()` | `OnGetWCSInfo` | 查询武道会赛程信息 | `sc/user/UI/wcs/WCSProtocol.lua:20` |

#### XingHunData

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_StarSoulProtocol`.**`ClientBatchDivineReq`** ⟳ | `(nTimes: number)` | `—` |  | `sc/user/UI/XingHun/XingHunData.lua:159` |
| `G_StarSoulProtocol`.**`ClientBatchSellReq`** ⟳ | `()` | `—` |  | `sc/user/UI/XingHun/XingHunData.lua:159` |
| `G_StarSoulProtocol`.**`ClientBatchUpgradeReq`** ⟳ | `()` | `—` |  | `sc/user/UI/XingHun/XingHunData.lua:159` |
| `G_StarSoulProtocol`.**`ClientBuyPackReq`** ⟳ | `()` | `—` |  | `sc/user/UI/XingHun/XingHunData.lua:159` |
| `G_StarSoulProtocol`.**`ClientConjureZiwenReq`** ⟳ | `()` | `—` |  | `sc/user/UI/XingHun/XingHunData.lua:159` |
| `G_StarSoulProtocol`.**`ClientDemountReq`** ⟳ | `(arr: any)` | `—` |  | `sc/user/UI/XingHun/XingHunData.lua:159` |
| `G_StarSoulProtocol`.**`ClientDivineReq`** ⟳ | `()` | `—` |  | `sc/user/UI/XingHun/XingHunData.lua:159` |
| `G_StarSoulProtocol`.**`ClientGetReq`** ⟳ | `()` | `—` |  | `sc/user/UI/XingHun/XingHunData.lua:159` |
| `G_StarSoulProtocol`.**`ClientMountReq`** ⟳ | `(result: any)` | `—` |  | `sc/user/UI/XingHun/XingHunData.lua:159` |
| `G_StarSoulProtocol`.**`ClientSellReq`** ⟳ | `(_index: any, star_soul_id: any)` | `—` |  | `sc/user/UI/XingHun/XingHunData.lua:159` |
| `G_StarSoulProtocol`.**`ClientSortPackReq`** ⟳ | `()` | `—` |  | `sc/user/UI/XingHun/XingHunData.lua:159` |
| `G_StarSoulProtocol`.**`ClientUpgradeInCellReq`** ⟳ | `(self: any, self: any, xhData: any, arr: any)` | `—` |  | `sc/user/UI/XingHun/XingHunData.lua:159` |
| `G_StarSoulProtocol`.**`ClientUpgradeInPackReq`** ⟳ | `(self: any, xhData: any, arr: any)` | `—` |  | `sc/user/UI/XingHun/XingHunData.lua:159` |

### 3.5 `SERVER.GUILD` — 23 API


#### ClientGuildCampLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_GuildCampLogic`.**`ClientDoAction`** | `(...: any)` | `—` | 自身做动作 | `sc/user/Logical/ClientGuildCampLogic.lua:90` |
| `G_GuildCampLogic`.**`ClientEnterGuildCamp`** | `(tClientUserState: table)` | `OnEnterGuildCamp` | 自身进入营地 | `sc/user/Logical/ClientGuildCampLogic.lua:75` |
| `G_GuildCampLogic`.**`ClientGetGuildCampData`** | `()` | `OnGetGuildCampData` | 获取营地状态 | `sc/user/Logical/ClientGuildCampLogic.lua:158` |
| `G_GuildCampLogic`.**`ClientLeaveGuildCamp`** | `()` | `—` | 自身退出营地 | `sc/user/Logical/ClientGuildCampLogic.lua:80` |
| `G_GuildCampLogic`.**`ClientUserMoveTo`** | `(x: any, y: any, direction: any)` | `OnUserMoveTo` | 自身移动 | `sc/user/Logical/ClientGuildCampLogic.lua:85` |
| `G_GuildCampLogic`.**`ClientWaterTree`** | `()` | `—` | 浇水 | `sc/user/Logical/ClientGuildCampLogic.lua:189` |

#### ClientGuildChapterLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_GuildChapterLogic`.**`ClientChapterRequestDetailed`** | `(prizeKey: any)` | `OnChapterRequestDetailed` | 查询战利品申请详情 | `sc/user/Logical/ClientGuildChapterLogic.lua:321` |
| `G_GuildChapterLogic`.**`ClientDivideReward`** | `(prizeKey: any, receiverUid: any)` | `OnDivideReward` | 战利品分配 | `sc/user/Logical/ClientGuildChapterLogic.lua:261` |
| `G_GuildChapterLogic`.**`ClientGiveUpGuildChapterPrepare`** | `(chapterKey: any)` | `OnGiveUpGuildChapterPrepare` | 放弃军团副本战斗准备(暂时没用) | `sc/user/Logical/ClientGuildChapterLogic.lua:149` |
| `G_GuildChapterLogic`.**`ClientGuildChapterFightBegin`** | `(tData: table)` | `OnGuildChapterFightBegin` | 军团副本开始挑战 | `sc/user/Logical/ClientGuildChapterLogic.lua:169` |
| `G_GuildChapterLogic`.**`ClientGuildChapterFightComplete`** | `(chapterKey: any, tData: table)` | `OnGuildChapterFightComplete` | 军团副本挑战结束 | `sc/user/Logical/ClientGuildChapterLogic.lua:189` |
| `G_GuildChapterLogic`.**`ClientGuildChapterRewardInfo`** | `()` | `OnGuildChapterRewardInfo` | 查询战利品分配 | `sc/user/Logical/ClientGuildChapterLogic.lua:221` |
| `G_GuildChapterLogic`.**`ClientOpenGuildChapter`** | `(chapterKey: any)` | `OnOpenGuildChapter` | 开启军团副本 | `sc/user/Logical/ClientGuildChapterLogic.lua:69` |
| `G_GuildChapterLogic`.**`ClientPrepareGuildChapter`** | `(chapterKey: any)` | `OnPrepareGuildChapter` | 军团副本战斗准备 | `sc/user/Logical/ClientGuildChapterLogic.lua:129` |
| `G_GuildChapterLogic`.**`ClientQueryGuildChapterInfo`** | `(chapterKey: any)` | `OnQueryGuildChapterInfo` | 查询某章节副本信息 | `sc/user/Logical/ClientGuildChapterLogic.lua:109` |
| `G_GuildChapterLogic`.**`ClientQueryGuildChapterInjuryRank`** | `(chapterKey: any)` | `OnQueryGuildChapterInjuryRank` | 伤害排行 | `sc/user/Logical/ClientGuildChapterLogic.lua:363` |
| `G_GuildChapterLogic`.**`ClientQueryGuildChapterListInfo`** | `()` | `OnQueryGuildChapterListInfo` | 查询军团副本章节列表 | `sc/user/Logical/ClientGuildChapterLogic.lua:38` |
| `G_GuildChapterLogic`.**`ClientQueryGuildChapterRewardRecord`** | `()` | `OnQueryGuildChapterRewardRecord` | 战利品分配记录查询 | `sc/user/Logical/ClientGuildChapterLogic.lua:281` |
| `G_GuildChapterLogic`.**`ClientQueryGuildChapterServerInjuryRank`** | `(chapterKey: any)` | `OnQueryGuildChapterServerInjuryRank` | 全服排行 QueryGuildChapterServerInjuryRank | `sc/user/Logical/ClientGuildChapterLogic.lua:383` |
| `G_GuildChapterLogic`.**`ClientQueryReqestRewardMember`** | `(prizeKey: any)` | `OnQueryReqestRewardMember` | 查询战利品分配时成员列表 | `sc/user/Logical/ClientGuildChapterLogic.lua:241` |
| `G_GuildChapterLogic`.**`ClientQuerySelfRequestPrize`** | `()` | `OnQuerySelfRequestPrize` | 查询战利品申请列表 | `sc/user/Logical/ClientGuildChapterLogic.lua:301` |
| `G_GuildChapterLogic`.**`ClientRequestReward`** | `(chapterKey: any, prizeKey: any)` | `OnRequestReward` | 战利品申请 | `sc/user/Logical/ClientGuildChapterLogic.lua:343` |
| `G_GuildChapterLogic`.**`ClientResetGuildChapter`** | `(chapterKey: any)` | `OnResetGuildChapter` | 重置军团副本 | `sc/user/Logical/ClientGuildChapterLogic.lua:89` |

### 3.6 `SERVER.LOGIN` — 8 API


#### ClientLogin

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_Login`.**`ClientBindingAccount`** | `(strUserName: string, strPassword: string, strOldUserName: string, nUserType: number)` | `OnBindingAccount` |  | `sc/user/Logical/ClientLogin.lua:45` |
| `G_Login`.**`ClientBindingChannelAccount`** | `(strUserName: string, strOldUserName: string, nUserType: number)` | `—` |  | `sc/user/Logical/ClientLogin.lua:42` |
| `G_Login`.**`ClientChannelLogin`** | `(strSessionId: string, nUserType: number)` | `—` |  | `sc/user/Logical/ClientLogin.lua:55` |
| `G_Login`.**`ClientGPlayLogin`** | `(strSessionId: string, nUserType: number)` | `—` |  | `sc/user/Logical/ClientLogin.lua:60` |
| `G_Login`.**`ClientGetRecomendServers`** | `(strUserName: string, nUid: number)` | `OnClientGetRecomendServers` |  | `sc/user/Logical/ClientLogin.lua:68` |
| `G_Login`.**`ClientLogin`** | `(szUserName: string, szPassword: string, nUserType: number)` | `OnLogin` |  | `sc/user/Logical/ClientLogin.lua:31` |
| `G_Login`.**`ClientRegister`** | `(szUserName: string, szPassword: string, nUserType: number, strDid: string)` | `OnClientRegister` |  | `sc/user/Logical/ClientLogin.lua:36` |
| `G_Login`.**`ClientSdkLogin`** | `(strSessionId: string, "ysdk": string = "ysdk", "": string = "")` | `—` |  | `sc/user/Logical/ClientLogin.lua:53` |

### 3.7 `SERVER.LOGIN_GATEWAY` — 1 API


#### CUILoginRPCManager

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `nil`.**`Heartbeat`** | `()` | `—` |  | `sc/user/Logical/CUILoginRPCManager.lua:28` |

### 3.8 `SERVER.LOGIN_ROLE` — 1 API


#### ClientLogin

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| `G_Login`.**`ClientGetRecomendServers`** | `(strUserName: string, G_Login: any)` | `OnClientGetRecomendServers` |  | `sc/user/Logical/ClientLogin.lua:72` |

### 3.9 `SERVER.STATISTIC_ACHIEVEMENT` — 2 API


#### CServerRequestLogic

| Hàm server | Tham số | Handler trả về | Mô tả | Nguồn |
|---|---|---|---|---|
| **`ClientAwardAhieve`** | `(nAchieveId: number)` | `—` |  | `sc/user/Logical/CServerRequestLogic.lua:266` |
| **`ClientReachAchieveWithEvent`** | `(achieve: any, event: any)` | `—` | 成就---------------------------------------------- | `sc/user/Logical/CServerRequestLogic.lua:261` |

## 4. Callback server → client

Server gọi ngược các hàm này. Cột *Trường đọc* là các khoá client thực sự truy cập trên tham số — chính là hình dạng tối thiểu của payload trả về.

| Handler | Đối tượng | Tham số | Trường đọc từ payload | Nguồn |
|---|---|---|---|---|
| **`OnAcceptApply`** | `ClientFriendLogic` | `nErrCode,nTargetUid` | — | `sc/user/Logical/ClientFriendLogic.lua:319` |
| **`OnActiveProgress`** | `ClientDestinyLogic` | `—` | — | `sc/user/Logical/ClientDestinyLogic.lua:21` |
| **`OnActiveProgressWithCount`** | `ClientDestinyLogic` | `newProcess` | — | `sc/user/Logical/ClientDestinyLogic.lua:32` |
| **`OnActiveRareFormation`** | `ClientFormationLogic` | `strName` | — | `sc/user/Logical/ClientFormationLogic.lua:24` |
| **`OnActivityShopping`** | `ClientActivityShoppingLogic` | `dwSucBuyNum` | — | `sc/user/Logical/ClientActivitiesLogic.lua:386` |
| **`OnAddArenaFightCount`** | `ClientArenaLogic` | `—` | — | `sc/user/Logical/ClientArenalLogic.lua:510` |
| **`OnAddTeam`** | `COGProtocol` | `nErrCode` | — | `sc/user/UI/cog/COGProtocol.lua:354` |
| **`OnAgreeFriendApply`** | *(toàn cục)* | `tData` | `data`, `err` | `sc/user/Logical/CServerResponseLogic.lua:854` |
| **`OnAngerAttackWarBoss`** | `ClientGuildWarLogic` | `eventList, nErrCode, totalDemageList` | — | `sc/user/Logical/ClientGuildWarLogic.lua:762` |
| **`OnAnnounceWar`** | `ClientGuildWarLogic` | `eventList, nErrCode` | — | `sc/user/Logical/ClientGuildWarLogic.lua:525` |
| **`OnApplyForFriend`** | *(toàn cục)* | `tData` | `data`, `err` | `sc/user/Logical/CServerResponseLogic.lua:823` |
| **`OnApplyGuild`** | `ClientGuildLogic` | `—` | — | `sc/user/Logical/ClientGuildApplyLogic.lua:238` |
| **`OnArenaFightRanking`** | `ClientArenaLogic` | `arenaFight` | `BaseInfo`, `FightData`, `Groups` | `sc/user/Logical/ClientArenalLogic.lua:199` |
| **`OnArenaFightTest`** | `CUIMain` | `tReturnData` | `ArenaFight`, `ArmyData`, `ChapterData`, `FightData`, `FightHeroList`, `OtherParam` | `sc/user/UI/CUIGM.lua:437` |
| **`OnAttackCity`** | `COGProtocol` | `...` | — | `sc/user/UI/cog/COGProtocol.lua:113` |
| **`OnAttackWarBoss`** | `ClientGuildWarLogic` | `eventList, nErrCode, demage, hit` | — | `sc/user/Logical/ClientGuildWarLogic.lua:699` |
| **`OnAwardAchieve`** | `ScoreStroeLogic` | `tAchieve` | `AchieveType` | `sc/share/ScoreStroeLogic.lua:181` |
| **`OnAwardDailyTask`** | *(toàn cục)* | `tData` | `data`, `err` | `sc/user/Logical/CServerResponseLogic.lua:1123` |
| **`OnBatchReceiveFriendFatigue`** | `ClientFriendLogic` | `—` | — | `sc/user/Logical/ClientFriendLogic.lua:829` |
| **`OnBatchSendriendFatigue`** | `ClientFriendLogic` | `—` | — | `sc/user/Logical/ClientFriendLogic.lua:799` |
| **`OnBatchUseItemWithItemList`** | `ClientItemLogic` | `tUseItemList` | — | `sc/user/Logical/ClientItemLogic.lua:252` |
| **`OnBeginFightStateWar`** | `StateWarBattleData` | `data` | — | `sc/user/UI/StateWar/StateWarBattleData.lua:314` |
| **`OnBindingAccount`** | `CUIBinding` | `tData` | `err` | `sc/user/UI/CUIBinding.lua:151` |
| **`OnBreakThrough`** | `CUISBMainContent` | `—` | — | `sc/user/UI/sb/CUISBMainContent.lua:132` |
| **`OnBuyActivityFund`** | `CUIActivityFund` | `strFundType` | — | `sc/user/UI/CUIActivityFund.lua:92` |
| **`OnBuyArenaGoods`** | `ClientArenaLogic` | `goodsIndex` | — | `sc/user/Logical/ClientArenalLogic.lua:491` |
| **`OnBuyChapterBattleResetCount`** | `CUIChapterInfo` | `strChapterKey` | — | `sc/user/UI/CUIChapterInfo.lua:2096` |
| **`OnBuyChapterSweepCount`** | `CUIChapterInfo` | `nSweepCount` | — | `sc/user/UI/CUIChapterInfo.lua:2065` |
| **`OnBuyExpGoods`** | `ClientUserLogic` | `tData` | — | `sc/user/Logical/ClientUserLogic.lua:347` |
| **`OnBuyFatigue`** | `Statistics` | `—` | — | `sc/share/Statistics.lua:590` |
| **`OnBuyFishQueue`** | `CUIAquariumMainDlg` | `data` | `nCost`, `nCostCount`, `nCount`, `nFreeCount`, `nTotal` | `sc/user/UI/pet/CUIAquariumMainDlg.lua:733` |
| **`OnBuyGoods`** | *(toàn cục)* | `tData` | `data`, `err`, `fun` | `sc/user/Logical/CServerResponseLogic.lua:897` |
| **`OnBuyPotion`** | `ClientPotionLogic` | `nErrCode,nPotionID` | — | `sc/user/Logical/ClientPotionLogic.lua:329` |
| **`OnBuyVipPackage`** | `CUIActivityVipGiftBag` | `—` | — | `sc/user/UI/CUIActivityVipGiftBag.lua:318` |
| **`OnCancelApply`** | `ClientGuildLogic` | `—` | — | `sc/user/Logical/ClientGuildApplyLogic.lua:287` |
| **`OnCancelBuildingUpgrade`** | *(toàn cục)* | `tData` | `data`, `err` | `sc/user/Logical/CServerResponseLogic.lua:116` |
| **`OnCancelGuild`** | `ClientGuildLogic` | `nErrCode` | — | `sc/user/Logical/ClientGuildManageLogic.lua:580` |
| **`OnCancelManager`** | `ClientGuildLogic` | `nErrCode` | — | `sc/user/Logical/ClientGuildManageLogic.lua:460` |
| **`OnCancelUpgradeArmy`** | *(toàn cục)* | `tData` | `data`, `err` | `sc/user/Logical/CServerResponseLogic.lua:343` |
| **`OnCatchFish`** | `CUIAquariumMainDlg` | `data` | `nCostCount`, `nCount`, `nFreeCount`, `nTotal` | `sc/user/UI/pet/CUIAquariumMainDlg.lua:683` |
| **`OnCavernSweepAll`** | `Statistics` | `tRetInfo` | — | `sc/share/Statistics.lua:439` |
| **`OnChangeCloudShopStatus`** | `ClientTourMerchantLogic` | `—` | — | `sc/user/Logical/ClientTourMerchantLogic.lua:221` |
| **`OnChangeHeroEquipment`** | *(toàn cục)* | `tData` | `data`, `err` | `sc/user/Logical/CServerResponseLogic.lua:367` |
| **`OnChangeNickName`** | `ClientUserLogic` | `—` | — | `sc/user/Logical/ClientUserLogic.lua:192` |
| **`OnChangePortrait`** | `ClientUserLogic` | `—` | — | `sc/user/Logical/ClientUserLogic.lua:220` |
| **`OnChapterCompleteFaild`** | *(toàn cục)* | `tData` | `data`, `err` | `sc/user/Logical/CServerResponseLogic.lua:261` |
| **`OnChapterCompleteSuccess`** | `Statistics` | `tData` | `ChapterKey` | `sc/share/Statistics.lua:114` |
| **`OnChapterPetBossComplete`** | `ClientChapterLogic` | `tData` | `ChapterKey`, `KillDropList` | `sc/user/Logical/ClientChapterLogic.lua:917` |
| **`OnChapterRequestDetailed`** | `ClientGuildChapterLogic` | `eventList, nErrCode, tData, leftDispatchTime` | — | `sc/user/Logical/ClientGuildChapterLogic.lua:325` |
| **`OnChapterSCSComplete`** | *(toàn cục)* | `tData` | `data`, `err` | `sc/user/Logical/CServerResponseLogic.lua:238` |
| **`OnChapterSYZLBAndXZWCSweep`** | `ClientChapterLogic` | `tData` | `ChapterKey` | `sc/user/Logical/ClientChapterLogic.lua:3288` |
| **`OnChapterSweepOnce`** | *(toàn cục)* | `tData` | `data`, `err` | `sc/user/Logical/CServerResponseLogic.lua:275` |
| **`OnChapterSweepTen`** | *(toàn cục)* | `tData` | `data`, `err` | `sc/user/Logical/CServerResponseLogic.lua:290` |
| **`OnChapterTGZZComplete`** | `ClientChapterLogic` | `tData` | `ChapterKey`, `KillDropList` | `sc/user/Logical/ClientChapterLogic.lua:847` |
| **`OnChapterTGZZSweep`** | `ClientChapterLogic` | `tPrizeList` | — | `sc/user/Logical/ClientChapterLogic.lua:1037` |
| **`OnCheckCanChangeTeam`** | `ClientGuildWarLogic` | `eventList, nErrCode, nResult` | — | `sc/user/Logical/ClientGuildWarLogic.lua:805` |
| **`OnCheckNewEquipment`** | *(toàn cục)* | `tData` | `data`, `err` | `sc/user/Logical/CServerResponseLogic.lua:419` |
| **`OnClientEpicChapterOpenBox`** | `ClientEpicBattleLogic` | `tItemList` | — | `sc/user/Logical/ClientEpicBattleLogic.lua:22` |
| **`OnClientGMNextStep`** | `HeroPKBattleData` | `data` | `BaseInfo`, `HeroFightMap` | `sc/user/UI/heroPK/HeroPKBattleData.lua:120` |
| **`OnClientGetData`** | `HeroPKBattleData` | `data` | `BaseInfo` | `sc/user/UI/heroPK/HeroPKBattleData.lua:105` |
| **`OnClientGetRecomendServers`** | `CUILoginServerList` | `tData` | `RecomendList` | `sc/user/UI/CUILoginServerList.lua:481` |
| **`OnClientRegister`** | `G_LoginTest` | `tData` | `err`, `serverlist`, `session`, `uid` | `sc/test/TestLogin.lua:180` |
| **`OnClientSaveLineup`** | `HeroPKBattleData` | `data` | `BaseInfo`, `HeroFightMap`, `Rand`, `WinIndex` | `sc/user/UI/heroPK/HeroPKBattleData.lua:140` |
| **`OnClientSetTodayChapterDifficult`** | `ClientEpicBattleLogic` | `nErroCode` | — | `sc/user/Logical/ClientEpicBattleLogic.lua:76` |
| **`OnCollect`** | `CUIAquariumMainDlg` | `data` | `nCost`, `nCostCount`, `nCount`, `nFreeCount`, `nTotal` | `sc/user/UI/pet/CUIAquariumMainDlg.lua:697` |
| **`OnCompeleteArenaFight`** | `CUIGame` | `tData` | `bResult` | `sc/user/Battle/CUIGame.lua:4537` |
| **`OnCompeleteArenaFightTest`** | `ClientArenaLogic` | `resultData` | — | `sc/user/Logical/ClientArenalLogic.lua:322` |
| **`OnCompeleteProgress`** | `CUICavern` | `—` | — | `sc/user/UI/CUICavern.lua:169` |
| **`OnComplateFightStateWar`** | `StateWarBattleData` | `data` | — | `sc/user/UI/StateWar/StateWarBattleData.lua:332` |
| **`OnCompleteBuildingUpgrade`** | *(toàn cục)* | `tData` | `data`, `err` | `sc/user/Logical/CServerResponseLogic.lua:127` |
| **`OnCompletePotionUpgradeWithDiamond`** | `ClientPotionLogic` | `nErrCode` | — | `sc/user/Logical/ClientPotionLogic.lua:237` |
| **`OnCompleteUpgradeArmy`** | *(toàn cục)* | `tData` | `data`, `err` | `sc/user/Logical/CServerResponseLogic.lua:320` |
| **`OnCompleteUpgradePotion`** | `ClientPotionLogic` | `nErrCode` | — | `sc/user/Logical/ClientPotionLogic.lua:167` |
| **`OnComposeClothing`** | `ClientClothingLogic` | `—` | — | `sc/user/Logical/ClientClothingLogic.lua:222` |
| **`OnConvertUniversalFragment`** | `CUIBackpack` | `tData` | `Count`, `HeroID` | `sc/user/UI/CUIBackpack.lua:656` |
| **`OnCreateCharacter`** | `G_GameLogic` | `bRt` | — | `sc/test/TestGameLogic.lua:128` |
| **`OnCreateGuild`** | `ClientGuildLogic` | `tData` | — | `sc/user/Logical/ClientGuildApplyLogic.lua:132` |
| **`OnDispatchHero`** | `Statistics` | `—` | — | `sc/share/Statistics.lua:530` |
| **`OnDispatchTeam`** | `COGDataManager` | `tMapTeam` | — | `sc/user/UI/cog/COGDataManager.lua:989` |
| **`OnDivideReward`** | `ClientGuildChapterLogic` | `eventList, nErrCode` | — | `sc/user/Logical/ClientGuildChapterLogic.lua:265` |
| **`OnDoQuiz`** | `ClientContestLogic` | `nErrCode, tData` | — | `sc/user/Logical/ClientContestLogic.lua:174` |
| **`OnDonateGuild`** | `ClientGuildLogic` | `nErrCode` | — | `sc/user/Logical/ClientGuildManageLogic.lua:665` |
| **`OnDonateGuildTechnology`** | `ClientGuildLogic` | `—` | — | `sc/user/Logical/ClientGuildApplyLogic.lua:921` |
| **`OnEnterChannel`** | `ClientChattingLogic` | `errCode, nChannelId, tMsgData, tListFriendInfo` | — | `sc/user/Logical/ClientChattingLogic.lua:37` |
| **`OnEnterChatGame`** | `ClientChattingLogic` | `errCode` | — | `sc/user/Logical/ClientChattingLogic.lua:17` |
| **`OnEnterGame`** | `CGuideEvent` | `nError` | — | `sc/user/Guide/CGuideEvent.lua:54` |
| **`OnEnterGuildCamp`** | `ClientGuildCampLogic` | `errCode,returnData` | — | `sc/user/Logical/ClientGuildCampLogic.lua:94` |
| **`OnEnterPetRoom`** | `CUIPetMain` | `—` | — | `sc/user/UI/pet/CUIPetMain.lua:1009` |
| **`OnEnterStateWarScene`** | `StateWarBattleData` | `data` | `hero` | `sc/user/UI/StateWar/StateWarBattleData.lua:72` |
| **`OnEpicChapterCompeleteFight`** | `ClientEpicBattleLogic` | `tData` | — | `sc/user/Logical/ClientEpicBattleLogic.lua:64` |
| **`OnEpicResetDaily`** | `ClientEpicBattleLogic` | `—` | — | `sc/user/Logical/ClientEpicBattleLogic.lua:84` |
| **`OnExchange`** | `ClientGodSecret` | `nIndex` | — | `sc/user/Logical/ClientGodSecret.lua:377` |
| **`OnExchangePrize`** | `ClientTourMerchantLogic` | `—` | — | `sc/user/Logical/ClientTourMerchantLogic.lua:254` |
| **`OnExchangeTongqueItem`** | `CUITongqueDlg` | `data` | — | `sc/user/UI/CUITongqueDlg.lua:172` |
| **`OnExitChannel`** | `ClientChattingLogic` | `errCode` | — | `sc/user/Logical/ClientChattingLogic.lua:74` |
| **`OnExitGuild`** | `ClientGuildLogic` | `—` | — | `sc/user/Logical/ClientGuildManageLogic.lua:553` |
| **`OnFight`** | `ClientEndlessChapterLogic` | `heroIdList,nInspireCount,tEmployHero` | — | `sc/user/Logical/ClientEndlessChapterLogic.lua:44` |
| **`OnFightFriend`** | `ClientFriendLogic` | `errCode,returnData,fightHeroList` | — | `sc/user/Logical/ClientFriendLogic.lua:72` |
| **`OnFirewood`** | `CUIArmyGroupCampsite` | `returnData` | `UserFireWoodCount`, `UserLastFireWoodTime` | `sc/user/UI/CUIArmyGroupCampsite.lua:2562` |
| **`OnForgingExclusiveEquip`** | `CUIEquipment` | `nHeroID` | — | `sc/user/UI/CUIEquipment_Refine.lua:1762` |
| **`OnFreeRefresh`** | `ClientGodSecret` | `nErrCode, tData` | — | `sc/user/Logical/ClientGodSecret.lua:355` |
| **`OnGMCommond`** | `ClientGameWorld` | `nErrorCode` | — | `sc/user/Logical/ClientGameWorld.lua:395` |
| **`OnGet5HeroPowerRank`** | `ClientLeaderboardLogic` | `tRankList, nSelfRank, nYesterdayRank` | — | `sc/user/Logical/ClientLeaderboard.lua:296` |
| **`OnGetAchievement`** | `CUIStateWarAchievementTask` | `tData` | — | `sc/user/UI/StateWar/CUIStateWarAchievementTask.lua:234` |
| **`OnGetActivityConfig`** | `ClientActivityLogic` | `strType,tCondif` | — | `sc/user/Logical/ClientActivitiesLogic.lua:126` |
| **`OnGetAndoirdFeedBack`** | `ClientRechargeLogic` | `nRebateCount, nAdvancedCarDay, nNormalCarDay` | — | `sc/user/Logical/ClientRechargeLogic.lua:234` |
| **`OnGetAnniversaryAward`** | `CUIAnniversaryThankLetter` | `—` | — | `sc/user/UI/anniversary/CUIAnniversaryThankLetter.lua:252` |
| **`OnGetArenaDefendPowerRank`** | `ClientLeaderboardLogic` | `tRankList, nSelfRank, nYesterdayRank` | — | `sc/user/Logical/ClientLeaderboard.lua:245` |
| **`OnGetArenaDetailByUid`** | `ClientArenaLogic` | `retUserArenaData` | — | `sc/user/Logical/ClientArenalLogic.lua:806` |
| **`OnGetArenaHeroInfo`** | `ClientArenaLogic` | `tData` | — | `sc/user/Logical/ClientArenalLogic.lua:620` |
| **`OnGetArenaRankWithYesterday`** | `ClientArenaLogic` | `tRankList, nSelfRank, nYesterdayRank` | — | `sc/user/Logical/ClientArenalLogic.lua:24` |
| **`OnGetAuditionDetailsReport`** | `CUIWCSBattleInfo` | `tData` | `Players`, `Rand`, `Result`, `WinIndex` | `sc/user/UI/wcs/CUIWCSBattleInfo.lua:560` |
| **`OnGetBattleArray`** | `ClientContestLogic` | `nErrCode, tData` | — | `sc/user/Logical/ClientContestLogic.lua:111` |
| **`OnGetBattleDetailsReport`** | `ClientContestLogic` | `nErrCode, tData` | — | `sc/user/Logical/ClientContestLogic.lua:216` |
| **`OnGetBattleReport`** | `ClientContestLogic` | `nErrCode, tData` | — | `sc/user/Logical/ClientContestLogic.lua:48` |
| **`OnGetBriefInfo`** | `COGDataManager` | `svrData` | `AttackCityID`, `IsApplied`, `OccupyCityID`, `Step`, `StepFinishTime` | `sc/user/UI/cog/COGDataManager.lua:51` |
| **`OnGetCOGInfo`** | `COGDataManager` | `svrData` | `AppliedCityID`, `ApplyList`, `AttackCityID`, `AttackGuild`, `AttackTarget`, `BattleReport`, `CityID`, `CityList`, `Defend`, `DfendTask`, `GuildID`, `GuildMsg` | `sc/user/UI/cog/COGDataManager.lua:669` |
| **`OnGetCanBeAttackUser`** | `ClientGuildWarLogic` | `eventList, nErrCode, retInfo, TargetGuildName, BeFightedGuildName, nRosource` | — | `sc/user/Logical/ClientGuildWarLogic.lua:861` |
| **`OnGetChampionInfo`** | `ClientContestLogic` | `nErrCode, tData` | — | `sc/user/Logical/ClientContestLogic.lua:154` |
| **`OnGetChapterDropData`** | *(toàn cục)* | `tData` | `data`, `err` | `sc/user/Logical/CServerResponseLogic.lua:648` |
| **`OnGetCityDefendMission`** | `COGProtocol` | `...` | — | `sc/user/UI/cog/COGProtocol.lua:145` |
| **`OnGetCityInfo`** | `COGDataManager` | `svrData` | `ApplyList`, `AttackGuild`, `CityID`, `Defend`, `GuildID`, `GuildName`, `Last2Guild`, `PictureId` | `sc/user/UI/cog/COGDataManager.lua:765` |
| **`OnGetCityPlayback`** | `COGDataManager` | `svrData, bBattle` | `AttackTeamSetting`, `DefendTeamSetting`, `Detail`, `Result` | `sc/user/UI/cog/COGDataManager.lua:1151` |
| **`OnGetCityReport`** | `COGProtocol` | `nErrCode, tData` | — | `sc/user/UI/cog/COGProtocol.lua:469` |
| **`OnGetClothingPrize`** | `CUICharacterDressGet` | `tData` | `nClientErrCode`, `nServerErrCode` | `sc/user/UI/CUICharacterDressGet.lua:1000` |
| **`OnGetClothingPrizeCount`** | `CUICharacterDressGet` | `tData` | `RetData`, `nClientErrCode`, `nServerErrCode` | `sc/user/UI/CUICharacterDressGet.lua:977` |
| **`OnGetContestInfo`** | `ClientContestLogic` | `nErrCode, tData` | — | `sc/user/Logical/ClientContestLogic.lua:24` |
| **`OnGetCopySubtitle`** | `CUISubtitle` | `tData` | — | `sc/user/Battle/CUISubtitle.lua:115` |
| **`OnGetDJSJFRank`** | `ClientLeaderboardLogic` | `tRankList` | — | `sc/user/Logical/ClientLeaderboard.lua:454` |
| **`OnGetDailyOccupyPrize`** | `COGDataManager` | `—` | — | `sc/user/UI/cog/COGDataManager.lua:1616` |
| **`OnGetDiceGameData`** | `ClientGuildLogic` | `tData` | — | `sc/user/Logical/ClientGuildINeedHeroLogic.lua:14` |
| **`OnGetDiceGameReward`** | `ClientGuildLogic` | `tData` | — | `sc/user/Logical/ClientGuildINeedHeroLogic.lua:51` |
| **`OnGetDispatchHeroList`** | `ClientGuildLogic` | `nErrCode, tData` | — | `sc/user/Logical/ClientGuildDispatchLogic.lua:197` |
| **`OnGetEndlessChapterRank`** | `ClientEndlessChapterLogic` | `tRankList,nSelfRank,nYesterdayRank` | — | `sc/user/Logical/ClientEndlessChapterLogic.lua:309` |
| **`OnGetExchangeInfo`** | `CUIRedPacket` | `data` | `bGrabbed` | `sc/user/UI/RedPacket/CUIRedPacket.lua:1058` |
| **`OnGetFightDetail`** | `HeroPKBattleData` | `data` | `BaseInfo`, `ChapterType`, `HeroFightMap`, `Rand`, `Result`, `Version`, `WinIndex` | `sc/user/UI/heroPK/HeroPKBattleData.lua:155` |
| **`OnGetFightTestResult`** | `ClientContestLogic` | `nErrorCode, strResult` | — | `sc/user/Logical/ClientContestLogic.lua:351` |
| **`OnGetFinal32Info`** | `ClientContestLogic` | `nErrCode, tData` | — | `sc/user/Logical/ClientContestLogic.lua:309` |
| **`OnGetFinalMatchInfo`** | `CUIGuildContestFinalListDlg` | `tData` | — | `sc/user/UI/GuildContest/CUIGuildContestFinalListDlg.lua:49` |
| **`OnGetFinalsInfo`** | `ClientContestLogic` | `nErrCode, tSeatsData, tQuizData` | — | `sc/user/Logical/ClientContestLogic.lua:89` |
| **`OnGetFirstRechargePrize`** | `CUIFirstPayGift` | `tData` | `RetData`, `nClientErrCode` | `sc/user/UI/CUIFirstPayGift.lua:326` |
| **`OnGetFirstRechargeUserAndCount`** | `ClientRechargeLogic` | `tRetData` | — | `sc/user/Logical/ClientRechargeLogic.lua:85` |
| **`OnGetFreeStrength`** | `ScoreStroeLogic` | `—` | — | `sc/share/ScoreStroeLogic.lua:211` |
| **`OnGetFriendChatRecord`** | `ClientChattingLogic` | `errCode,tListMsgRecord` | — | `sc/user/Logical/ClientChattingLogic.lua:171` |
| **`OnGetGloblePrize`** | `ClientGodSecret` | `nIndex` | — | `sc/user/Logical/ClientGodSecret.lua:423` |
| **`OnGetGlobleScore`** | `ClientGodSecret` | `nGlobalScore` | — | `sc/user/Logical/ClientGodSecret.lua:411` |
| **`OnGetGuanzhiInfo`** | `CUIStateWarOfficalRewardDlg` | `data` | — | `sc/user/UI/StateWar/CUIStateWarOfficalRewardDlg.lua:147` |
| **`OnGetGuanzhiReward`** | `CUIStateWarOfficalRewardDlg` | `data` | — | `sc/user/UI/StateWar/CUIStateWarOfficalRewardDlg.lua:102` |
| **`OnGetGuildApplyList`** | `ClientGuildLogic` | `nErrCode, tApplyList` | — | `sc/user/Logical/ClientGuildManageLogic.lua:731` |
| **`OnGetGuildBattleReport`** | `COGProtocol` | `nErrCode, tData` | — | `sc/user/UI/cog/COGProtocol.lua:299` |
| **`OnGetGuildCampData`** | `ClientGuildCampLogic` | `errCode,tdata` | — | `sc/user/Logical/ClientGuildCampLogic.lua:161` |
| **`OnGetGuildInfo`** | `ClientGuildLogic` | `nErrCode,tGuildInfo` | — | `sc/user/Logical/ClientGuildManageLogic.lua:283` |
| **`OnGetGuildLeftMemberByRound`** | `GuildContestData` | `data` | — | `sc/user/UI/GuildContest/GuildContestData.lua:742` |
| **`OnGetGuildLogList`** | `ClientGuildLogic` | `nErrCode, tLogList` | — | `sc/user/Logical/ClientGuildManageLogic.lua:635` |
| **`OnGetGuildRank`** | `ClientLeaderboardLogic` | `tRankList, nSelfRank, nYesterdayRank` | — | `sc/user/Logical/ClientLeaderboard.lua:685` |
| **`OnGetGuildRankList`** | `CUIGuildContestRankDlg` | `data` | `GuildRank`, `HotData`, `MyGuildScore`, `MyRank`, `Rank` | `sc/user/UI/GuildContest/CUIGuildContestRankDlg.lua:86` |
| **`OnGetGuildTeamList`** | `COGDataManager` | `svrData` | `AttackTeamSetting`, `DefendTeamSetting`, `Detail`, `Result` | `sc/user/UI/cog/COGDataManager.lua:1045` |
| **`OnGetGuildTeamProfile`** | `COGDataManager` | `svrData` | `AttackTeamSetting`, `DefendTeamSetting`, `Detail`, `Result` | `sc/user/UI/cog/COGDataManager.lua:1020` |
| **`OnGetGuildWarInfo`** | `ClientGuildWarLogic` | `eventList, nErrCode, tArgData` | — | `sc/user/Logical/ClientGuildWarLogic.lua:589` |
| **`OnGetGuildWarMockFightData`** | `ClientGuildWarLogic` | `eventList, nErrCode, tData` | — | `sc/user/Logical/ClientGuildWarLogic.lua:641` |
| **`OnGetGuildWarScoreRank`** | `ClientLeaderboardLogic` | `tRankList, nSelfRank, nYesterdayRank` | — | `sc/user/Logical/ClientLeaderboard.lua:737` |
| **`OnGetHistoryWushuangRankList`** | `ActivityWushuang` | `tPlayer, tRankData, nRankType` | — | `sc/user/Logical/ClientAcivityWushuang.lua:203` |
| **`OnGetHjrqRank`** | `ClientLeaderboardLogic` | `tRankList, strChapterKey` | — | `sc/user/Logical/ClientLeaderboard.lua:353` |
| **`OnGetIsHaveQQFeedBack`** | `ClientRechargeLogic` | `nErrCode, nRebateCount, nAdvancedCarDay, nNormalCarDay` | — | `sc/user/Logical/ClientRechargeLogic.lua:145` |
| **`OnGetLevelRank`** | `ClientLeaderboardLogic` | `tRankList, nSelfRank, nYesterdayRank` | — | `sc/user/Logical/ClientLeaderboard.lua:195` |
| **`OnGetLevelTongqueReward`** | `CUITongqueDlg` | `data` | — | `sc/user/UI/CUITongqueDlg.lua:177` |
| **`OnGetLivenessPrize`** | `CUIDailyTask` | `—` | — | `sc/user/UI/CUIDailyTask.lua:346` |
| **`OnGetLoginReward`** | `ScoreStroeLogic` | `—` | — | `sc/share/ScoreStroeLogic.lua:293` |
| **`OnGetLoginRewardData`** | `ClientActivityLoginReward` | `nErrCode, tData` | — | `sc/user/Logical/ClientActivityLoginRewardLogic.lua:19` |
| **`OnGetLotteryData`** | *(toàn cục)* | `tData` | `data`, `err`, `fun` | `sc/user/Logical/CServerResponseLogic.lua:1006` |
| **`OnGetMailList`** | *(toàn cục)* | `tData` | `data`, `err`, `fun` | `sc/user/Logical/CServerResponseLogic.lua:921` |
| **`OnGetMyLineUps`** | `GuildContestData` | `data` | — | `sc/user/UI/GuildContest/GuildContestData.lua:595` |
| **`OnGetMyTeamList`** | `COGDataManager` | `svrData` | — | `sc/user/UI/cog/COGDataManager.lua:838` |
| **`OnGetNewGuildWarCurrentStatus`** | `GuildContestData` | `data` | — | `sc/user/UI/GuildContest/GuildContestData.lua:703` |
| **`OnGetObjectExchangeList`** | `ClientActivityObjExchange` | `tData` | — | `sc/user/Logical/ClientActivityObjExchangeLogic.lua:20` |
| **`OnGetOneGuildReportByRound`** | `GuildContestData` | `data` | — | `sc/user/UI/GuildContest/GuildContestData.lua:629` |
| **`OnGetOneGuildSignMembers`** | `CUIGuildContestEnrollDlg` | `data` | `cellIndex`, `eventName` | `sc/user/UI/GuildContest/CUIGuildContestEnrollDlg.lua:62` |
| **`OnGetOneServerSignInfo`** | `CUIGuildContestMainDlg` | `info` | `applyDataArr`, `bApplied`, `rankData` | `sc/user/UI/GuildContest/CUIGuildContestMainDlg.lua:1071` |
| **`OnGetOneUserReportByRound`** | `GuildContestData` | `data` | — | `sc/user/UI/GuildContest/GuildContestData.lua:659` |
| **`OnGetOrderId`** | `RechargeLogic` | `nErrCode, payload` | — | `sc/user/Logical/ClientRechargeLogic.lua:120` |
| **`OnGetOtherInfo`** | `ClientContestLogic` | `nErrCode, tData` | — | `sc/user/Logical/ClientContestLogic.lua:291` |
| **`OnGetOtherLineup`** | `CUIHeroPKPreviewDeployDlg` | `data` | — | `sc/user/UI/heroPK/CUIHeroPKPreviewDeployDlg.lua:145` |
| **`OnGetPack`** | `CUIRedPacket` | `data` | `bGrabbed` | `sc/user/UI/RedPacket/CUIRedPacket.lua:1107` |
| **`OnGetPackDetail`** | `CUIRedPacketRankDlg` | `data` | — | `sc/user/UI/RedPacket/CUIRedPacketRankDlg.lua:217` |
| **`OnGetPassMissionCountList`** | *(toàn cục)* | `tData` | `data`, `err` | `sc/user/Logical/CServerResponseLogic.lua:661` |
| **`OnGetPaymentConfig`** | `CUIRechargeStore` | `tData` | `RetData`, `nClientErrCode` | `sc/user/UI/CUIRechargeStore.lua:136` |
| **`OnGetPlayback`** | `ClientContestLogic` | `nErrCode, tData` | — | `sc/user/Logical/ClientContestLogic.lua:236` |
| **`OnGetPlayerBattleReport`** | `COGProtocol` | `nErrCode, tData` | — | `sc/user/UI/cog/COGProtocol.lua:208` |
| **`OnGetPlayerDiamondConsume`** | `CUIActivityCost` | `nPayCount` | — | `sc/user/UI/CUIActivityCost.lua:219` |
| **`OnGetPlayerPayment`** | `CUIActivityRecharge` | `nPayCount` | — | `sc/user/UI/CUIActivityRecharge.lua:271` |
| **`OnGetPlayerPlayback`** | `COGProtocol` | `nErrCode, tData` | — | `sc/user/UI/cog/COGProtocol.lua:508` |
| **`OnGetPrize`** | `ClientActivityLoginReward` | `tData` | — | `sc/user/Logical/ClientActivityLoginRewardLogic.lua:42` |
| **`OnGetPveEliteRank`** | `ClientLeaderboardLogic` | `tRankList, nSelfRank, nYesterdayRank` | — | `sc/user/Logical/ClientLeaderboard.lua:578` |
| **`OnGetPveNormalRank`** | `ClientLeaderboardLogic` | `tRankList, nSelfRank, nYesterdayRank` | — | `sc/user/Logical/ClientLeaderboard.lua:525` |
| **`OnGetPveStarRank`** | `ClientLeaderboardLogic` | `tRankList, nSelfRank, nYesterdayRank` | — | `sc/user/Logical/ClientLeaderboard.lua:631` |
| **`OnGetQQBiGift`** | `RechargeLogic` | `nErrCode, nType` | — | `sc/user/Logical/ClientRechargeLogic.lua:284` |
| **`OnGetQQPayFeedBack`** | `ClientRechargeLogic` | `nRebateCount, nAdvancedCarDay, nNormalCarDay` | — | `sc/user/Logical/ClientRechargeLogic.lua:175` |
| **`OnGetQQWXFriendDetail`** | `ClientFriendLogic` | `tRetData, number` | — | `sc/user/Logical/ClientFriendLogic.lua:702` |
| **`OnGetQqWxFriendFatigue`** | `ClientFriendLogic` | `—` | — | `sc/user/Logical/ClientFriendLogic.lua:737` |
| **`OnGetQuizInfo`** | `ClientContestLogic` | `nErrCode, tData` | — | `sc/user/Logical/ClientContestLogic.lua:195` |
| **`OnGetRandGuildList`** | `ClientGuildLogic` | `nErrCode, tData` | — | `sc/user/Logical/ClientGuildApplyLogic.lua:66` |
| **`OnGetRandomName`** | `CUILogin` | `szName` | — | `sc/user/UI/CUILogin2.lua:2332` |
| **`OnGetRanking`** | `ClientGodSecret` | `tData` | — | `sc/user/Logical/ClientGodSecret.lua:399` |
| **`OnGetRechargeSignMonthConfig`** | `ClientRechargeSignLogic` | `tConfig` | — | `sc/user/Logical/ClientRechargeSignLogic.lua:30` |
| **`OnGetRecommendedFriend`** | `ClientFriendLogic` | `nErrCode, tData` | — | `sc/user/Logical/ClientFriendLogic.lua:524` |
| **`OnGetRecommendedUserList`** | *(toàn cục)* | `tData` | `data`, `err` | `sc/user/Logical/CServerResponseLogic.lua:793` |
| **`OnGetRedPackList`** | `CUIRedPacket` | `data` | `bGrabbed` | `sc/user/UI/RedPacket/CUIRedPacket.lua:1046` |
| **`OnGetReward`** | `CUIAPRReward` | `tData` | — | `sc/user/UI/apr/CUIAPRReward.lua:382` |
| **`OnGetRoleRankList`** | `CUIGuildContestRankDlg` | `data` | `HotData`, `Rank` | `sc/user/UI/GuildContest/CUIGuildContestRankDlg.lua:141` |
| **`OnGetSCSZLRank`** | `ClientLeaderboardLogic` | `tRankList` | — | `sc/user/Logical/ClientLeaderboard.lua:422` |
| **`OnGetSYZLBRank`** | `ClientLeaderboardLogic` | `tRankList` | — | `sc/user/Logical/ClientLeaderboard.lua:389` |
| **`OnGetScorePrize`** | `ClientActivityGodHero` | `strIndex,tUserActivityData` | — | `sc/user/Logical/ClientActivityGodHeroLogic.lua:189` |
| **`OnGetSearchList`** | `ClientArenaLogic` | `searchList` | — | `sc/user/Logical/ClientArenalLogic.lua:177` |
| **`OnGetSelfDJSJFRankScore`** | `ClientLeaderboardLogic` | `nDamage` | — | `sc/user/Logical/ClientLeaderboard.lua:132` |
| **`OnGetSelfHJRQRankScore`** | `ClientLeaderboardLogic` | `nCostTime, nWave` | — | `sc/user/Logical/ClientLeaderboard.lua:36` |
| **`OnGetSelfSCSZLRankScore`** | `ClientLeaderboardLogic` | `nkillCount` | — | `sc/user/Logical/ClientLeaderboard.lua:106` |
| **`OnGetSelfSYZLBRankScore`** | `ClientLeaderboardLogic` | `nCostTime` | — | `sc/user/Logical/ClientLeaderboard.lua:68` |
| **`OnGetSelfXZWCRankScore`** | `ClientLeaderboardLogic` | `nCostTime` | — | `sc/user/Logical/ClientLeaderboard.lua:162` |
| **`OnGetShopConf`** | `CUIExchangeShop` | `data` | `costPrizeData` | `sc/user/UI/CUIExchangeShop.lua:431` |
| **`OnGetShuashualeList`** | `CUIShuaShuaLeDlg` | `data` | `NeedObjectList`, `nRemainTimes` | `sc/user/UI/CUIShuaShuaLeDlg.lua:711` |
| **`OnGetSpeechContent`** | `ClientChattingLogic` | `errCode,Speech` | — | `sc/user/Logical/ClientChattingLogic.lua:122` |
| **`OnGetStateWarMedals`** | `CUIStateWarBattleReportDlg` | `data` | — | `sc/user/UI/StateWar/CUIStateWarBattleReportDlg.lua:216` |
| **`OnGetStateWarMedalsRankList`** | `CUIStateWarGloryList` | `data` | — | `sc/user/UI/StateWar/CUIStateWarGloryListDlg.lua:144` |
| **`OnGetStateWarReplay`** | `CUIStateWarBattleReportDlg` | `data` | — | `sc/user/UI/StateWar/CUIStateWarBattleReportDlg.lua:243` |
| **`OnGetStateWarReportList`** | `CUIStateWarBattleReportDlg` | `data` | — | `sc/user/UI/StateWar/CUIStateWarBattleReportDlg.lua:228` |
| **`OnGetTGZZRank`** | `ClientLeaderboardLogic` | `tHotData` | — | `sc/user/Logical/ClientLeaderboard.lua:82` |
| **`OnGetTongqueData`** | `CUITongqueDlg` | `data` | — | `sc/user/UI/CUITongqueDlg.lua:96` |
| **`OnGetTop3DiamondConsume`** | `CUIActivityCost` | `tData` | — | `sc/user/UI/CUIActivityCost.lua:223` |
| **`OnGetTop3Payment`** | `CUIActivityRecharge` | `tData` | — | `sc/user/UI/CUIActivityRecharge.lua:275` |
| **`OnGetTopFightCapacity`** | `ClientHeroLogic` | `nFightCapacity` | — | `sc/user/Logical/ClientHeroLogic.lua:1099` |
| **`OnGetUserArenaData`** | *(toàn cục)* | `tData` | `data`, `err` | `sc/user/Logical/CServerResponseLogic.lua:1067` |
| **`OnGetUserArenaFightData`** | *(toàn cục)* | `tData` | `data`, `err` | `sc/user/Logical/CServerResponseLogic.lua:1081` |
| **`OnGetUserArenaFightRecord`** | `ClientArenaLogic` | `recordList` | — | `sc/user/Logical/ClientArenalLogic.lua:341` |
| **`OnGetUserArenaFightReplay`** | `ClientArenaLogic` | `repaly` | — | `sc/user/Logical/ClientArenalLogic.lua:361` |
| **`OnGetUserArenaFightReplayNew`** | `ClientArenaLogic` | `repaly` | — | `sc/user/Logical/ClientArenalLogic.lua:378` |
| **`OnGetUserArenal`** | `ClientArenaLogic` | `ranking` | — | `sc/user/Logical/ClientArenalLogic.lua:111` |
| **`OnGetUserBalance`** | `ClientRechargeLogic` | `nRet, nTotalRechargeCount` | — | `sc/user/Logical/ClientPaymentLogic.lua:259` |
| **`OnGetUserDetailByUid`** | `ClientFriendLogic` | `nErrCode, returnData` | — | `sc/user/Logical/ClientFriendLogic.lua:257` |
| **`OnGetUserFriends`** | `ClientFriendLogic` | `nErrCode, returnData` | — | `sc/user/Logical/ClientFriendLogic.lua:228` |
| **`OnGetUserInfo`** | `CUIRedPacket` | `data` | `bGrabbed` | `sc/user/UI/RedPacket/CUIRedPacket.lua:1036` |
| **`OnGetUserNewHandPrivilegeInfo`** | `CUINewHandPrivilege` | `—` | — | `sc/user/UI/CUINewHandPrivilege.lua:142` |
| **`OnGetUserRelation`** | *(toàn cục)* | `tData` | `data`, `err` | `sc/user/Logical/CServerResponseLogic.lua:778` |
| **`OnGetUserRelations`** | `ClientFriendLogic` | `nErrCode,returnData` | — | `sc/user/Logical/ClientFriendLogic.lua:44` |
| **`OnGetUserState`** | `ClientActivityContinuousRecharge` | `tUserState` | — | `sc/user/Logical/ClientActivityContinuousRecharge.lua:21` |
| **`OnGetWCSInfo`** | `CUIWCS` | `—` | — | `sc/user/UI/wcs/CUIWCS.lua:153` |
| **`OnGetWaterTreeReward`** | `CUIArmyGroupCampsite` | `—` | — | `sc/user/UI/CUIArmyGroupCampsite.lua:2404` |
| **`OnGetWeeklyFunPrize`** | `ClientWeeklyFunLogic` | `nActivityId` | — | `sc/user/Logical/ClientWeeklyFunLogic.lua:16` |
| **`OnGetWelfare`** | `ClientContestLogic` | `nID, tData` | — | `sc/user/Logical/ClientContestLogic.lua:444` |
| **`OnGetWorldArenalRanking`** | `ClientArenaLogic` | `rankingList` | — | `sc/user/Logical/ClientArenalLogic.lua:131` |
| **`OnGetWushuangRankList`** | `ActivityWushuang` | `tData` | — | `sc/user/Logical/ClientAcivityWushuang.lua:133` |
| **`OnGetXZWCRank`** | `ClientLeaderboardLogic` | `tRankList` | — | `sc/user/Logical/ClientLeaderboard.lua:491` |
| **`OnGiveUpGuildChapterPrepare`** | `ClientGuildChapterLogic` | `eventList, nErrCode` | — | `sc/user/Logical/ClientGuildChapterLogic.lua:153` |
| **`OnGuildChapterFightBegin`** | `Statistics` | `—` | — | `sc/share/Statistics.lua:612` |
| **`OnGuildChapterFightComplete`** | `ClientGuildChapterLogic` | `eventList, nErrCode, tData` | — | `sc/user/Logical/ClientGuildChapterLogic.lua:193` |
| **`OnGuildChapterRewardInfo`** | `ClientGuildChapterLogic` | `eventList, nErrCode, tData` | — | `sc/user/Logical/ClientGuildChapterLogic.lua:225` |
| **`OnGuildWarCompeleteFight`** | `CUIGame` | `tData` | — | `sc/user/Battle/CUIGame.lua:4578` |
| **`OnGuildWarFightBegin`** | `ClientGuildWarLogic` | `eventList, nErrCode, retInfo` | — | `sc/user/Logical/ClientGuildWarLogic.lua:964` |
| **`OnGuildWarIsOpen`** | `ClientGuildWarLogic` | `eventList, nErrCode, result` | — | `sc/user/Logical/ClientGuildWarLogic.lua:411` |
| **`OnHeroExpedition`** | *(toàn cục)* | `tData` | `data`, `err` | `sc/user/Logical/CServerResponseLogic.lua:444` |
| **`OnImpeachHeadman`** | `ClientGuildLogic` | `tData` | — | `sc/user/Logical/ClientGuildApplyLogic.lua:864` |
| **`OnInspire`** | `CUIInfiniteLevelInspire` | `isSuccess` | — | `sc/user/UI/CUIInfiniteLevelInspire.lua:262` |
| **`OnIntensifyEquipment`** | `Statistics` | `tData` | `ChapterKey`, `NewLevel`, `OriLevel` | `sc/share/Statistics.lua:86` |
| **`OnIntoLineup`** | `ClientArmyLogic` | `tReturnData` | — | `sc/user/Logical/ClientArmyLogic.lua:72` |
| **`OnIsHaveAndroidFeedBack`** | `ClientRechargeLogic` | `nErrCode, nRebateCount, nAdvancedCarDay, nNormalCarDay` | — | `sc/user/Logical/ClientRechargeLogic.lua:204` |
| **`OnIsHaveGuildWarRankReward`** | `ClientGuildWarLogic` | `eventList, nErrCode, bReward, rankInfo` | — | `sc/user/Logical/ClientGuildWarLogic.lua:1056` |
| **`OnIsUniqueNickName`** | `ClientUserLogic` | `bUniqueNickName` | — | `sc/user/Logical/ClientUserLogic.lua:161` |
| **`OnKeepFishBaby`** | `CUIAquariumCatchFryDlg` | `data` | — | `sc/user/UI/pet/CUIAquariumCatchFryDlg.lua:220` |
| **`OnKickGuild`** | `ClientGuildLogic` | `nErrCode` | — | `sc/user/Logical/ClientGuildManageLogic.lua:491` |
| **`OnLogin`** | *(toàn cục)* | `tData` | `data`, `err`, `fun` | `sc/user/Logical/CServerResponseLogic.lua:1026` |
| **`OnManualRefreshMission`** | `COGProtocol` | `tData` | — | `sc/user/UI/cog/COGProtocol.lua:178` |
| **`OnModifyNotice`** | `ClientGuildLogic` | `nErrCode` | — | `sc/user/Logical/ClientGuildManageLogic.lua:699` |
| **`OnNewGuildWarRelpayInfo`** | `GuildContestData` | `data` | — | `sc/user/UI/GuildContest/GuildContestData.lua:688` |
| **`OnNotifyMessage`** | `ClientChattingLogic` | `errCode, SpeechId` | — | `sc/user/Logical/ClientChattingLogic.lua:94` |
| **`OnObjectExchange`** | `ClientActivityObjExchange` | `tData` | — | `sc/user/Logical/ClientActivityObjExchangeLogic.lua:43` |
| **`OnOpenBoxWithDiamond`** | `ClientMagicWeaponTreasureBox` | `tPrizeList` | — | `sc/user/Logical/ClientMagicWeaponTreasureBox.lua:20` |
| **`OnOpenBoxWithKey`** | `ClientMagicWeaponTreasureBox` | `tPrizeList` | — | `sc/user/Logical/ClientMagicWeaponTreasureBox.lua:9` |
| **`OnOpenGuildChapter`** | `ClientGuildChapterLogic` | `eventList, nErrCode` | — | `sc/user/Logical/ClientGuildChapterLogic.lua:73` |
| **`OnOutOffLineup`** | `ClientArmyLogic` | `tReturnData` | — | `sc/user/Logical/ClientArmyLogic.lua:102` |
| **`OnPickGuildHero`** | `ClientGuildLogic` | `tData` | — | `sc/user/Logical/ClientGuildDispatchLogic.lua:146` |
| **`OnPlayDiceGame`** | `ClientGuildLogic` | `tData` | — | `sc/user/Logical/ClientGuildINeedHeroLogic.lua:37` |
| **`OnPossess`** | `CUIPetAttached` | `—` | — | `sc/user/UI/pet/CUIPetAttached.lua:570` |
| **`OnPotionExpedition`** | *(toàn cục)* | `tData` | `data`, `err` | `sc/user/Logical/CServerResponseLogic.lua:542` |
| **`OnPracticeHero`** | `Statistics` | `—` | — | `sc/share/Statistics.lua:635` |
| **`OnPrepareGuildChapter`** | `ClientGuildChapterLogic` | `eventList, nErrCode` | — | `sc/user/Logical/ClientGuildChapterLogic.lua:133` |
| **`OnPromoteQualityEquipment`** | `Statistics` | `tData` | `ArmyLevel`, `Quality` | `sc/share/Statistics.lua:485` |
| **`OnPurifyExclusiveEquip`** | `CUIEquipment` | `tData` | — | `sc/user/UI/CUIEquipment_Refine.lua:727` |
| **`OnQueryAccnList`** | `ClientGuildWarLogic` | `eventList, nErrCode, tData` | — | `sc/user/Logical/ClientGuildWarLogic.lua:467` |
| **`OnQueryActivityShoppingLimit`** | `ClientActivityShoppingLogic` | `tData` | — | `sc/user/Logical/ClientActivitiesLogic.lua:397` |
| **`OnQueryAttckCanBeAttack`** | `ClientGuildWarLogic` | `eventList, nErrCode, nCanAttack` | — | `sc/user/Logical/ClientGuildWarLogic.lua:909` |
| **`OnQueryGuildChapterInfo`** | `ClientGuildChapterLogic` | `eventList, nErrCode, tData` | — | `sc/user/Logical/ClientGuildChapterLogic.lua:113` |
| **`OnQueryGuildChapterInjuryRank`** | `ClientGuildChapterLogic` | `eventList, nErrCode, tData` | — | `sc/user/Logical/ClientGuildChapterLogic.lua:367` |
| **`OnQueryGuildChapterListInfo`** | `ClientGuildChapterLogic` | `eventList, nErrCode, tData` | — | `sc/user/Logical/ClientGuildChapterLogic.lua:42` |
| **`OnQueryGuildChapterRewardRecord`** | `ClientGuildChapterLogic` | `eventList, nErrCode, tData` | — | `sc/user/Logical/ClientGuildChapterLogic.lua:285` |
| **`OnQueryGuildChapterServerInjuryRank`** | `ClientGuildChapterLogic` | `eventList, nErrCode, tData` | — | `sc/user/Logical/ClientGuildChapterLogic.lua:387` |
| **`OnQueryGuildWarEndInfo`** | `ClientGuildWarLogic` | `eventList, nErrCode, tRetData` | — | `sc/user/Logical/ClientGuildWarLogic.lua:1085` |
| **`OnQueryGuildWarRank`** | `ClientGuildWarLogic` | `eventList, nErrCode, tData` | — | `sc/user/Logical/ClientGuildWarLogic.lua:278` |
| **`OnQueryQQBiGiftInfo`** | `RechargeLogic` | `nErrCode,tGiftInfo` | — | `sc/user/Logical/ClientRechargeLogic.lua:263` |
| **`OnQueryReqestRewardMember`** | `ClientGuildChapterLogic` | `eventList, nErrCode, tData` | — | `sc/user/Logical/ClientGuildChapterLogic.lua:245` |
| **`OnQueryScore`** | `ClientGuildWarLogic` | `eventList, nErrCode, tData` | — | `sc/user/Logical/ClientGuildWarLogic.lua:214` |
| **`OnQuerySelfRequestPrize`** | `ClientGuildChapterLogic` | `eventList, nErrCode, tData` | — | `sc/user/Logical/ClientGuildChapterLogic.lua:305` |
| **`OnReachAchieve`** | `ScoreStroeLogic` | `tAchieve` | `AchieveType` | `sc/share/ScoreStroeLogic.lua:162` |
| **`OnRecastEquipment`** | *(toàn cục)* | `tData` | `data`, `err` | `sc/user/Logical/CServerResponseLogic.lua:600` |
| **`OnReceiveGift`** | `ClientFriendLogic` | `nErrCode` | — | `sc/user/Logical/ClientFriendLogic.lua:480` |
| **`OnReceiveGiftAll`** | `ClientFriendLogic` | `nErrCode` | — | `sc/user/Logical/ClientFriendLogic.lua:593` |
| **`OnRecruitHero`** | `CUITravern` | `nHeroID` | — | `sc/user/UI/CUITavern.lua:361` |
| **`OnReduceDiamondToGold`** | *(toàn cục)* | `tData` | `data`, `err`, `fun` | `sc/user/Logical/CServerResponseLogic.lua:992` |
| **`OnRefineEquip`** | `ClientEquipmentLogic` | `—` | — | `sc/user/Logical/ClientEquipmentLogic.lua:79` |
| **`OnRefresh`** | `ClientGodSecret` | `—` | — | `sc/user/Logical/ClientGodSecret.lua:366` |
| **`OnRefreshArenaGoodsWithHonor`** | `ClientArenaLogic` | `userGoodsList` | — | `sc/user/Logical/ClientArenalLogic.lua:438` |
| **`OnRefreshFightTime`** | `ClientArenaLogic` | `—` | — | `sc/user/Logical/ClientArenalLogic.lua:553` |
| **`OnRefreshFishBaby`** | `CUIAquariumCatchFryDlg` | `data` | — | `sc/user/UI/pet/CUIAquariumCatchFryDlg.lua:206` |
| **`OnRefreshFishQueue`** | `CUIAquariumMainDlg` | `—` | — | `sc/user/UI/pet/CUIAquariumMainDlg.lua:743` |
| **`OnRefreshGoodsList`** | `CUIArenaShop` | `userGoodsList` | — | `sc/user/UI/CUIArenaShop.lua:88` |
| **`OnRefreshLeftWingCount`** | `CUIWingGet` | `—` | — | `sc/user/UI/CUIWingGet.lua:271` |
| **`OnRefreshUserArenaGoods`** | `ClientArenaLogic` | `userGoodsList` | — | `sc/user/Logical/ClientArenalLogic.lua:398` |
| **`OnRefreshUserGuild`** | `ClientGuildLogic` | `—` | — | `sc/user/Logical/ClientGuildManageLogic.lua:610` |
| **`OnRefuseAllApply`** | `ClientFriendLogic` | `nErrCode` | — | `sc/user/Logical/ClientFriendLogic.lua:364` |
| **`OnRefuseFriendApply`** | *(toàn cục)* | `tData` | `data`, `err` | `sc/user/Logical/CServerResponseLogic.lua:869` |
| **`OnRejectApply`** | `ClientGuildLogic` | `nErrCode` | — | `sc/user/Logical/ClientGuildManageLogic.lua:367` |
| **`OnRemoveFriend`** | `ClientFriendLogic` | `nErrCode,bReduceGift,nTargetUid` | — | `sc/user/Logical/ClientFriendLogic.lua:400` |
| **`OnRemoveFriendApply`** | *(toàn cục)* | `tData` | `data`, `err` | `sc/user/Logical/CServerResponseLogic.lua:839` |
| **`OnRemoveFriendRelation`** | *(toàn cục)* | `tData` | `data`, `err` | `sc/user/Logical/CServerResponseLogic.lua:884` |
| **`OnRemoveTeam`** | `COGDataManager` | `nTeamID` | — | `sc/user/UI/cog/COGDataManager.lua:929` |
| **`OnRepairCity`** | `COGProtocol` | `...` | — | `sc/user/UI/cog/COGProtocol.lua:81` |
| **`OnRequestFightTest`** | `ClientContestLogic` | `nErrorCode, strSequence, strFightData` | — | `sc/user/Logical/ClientContestLogic.lua:324` |
| **`OnRequestReward`** | `ClientGuildChapterLogic` | `eventList, nErrCode` | — | `sc/user/Logical/ClientGuildChapterLogic.lua:347` |
| **`OnResetCavern`** | `CUICavern` | `—` | — | `sc/user/UI/CUICavern.lua:165` |
| **`OnResetEndlessChapter`** | `CUIInfiniteLevelMain` | `—` | — | `sc/user/UI/CUIInfiniteLevelMain.lua:912` |
| **`OnResetGuildChapter`** | `ClientGuildChapterLogic` | `eventList, nErrCode` | — | `sc/user/Logical/ClientGuildChapterLogic.lua:93` |
| **`OnResetHeroSkyFate`** | `ClientHeroLogic` | `nErrCode` | — | `sc/user/Logical/ClientHeroLogic.lua:1160` |
| **`OnReturnHome`** | *(toàn cục)* | `tData` | `data`, `err` | `sc/user/Logical/CServerResponseLogic.lua:179` |
| **`OnReviveInBattle`** | `ChapterNormalLevel` | `—` | — | `sc/user/Battle/ChapterNormalLevel.lua:682` |
| **`OnSaveAllMailPrize`** | *(toàn cục)* | `tData` | `data`, `err`, `fun` | `sc/user/Logical/CServerResponseLogic.lua:979` |
| **`OnSaveBattleArray`** | `ClientContestLogic` | `nErrCode, tData` | — | `sc/user/Logical/ClientContestLogic.lua:133` |
| **`OnSaveMailPrizeWithMailID`** | *(toàn cục)* | `tData` | `data`, `err`, `fun` | `sc/user/Logical/CServerResponseLogic.lua:933` |
| **`OnSearchGuild`** | `ClientGuildLogic` | `nErrCode, tData` | — | `sc/user/Logical/ClientGuildApplyLogic.lua:340` |
| **`OnSearchUserWithName`** | `ClientFriendLogic` | `nErrCode,returnData` | — | `sc/user/Logical/ClientFriendLogic.lua:198` |
| **`OnSelectAdvancedFormation`** | `ClientFormationLogic` | `strName` | — | `sc/user/Logical/ClientFormationLogic.lua:36` |
| **`OnSellItem`** | *(toàn cục)* | `tData` | `data`, `err` | `sc/user/Logical/CServerResponseLogic.lua:688` |
| **`OnSendBenefitReward`** | `ClientContestLogic` | `bDiamond` | — | `sc/user/Logical/ClientContestLogic.lua:275` |
| **`OnSendGift`** | `ClientFriendLogic` | `nErrCode` | — | `sc/user/Logical/ClientFriendLogic.lua:445` |
| **`OnSendGiftAll`** | `ClientFriendLogic` | `nErrCode` | — | `sc/user/Logical/ClientFriendLogic.lua:560` |
| **`OnSendPack`** | `CUIRedPacket` | `data` | `bGrabbed` | `sc/user/UI/RedPacket/CUIRedPacket.lua:1066` |
| **`OnSendQqWxFriendFatigue`** | `ClientFriendLogic` | `—` | — | `sc/user/Logical/ClientFriendLogic.lua:767` |
| **`OnSendReward`** | `CUINewHandPrivilege` | `—` | — | `sc/user/UI/CUINewHandPrivilege.lua:99` |
| **`OnSetArenaHero`** | `ClientArenaLogic` | `heroIdList` | — | `sc/user/Logical/ClientArenalLogic.lua:152` |
| **`OnSetExclusiveSkinState`** | `ClientHeroLogic` | `nHeroID,isCancel` | — | `sc/user/Logical/ClientHeroLogic.lua:1171` |
| **`OnSetGuildMsg`** | `COGDataManager` | `—` | — | `sc/user/UI/cog/COGDataManager.lua:833` |
| **`OnSetGuildWarFightHero`** | `ClientGuildWarLogic` | `eventList, nErrCode` | — | `sc/user/Logical/ClientGuildWarLogic.lua:338` |
| **`OnSetHead`** | `ClientGuildLogic` | `nErrCode` | — | `sc/user/Logical/ClientGuildManageLogic.lua:398` |
| **`OnSetMailReadWithMailID`** | *(toàn cục)* | `tData` | `data`, `err`, `fun` | `sc/user/Logical/CServerResponseLogic.lua:945` |
| **`OnSetManager`** | `ClientGuildLogic` | `nErrCode` | — | `sc/user/Logical/ClientGuildManageLogic.lua:429` |
| **`OnSetNewGuildWarLineUps`** | `GuildContestData` | `data` | — | `sc/user/UI/GuildContest/GuildContestData.lua:588` |
| **`OnSetStateWarLineUp`** | `StateWarBattleData` | `—` | — | `sc/user/UI/StateWar/StateWarBattleData.lua:40` |
| **`OnSetTargetCity`** | `COGDataManager` | `nCityId` | — | `sc/user/UI/cog/COGDataManager.lua:822` |
| **`OnShowWing`** | `CUIWingShow` | `—` | — | `sc/user/UI/CUIWingShow.lua:291` |
| **`OnShuashualeExchange`** | `CUIShuaShuaLeDlg` | `data` | `NeedObjectList`, `nRemainTimes` | `sc/user/UI/CUIShuaShuaLeDlg.lua:761` |
| **`OnSignIn`** | *(toàn cục)* | `tData` | `data`, `err` | `sc/user/Logical/CServerResponseLogic.lua:701` |
| **`OnSignInNewGuildWar`** | `CUIGuildContestMainDlg` | `data` | — | `sc/user/UI/GuildContest/CUIGuildContestMainDlg.lua:1088` |
| **`OnSignUp`** | `ClientContestLogic` | `nErrCode` | — | `sc/user/Logical/ClientContestLogic.lua:69` |
| **`OnSkipAchieve`** | `ClientAchieveLogic` | `nErrCode,nAchieveType` | — | `sc/user/Logical/ClientAchieveLogic.lua:723` |
| **`OnStarDown`** | `CUISBDegrade` | `tData` | `feedback` | `sc/user/UI/sb/CUISBDegrade.lua:19` |
| **`OnStarUp`** | `CUISBMainContent` | `—` | — | `sc/user/UI/sb/CUISBMainContent.lua:114` |
| **`OnStartLottery`** | *(toàn cục)* | `tData` | `data`, `err`, `fun` | `sc/user/Logical/CServerResponseLogic.lua:1015` |
| **`OnStopSwap`** | `ClientEndlessChapterLogic` | `tPrizeList` | — | `sc/user/Logical/ClientEndlessChapterLogic.lua:356` |
| **`OnStrengthen`** | `CUISBMainContent` | `—` | — | `sc/user/UI/sb/CUISBMainContent.lua:127` |
| **`OnSwap`** | `ClientEndlessChapterLogic` | `—` | — | `sc/user/Logical/ClientEndlessChapterLogic.lua:332` |
| **`OnSweepEpicChapter`** | `ClientEpicBattleLogic` | `tRewardList` | — | `sc/user/Logical/ClientEpicBattleLogic.lua:93` |
| **`OnTestAddMail`** | *(toàn cục)* | `tData` | `data`, `err`, `fun` | `sc/user/Logical/CServerResponseLogic.lua:968` |
| **`OnUnlockArmy`** | `ClientArmyLogic` | `nArmyId` | — | `sc/user/Logical/ClientArmyLogic.lua:42` |
| **`OnUpHeroFightSoul`** | `ClientHeroLogic` | `upResult` | — | `sc/user/Logical/ClientHeroLogic.lua:981` |
| **`OnUpdateFreeStrengthState`** | `ClientAchieveLogic` | `—` | — | `sc/user/Logical/ClientAchieveLogic.lua:292` |
| **`OnUpdateHeroSkyFate`** | `ClientHeroLogic` | `nErrCode` | — | `sc/user/Logical/ClientHeroLogic.lua:1149` |
| **`OnUpdateServerTimeEx`** | `ClientGameWorld` | `nServerTime, iTimeZone` | — | `sc/user/Logical/ClientGameWorld.lua:213` |
| **`OnUpdateTeam`** | `COGProtocol` | `nErrCode` | — | `sc/user/UI/cog/COGProtocol.lua:336` |
| **`OnUpgrade`** | `ClientFormationLogic` | `strName` | — | `sc/user/Logical/ClientFormationLogic.lua:13` |
| **`OnUpgradeArmy`** | *(toàn cục)* | `tData` | `data`, `err` | `sc/user/Logical/CServerResponseLogic.lua:309` |
| **`OnUpgradeHeroGrowthFactor`** | *(toàn cục)* | `tData` | `data`, `err` | `sc/user/Logical/CServerResponseLogic.lua:455` |
| **`OnUpgradePotion`** | *(toàn cục)* | `tData` | `data`, `err` | `sc/user/Logical/CServerResponseLogic.lua:499` |
| **`OnUpgradeResearch`** | `ClientPotionLogic` | `nErrCode` | — | `sc/user/Logical/ClientPotionLogic.lua:65` |
| **`OnUpgradeWing`** | `CUITest` | `bIsSuccess` | — | `sc/user/UI/CUITest.lua:1159` |
| **`OnUploadWeChatGroup`** | `ClientGuildLogic` | `nErrCode` | — | `sc/user/Logical/ClientGuildManageLogic.lua:780` |
| **`OnUseHeroExperiencePill`** | `CUIHeroUpgradeLevel` | `tData` | `Count`, `HeroID`, `ItemID` | `sc/user/UI/CUIHeroUpgradeLevel.lua:1221` |
| **`OnUseItem`** | *(toàn cục)* | `tData` | `data`, `err` | `sc/user/Logical/CServerResponseLogic.lua:673` |
| **`OnUseRedeemCode`** | `CUIRedeemCode` | `tData` | `RetData`, `nClientErrCode`, `nServerErrCode` | `sc/user/UI/CUIRedeemCode.lua:132` |
| **`OnUserMoveTo`** | `ClientGuildCampLogic` | `nUid,x,y,direction` | — | `sc/user/Logical/ClientGuildCampLogic.lua:130` |
| **`OnUserOverHJRQ`** | `ClientRollingSubtitles` | `name,nCount` | — | `sc/user/Logical/ClientRollingSubtitles.lua:78` |
| **`OnVipRoll`** | `ClientRollingSubtitles` | `strCharacterName,itemID` | — | `sc/user/Logical/ClientRollingSubtitles.lua:146` |

## 5. Mã lỗi (`sc/share/error.lua`)

Trường `err` của mọi payload trả về.

<details><summary><code>ErrorCode.Common</code> — 14 mã</summary>

| mã | tên |
|---:|---|
| 500 | `NotEnoughGold` |
| 501 | `LuaError` |
| 502 | `LevelError` |
| 503 | `RedisError` |
| 504 | `NotEnoughDiamond` |
| 505 | `GoldCostMismatch` |
| 506 | `DiamCostMismatch` |
| 507 | `GetUserLockFailed` |
| 508 | `UserDataErr` |
| 509 | `SetDataErr` |
| 510 | `GetConfigFaild` |
| 511 | `CostResourceFailed` |
| 512 | `UnknowPayChannelId` |
| 513 | `TooOldVersion` |

</details>

<details><summary><code>ErrorCode.GameWorld</code> — 5 mã</summary>

| mã | tên |
|---:|---|
| 1001 | `NeedCreateCharacter` |
| 1002 | `InitUserDataError` |
| 1003 | `GetUserDataFaild` |
| 1004 | `CanNotFindUserWithName` |
| 1005 | `NoEnoughUserLevel` |

</details>

<details><summary><code>ErrorCode.Login</code> — 9 mã</summary>

| mã | tên |
|---:|---|
| 1050 | `WrongPassword` |
| 1051 | `NoUser` |
| 1052 | `UserHasExist` |
| 1053 | `UserHasOnline` |
| 1054 | `UserNameExist` |
| 1055 | `CreateAccountFaild` |
| 1056 | `CannotGetUserNameFromChannel` |
| 1057 | `UserBeForbided` |
| 1058 | `UserUidLimit` |

</details>

<details><summary><code>ErrorCode.GameGateway</code> — 7 mã</summary>

| mã | tên |
|---:|---|
| 1080 | `UserHasOnline` |
| 1081 | `SessionInvalid` |
| 1082 | `ConnIdNotFixUid` |
| 1083 | `KickForce` |
| 1084 | `ConnIdNotFound` |
| 1085 | `TokenWrong` |
| 1086 | `UserLoginAtOtherPlace` |

</details>

<details><summary><code>ErrorCode.Equipment</code> — 17 mã</summary>

| mã | tên |
|---:|---|
| 1101 | `NotFindEquipment` |
| 1102 | `ExceedMaxIntensifyLevel` |
| 1103 | `NotEnoughResourceForIntensifyEquipment` |
| 1104 | `SetEquipIntensifyLevel` |
| 1105 | `NotFindEquipmentMaterial` |
| 1106 | `NotEquipmentExist` |
| 1107 | `FillDropIconTypeWithDropListFail` |
| 1108 | `NotRechedLevelToPromoteQualityEquipment` |
| 1109 | `NotEnoughConcentrate` |
| 1110 | `MaxRefineLevelCantRefine` |
| 1111 | `IsNotExclusive` |
| 1112 | `CanNotPurifyThisPartEquip` |
| 1113 | `IsMaxPurifyLevel` |
| 1114 | `NoEnoughPurifyLevel` |
| 1115 | `NoGetAllExclusiveEquip` |
| 1116 | `IsExclusive` |
| 1117 | `CanNotForgingExclusiveWeapon` |

</details>

<details><summary><code>ErrorCode.Hero</code> — 33 mã</summary>

| mã | tên |
|---:|---|
| 1301 | `NotFindHero` |
| 1302 | `NotEnoughForUpgradeGrowth` |
| 1303 | `SetGrowthFail` |
| 1304 | `FillDataFail` |
| 1305 | `GetGrowthConfigFail` |
| 1306 | `HasUnlocked` |
| 1307 | `HasLocked` |
| 1308 | `NotFindHeroConfig` |
| 1309 | `SetHeroFragmentFail` |
| 1310 | `AddHeroEquipmentFail` |
| 1311 | `AddHeroFail` |
| 1312 | `GetMaxLevelConfigFail` |
| 1313 | `LimitBreakthrough` |
| 1314 | `SetMaxLevelFail` |
| 1315 | `setBreakthroughCountFail` |
| 1316 | `LimitGrowth` |
| 1317 | `CharacterNotUse` |
| 1318 | `NotFindExperiencePill` |
| 1319 | `CalcExperiencePillCountFail` |
| 1320 | `AddHeroExFail` |
| 1321 | `AddHeroLevelFail` |
| 1322 | `SetHeroExFail` |
| 1323 | `GetHeroLevelConfigFail` |
| 1324 | `NotRechedLevelToPromoteQualityEquipment` |
| 1325 | `UpHeroFightSoulLevelLimit` |
| 1326 | `GetFightSoulConfigFail` |
| 1327 | `NoWing` |
| 1328 | `NoCountIntensifyWing` |
| 1329 | `NoSoMuchLevelWing` |
| 1330 | `NotExclusiveHero` |
| 1331 | `HasGetExclusiveSkin` |
| 1332 | `HeroFragmentNotEnough` |
| 1333 | `FateConditionLimit` |

</details>

<details><summary><code>ErrorCode.Chapter</code> — 38 mã</summary>

| mã | tên |
|---:|---|
| 1401 | `GetBattleReportsFail` |
| 1402 | `NotEnoughFatigue` |
| 1403 | `MaxPassMissionCount` |
| 1404 | `CanNotFoundConfig` |
| 1405 | `GetNPCDropDataError` |
| 1406 | `SweepCountError` |
| 1407 | `SaveVictoryReportError` |
| 1408 | `SaveDropDataError` |
| 1409 | `SavePrizeDataError` |
| 1410 | `SaveFailedReportError` |
| 1411 | `ParamNotEqWhiteBoard` |
| 1412 | `SetHeroFightFail` |
| 1413 | `AddFightHeroExFail` |
| 1414 | `ChapterNotFound` |
| 1415 | `GetUserGlobalConfigFail` |
| 1416 | `CheckDropDataIsValid` |
| 1417 | `GetFatigueValueFail` |
| 1418 | `GetChapterUserExFail` |
| 1419 | `GetLatestChapterKeyFail` |
| 1420 | `BuySweepCountError` |
| 1421 | `BuyBattleResetCountError` |
| 1422 | `ChapterIsNotActivityMode` |
| 1423 | `FilterKillDropListFail` |
| 1424 | `TempChapterDropDataFail` |
| 1425 | `MainChapterStatusFail` |
| 1426 | `SweepIsCooldown` |
| 1427 | `SetSweepCooldownFail` |
| 1428 | `ChapterCanNotBattle` |
| 1429 | `CheckIsDoublePrizeTimeFaild` |
| 1430 | `GetChapterTargetRewardStatusMapFaild` |
| 1431 | `ChapterTargetRewardHasGet` |
| 1432 | `GetOtherPrizeFail` |
| 1433 | `NoEnoughUserLevel` |
| 1434 | `ChapterInCooldown` |
| 1435 | `NotCrossCantSweep` |
| 1436 | `Overtime` |
| 1437 | `DifferentHeroFactions` |
| 1470 | `saveChapterBeginStatusFail` |

</details>

<details><summary><code>ErrorCode.UserLogic</code> — 14 mã</summary>

| mã | tên |
|---:|---|
| 1801 | `BeginGuideFail` |
| 1802 | `CompleteGuideFail` |
| 1803 | `CreateCharacterFail` |
| 1804 | `GetUserGlobalDataFail` |
| 1805 | `SetUserFreeExPill` |
| 1806 | `CharacterNameHasExist` |
| 1807 | `GetUserBaseInfoFaild` |
| 1808 | `GetBuyFatigueConfigFaild` |
| 1809 | `HasMaxBuyFatigue` |
| 1810 | `AddFatigueFaild` |
| 1811 | `AddUserVipEx` |
| 1812 | `SetFatigueDataFaild` |
| 1812 | `UserHasExit` |
| 1813 | `CreateUserNickFaild` |

</details>

<details><summary><code>ErrorCode.Shop</code> — 2 mã</summary>

| mã | tên |
|---:|---|
| 1901 | `NotEnoughCurrency` |
| 1902 | `OutOfDayBuyLimit` |

</details>

<details><summary><code>ErrorCode.Lottery</code> — 3 mã</summary>

| mã | tên |
|---:|---|
| 2001 | `NotEnoughResource` |
| 2002 | `HasNotColdDown` |
| 2003 | `CheckSoulBoxNotOpen` |

</details>

<details><summary><code>ErrorCode.Mail</code> — 14 mã</summary>

| mã | tên |
|---:|---|
| 2101 | `GetMailListFail` |
| 2102 | `GetMailWithIdFail` |
| 2103 | `PrizeHasGetFail` |
| 2104 | `CheckMailIsGetPrizeFail` |
| 2105 | `SetMailStatusFail` |
| 2106 | `DeleteMailFail` |
| 2107 | `PrizeDataIsNull` |
| 2108 | `SaveMailAttachFail` |
| 2109 | `SystemMailFail` |
| 2110 | `mergeUserNewMailFail` |
| 2111 | `SetMailListFail` |
| 2112 | `FilterMailListFail` |
| 2113 | `MailConfigIsNull` |
| 2114 | `SendMailFailed` |

</details>

<details><summary><code>ErrorCode.Achieve</code> — 10 mã</summary>

| mã | tên |
|---:|---|
| 2200 | `GetUserAchieveFail` |
| 2201 | `WrongAcheiveState` |
| 2202 | `CheckAchieveWrong` |
| 2203 | `CheckAchieveFail` |
| 2204 | `SetAchieveStateFail` |
| 2205 | `SetAchieveIndexFail` |
| 2206 | `GetIsGetLoginRewardFail` |
| 2207 | `HasGetLoginReward` |
| 2208 | `InitUserAchieveFail` |
| 2209 | `NoEnoughHeroLevel` |

</details>

<details><summary><code>ErrorCode.Arenal</code> — 21 mã</summary>

| mã | tên |
|---:|---|
| 2301 | `TargetUserHasLocked` |
| 2302 | `UserHasLocked` |
| 2303 | `ArenaFightCountNotEnough` |
| 2304 | `ArenaFightInCD` |
| 2305 | `GetArenaFightDataFaild` |
| 2306 | `GetUserArenaDataFaild` |
| 2307 | `UpdateUserArenaDataFaild` |
| 2308 | `UpdateUserArenaRankingFaild` |
| 2309 | `GetArenalRankingWithRangeFaild` |
| 2310 | `RefreshArenaGoodsInCD` |
| 2311 | `GetRandomGoodsListFaild` |
| 2312 | `GetArenaRepalyFaild` |
| 2313 | `RefreshArenaGoodsFaild` |
| 2314 | `ArenaRankingEmpty` |
| 2315 | `FightTargetError` |
| 2316 | `RefreshFightCDFaild` |
| 2317 | `AddFightCountFaild` |
| 2318 | `RefreshCountOver` |
| 2319 | `NoEnoughHonor` |
| 2320 | `GetRefreshGoodsCostFaild` |
| 2321 | `GetUserRankingFaild` |

</details>

<details><summary><code>ErrorCode.RedeemCode</code> — 12 mã</summary>

| mã | tên |
|---:|---|
| 2401 | `RedeemCodeIllegal` |
| 2402 | `ExchangeItemFail` |
| 2403 | `GetRedeemCodeFail` |
| 2404 | `SetRedeemCodeFail` |
| 2405 | `RedeemCodeNotExist` |
| 2406 | `RedeemCodeHasUsed` |
| 2407 | `RedeemCodeOutOfDate` |
| 2408 | `ExchangeSameBatch` |
| 2409 | `CharacterDataFail` |
| 2410 | `UserHaveUseMaxCount` |
| 2411 | `UseTheSameMutexGroup` |
| 2412 | `ServerNotMatch` |

</details>

<details><summary><code>ErrorCode.MStore</code> — 7 mã</summary>

| mã | tên |
|---:|---|
| 2501 | `GetUserMStoreFaild` |
| 2502 | `RefreshFaild` |
| 2503 | `RefreshCountOver` |
| 2504 | `CreateGoodsListFaild` |
| 2505 | `GetRefreshDiamondFaild` |
| 2506 | `NoIncludeGoods` |
| 2507 | `HasSelled` |

</details>

<details><summary><code>ErrorCode.Cavern</code> — 8 mã</summary>

| mã | tên |
|---:|---|
| 2701 | `CompeleteProgressFaild` |
| 2702 | `WrongProgress` |
| 2703 | `CharacterIsDead` |
| 2704 | `WrongState` |
| 2705 | `NoEnoughHeroLevel` |
| 2707 | `HeroHasDead` |
| 2708 | `NoIncludeCharactor` |
| 2709 | `NoNeedSweep` |

</details>

<details><summary><code>ErrorCode.MidasTouch</code> — 5 mã</summary>

| mã | tên |
|---:|---|
| 2801 | `MidasTouchGetConfigFaild` |
| 2802 | `MidasTouchGetDataFaild` |
| 2803 | `MidasTouchSetDataFaild` |
| 2804 | `MidasTouchRunMax` |
| 2805 | `NotEnoughResource` |

</details>

<details><summary><code>ErrorCode.DestinyLogic</code> — 4 mã</summary>

| mã | tên |
|---:|---|
| 2901 | `ActiveProgressFaild` |
| 2902 | `GetUserDestinyFaild` |
| 2903 | `OverMaxDestinyCount` |
| 2904 | `SetDestinyDataFaild` |

</details>

<details><summary><code>ErrorCode.FortuneWheel</code> — 8 mã</summary>

| mã | tên |
|---:|---|
| 2910 | `OverFreeRollCount` |
| 2911 | `FreeRollInCD` |
| 2912 | `OverVipRollCount` |
| 2913 | `CanNotRunNewServerDailyWheel` |
| 2914 | `GetUserFortuneWheelFaild` |
| 2915 | `GetNewServerDailyWheelConfigFaild` |
| 2916 | `SetUserFortuneWheelFaild` |
| 2917 | `HasNoWheelPrize` |

</details>

<details><summary><code>ErrorCode.Recharge</code> — 24 mã</summary>

| mã | tên |
|---:|---|
| 3101 | `HasNotFirstRecharge` |
| 3102 | `HasGetFirstRechargePrize` |
| 3103 | `SavePrizeDataError` |
| 3104 | `GetConfigFaild` |
| 3105 | `GetUserRechargeDataFaild` |
| 3106 | `SetUserRechargeDataFaild` |
| 3107 | `DataNotEqualityConfig` |
| 3108 | `SavePrizeDataFaild` |
| 3109 | `CheckGoodsFirstRechargeFaild` |
| 3110 | `SetGoodsFirstRechargeFaild` |
| 3111 | `AddUserRechargeCountFaild` |
| 3112 | `RefreshUserVipLevelFaild` |
| 3113 | `GetRechargeDiamondCountFaild` |
| 3114 | `GetPayloadError` |
| 3115 | `PayloadHasGetGift` |
| 3116 | `NotUserOrder` |
| 3117 | `UserUidHasGotQQBiGift` |
| 3118 | `ImeiHasGotQQBiGift` |
| 3119 | `QqNumHasGotQQBiGift` |
| 3120 | `QQBiHasSendOver` |
| 3121 | `QQNumberIsWrong` |
| 3122 | `OrderHasNoPayLoad` |
| 3123 | `AppleCheckSignError` |
| 3124 | `AppleCheckSignTimeOut` |

</details>

<details><summary><code>ErrorCode.SevenDaysGift</code> — 6 mã</summary>

| mã | tên |
|---:|---|
| 3201 | `ExceedMaxDay` |
| 3202 | `NotOpen` |
| 3203 | `HasGet` |
| 3204 | `GetSevenDaysGiftDataFaild` |
| 3205 | `GetConfigFaild` |
| 3206 | `SetSevenDaysGiftDataFaild` |

</details>

<details><summary><code>ErrorCode.Clothing</code> — 6 mã</summary>

| mã | tên |
|---:|---|
| 3301 | `CanNotGetClothingPrize` |
| 3302 | `GetConfigFaild` |
| 3303 | `GetUserDataFaild` |
| 3304 | `SetUserDataFaild` |
| 3305 | `NotEnoughItemForCompose` |
| 3306 | `ClothingNotMatchHero` |

</details>

<details><summary><code>ErrorCode.VIP</code> — 2 mã</summary>

| mã | tên |
|---:|---|
| 3401 | `NoEnoughVipLevel` |
| 3402 | `HasBuyVipPackage` |

</details>

<details><summary><code>ErrorCode.Guild</code> — 65 mã</summary>

| mã | tên |
|---:|---|
| 3501 | `GuildNotExist` |
| 3502 | `GuildIsIn` |
| 3503 | `GuildFull` |
| 3504 | `GuildCdTime` |
| 3505 | `GuildWithoutCheckClosed` |
| 3506 | `GuildPowerLess` |
| 3507 | `GuildAuthLess` |
| 3508 | `GuildListMismatch` |
| 3509 | `GuildManagerFull` |
| 3510 | `GuildClosed` |
| 3511 | `GuildApplyReachMax` |
| 3512 | `GuildDisptachFull` |
| 3513 | `GuildRedisptach` |
| 3514 | `GuildDisptchInfoChange` |
| 3515 | `GuildEmployDouble` |
| 3516 | `GuildNotEnoughGold` |
| 3517 | `GuildNotEnoughTime` |
| 3518 | `GuildTargetIsBeAnnc` |
| 3519 | `GuildNotActivityTime` |
| 3520 | `GuildTimesNotEnough` |
| 3524 | `GuildNameConflict` |
| 3525 | `GuildJoinTimeErr` |
| 3526 | `GuildAngerNotEnough` |
| 3527 | `GuildWarBossLackDiamand` |
| 3528 | `GuildActAnncNotMatter` |
| 3529 | `GuildNotAllowedExit` |
| 3530 | `GuildTypeMismatch` |
| 3531 | `GuildNotApply` |
| 3532 | `GuildExitWithDispatch` |
| 3533 | `GuildDonateCdTime` |
| 3534 | `GuildCantMainRole` |
| 3535 | `GuildNotInGuild` |
| 3536 | `GuildCertificateLimit` |
| 3537 | `GuildWarErrorTarget` |
| 3538 | `GuildWarNoFightData` |
| 3539 | `GuildWarValidGuild` |
| 3540 | `GuildWarDataNeedRefresh` |
| 3541 | `GuildGuildChapterOperNotMatter` |
| 3542 | `GuildChapterNotAchieveNormalChp` |
| 3543 | `GuildChapterNotEnoughResource` |
| 3544 | `GuildChapterNotOpen` |
| 3545 | `GuildChapterLockError` |
| 3546 | `GuildChapterFightTimeLimit` |
| 3547 | `GuildChapterValidCalc` |
| 3548 | `GuildRecurRequest` |
| 3549 | `GuildChapterPrizeCountNotEngough` |
| 3550 | `GuildChapterDispatchTimeErr` |
| 3551 | `GuildChapterNotFightTime` |
| 3552 | `GuildChapterHasBeenFight` |
| 3553 | `GuildTargetNotHeadman` |
| 3554 | `GuildEnoughDiamondForImeach` |
| 3555 | `GuildHeadManIsAlive` |
| 3556 | `GuildWarTargetBeAttack` |
| 3557 | `GuildWarCantSetHeroList` |
| 3558 | `UserNotJoinInGuild` |
| 3559 | `GuildDonateTimesLimit` |
| 3560 | `CanNotDissolveGuild` |
| 3561 | `GuildChapterMaxCount` |
| 3562 | `GuildDonateTimesTotalLimit` |
| 3563 | `ExitCD` |
| 3564 | `KickCD` |
| 3565 | `BetrayCDChapter` |
| 3566 | `BetrayCDDonate` |
| 3567 | `GuildWarFighting` |
| 3568 | `GuildWarFinalStatus` |

</details>

<details><summary><code>ErrorCode.Rank</code> — 1 mã</summary>

| mã | tên |
|---:|---|
| 3601 | `GetRankFailed` |

</details>

<details><summary><code>ErrorCode.Yunbiao</code> — 12 mã</summary>

| mã | tên |
|---:|---|
| 3701 | `HeroMismatch` |
| 3702 | `ArmyMismatch` |
| 3703 | `ArmyLevelMismatch` |
| 3704 | `LeaderShipMismatch` |
| 3705 | `StatusMismatch` |
| 3706 | `AdouQualityMax` |
| 3707 | `MaxEncourageTimes` |
| 3708 | `MaxGrabedTimes` |
| 3709 | `LevelMismatch` |
| 3710 | `TimeMismatch` |
| 3711 | `BeGrabing` |
| 3712 | `MaxGrabTimes` |

</details>

<details><summary><code>ErrorCode.Friend</code> — 14 mã</summary>

| mã | tên |
|---:|---|
| 3086 | `HasSendGiftYet` |
| 3801 | `GetUserRelationFaild` |
| 3802 | `GetUserRelationDataFaild` |
| 3803 | `WrongRelation` |
| 3804 | `NoApply` |
| 3805 | `NotFriend` |
| 3807 | `NoGift` |
| 3808 | `OverRemoveCount` |
| 3809 | `OverMyFriendCount` |
| 3810 | `OverTargetFriendCount` |
| 3811 | `LevelLimit` |
| 3812 | `HasFriend` |
| 3813 | `HasApply` |
| 3814 | `GetFatigueCountLimit` |

</details>

<details><summary><code>ErrorCode.Chat</code> — 5 mã</summary>

| mã | tên |
|---:|---|
| 3901 | `CanNotFindChannel` |
| 3902 | `SpeechNotExists` |
| 3903 | `CantEnterGuildCamp` |
| 3904 | `NoGuildCant` |
| 3905 | `ChatProhibit` |

</details>

<details><summary><code>ErrorCode.QQPay</code> — 2 mã</summary>

| mã | tên |
|---:|---|
| 1004 | `DIAMOND_NOT_ENOUGH` |
| 4301 | `NOT_QQ_CHANNEL` |

</details>

<details><summary><code>ErrorCode.Activity</code> — 10 mã</summary>

| mã | tên |
|---:|---|
| 4001 | `ActivityNotOpen` |
| 4002 | `ConfigError` |
| 4003 | `HasSendActivityPrize` |
| 4004 | `LimitBuyTimes` |
| 4005 | `CommonCountNotEnough` |
| 4006 | `ActivityDataErr` |
| 4007 | `HasGetActivityPrize` |
| 4008 | `NoEnoughRechargeCount` |
| 4009 | `NoEnoughConsumeCount` |
| 4010 | `ExchangeLimitTimes` |

</details>

<details><summary><code>ErrorCode.EndlessChapter</code> — 2 mã</summary>

| mã | tên |
|---:|---|
| 4101 | `NotPass` |
| 4102 | `HasGetFristPrize` |

</details>

<details><summary><code>ErrorCode.HeroPractice</code> — 7 mã</summary>

| mã | tên |
|---:|---|
| 4201 | `NoInTime` |
| 4202 | `NoEnoughLevel` |
| 4203 | `NoEnoughVipLevel` |
| 4204 | `NoEnoughHeroLevel` |
| 4205 | `HeroHasInPractice` |
| 4206 | `AreaHasInPractice` |
| 4207 | `HasMaxPracticeCount` |

</details>

<details><summary><code>ErrorCode.NewHandPrivilege</code> — 3 mã</summary>

| mã | tên |
|---:|---|
| 4301 | `NoPrivilege` |
| 4302 | `NoRewardTimes` |
| 4303 | `TodayCanNotGetReward` |

</details>

<details><summary><code>ErrorCode.ConnectCode</code> — 2 mã</summary>

| mã | tên |
|---:|---|
| 3001 | `Disconnect` |
| 3002 | `Overtime` |

</details>

<details><summary><code>ErrorCode.TournamentCode</code> — 21 mã</summary>

| mã | tên |
|---:|---|
| 4401 | `Closed` |
| 4402 | `Over` |
| 4403 | `SignUpOver` |
| 4404 | `RepeatSignUp` |
| 4405 | `HeroTooLess` |
| 4406 | `SetLineUpFail` |
| 4407 | `LevelTooLow` |
| 4408 | `NotAjustState` |
| 4409 | `NotInQuizStep` |
| 4410 | `AlreadyQuiz` |
| 4411 | `QuziCountError` |
| 4412 | `NoPlayback` |
| 4413 | `GetPrizeConfFail` |
| 4414 | `SendPrizeFail` |
| 4415 | `BenefitFail` |
| 4416 | `NoBattleReport` |
| 4417 | `NoEnoughScore` |
| 4418 | `WelfareDataErr` |
| 4419 | `InvalidData` |
| 4420 | `HaveGotWelfare` |
| 4421 | `TooEarlyToGet` |

</details>

<details><summary><code>ErrorCode.COGCode</code> — 29 mã</summary>

| mã | tên |
|---:|---|
| 4501 | `NotSignUpState` |
| 4502 | `AuthFail` |
| 4503 | `WaitGuildSignUp` |
| 4504 | `CityNotOpen` |
| 4505 | `OccupyCity` |
| 4506 | `NoDismissTeamId` |
| 4507 | `NoDispatchTime` |
| 4508 | `NoDispatchTeamId` |
| 4509 | `NoCityDispatch` |
| 4510 | `NoAttackTargetDispatch` |
| 4511 | `TeamAlreadyInDefend` |
| 4512 | `NoTeamDeployTime` |
| 4513 | `NoGuild` |
| 4514 | `DispatchTeamInvalid` |
| 4515 | `UnlockLevelNotEnough` |
| 4516 | `MissionStateIsCompleted` |
| 4517 | `MissionTypeError` |
| 4518 | `RemainingCompleteTimesNotEnough` |
| 4519 | `CityIsClose` |
| 4520 | `CanNotRepairOthersCity` |
| 4521 | `MissionStateIsNotCompleted` |
| 4522 | `NoCityPlayback` |
| 4523 | `NoPlayerPlayback` |
| 4524 | `ConfigError` |
| 4525 | `TodayHaveGotPrize` |
| 4526 | `NotGetPrizeState` |
| 4527 | `SameSignupCity` |
| 4528 | `NotSignupCity` |
| 4529 | `CanNotAttackOwnCity` |

</details>

<details><summary><code>ErrorCode.Prize</code> — 3 mã</summary>

| mã | tên |
|---:|---|
| 4401 | `GetPrizeFailed` |
| 4402 | `GetPrizeConfFailed` |
| 4403 | `SendPrizeFailed` |

</details>

<details><summary><code>ErrorCode.Adventure</code> — 6 mã</summary>

| mã | tên |
|---:|---|
| 4601 | `NoInTriggerTime` |
| 4602 | `HasTriggerAdventure` |
| 4603 | `NotReachRechargeTarget` |
| 4604 | `GetPrizeFaild` |
| 4605 | `HasNotTriggerAdventure` |
| 4606 | `HasGetPrize` |

</details>

<details><summary><code>ErrorCode.DiceGame</code> — 4 mã</summary>

| mã | tên |
|---:|---|
| 4700 | `NotEnoughPlayTimes` |
| 4701 | `PayTimesLimit` |
| 4702 | `NeedPayDiceGame` |
| 4703 | `NoReward` |

</details>

<details><summary><code>ErrorCode.CloudShop</code> — 3 mã</summary>

| mã | tên |
|---:|---|
| 4750 | `GoodsHasSale` |
| 4751 | `BusinessManHasGone` |
| 4752 | `HeroFragmentNotEnough` |

</details>

<details><summary><code>ErrorCode.WeeklyFun</code> — 2 mã</summary>

| mã | tên |
|---:|---|
| 4801 | `GetDataFailed` |
| 4802 | `GetConfigFailed` |

</details>

<details><summary><code>ErrorCode.LoginReward</code> — 3 mã</summary>

| mã | tên |
|---:|---|
| 4901 | `ActivityIsClose` |
| 4902 | `NoPrizeCanGet` |
| 4903 | `HasGetAllPrize` |

</details>

<details><summary><code>ErrorCode.MagicWeapon</code> — 12 mã</summary>

| mã | tên |
|---:|---|
| 5001 | `DataException` |
| 5002 | `SystemIsClosed` |
| 5003 | `OverLevelLimit` |
| 5004 | `ResourceIsNotEnough` |
| 5005 | `OverExpLimit` |
| 5006 | `NeedToBreakThrough` |
| 5007 | `IllegalItem` |
| 5008 | `CanNotBreakThrough` |
| 5009 | `BreakThroughLevelIsNil` |
| 5010 | `NoBoxKey` |
| 5011 | `HasBoxKey` |
| 5012 | `HeroLevelTooLow` |

</details>

<details><summary><code>ErrorCode.Formation</code> — 7 mã</summary>

| mã | tên |
|---:|---|
| 5101 | `NoThisFormation` |
| 5102 | `NoOpen` |
| 5103 | `NoActived` |
| 5104 | `IsMaxLevel` |
| 5105 | `WrongType` |
| 5106 | `HasActived` |
| 5107 | `NoEnoughLevel` |

</details>

<details><summary><code>ErrorCode.WCSCode</code> — 17 mã</summary>

| mã | tên |
|---:|---|
| 5201 | `Closed` |
| 5203 | `SignUpOver` |
| 5204 | `RepeatSignUp` |
| 5205 | `HeroTooLess` |
| 5206 | `SetLineUpFail` |
| 5207 | `LevelTooLow` |
| 5208 | `NotAjustState` |
| 5209 | `NotInQuizStep` |
| 5210 | `AlreadyQuiz` |
| 5211 | `QuziCountError` |
| 5212 | `NoPlayback` |
| 5213 | `GetPrizeConfFail` |
| 5214 | `SendPrizeFail` |
| 5215 | `BenefitFail` |
| 5216 | `NoBattleReport` |
| 5217 | `NoEnoughScore` |
| 5218 | `NoArriveOpenDay` |

</details>

<details><summary><code>ErrorCode.GodSecret</code> — 1 mã</summary>

| mã | tên |
|---:|---|
| 5301 | `HasExchange` |

</details>

<details><summary><code>ErrorCode.StarSoul</code> — 8 mã</summary>

| mã | tên |
|---:|---|
| 5400 | `Closed` |
| 5401 | `MaxConjureZiwenCount` |
| 5402 | `NoNeedConjure` |
| 5403 | `PackFull` |
| 5404 | `NotEnoughPack` |
| 5405 | `BatchDivineNoGold` |
| 5406 | `NoBatchUpdateItem` |
| 5407 | `ExtraPackFull` |

</details>

<details><summary><code>ErrorCode.ScoreCompetitive</code> — 8 mã</summary>

| mã | tên |
|---:|---|
| 5500 | `Closed` |
| 5501 | `Challenged` |
| 5502 | `Rewarded` |
| 5503 | `RewardNotAble` |
| 5504 | `MaxRevenge` |
| 5505 | `NotMatch` |
| 5507 | `NotSameMatch` |
| 5508 | `RankCanNotRevenge` |

</details>

<details><summary><code>ErrorCode.Pet</code> — 20 mã</summary>

| mã | tên |
|---:|---|
| 5600 | `Rewarded` |
| 5601 | `NotEnoughDays` |
| 5602 | `LockLevel` |
| 5603 | `NotEnoughIntimacy` |
| 5604 | `IntelligenceFull` |
| 5605 | `NoCatchCount` |
| 5606 | `NoQueue` |
| 5607 | `FishNotGrow` |
| 5608 | `NoCollectTime` |
| 5609 | `FightPetPossess` |
| 5610 | `FishGrowUp` |
| 5611 | `MaxFishHelp` |
| 5612 | `MaxPetHelp` |
| 5613 | `MaxFishSpeed` |
| 5614 | `MaxPetSpeed` |
| 5615 | `MaxPetLevel` |
| 5616 | `EmptyPet` |
| 5617 | `EmptyFish` |
| 5618 | `PetSpeeding` |
| 5619 | `ClassLimit` |

</details>

<details><summary><code>ErrorCode.RedPack</code> — 3 mã</summary>

| mã | tên |
|---:|---|
| 5650 | `CountLimit` |
| 5651 | `ScoreLimit` |
| 5652 | `HasGot` |

</details>

<details><summary><code>ErrorCode.GuildRedPack</code> — 1 mã</summary>

| mã | tên |
|---:|---|
| 5670 | `CountLimit` |

</details>

<details><summary><code>ErrorCode.Pk</code> — 9 mã</summary>

| mã | tên |
|---:|---|
| 6700 | `PkNotOpen` |
| 6701 | `PkSignClosed` |
| 6702 | `PkSignFailed` |
| 6703 | `PkSignLevelNotEnough` |
| 6704 | `PkSignDataError` |
| 6705 | `PkGambleClosed` |
| 6706 | `PkGambleRepeated` |
| 6707 | `PkSaveLineFailed` |
| 6708 | `PkNotActiveUser` |

</details>

<details><summary><code>ErrorCode.StateWar</code> — 10 mã</summary>

| mã | tên |
|---:|---|
| 6710 | `Moving` |
| 6711 | `TargetCitySame` |
| 6712 | `MoveFinished` |
| 6713 | `NotEnoughAttackTimes` |
| 6714 | `EnemyNotInCity` |
| 6715 | `FactionMisMatch` |
| 6716 | `InProtectTime` |
| 6717 | `SelfNotInCity` |
| 6718 | `NotEnoughDefendTimes` |
| 6719 | `NotEnoughDailyBuyAttackTimes` |

</details>

<details><summary><code>ErrorCode.System</code> — 6 mã</summary>

| mã | tên |
|---:|---|
| 1 | `RequestTimeout` |
| 2 | `NetworkShutsDown` |
| 3 | `DataOutSync` |
| 4 | `ParamError` |
| 5 | `GetTableFaild` |
| 6 | `GetConfigFaild` |

</details>

<details><summary><code>ErrorCode.Item</code> — 4 mã</summary>

| mã | tên |
|---:|---|
| 1201 | `NotEnoughItem` |
| 1202 | `ReduceItemError` |
| 1203 | `GetItemConfigFail` |
| 1204 | `UseItemFail` |

</details>

<details><summary><code>ErrorCode.Potion</code> — 2 mã</summary>

| mã | tên |
|---:|---|
| 1501 | `ReducePotionFail` |
| 1502 | `SetPotionExpeditionFail` |

</details>

<details><summary><code>ErrorCode.Character</code> — 1 mã</summary>

| mã | tên |
|---:|---|
| 1601 | `AddUserExFail` |

</details>

<details><summary><code>ErrorCode.Resource</code> — 4 mã</summary>

| mã | tên |
|---:|---|
| 1701 | `AddResourceFail` |
| 1702 | `NoEnoughResource` |
| 1703 | `ReduceResourceFail` |
| 1704 | `GetResourceFail` |

</details>

<details><summary><code>ErrorCode.(gốc)</code> — 3 mã</summary>

| mã | tên |
|---:|---|
| 0 | `OK` |
| 1 | `UnknowError` |
| 2 | `ArgError` |

</details>

## 6. Lời gọi có tên hàm dựng động

Những chỗ này `funcName` là biến, phải đọc tay để biết tập tên đầy đủ.

| Biểu thức | Module | Hàm client | Nguồn |
|---|---|---|---|
| `strFunction` | nModule | `CUIRPCManager:CallServer` | `sc/user/Logical/CUIRPCManager.lua:154` |
| `reqName` | GAME_LOGIC | `CUIAssist._addRpcFunc` | `sc/user/UI/CUIAssist.lua:347` |

## 7. Luật chơi dùng chung với server (`sc/share/`)

138 file logic client và server dùng chung — đây là phần quy tắc nghiệp vụ server phải tái hiện. Cột *hằng số* đếm các hằng số cấu hình khai báo trong `ctor`.

| File | dòng | hằng số | mô tả đầu file |
|---|---:|---:|---|
| `sc/share/AchieveCheckLogic.lua` | 1121 | 0 | 检测角色等级 |
| `sc/share/AchieveGuideCheckLogic.lua` | 271 | 0 | 检测新手引导 |
| `sc/share/AchieveLogic.lua` | 1777 | 12 | sunyutao |
| `sc/share/Activities/ActivityGodHeroLogic.lua` | 157 | 1 | [[ |
| `sc/share/Activities/Anniversary.lua` | 66 | 1 |  |
| `sc/share/Activities/ContinuousRechargeLogic.lua` | 203 | 0 | [[ |
| `sc/share/Activities/FundLogic.lua` | 162 | 0 | [[ |
| `sc/share/Activities/GodSecret.lua` | 243 | 5 | [[ |
| `sc/share/Activities/LevelCapacityLogic.lua` | 9 | 0 | 获得活动剩余时间 |
| `sc/share/Activities/MonthlyCardLogic.lua` | 272 | 1 | G_UserDataManager:GetUserGlobalData("FirstEnterGameTime") |
| `sc/share/Activities/RechargeSignLogic.lua` | 239 | 2 | 配置拉新最短时间 |
| `sc/share/AdventureLogic.lua` | 181 | 1 | [[ |
| `sc/share/ArenaDataManager.lua` | 664 | 0 |  |
| `sc/share/ArenaLogic.lua` | 688 | 8 |  |
| `sc/share/ArmyDataManager.lua` | 457 | 0 | self.bIsInited = false |
| `sc/share/ArmyLogic.lua` | 793 | 2 | sunyutao |
| `sc/share/COGDef.lua` | 205 | 0 | 攻城战定义 |
| `sc/share/CavernDataManager.lua` | 871 | 0 |  |
| `sc/share/CavernLogic.lua` | 873 | 7 |  |
| `sc/share/CharacterLogic.lua` | 8 | 0 |  |
| `sc/share/CommonLogic.lua` | 125 | 0 | ÒÔÏÂÊÇÐèÒª¿ç·þ¹²ÏíµÄÂß¼­·½·¨ |
| `sc/share/Container.lua` | 68 | 1 | [[ |
| `sc/share/DestinyLogic.lua` | 527 | 1 | [[ |
| `sc/share/EndlessChapterLogic.lua` | 557 | 7 | [[ |
| `sc/share/EventManager.lua` | 1206 | 0 | Created by IntelliJ IDEA. |
| `sc/share/EventManagerBase.lua` | 234 | 0 | [[ |
| `sc/share/EventManagerDefine.lua` | 108 | 0 | [[ |
| `sc/share/EventManagerTest.lua` | 60 | 0 | Date:		2014-05-27 |
| `sc/share/FightLogic.lua` | 1024 | 0 | 获取全部英雄战斗属性 |
| `sc/share/FormationLogic.lua` | 526 | 0 | 阵法逻辑，公共 |
| `sc/share/FortuneWheelLogic.lua` | 945 | 3 |  |
| `sc/share/GuildLogic.lua` | 173 | 1 |  |
| `sc/share/GuildStoreLogic.lua` | 290 | 2 |  |
| `sc/share/HeroBondLogic.lua` | 298 | 0 | 英雄羁绊 |
| `sc/share/HeroCapacityLogic.lua` | 490 | 0 | [[ |
| `sc/share/HeroLogicStatic.lua` | 101 | 0 | sunyutao |
| `sc/share/HeroPracticeLogic.lua` | 428 | 6 | 修炼时间 |
| `sc/share/HeroSkinLogic.lua` | 633 | 0 |  |
| `sc/share/KDebug.lua` | 829 | 0 | Date:		2014-05-21 |
| `sc/share/Login.lua` | 4 | 0 |  |
| `sc/share/LoginRequire.lua` | 4 | 0 |  |
| `sc/share/LoginRewardDef.lua` | 17 | 0 | 状态 |
| `sc/share/LoginTest.lua` | 1 | 0 |  |
| `sc/share/LotteryLogic.lua` | 1043 | 0 | [[ |
| `sc/share/LotteryLogicDataManager.lua` | 490 | 0 | [[ |
| `sc/share/LotteryLogicTest.lua` | 20 | 0 | G_LotteryLogic:runFreeLottery() |
| `sc/share/MagicWeaponDef.lua` | 22 | 0 |  |
| `sc/share/MagicWeaponTreasureBox.lua` | 211 | 3 | 神兵宝箱 |
| `sc/share/MailLogic.lua` | 921 | 0 | [[ |
| `sc/share/MailLogicDataManager.lua` | 46 | 0 | [[ |
| `sc/share/MailLogicTest.lua` | 1 | 0 |  |
| `sc/share/MysteriousStoreLogic.lua` | 540 | 2 |  |
| `sc/share/NewGuildWarDef.lua` | 13 | 0 | 新军团战定义 |
| `sc/share/Pet/share_PetConfigManager.lua` | 1 | 0 |  |
| `sc/share/Pet/share_PetDataManager.lua` | 225 | 0 | [[ |
| `sc/share/Pet/share_PetLogic.lua` | 228 | 32 | 等级是否可以超过玩家等级？ |
| `sc/share/Pk/PkDef.lua` | 99 | 0 | PK系统定义 煮酒论英雄 |
| `sc/share/PotionDataManager.lua` | 853 | 0 | sunyutao |
| `sc/share/PotionLogic.lua` | 615 | 1 | sunyutao |
| `sc/share/PrizeLogic.lua` | 173 | 0 |  |
| `sc/share/Protocol.lua` | 1004 | 0 | 服务器类型序号 |
| `sc/share/ResourceDataManager.lua` | 149 | 0 | [[ |
| `sc/share/SBConfig.lua` | 158 | 0 |  |
| `sc/share/ScoreCompetitivePlay/share_ScoreCompetitivePlayConfig.lua` | 6 | 0 | [[ |
| `sc/share/ScoreCompetitivePlay/share_ScoreCompetitivePlayDataMgr.lua` | 1 | 0 |  |
| `sc/share/ScoreCompetitivePlay/share_ScoreCompetitivePlayLogic.lua` | 377 | 13 |  |
| `sc/share/ScoreStroeLogic.lua` | 636 | 6 |  |
| `sc/share/Setting.lua` | 51 | 0 | 屏蔽支付 |
| `sc/share/ShareTournamentLogic.lua` | 20 | 0 | 获取武道会积分 |
| `sc/share/ShopLogic.lua` | 401 | 0 | [[ |
| `sc/share/ShopLogicDataManager.lua` | 119 | 0 | [[ |
| `sc/share/ShopLogicTest.lua` | 17 | 0 |  |
| `sc/share/SignInLogic.lua` | 6 | 0 |  |
| `sc/share/SkillLogic.lua` | 736 | 0 | 提升上阵英雄攻击力百分比 |
| `sc/share/StarSoul/share_StarSoulConfig.lua` | 6 | 0 | [[ |
| `sc/share/StarSoul/share_StarSoulDataManager.lua` | 416 | 2 | [[ |
| `sc/share/StarSoul/share_StarSoulLogic.lua` | 240 | 19 |  |
| `sc/share/Statistics.lua` | 655 | 0 | [[function Statistics:ctor() |
| `sc/share/TimeHeroDataManager.lua` | 84 | 0 | [[ |
| `sc/share/TimeHeroLogic.lua` | 339 | 0 | [[ |
| `sc/share/TournamentDef.lua` | 307 | 0 | 一些通用的定义,晚点改造一部分到配置表让策划配置 |
| `sc/share/UserDataManager.lua` | 233 | 0 | Created by IntelliJ IDEA. |
| `sc/share/UserLogic.lua` | 3408 | 3 | [[ |
| `sc/share/UserLogicDataManager.lua` | 678 | 0 | Created by IntelliJ IDEA. |
| `sc/share/UserLogicTest.lua` | 1 | 0 |  |
| `sc/share/WCSDef.lua` | 222 | 0 | 跨服武道会定义 |
| `sc/share/WeeklyFunDef.lua` | 62 | 0 | 七天乐活动类型 |
| `sc/share/class.lua` | 176 | 0 | [[ |
| `sc/share/error.lua` | 903 | 0 | system |
| `sc/share/jsonfile.lua` | 53 | 0 | [[ |
| `sc/share/public.lua` | 692 | 0 | 日志等级枚举 |
| `sc/share/share_CDataManager.lua` | 572 | 0 | 通过数据标示获取数据 |
| `sc/share/share_CDataManagerPrivate.lua` | 1182 | 0 | 数据接口geter\seter |
| `sc/share/share_CDataManagerUpdateConfig.lua` | 293 | 0 | 初始化兵种信息 |
| `sc/share/share_ChapterDataManager.lua` | 344 | 0 | [[ |
| `sc/share/share_ChapterLogic.lua` | 5964 | 0 | [[ |
| `sc/share/share_ChapterLogicTest.lua` | 162 | 0 | 临时测试 |
| `sc/share/share_CharacterNameLogic.lua` | 238 | 0 | [[ |
| `sc/share/share_ClothingDataManager.lua` | 100 | 0 | [[ |
| `sc/share/share_ClothingLogic.lua` | 835 | 9 | [[ |
| `sc/share/share_CloudShopDataManager.lua` | 14 | 0 |  |
| `sc/share/share_EquipmentDataManager.lua` | 462 | 0 | 装备数据中心 |
| `sc/share/share_EquipmentLogic.lua` | 1638 | 5 |  |
| `sc/share/share_EquipmentLogicTest.lua` | 142 | 0 | [[ |
| `sc/share/share_EquipmentPropertyLogic.lua` | 640 | 0 | sunyutao |
| `sc/share/share_GuildChapterLogic.lua` | 47 | 2 |  |
| `sc/share/share_GuildLogic.lua` | 47 | 0 | 公会数据中心 |
| `sc/share/share_HeroDataManager.lua` | 1094 | 0 | [[type GameUserHero struct { |
| `sc/share/share_HeroLogic.lua` | 3783 | 3 | [[ |
| `sc/share/share_ItemDataManager.lua` | 340 | 0 | 物品数据中心 |
| `sc/share/share_ItemLogic.lua` | 1088 | 0 | [[ |
| `sc/share/share_MidasTouchDataManager.lua` | 80 | 0 | 点金手数据中心 |
| `sc/share/share_MidasTouchLogic.lua` | 329 | 0 | [[ |
| `sc/share/share_RechargeDataManager.lua` | 84 | 0 | [[ |
| `sc/share/share_RechargeLogic.lua` | 763 | 0 | [[ |
| `sc/share/share_RechargeLogicTest.lua` | 63 | 0 | 临时测试 |
| `sc/share/share_SevenDaysGiftDataManager.lua` | 81 | 0 | 七日奖励数据中心 |
| `sc/share/share_SevenDaysGiftLogic.lua` | 323 | 0 | [[ |
| `sc/share/share_TestLua.lua` | 2 | 0 |  |
| `sc/share/share_UserInfoDataManager.lua` | 11 | 0 |  |
| `sc/share/share_achievement.lua` | 147 | 0 | 成就状态 |
| `sc/share/share_arena_request.lua` | 13 | 0 | require("share.StarSoul.share_StarSoulConfig") |
| `sc/share/share_building.lua` | 413 | 0 | building逻辑模块提供业务逻辑接口 |
| `sc/share/share_configManager.lua` | 4822 | 0 | 配置管理器 |
| `sc/share/share_dailyTask.lua` | 92 | 0 |  |
| `sc/share/share_gameLogic_require.lua` | 169 | 0 |  |
| `sc/share/share_gameWorld.lua` | 180 | 1 |  |
| `sc/share/share_goods.lua` | 133 | 0 | [[ |
| `sc/share/share_magicWeapon.lua` | 698 | 0 | fengwenbin@kingsoft.com |
| `sc/share/share_math.lua` | 50 | 0 | function RoundUp(num) |
| `sc/share/share_potion.lua` | 260 | 0 | [====[ |
| `sc/share/share_prize.lua` | 34 | 0 | [[CPrizeLogic = class() |
| `sc/share/share_property.lua` | 3 | 0 |  |
| `sc/share/share_public_require.lua` | 34 | 0 | 所有服务端都需要的客户端公共脚本 |
| `sc/share/share_warehouse.lua` | 55 | 0 | [====[ |
| `sc/share/share_weeklyFun.lua` | 265 | 0 | fengwenbin@kingsoft.com |
| `sc/share/shrae_channel.lua` | 15 | 2 | 为了兼容建造队列，使用建造队列填数据充UpgradeAbleObject结构的相关升级信息 |
| `sc/share/shrae_commonLogic.lua` | 23 | 0 | 根据剩余时间 |
