# Bản đồ hệ thống của bản gốc

Tài liệu này tồn tại để **không phải lần ngược vào 973 file Lua mỗi lần làm một
tính năng**. Đọc một lần, ghi lại, rồi viết game mới dựa trên nó.

Nguồn: `vn/decrypted/assets/sc/` — **139 module luật, 64 507 dòng**, còn nguyên
comment tiếng Trung của tác giả. Đây là mã nguồn thật, không phải suy đoán.

Sinh lại bảng tra:

```bash
python systems.py                    # bảng tóm tắt mọi module
python systems.py --detail Arena     # đổ chi tiết một hệ thống
python systems.py --json out.json    # bản máy đọc được
```

## Quyết định nền: giữ nguyên luật và thang số của bản gốc

Game mới **dùng lại công thức và con số** của bản gốc, không tự cân bằng lại.
Lý do: đó là thang số đã qua người chơi thật nhiều năm, và repo `bravecross-game`
đã đi theo hướng này từ đầu (`AddGrowthFactor`, hệ thế trận giữ nguyên số liệu).

## 139 module chia theo mảng

| Mảng | Module | Dòng | Nội dung chính |
|---|---:|---:|---|
| Nền tảng | 25 | 13 448 | `class`, `EventManager`, `CDataManager`, `configManager`, `Protocol`, `error` |
| Màn chơi | 22 | 12 653 | chương, hang động, vô tận, bang hội, đấu trường, giải đấu |
| Nhân vật | 23 | 10 399 | tướng, tinh hồn, trang phục, thú cưng, thiên mệnh, tu luyện |
| Người chơi | 23 | 10 125 | tài khoản, thành tựu, nhiệm vụ ngày, điểm danh, thư, thống kê |
| Vật phẩm | 17 | 7 427 | trang bị, đan dược, pháp bảo, kho, thuộc tính |
| Kinh tế | 16 | 5 350 | cửa hàng, gacha, nạp thẻ, vòng quay, cổ phiếu |
| Chiến đấu | 7 | 3 800 | `FightLogic`, `SkillLogic`, `ArmyLogic`, `FormationLogic` |

Năm module lớn nhất, đọc trước nếu cần hiểu sâu:

```
share_ChapterLogic.lua      5964 dòng    luật chương, mở khoá, thưởng
share_configManager.lua     5064 dòng    nạp và tra mọi bảng số liệu
share_HeroLogic.lua         3788 dòng    chỉ số tướng, cấp, phẩm, sao
UserLogic.lua               3408 dòng    dữ liệu người chơi, cấp, EXP
AchieveLogic.lua            1777 dòng    thành tựu, nhiệm vụ ngày, 7 ngày
```

## Hằng số cân bằng nằm ngay trong `ctor`

126 hằng số rải trong 139 module, khai báo thẳng dạng `self.X = <số>` kèm
comment. Đây là **luật chơi thật**, không phải cấu hình ngoài:

```lua
-- Pet/share_PetLogic.lua
MaxPetLevel            = 80    -- cấp thú cưng
MaxFishBeSpeededCount  = 2     -- số lần được tăng tốc nuôi cá
MaxPetHelpCount        = 5     -- số lần chủ động giúp người khác

-- StarSoul/share_StarSoulLogic.lua
CONJURE_ZIWEN_PRICE      = 50  -- giá triệu hồi
MAX_CONJURE_ZIWEN_COUNT  = 20  -- lượt thường
VIP_EXTRA_ZIWEN_COUNT    = 20  -- VIP 14+ được thêm
MAX_STAR_SOUL_QUALITY    = 7

-- EndlessChapterLogic.lua
FreeChallengesCount = 2    MaxChallengesCount = 7
PayChallengesCost   = 50   MaxInspireCount    = 3
```

`python systems.py --detail <tên>` in đủ hằng số + hàm + RPC của một hệ thống.

## Game mới đang ở đâu

`bravecross-game` hiện có **10 RPC** trên 614 của bản gốc:

