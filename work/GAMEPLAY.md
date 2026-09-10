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

`bravecross-game` hiện có **23 RPC** trên 614 của bản gốc:

```
bx.chapters   bx.fight      bx.set_roster   bx.level_up
bx.formations bx.set_formation bx.upgrade_formation bx.set_placement
bx.equipment  bx.intensify  bx.refine       bx.synthesize
bx.forge_exclusive bx.recast bx.promote_quality
bx.items      bx.sell_item  bx.dismantle_item
bx.tasks      bx.claim_task bx.claim_liveness
bx.selftest   bx.fieldtest
```

Tức đã xong **vòng lặp lõi**: chọn chương → dàn trận → đánh → lên cấp → thế trận.
Ba bản cài đặt của mô hình chiến đấu (Python, GDScript, Lua) đối chiếu nhau
từng trận.

Khoảng trống lớn nhất, theo thứ tự nên làm:

1. ~~**Trang bị**~~ — xong, xem mục "Trang bị" bên dưới.
2. ~~**Vật phẩm và kho**~~ — xong, xem mục "Vật phẩm và kho".
3. ~~**Thành tựu và nhiệm vụ ngày**~~ — xong phần đo được, xem mục "Thành tựu
   và nhiệm vụ ngày".
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

### Chỉ số chính — công thức thật, đã đọc

Đây là thứ quan trọng nhất trong cả mảng, và trước đây chưa đọc:
`share_EquipmentPropertyLogic:getMainPropertyValWithCoefficient`.

```
Ap        : 20 * (L + 10 + Q*6)^1.45 / (60 - J*6)
HpLimit   : 30 * (L + 10 + Q*5)^1.5  / (20 + J*10)
DpAddtion : 5  * (L + 10 + Q*6)^1.45 / (20 + J*8)
```

- `Q` phẩm chất, `J` hệ số nghề (Warrior 1 → Archer 5)
- `L` **không phải cấp món đồ** mà là hệ số cấp: `getEquipLevelCoefficient` trả
  về đúng cột `HeroLevel` của bảng ghép đồ. Tức **bảng ghép đồ vừa là bảng giá,
  vừa là thang sức mạnh**.

`EquipmentType = LOẠI Ô × 10 + NGHỀ` (`Protocol.lua:322`): vũ khí 1–5, giáp
21–25, giày 31–35, dây chuyền 41–45, nhẫn 51–55. Ô nào cho chỉ số gì:
vũ khí → Ap, giáp → DpAddtion, giày/dây chuyền → HpLimit, nhẫn → DpAddtion.

Hệ số chỉ số: `HpLimit 30`, `DpAddtion 5`, `Ap 20`, `CriticalStrike 0.0025`.

**Chí mạng không có nhánh nào** trong hàm gốc — nhánh thứ tư là bản sao của
`DpAddtion`, rõ ràng là lỗi gõ. Nên ngựa/cánh không sinh được chỉ số chính.
Khớp với chuyện bảng cường hoá cũng chỉ có ba loại đó.

### Ghép đồ — đã đọc, đã hiện thực

`share_EquipmentLogic:SynthesisEquipment` — ghép đồ là **nâng cấp món đồ lên
một cấp**: trừ vàng, trừ nguyên liệu, rồi `EquipLevel + 1`. Vì hệ số cấp chính
là cột `HeroLevel`, lên một cấp là **mạnh lên thật**, không chỉ đổi icon.

Bảng `KDBGameEquipmentSynthesisConfig`: 25 loại × 10 cấp = 250 bản ghi, mỗi
bản ghi có `HeroLevel`, `GoldCost`, và tối đa 5 cặp `(MaterialID, Count)`.
Vũ khí chiến binh chẳng hạn:

| Cấp | Cần tướng cấp | Vàng | Nguyên liệu |
|---:|---:|---:|---|
| 2 | 10 | 110 | 24×1, 51×2 |
| 3 | 20 | 3 700 | 25×3, 52×5 |
| 5 | 40 | 32 000 | 27×6, 54×14 |
| 10 | 90 | 10 000 000 | 32×120, 59×680, 82×100 |

**Một lỗi trong bản gốc**: điều kiện cấp tướng có đọc nhưng **không bao giờ
chạy** — nó viết `if HeroLevel < need then if ProcessError(bRecode) ... end end`,
mà `bRecode` lúc đó đang `true` nên thân lệnh câm. Bên game mới **có chặn**:
một điều kiện nằm trong bảng mà không ai kiểm thì bảng đó vô nghĩa.

