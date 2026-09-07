# brave-cross

Dịch ngược game **"Búa Tạ / Siêu Anh Hùng"** (Cocos2d-x + Lua, 2017 — đã đóng
cửa, không còn server), rồi dùng kết quả đó làm nền để **làm một game mới cùng
dòng**.

Hai bản được phân tích song song: bản CN `com.xh.dachui.xsj` 1.25.78923 và bản
VN `com.cmn.buatanew` 1.26.81485.

Phần dịch ngược coi như xong. Trọng tâm hiện tại đã chuyển sang game mới — xem
mục [Hướng đi](#hướng-đi-làm-game-mới) bên dưới.

## Trong repo có gì

| | |
|---|---|
| [`work/`](work/README.md) | công cụ dịch ngược, tài liệu đầy đủ |
| [`work/offline/`](work/offline/README.md) | lớp giả lập server chạy trong client |
| `work/server-spec/` | đặc tả API bản CN — 584 hàm server |
| `work/server-spec-vn/` | đặc tả API bản VN — 614 hàm server |

Mở `work/server-spec-vn/rpc-reference.html` để tra cứu API có tìm kiếm.

## Không có trong repo

Toàn bộ nội dung game — APK, OBB, tài nguyên đã giải mã, mã Lua gốc — **không**
được đưa lên: đó là tài sản có bản quyền, và cũng quá lớn cho GitHub (29.000
file, 320 MB riêng phần APK/XAPK).

Repo chỉ chứa phần tự viết: bộ công cụ, đặc tả rút ra được từ phân tích, và lớp
offline. Nhưng **dựng lại được đầy đủ** — tự lấy APK/XAPK về, đặt vào thư mục
gốc, rồi:

```bash
cd work
python unpack.py ../<file>.apk            # hoặc .xapk, dùng --out vn
python build_spec.py
```

`unpack.py` giải nén, giải nhị phân manifest và giải mã toàn bộ tài nguyên.
Đã kiểm chứng: dựng lại từ file gốc cho ra cây thư mục **trùng từng byte** với
bản đang dùng (3984 file bản CN, 9728 file bản VN), và đặc tả sinh ra cũng
trùng khít.

## Hướng đi: làm game mới

Dựng lại nguyên bản gốc là việc quá lớn: 614 API server, 92 tướng, 18 chương,
bang hội, quốc chiến, đấu trường, cổ phiếu, thú cưng, tinh hồn, chiến hồn — tức
5 năm vận hành của một studio cộng lại. Nên mục tiêu đổi thành **làm game mới
cùng dòng**, và những gì đã dịch ngược được chuyển vai: từ "để dựng lại bản cũ"
thành **tài liệu thiết kế của một game đã vận hành thật**.

### Dùng lại được gì, không dùng được gì

Ranh giới: **art, âm thanh và text của bản gốc không được ship.** Dùng làm tham
chiếu và ảnh tạm trong lúc dev thì được, nhưng phải thay hết trước khi phát hành.

| Thứ | Vai trò trong game mới |
|---|---|
| `server-spec/SERVER_API.md` | bản đồ **những gì KHÔNG làm ở v1** — chọn 40–50 API cho vòng lặp lõi, gạch phần còn lại |
| `work/decrypted/assets/sc/share/` | đọc để biết **luật nào cần tồn tại** (công thức sát thương, thang EXP, CD, giá nâng cấp) rồi tự viết lại — đây là đặc tả, không phải code để copy |
| `config/share/*.xgg` (JSON) | thang số liệu đã cân bằng thật qua người chơi thật: đường cong EXP, giá nâng cấp, tỉ lệ gacha |
| Hoạt ảnh đã xuất (`export.py`) | đối chiếu quy mô cho art của mình: trung bình mỗi atlas có **20 động tác, 32 sprite, ~313 xương, ~1600 keyframe** — biết trước để không vẽ quá tay |

### Bộ công cụ khuyến nghị

Chưa chốt engine — còn phụ thuộc làm một mình hay có đội, và có ra PC/web ngoài
mobile không.

| Việc | Công cụ | Lý do |
|---|---|---|
| **Engine** | **Godot 4.7** | miễn phí không phí bản quyền; 2D mạnh; và quan trọng nhất là **có hệ UI thật** (Control + theme) — dòng game này 80% là UI, bản gốc có 501 file Lua chỉ riêng `sc/user/UI/` |
| **Hoạt ảnh xương** | **Spine** Essential, hoặc **DragonBones** nếu 0đ | đúng thứ dòng game này dùng; bản gốc tự viết hệ xương, Spine là bản thương mại của cùng ý tưởng |
| **Art + UI** | **Krita** (0đ) hoặc Affinity Designer; **Figma** để mockup | game này **không phải pixel art** nên đừng dùng Aseprite |
| **Bảng số liệu** | Google Sheets → JSON bằng script Python | đúng cách bản gốc làm: `KDBGameHero.xgg` chính là JSON |
| **Backend** | **Nakama** tự host | khớp sẵn nhu cầu: `groups` = bang hội, `leaderboards` = đấu trường, `storage` = dữ liệu người chơi, `wallet` = tiền tệ, có mail và matchmaking. Server module viết được bằng **Lua** — tái hiện đúng thứ thông minh nhất của bản gốc: client và server chạy chung một bộ luật |
| **Test luật chơi** | gdUnit4 + script Python mô phỏng trận | auto-battler chỉ cân bằng được bằng mô phỏng hàng nghìn trận, không phải chơi tay |
| **Test máy thật** | `adb` + máy Android thật, hoặc emulator | `adb` cài kèm ở mục dưới; máy thật cho cảm giác chạm và hiệu năng đúng hơn emulator |
| **Repo** | git + **Git LFS** | art phình rất nhanh — bật LFS từ commit đầu |
| **CI** | GitHub Actions | build APK tự động mỗi lần push |

Đổi engine nếu:

* **muốn giữ Lua** → **Defold** (scripting là Lua thật, build nhỏ, mạnh 2D
  mobile; đánh đổi: cộng đồng nhỏ hơn Godot nhiều)
* **muốn kiến trúc gần bản gốc nhất** → **Cocos Creator 3.x**, hậu duệ trực tiếp
  của Cocos2d-x, viết TypeScript
* **cần dễ tuyển người / nhiều asset mua sẵn** → **Unity 6**

### Cài đặt trên máy trắng (Windows)

Mọi ID dưới đây đã kiểm bằng `winget show`, phiên bản ghi kèm là bản winget đang
phục vụ. Dán cả khối vào PowerShell.

**Bắt buộc:**

```powershell
winget install GodotEngine.GodotEngine       # 4.7.2    engine
winget install Python.Python.3.13            # 3.13.15  script, mô phỏng trận, xuất bảng số liệu
winget install Git.Git                       # 2.55.0   quản lý mã
winget install GitHub.GitLFS                 # 3.8.0    art nặng — bật LFS từ commit đầu
winget install Microsoft.VisualStudioCode     # 1.136.1  editor
winget install Docker.DockerDesktop          # 4.89.0   chạy Nakama
winget install KDE.Krita                     # 5.3.3    vẽ art + UI
```

**Để build và test APK trên máy Android thật:**

```powershell
winget install Microsoft.OpenJDK.17          # 17.0.20  Godot cần JDK để export Android
winget install Google.PlatformTools          # 37.0.1   adb — đẩy APK, xem logcat
```

Chỉ cần `adb` thì hai gói trên là đủ, **không phải cài cả Android Studio**. Cần
SDK đầy đủ (emulator, SDK manager) thì thêm `winget install Google.AndroidStudio`
(2026.1.4.7).

**Tuỳ chọn:**

```powershell
winget install Gyan.FFmpeg                                # 9.0.1   xử lý audio/video
winget install DBBrowserForSQLite.DBBrowserForSQLite       # 3.13.1  xem dữ liệu người chơi
```

**Không có trên winget:**

* Hoạt ảnh xương — chọn một: **Spine** Essential ~$70 (`esotericsoftware.com`,
  có runtime Godot chính thức) hoặc **DragonBones** 0đ (dùng được nhưng đã ngừng
  phát triển)
* Mockup UI: **Figma** trên web, bản free đủ dùng

**Sau khi cài, cấu hình export Android trong Godot** (chỉ làm một lần):
Editor → Editor Settings → Export → Android, trỏ `Java SDK Path` tới JDK 17 và
`Android SDK Path` tới SDK, rồi Project → Install Android Build Template.

### Backend Nakama

Docker đã có sẵn nên chỉ cần file compose. Đã kiểm: `docker compose config` hợp
lệ, và cả hai image đều tồn tại thật trên registry (`docker manifest inspect`).

```yaml
# docker-compose.yml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: nakama
      POSTGRES_PASSWORD: localdb
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "postgres", "-d", "nakama"]
      interval: 3s
      timeout: 3s
      retries: 10

  nakama:
    image: registry.heroiclabs.com/heroiclabs/nakama:3.27.0
    depends_on:
      postgres:
        condition: service_healthy
    entrypoint:
      - /bin/sh
      - -ecx
      - >
        /nakama/nakama migrate up
        --database.address postgres:localdb@postgres:5432/nakama &&
        exec /nakama/nakama
        --database.address postgres:localdb@postgres:5432/nakama
        --logger.level INFO
    volumes:
      - ./modules:/nakama/data/modules       # server module viết bằng Lua đặt ở đây
    ports:
      - "7350:7350"                          # API cho client
      - "7351:7351"                          # console quản trị
    healthcheck:
      test: ["CMD", "/nakama/nakama", "healthcheck"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  pgdata:
```

```powershell
mkdir modules
docker compose up -d
docker compose ps            # cả hai phải "healthy"
```

Console ở `http://127.0.0.1:7351`, đăng nhập mặc định `admin` / `password` —
**đổi ngay** trước khi mở ra ngoài máy mình. API cho client ở cổng `7350`.

### Kiểm tra sau khi cài

Mở **terminal mới** rồi chạy — winget chỉ thêm vào PATH cho tiến trình mới:

```powershell
python --version             # 3.13.x
git --version                # 2.55.x
git lfs version              # 3.8.x
code --version               # 1.136.x
docker --version             # 4.89 -> Docker Desktop phải đang chạy
java -version                # 17.x  (cho export Android)
adb version                  # 37.x
godot --version              # 4.7.x
```

Nếu lệnh nào báo *not recognized* mà đã cài xong: mở lại terminal, hoặc gọi bằng
đường dẫn đầy đủ. Godot và Krita hay không vào PATH — cứ mở từ Start Menu cũng
được, không ảnh hưởng gì.

### Thứ tự làm

Đừng bắt đầu bằng engine. Bắt đầu bằng câu hỏi *game này có vui không*:

1. **Mô phỏng trận bằng Python**, không đồ hoạ — lấy 5 tướng từ bảng JSON của
   bản gốc, viết vòng lặp chiến đấu, chạy 10.000 trận, xem tỉ lệ thắng có thú vị
   hay một tướng đè hết. Vài trăm dòng, trả lời câu hỏi đắt nhất trước khi tốn
   đồng nào cho art.
2. **Một màn trong Godot**: hai đội lính chạy vào nhau, có thanh máu. Ảnh vuông
   màu thay art.
3. **Nakama chạy bằng Docker**, đúng hai API: đăng nhập và lưu dữ liệu người chơi.
4. Chỉ khi ba bước trên chạy thông mới nghĩ tới art thật.

Điểm chết của dòng game này là **phạm vi**, không phải công cụ. Một mình thì chọn
**một** vòng lặp — thu thập tướng, nâng cấp, đánh chương — và ship nó.

## Trạng thái

Phần dịch ngược — **đã xong**:

* Phá lớp mã hoá tài nguyên `sngFile` (many-time pad trên 952 file Lua dùng
  chung keystream) — giải và mã hoá ngược đều trùng từng byte
* Rút đặc tả server tự động từ mã Lua: 584 API (CN) / 614 API (VN), gồm cả 100+
  API mà quét thông thường bỏ sót vì tên hàm chỉ sinh ra lúc chạy
* Giải trọn ba định dạng nhị phân riêng (`xgg5.0`/`sngXgg`, `sngXml` bản
  `.plist` và bản `.xml`) — 0 lỗi trên toàn bộ cây
* Xuất được nội dung: 397 atlas hoạt ảnh (~289 nhân vật/quân chủng/trang phục),
  12.820 PNG, 641.538 keyframe

Lớp offline — **tạm dừng**: chặn ở `CallServer`/`CallLocal`, tái dùng chính luật
chơi client đã mang sẵn, kho dữ liệu 33 bảng lưu ra JSON. Đạt **9/614 handler**;
chuỗi đăng nhập → bắt tay → vào game chạy thông trong môi trường test (33/33),
chưa kiểm chứng trên máy Android thật. Giữ lại làm tham chiếu cho game mới, chưa
làm tiếp.

Game mới — **chưa bắt đầu**. Bước kế tiếp là mục [Thứ tự làm](#thứ-tự-làm) ở trên.