```
bx.chapters   bx.fight      bx.set_roster   bx.level_up
bx.formations bx.set_formation bx.upgrade_formation bx.set_placement
bx.selftest   bx.fieldtest
```

Tức đã xong **vòng lặp lõi**: chọn chương → dàn trận → đánh → lên cấp → thế trận.
Ba bản cài đặt của mô hình chiến đấu (Python, GDScript, Lua) đối chiếu nhau
từng trận.

Khoảng trống lớn nhất, theo thứ tự nên làm:

1. **Trang bị** — `share_EquipmentLogic` (1638 dòng) + `share_EquipmentPropertyLogic`
   (640). Sức mạnh tướng hiện chỉ đến từ cấp; thiếu hẳn một trục nuôi.
2. **Vật phẩm và kho** — `share_ItemLogic` (1088), `share_warehouse`. Là nền cho
   mọi thứ rơi ra từ trận.
3. **Thành tựu và nhiệm vụ ngày** — `AchieveLogic` (1777) + `AchieveCheckLogic`
   (1121). Đây là thứ giữ người chơi quay lại, và luật kiểm đã viết sẵn.
4. **Gacha** — `LotteryLogic` (1043). Tỉ lệ đã có trong `KDBGameLotteryConfig`
   và **giống hệt giữa hai bản**, không cần cân lại.
5. **Cửa hàng** — `ShopLogic`, `MysteriousStoreLogic`, `ScoreStroeLogic`.

## Kiến trúc cần biết trước khi viết

**Node UI là biến toàn cục.** Engine nạp `.xgg` xong thì bơm mọi node vào `_G`
theo tên instance — `CUIPublic:GetRootUI()` chỉ làm `_G[self.RootUIName]`. Nhờ
vậy Lua gọi thẳng `g_btnAutoCombat:setVisible(...)`. Bên Godot, `XggLayout` gắn
bảng tên tương đương lên node gốc.

**Ảnh gán lúc chạy, không lưu sẵn.** `node:setDisplayFrame(spriteFrameByName(tên))`
— 573 chỗ gọi, tên thường tính tại chỗ (`"battle_medicine0"..i..".png"`). Không
có bảng tĩnh node→ảnh để trích. `UiFrames.set_frame()` dựng lại đúng cơ chế đó.

**Một màn hình = một lớp `CUIPublic` + một hoặc vài `.xgg`.** Mỗi lớp khai
`ResourceXggList` và `RootUIName`, rồi tìm node qua tên. Muốn port một màn thì
đọc đúng lớp đó, không phải cả cây.

**HUD chứa nhiều trạng thái chồng nhau.** `Game_UI_Control_Panel` có 20 lớp:
`lUITopLayer` (HUD trong trận) có 13 con, mỗi con một chế độ chơi
(`lUINormal`, `lUIEndless`, `lUIArena`, `lUIJFZY`…), tất cả ẩn sẵn và Lua bật
đúng một cái. Bật hết cùng lúc thì màn hình thành một đống chồng chéo.

**Client và server dùng chung luật.** `sc/share/` được cả hai nạp. Đó là lý do
`server/modules/battle.lua` bên game mới tái hiện được nguyên mô hình chiến đấu.

## Trang bị — đã đọc, đủ để hiện thực

Nguồn: `share_EquipmentLogic.lua` (1638 dòng), `share_EquipmentPropertyLogic.lua`
(640), `share_EquipmentDataManager.lua` (462). Bảng số: `KDBGameEquipmentSynthesisConfig`
(250 bản ghi), `KDBGameNormalEquipRefineConfig` (275), `KDBGameScrollSynthesisConfig` (30).

### Một món trang bị gồm

```
HeroID, EquipPartID          6 ô: vũ khí, giáp, dây chuyền, nhẫn, giày, ô phụ
Level                        cấp món đồ
IntensifyLevel               cấp cường hoá
Quality                      phẩm chất
RefineLevel                  cấp tinh luyện
MainProperty  {PropertyType, Value}
IntensifyProperty {PropertyType, Value}
AppendProperty[]             thuộc tính phụ, ngẫu nhiên
```