Bên game mới: đủ ba bản, RPC `bx.synthesize`, và tab ghép dùng đúng khối
`lEquipmentForgeUI` — kể cả việc bản gốc có sẵn **ba biến thể khung theo số
nguyên liệu** (2/3/4 món) và chọn đúng cái theo bảng. Nguyên liệu hiện ra để
biết bản gốc đòi gì nhưng **chưa trừ được** (chưa có hệ vật phẩm); máy chủ chỉ
trừ vàng và đòi cấp tướng.

**Cần biết**: giá vàng là của bản gốc, nơi vòng vàng lớn hơn nhiều. Game mới
mỗi chương cho 60 vàng, nên cấp 3 (3 700) đã là rất xa. Giữ nguyên số theo
quyết định nền, nhưng đây là chỗ sẽ phải cân lại khi có thêm nguồn vàng.

### Trang bị chuyên thuộc — đã đọc, đã hiện thực

Nguồn: `KDBGameExclusiveEquipConfig.xgg` (4 bảng), `IsExclusiveEquip`,
`HasGetExclusiveEquipSkillList`, `getMainPropertyVal`, và `quality_config.xml`
cho hiệu ứng kỹ năng.

Món đồ thường **tinh luyện tới bậc 5 (+25%)** thì rèn lên được thành đồ chuyên
thuộc — nếu tướng nằm trong danh sách **22 tướng** có đồ riêng. Từ đó nó đổi
sang **đường tẩy riêng: 21 bậc (0–20)**, bắt đầu **ngay ở +25%** và lên tới
**+125%**.

Hai đường **nối liền nhau ở đúng +25%** — nên lúc rèn xong, lực chiến không
đổi; cái được là **trần nhà cao gấp năm** và **kỹ năng** món đồ cho.

| Ô | Kỹ năng | Hiệu ứng |
|---|---|---|
| 2 giáp | `ZhuanShuYiFu` | 10% miễn hẳn một đòn **thường** |
| 3 giày | `ZhuanShuXieZi` | chịu ít hơn 15% đòn **kỹ năng** |
| 4 dây chuyền | `ZhuanShuXiangLian` | +10% chí mạng |
| 5 nhẫn | `ZhuanShuJieZhi` | +0,25 hệ số sát thương chí mạng |

Ô 1 (vũ khí) không dùng bảng chung — nó có **kỹ năng riêng theo từng tướng**
(`GetExclusiveWeaponSkillConfig`), ví dụ `ShenQiangLongDan` của Triệu Vân.

Giá tẩy (tinh hoa): vũ khí 100/200/400/800/1600 rồi +400 mỗi bậc; các ô khác
rẻ hơn một bậc. Rèn thì tốn **nguyên liệu** (`ItemList`), chưa trừ được bên
game mới.

**Một điều chỉnh về thứ tự ô**: `HeroEquipPart` của bản gốc là 1 vũ khí,
2 giáp, **3 giày, 4 dây chuyền, 5 nhẫn**, 6 ô phụ. Trước đây bên game mới đặt
3 dây chuyền / 5 giày — sai, và đã sửa. Việc này quan trọng vì bảng kỹ năng
chuyên thuộc khoá theo đúng số ô đó.

Bên game mới: đủ ba bản, RPC `bx.forge_exclusive`, và **không mở tab thứ tư** —
bản gốc đổi *chế độ* của chính bảng tinh luyện khi đạt bậc 5
(`EquipRefineType.OpenExclusive`), nên làm đúng vậy. Hai kỹ năng cần cơ chế mới
(`immune_normal`, `taken_skill`) đã thêm vào cả ba bản mô hình chiến đấu.

### Tẩy luyện — đã đọc, đã hiện thực

Nguồn: `RecastEquipment`, `getAppendPropertyValue`, `updateAppendProperty`,
`CalcEquipFightingCapacity`, `AppendPropertyCoefficient`, `AppendPropertyValue`.

Thuộc tính phụ mở từ **cấp 4**, giá trị tính bằng:

```
value = coef * (base * quality - 0.3) * (levelCoef / 20)
```

- `base` là số **bốc ra** trong dải 0,8–1,3 — **tẩy luyện chính là bốc lại nó**
- `coef` từ `AppendPropertyCoefficient`: HpLimit 40, ApMax 11,8, ApMin 2,7,
  DpAddtion 2,5, CriticalStrike 0,1, CriticalMultiplier 50…