### Bốn trục nuôi, bốn công thức

**1. Cường hoá** — mỗi cấp nhân thêm `2.4^(1/200)` ≈ 1,004385; qua 200 cấp thì
gấp 2,4 lần:

```
increment(level, Val) = (Val / 25) * (2.4^(1/200))^level
```

Giá trị cộng thêm phụ thuộc LOẠI chỉ số, mỗi loại một mẫu số và một mốc riêng:

```
Ap        : main/35 * (2.4^(1/200))^10
HpLimit   : main/25 * (2.4^(1/200))^50
DpAddtion : main/30 * (2.4^(1/200))^50
```

**2. Chi phí cường hoá** — nhân đôi mỗi 4,5 cấp lúc đầu, giãn ra 6,5 cấp sau
cấp 31:

```
level-1 > 30 :  140 * (2^(1/6.5))^(level-1)
ngược lại    :   25 * (2^(1/4.5))^(level-1)
```

**3. Phẩm chất** — dải giá trị theo phẩm:

```
range(baseVal, coefficient, quality) = (baseVal/coefficient + 0.3) / quality
```

**4. Thuộc tính phụ** — mở từ **cấp 4**, giá trị ngẫu nhiên trong dải
**0,8–1,3** lần gốc. Tẩy lại (洗练) tốn **đá tẩy luyện, vật phẩm id 97**.

### Lực chiến của một món

```
capacity =   MainProperty.Value      * W[MainProperty.PropertyType]
           + intensifyPropertyVal    * W[MainProperty.PropertyType]
           + tổng đóng góp của AppendProperty
```

`W` là bảng trọng số theo loại chỉ số, ở `share_configManager.lua:3221`:

| Chỉ số | Trọng số |
|---|---:|
| `HpLimit` | 0.1 |
| `Ap` | 0.9 |
| `DpAddtion` | 1 |
| `FireResistence` / `IceResistence` / `ThunderResistence` | 18 |
| `CriticalStrike` | 50 |

Trọng số nói lên thang của từng chỉ số: 1 điểm chí mạng đáng 50 điểm lực chiến,
còn 1 điểm máu chỉ đáng 0,1 — tức máu đi theo hàng nghìn còn chí mạng theo phần
trăm.

### RPC liên quan bên bản gốc

`ClientIntensifyEquipment`, `ClientAutoIntensifyEquipment`, `ClientRecastEquipment`,
`ClientPromoteQualityEquipment`, `ClientSynthesisEquipment`,
`ClientAutoIntensifyEquipment` — tra đầy đủ trong `server-spec-vn/SERVER_API.md`.

### Đã hiện thực bên game mới

Ba bản đối chiếu nhau từng ca, y như cách mô hình chiến đấu đang được kiểm:

```
bravecross-game/sim/equipment.py               mô hình gốc + 168 ca đối chiếu
bravecross-game/server/modules/equipment.lua   bản máy chủ (module luật thuần)
bravecross-game/battle/equipment.gd            bản client
```

**Một phát hiện khi đọc**: `GetIntensifiedIncrementWithLevel` — hàm duy nhất
dùng **cấp** cường hoá — chỉ được gọi từ `GetIntensifiedIncrement`, mà hàm đó
**bị comment toàn bộ** trong bản phát hành. Tức ở client bản gốc, cường hoá
**không** làm đổi lực chiến hiển thị; đường tăng thật nằm bên máy chủ họ, thứ
ta không có. Nên bản mới giữ cả hai đường và ghi rõ: `capacity()` theo công
thức gốc của tác giả, `capacity_as_original()` đúng ý bản phát hành.

Đã nối suốt dây: bản lưu giữ `equipment` (tên tướng → tối đa 6 món), hai RPC
`bx.equipment` và `bx.intensify` (máy chủ tính giá và trừ vàng), và trang bị
**đổi kết quả trận thật** — đối chiếu từng trận giữa cả ba bản.