- `levelCoef` vẫn là cột `HeroLevel` của bảng ghép đồ

Tẩy luyện **giữ nguyên loại chỉ số**, chỉ bốc lại con số
(`updateAppendProperty` tính lại `Value` từ `BaseValue`). Giá: **10 000 vàng**,
hoặc 100 kim cương, hoặc **một viên đá tẩy luyện** (vật phẩm 97) thì miễn tiền.

**Điểm quan trọng nhất, và là chỗ tôi từng làm sai**: thuộc tính phụ **không**
quy ra lực chiến bằng giá trị × trọng số. `CalcEquipFightingCapacity` chấm nó
theo **dải bốc được**:

| base > | điểm |
|---:|---:|
| 0,8 | 10 |
| 0,9 | 20 |
| 1,0 | 30 |
| 1,1 | 40 |
| 1,2 | 60 |

Nên hai món cùng loại, cùng giá trị hiển thị, mà `base` khác nhau thì lực
chiến khác nhau — và vì thế **`base` phải được lưu trên món đồ**, không chỉ lưu
giá trị. Đó cũng là lý do tẩy luyện là một canh bạc thật.

Một điều về **đơn vị**: chí mạng và hệ số sát thương chí mạng của thuộc tính
phụ tính theo **điểm phần trăm** (`CriticalStrikeBase = 1` nghĩa là 1%), khác
chỉ số chính. Nhầm là sai 100 lần.

Bên game mới: đủ ba bản, RPC `bx.recast`, và tab tẩy dùng đúng khối
`lEquipmentAlterUI` — kể cả sáu dòng thuộc tính và sáu dòng **giá trị tối đa**
mà bản gốc bày sẵn. Tẩy cao cấp (kim cương) và đá tẩy thì ẩn: chưa có hệ.

### Nâng phẩm chất — đã đọc, đã hiện thực

Nguồn: `PromoteQualityEquipment`, `GetEquipQualityPromotionConfig`, và bảng
`KDBGameCommonConfig` mục `GameEquipQualityPromotionConfig`.

Phẩm chất **1 → 6**, mỗi bậc một dòng trong bảng:

| Lên phẩm | Cần tướng cấp | Vàng | Nguyên liệu |
|---:|---:|---:|---|
| 2 | 1 | 0 | — |
| 3 | 1 | 10 | 86 ×1 |
| 4 | 1 | 20 000 | 87 ×1 |
| 5 | **35** | 40 000 | 88 ×1 |
| 6 | **40** | 93 000 | 89 ×1 |

Điều kiện cấp tướng ở đây **có được kiểm thật** (khác ghép đồ, nơi câu kiểm là
mã chết). Phẩm chất ăn vào **hai chỗ** nên lên một bậc là mạnh cả hai đường:

```
chỉ số chính    (L + 10 + Q*6)^1.45
thuộc tính phụ  (base * Q - 0.3)
```

Nên khi nâng phẩm, **cả hai đều phải tính lại** — nhưng `base` của thuộc tính
phụ **giữ nguyên**: nâng phẩm không phải bốc lại, đó là việc của tẩy luyện.

**Một chỉnh sửa**: phẩm cao nhất là **6** (bảng lên tới 6, và art
`equipment_b_2..6` cũng vậy). Trước đây bên game mới chặn ở 5 — sai.

Bên game mới: đủ ba bản, RPC `bx.promote_quality`, và tab phẩm chất dùng đúng
khối `lEquipmentUpgradeQualityUI` — kể cả **hai khối trước/sau** mà bản gốc
bày sẵn để so.

Đến đây **cả năm bảng hành động của màn trang bị đều có luật**: cường hoá,
tinh luyện (kèm chế độ rèn chuyên thuộc), ghép đồ, tẩy luyện, nâng phẩm.

### Kỹ năng vũ khí chuyên thuộc — đã đọc, đã hiện thực một phần

Bản gốc **có gọi** `GetExclusiveWeaponSkillConfig(heroID)` nhưng bảng
`ExclusiveWeaponSkillConfig` **không tồn tại** trong bản phát hành — hàm luôn
trả `nil`. Ánh xạ thật nằm bên **engine**, ở hai file `assets/map/`:

```
heroex_config.xml    <tên>Exclus  ->  lsSkill        13 tướng
quality_config.xml   định nghĩa từng kỹ năng, mục <exclusive>
```

| Tướng | Kỹ năng | Nội dung |
|---|---|---|
| ZhaoYun | ShenQiangLongDan | phản đòn 22% |
| LvBu | ShenJiFangTian | phản đòn toàn đội |
| XiaoQiao | ShenQinRaoLiang | phá giáp 10%, +35 nộ |
| HuangYueYing | YueShiYinSuoJinLing | +13 nộ mỗi 5 giây |
| GuanYu | ShenMaoQingLongYanYue | hút máu 250% **khi dưới 20% máu** |
| SunShangXiang | BingJianGongShu | đánh nhanh hơn 50% |
| BuLianShi | FengBaoZhiLi | hồi sinh |
| PoJun | BingJianTianShu | đánh nhanh +25%, sát thương chí mạng +1 |
| CaoZhi | JiuXian | (không có trong `quality_config`) |
| SunWuKong | QiTianDaSheng | biến hình |
| DiaoChan | ChenYuLuoYan | gây debuff lên tướng địch |
| ZhouYu | GeMingZhiYue | chuỗi trạng thái nhiều tầng |
| MaChao | ShaFaZhiWu | đổi hình dạng đội |

**Chỉ ba kỹ năng quy được về chỉ số** mà mô hình chiến đấu bên game mới có
chỗ nhận: `ShenQinRaoLiang`, `BingJianTianShu`, `BingJianGongShu`. Số còn lại
là **máy trạng thái của engine** (phản đòn, hồi sinh, debuff, đổi hình) hoặc
có **điều kiện/nhịp** đi kèm — áp thẳng vào là sai hẳn, ví dụ hút máu của Quan
Vũ chỉ có tác dụng khi dưới 20% máu.

Cách xử: **ghi tên kỹ năng lên món đồ** (người chơi vẫn thấy mình đang có gì)
và đánh dấu `modelled = false` — không bịa hành vi. Ba kênh mới đã thêm vào cả
ba mô hình: `pierce`, `anger`, `interval_pct`.

### Mảng trang bị: xong

Cả năm bảng hành động và cả hai nhánh chuyên thuộc đều có luật.

## Vật phẩm và kho — đã đọc, đã hiện thực

Nguồn: `share_ItemLogic.lua` (1088 dòng), `share_ItemDataManager.lua`,
`share_warehouse.lua`, bảng `KDBGameItemConfig.xgg` (619 vật phẩm).

Bảng vật phẩm mỗi dòng có: `ItemID`, `ItemName`, `ItemType`, `MaxCount`,
`Price` (giá bán ra vàng), `Quality`, `Value`, và **`Concentrate`** — số tinh
hoa thu được khi phân giải.

Loại (`Protocol.lua`): 1 tiêu hao, 2 nguyên liệu, 3 đan dược, 4 gói quà,
5 rương, 6 nguyên liệu thần binh, 8 gói chọn, 9 ảnh đại diện.

Luật lõi rất gọn:

```
AddItem      cộng vào rồi CẮT ở MaxCount của từng loại
IsEnoughResourceForSynthesis   thiếu MỘT thứ là hỏng cả
UseMaterialResourceForSynthesis trừ từng món, cuộn lại nếu giữa chừng thất bại
GetItemSalePrice               chính là cột Price
GetWareHouseCurrentCount       đếm TỔNG SỐ LƯỢNG, không phải số loại
```

**Đây là mảnh còn thiếu của ba hệ trước**: ghép đồ, nâng phẩm và rèn chuyên
thuộc đều gọi đúng cặp `IsEnough…` / `UseMaterial…` này. Bên game mới trước
đây chỉ **hiện** nguyên liệu mà không trừ; giờ trừ thật, và báo lỗi nói rõ
thiếu thứ gì bao nhiêu trên bao nhiêu.

Bên game mới: bản lưu có túi đồ (`items`), RPC `bx.items` / `bx.sell_item` /
`bx.dismantle_item`, và **thắng chương thì rơi nguyên liệu** hợp với bậc của
chương đó. Phân giải vật phẩm giờ là nguồn tinh hoa **thật** như bản gốc, bên
cạnh nguồn tạm cũ (đồ thừa bị phân giải).

Màn hình: mỗi ô nguyên liệu hiện **đang có / cần**, thiếu thì tô đỏ, và nút bị
làm mờ kèm dòng "Thiếu nguyên liệu".

### Chưa đọc trong mảng này

Dùng vật phẩm (`UseItem` với ~15 nhánh `useItem_*`: đan dược, gói quà, rương,
ảnh đại diện), mua bán trong cửa hàng, và giới hạn kho (`WarehouseCap`, thư
báo kho đầy).