Trang bị đi đúng kênh buff mà thế trận đang dùng, gộp chung một bảng rồi áp
một lần, nên thứ tự áp dụng không thể làm ba bản lệch nhau.

Chỗ còn tạm: **nguồn ra trang bị**. Bản gốc lấy từ rơi đồ, ghép đồ, cửa hàng,
kho — chưa hệ nào trong số đó tồn tại bên game mới, nên tạm thời món đồ rơi
thẳng từ trận ra (35% khi thắng) và gắn luôn vào tướng, món mạnh hơn thì giữ.
Khi có hệ vật phẩm và kho thì thay chỗ đó, không phải thay công thức.

### Tinh luyện — đã đọc, đã hiện thực

Nguồn: `share_EquipmentPropertyLogic:getMainPropertyVal`, bảng
`KDBGameCommonConfig` mục `ConfigName = "EquipRefineConfig"`,
`HeroLogic:GetUpgradeRefineCost`, `CUIEquipment_Refine.lua`.

Tinh luyện **cộng phần trăm vào chỉ số chính**, không cộng thẳng một lượng:

```
val = val + val * AddPrecent / 100
```

Bảng đầy đủ (5 ô × 5 bậc), lấy nguyên từ `EquipRefineConfig`:

| Bậc | Cộng | Tinh hoa (vũ khí) | Tinh hoa (ô khác) |
|---:|---:|---:|---:|
| 1 | +5% | 40 | 30 |
| 2 | +10% | 80 | 60 |
| 3 | +15% | 160 | 120 |
| 4 | +20% | 320 | 240 |
| 5 | +25% | 640 | 480 |

Giá nhân đôi mỗi bậc, vũ khí đắt hơn các ô khác đúng một bậc. **VIP 10 trở lên
được giảm 20%**, làm tròn lên (`GetUpgradeRefineCost`).

Tiền tệ là **tinh hoa** (`Concentrate`, `ResourceType = 8`) — một tài nguyên
riêng, không phải vàng. Bản gốc cho tinh hoa từ việc **phân giải vật phẩm**
(RPC `ClientRefineItem`; mỗi vật phẩm một giá trị `Concentrate` trong bảng đồ).
RPC tinh luyện là `ClientRefineEquip`.

Vì tinh luyện nhân vào chỉ số chính **ngay trong `getMainPropertyVal`**, mọi
thứ tính sau đó — kể cả cường hoá — đều dựa trên con số đã nhân. Hai trục nhân
nhau chứ không cộng rời.

Bên game mới: đã có đủ ba bản (`sim/equipment.py`, `server/modules/equipment.lua`,
`battle/equipment.gd`), RPC `bx.refine`, và tab tinh luyện dùng đúng khối bố cục
`lEquipmentRefineUI` của bản gốc. Nguồn tinh hoa tạm thời: **món đồ thừa bị
phân giải** — đúng ý bản gốc, và vừa khớp chỗ trống trong vòng lặp hiện có.

### Chưa đọc trong mảng này

Luật ghép đồ (`SynthesisEquipment`) và trang bị chuyên thuộc (`ExclusiveEquip`).

**Đính chính**: bảng `KDBGameNormalEquipRefineConfig` (275 bản ghi) trước đây
ghi ở đây là bảng tinh luyện — **sai**. Nó khoá theo `(HeroJob, EquipPart,
StarLevel)` và chỉ có `SBDataManager` dùng, tức thuộc hệ **thần binh** (神兵),
không phải hệ tinh luyện trang bị.

## Còn chưa đọc

Tài liệu này mới là **bản đồ**, chưa phải đặc tả từng hệ thống. Cần đọc sâu
tiếp, theo thứ tự ưu tiên ở trên, và mỗi lần đọc thì bổ sung một mục vào đây —
công thức, thang số, và các RPC liên quan.