Còn lại trong `GAMEPLAY.md`: thành tựu, gacha, cửa hàng.

**Đính chính**: bảng `KDBGameNormalEquipRefineConfig` (275 bản ghi) trước đây
ghi ở đây là bảng tinh luyện — **sai**. Nó khoá theo `(HeroJob, EquipPart,
StarLevel)` và chỉ có `SBDataManager` dùng, tức thuộc hệ **thần binh** (神兵),
không phải hệ tinh luyện trang bị.

## Thành tựu và nhiệm vụ ngày — đã đọc, đã hiện thực

Nguồn: `AchieveLogic.lua` (1777 dòng), `AchieveCheckLogic.lua` (1121),
`share_achievement.lua`, `CUIAchieve.lua`, `CUIDailyTask.lua`; bảng
`KDBGameAchieveConfig.xgg` (357 dòng), `KDBGamePrizeConfig.xgg` (2341 phần
thưởng), `KDBGameCommonConfig.xgg` (`DailyTaskLiveness`, `LivenessPrizeConfig`).

### Một bảng, năm họ nhiệm vụ

`AchieveType` chia khoảng (hằng số trong `AchieveLogic:ctor`):

| khoảng | họ |
|---|---|
| 0 | điểm danh — `Award` là 12 phần thưởng, mỗi tháng một cái |
| 1–99 | thành tựu |
| 100–999 | nhiệm vụ ngày |
| 1000–1999 | nhiệm vụ hướng dẫn |
| 2000–2999 | nhiệm vụ bảy ngày |

Mỗi loại là một **chuỗi bước** `AchieveIndex` 1..n. Người chơi giữ một bản ghi
cho mỗi loại: đang ở bước nào, trạng thái gì (`AchieveState`: 1 đang làm, 2 đã
đạt, 3 đã nhận hết). Nhận xong thì sang bước sau, hết bước thì "đã nhận hết" —
và `Init()` mở lại chuỗi đã hết nếu bảng số có thêm bước mới.

**Bẫy khi đọc bảng**: cột `AchieveCondition` không có ở các dòng điểm danh, mà
dòng đầu tiên của bảng lại là điểm danh — đọc tên cột từ dòng đầu sẽ tưởng bảng
không có điều kiện. Đã nhầm đúng thế một lần.

### Điều kiện: một hàm kiểm cho mỗi loại

`GetProgressFuncNameMap` gắn mỗi loại với một hàm trong `AchieveCheckLogic`, trả
về `(đang có, cần)`. Những loại game mới đo được:

| loại | hàm | điều kiện |
|---|---|---|
| 6 | `getChapterPassProgress` | qua màn `L_N_<chương>_<màn>` (72 mốc, 4 mỗi chương) |
| 9 | `getHeroLevelCountProgress` | `HeroCount` tướng đạt cấp `Level` |
| 11 | `getEquipQualityProgress` | phẩm chất trang bị cao nhất **từng đạt** ≥ 3..6 |
| 14 | `getSomeHeroLevelToProgress` | 5 tướng đạt cấp 5, 10, … 90 |
| 16/17/18 | `get{Weapon,Defender,Jewelry}LevelCountProgress` | 5 món ở ô vũ khí / giáp+giày / dây chuyền+nhẫn đạt cấp 1..10 |
| 103 | `getChapterPassCountProgress` | thắng 10 trận trong ngày (`AnyChapterPassCountDaily`) |
| 113 | `getPracticeHeroProgress` | luyện tướng 1 lần trong ngày (`PracticeHeroCountDaily`) |

Loại 11 đọc một **thống kê** (`MaxEquipQuality`) chứ không đếm lại từ đồ đang
có: thay hay phân giải món đồ thì thành tựu đã đạt không mất.

### Hai bước: đạt rồi mới nhận

`ReachAchieve` kiểm điều kiện → đã đạt; `AwardAchieve` trao thưởng → bước sau
hoặc đã nhận hết. Nhiệm vụ ngày khi nhận còn cộng **điểm năng động**
(`DailyTaskLiveness`, mỗi loại 1 điểm; loại 107 — thể lực miễn phí lúc ăn —
không cộng). Đủ điểm thì mở rương (`LivenessPrizeConfig`: 5 điểm, từ cấp 34 là
6 điểm; một rương mỗi ngày).

### Phần thưởng

`Award` là danh sách `PrizeID`. Mỗi phần thưởng có `PrizeResType`
(`Protocol.lua`): 2 vật phẩm, 3 tài nguyên (`CurrencyType` 1 vàng, 8 tinh hoa,
20 kim cương), 4 thuộc tính người chơi (`UserEx` kinh nghiệm tài khoản,
`AddGoldInLevel` vàng × cấp người chơi, `AddFatigue` thể lực). Icon:
`item_<id>.png`, vàng `v6/ui_jinbi02.png`, tinh hoa `v6/ui_ronglujingyan02.png`
(`CUIPrizeResHelper`).

Phần thưởng thành tựu chương (loại 6) **chỉ toàn** đan kinh nghiệm (4), đan
phẩm chất (14) và 脑白金 (13) — hệ tướng của bản gốc lên cấp bằng kinh nghiệm,
còn game mới lên cấp bằng vàng.

### Đã hiện thực bên game mới

Bảy chuỗi thành tựu (6, 9, 11, 14, 16, 17, 18 — 93 bước) và sáu nhiệm vụ ngày,
cùng điểm năng động và rương. RPC: `bx.tasks`, `bx.claim_task`,
`bx.claim_liveness`. Máy chủ kiểm lại điều kiện lúc nhận — gộp `ReachAchieve`
và `AwardAchieve` làm một.

Nhiệm vụ ngày: hai loại của bản gốc (103, 113) và **bốn loại của game mới**.
Chỉ hai trong mười ba loại gốc đo được bằng hệ thống đã có, nên rương năng động
(5 điểm) không bao giờ với tới; người dùng chọn thêm nhiệm vụ dựa trên hệ đã có:

| loại | việc | lần | căn cứ |
|---|---|---|---|
| 151 | cường hoá trang bị | 3 | biến đếm gốc `IntensifyEquipmentCountDaily` (`Statistics.lua`) và hàm kiểm gốc `getIntensifyEquipmentCountProgress` — bản gốc từng gắn cho loại 106 rồi bỏ khỏi bảng; phần thưởng `PrizeID` 10601 |
| 152 | tinh luyện | 1 | tự đặt; phần thưởng `PrizeID` 11301 |
| 153 | phân giải vật phẩm | 1 | tự đặt; phần thưởng `PrizeID` 11301 |
| 154 | ghép đồ | 1 | tự đặt; phần thưởng `PrizeID` 11301 |

Số lần là của ta; phần thưởng là đúng phần thưởng nhiệm vụ ngày gốc. Đặt ở
khoảng 151.. để không đụng loại nào của bản gốc — sau này làm đúng loại 106
(hang động) thì không vướng. Sáu nhiệm vụ đủ cho cả hai bậc rương (5 điểm, và 6
điểm từ cấp 34).

Chỗ lệch có chủ ý:

- **Chương**: game mới có 12 chương, mỗi chương một trận. Qua chương N nghĩa là
  đạt cả 4 mốc của chương N bên bản gốc. Bỏ 24 mốc của chương 13–18.
- **Cấp tướng**: tối đa 40, bỏ 8 bước đòi cấp 45–90 của loại 14.
- **Cấp người chơi**: game mới chưa có cấp tài khoản; "vàng theo cấp" và bậc
  rương dùng cấp tướng cao nhất.
- **Luyện tướng** (113): game mới chưa có khu luyện tướng; nâng cấp tướng đếm
  thay.
- **Phần thưởng không có chỗ chứa** (kim cương, kinh nghiệm tài khoản, thể lực)
  ghi vào "chưa trao", không đổi bừa sang thứ khác. Vật phẩm thì trao đúng như
  bản gốc, kể cả đan kinh nghiệm / đan phẩm chất chưa có công dụng.
- **Ngày cắt theo UTC+7.**

Còn mở: rương năng động cần 5 điểm mà mới có 2 nhiệm vụ ngày làm được, nên hiện
chưa với tới.

### Chưa làm trong mảng này

Điểm danh (loại 0, có ngày nhân đôi theo VIP), nhiệm vụ hướng dẫn, bảy ngày, và
11 loại nhiệm vụ ngày cần hệ thống game mới chưa có (đấu trường, hang động,
doanh trại, phái cử, điểm vàng, bang hội, chia sẻ).

## Còn chưa đọc

Tài liệu này mới là **bản đồ**, chưa phải đặc tả từng hệ thống. Cần đọc sâu
tiếp, theo thứ tự ưu tiên ở trên, và mỗi lần đọc thì bổ sung một mục vào đây —
công thức, thang số, và các RPC liên quan.
