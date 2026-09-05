# Lớp offline — chạy "Búa Tạ" không cần server

Game đã đóng cửa, không còn server để đối chiếu. Lớp này thay server bằng một
bộ giả lập **viết bằng Lua chạy ngay trong client**, dùng lại chính luật chơi
mà client đã mang sẵn.

Nền: **bản VN 1.26.81485** (`com.cmn.buatanew`).

## Vì sao chặn được sạch

Toàn bộ giao thức đi qua đúng hai hàm Lua **toàn cục** (`sc/system/rpc.lua`):

```lua
CallServer(nModule, strObjName, strFunction, ...)   -- client -> server   (dòng 155)
CallLocal(strObjName, strFunction, szJsonArgs)      -- server -> client   (dòng 79)
```

Lua tra cứu biến toàn cục lúc gọi, nên ghi đè `CallServer` bắt được **cả** các
lời gọi do `CUIAssist.bindRpcToEvent` sinh ra lúc chạy. Tầng protobuf và socket
trong `libgame.so` không bao giờ được chạm tới — không cần vá `.so`, không cần
vá dex.

Thứ hai, client đã mang sẵn tầng dữ liệu của server. `sc/share/` là mã dùng
chung hai phía; bằng chứng nằm ở `sc/share/share_CDataManager.lua:207`:

```lua
function CDataManager:initUserDataFromDB(strModuleName)
	return 0, nil          -- bản server nạp từ database ở đây
end
```

Hàm chạm database bị rút ruột, còn lại nguyên tầng đọc/ghi (`ModifyUserData`,
`WriteToTable`, `ChangeUserData`). `offline/store.lua` chính là cái database đó.

## Kiến trúc

```
sc/offline/
  init.lua            điểm vào; bịt initUserDataFromDB, cài hook
  net.lua             chặn CallServer + StartRPC, hàng đợi phản hồi bất đồng bộ
  router.lua          sổ đăng ký: tên hàm server -> handler cục bộ
  store.lua           33 bảng GameUser*, lưu ra JSON
  bootstrap.lua       dựng người chơi mới
  log.lua             nhật ký, trong đó có danh sách API còn thiếu
  handlers/login.lua  chuỗi đăng nhập -> bắt tay -> vào game
test/
  mock.lua            giả lập môi trường game để test trên PC
  run.lua             bộ test chuỗi vào game
```

**Phản hồi bắt buộc bất đồng bộ.** Server thật không trả lời trong lòng lời gọi;
trả đồng bộ sẽ tái nhập logic client giữa chừng và phá vỡ giả định của nó. Nên
`net.lua` xếp hàng phản hồi và đẩy ra ở khung hình sau qua `S_CCSchedule`.

**Không phải handler nào cũng dùng bao bì `{err=, data=}`.** Ví dụ
`OnServerEnterGame` nhận 5 tham số vị trí (`ClientGameWorld.lua:37`). `ctx:reply`
dùng cho loại bao bì, `ctx:call` cho loại tham số vị trí.

**`ctx:reply` tự dò tên handler lúc chạy.** Nó dựng danh sách ứng viên đúng thứ
tự `build_spec.candidates()` thử (bỏ tiền tố `Client`/`Req`/`Request`, thêm `On`)
rồi chọn tên nào thực sự phân giải ra một hàm theo đúng luật của `CallLocal`.
Quy tắc chuỗi đơn thuần sai 25/415 trường hợp — `ClientCatchFishReq` phải về
`OnCatchFish` chứ không phải `OnCatchFishReq` — và cách dò này còn bắt được cả
handler do `bindRpcToEvent` sinh lúc chạy. Không tên nào phân giải được thì nó
ghi `WARN` chứ không im lặng để client treo.

**Tham số `nil` được giữ chỗ bằng `cjson.null`.** `ctx:call(obj, fn, 1, nil, 3)`
gửi đủ ba tham số; bên client tham số giữa về thành `cjson.null` — đúng thứ
server thật cũng buộc phải gửi, vì transport là JSON và JSON không có "vắng mặt"
ở giữa mảng.

## Trạng thái

| | |
|---|---:|
| Handler đã hiện thực | **9** / 614 |
| API nuốt lặng lẽ (nhịp tim, thống kê) | 4 |
| Test đạt — lớp offline | 33 / 33 |
| Test đạt — `deploy.py` | 23 / 23 |

Đã chạy được: đăng nhập → danh sách máy chủ → bắt tay → `ClientEnterGame` →
`G_DataManager:Init` với đủ 33 bảng, lưu và nạp lại tiến trình.

Tên bảng lấy từ `EventManagerTableName` (`sc/share/EventManager.lua:1086`), tên
trường lấy từ các đăng ký `G_EventManager:Reg(..., EventManagerType.Data, <bảng>,
<trường>)` rải trong mã. **Giá trị** khởi tạo thì do ta chọn — không có cách nào
biết bản gốc dùng số nào — và được đánh dấu `ĐẶT` trong `bootstrap.lua`.

## Chạy test

```bash
pip install lupa
python run_tests.py            # lớp offline — 33 check, cần lupa
python test/test_deploy.py     # deploy.py  — 23 check, không cần gì thêm
```

`test_deploy.py` thay hàm `adb()` bằng một máy giả (dict đường dẫn → bytes) nên
chạy được khi không có thiết bị nào cắm vào. Nó khoá ba lời hứa của `--flags`:
không đụng vào file không phải XML thuần, không báo "đã thêm" khi phép chèn
không ăn, và không đẩy gì lên máy khi không sửa được gì. `--flags` là lệnh duy
nhất ghi đè một file của game trên máy thật, nên đây là chỗ đáng có test nhất.

## Đóng gói và tha lên máy

```bash
python build.py
```

Sinh hai bản trong `deploy/`: `plain/` (nguyên văn) và `sng/` (đã mã hoá đúng
định dạng `sngFile` của game — bộ mã hoá đã kiểm chứng round-trip trùng từng
byte trên cả 973 file Lua gốc).

Điểm chèn là `sc/user/require.lua`, thêm đúng một dòng `require("offline.init")`
ở cuối. Không phải đóng gói lại APK: `package.path` của game ưu tiên external
storage rồi download path **trước** assets (`sc/game.lua:60`) — đây vốn là cơ
chế cập nhật nóng của chính game.

### Cài adb (một lần)

```bash
winget install --id Google.PlatformTools --exact
```

Tải từ `dl.google.com`, winget tự kiểm hash. Sau khi cài phải **mở lại
terminal** thì PATH mới có `adb` — nhưng `deploy.py` cũng tự dò các vị trí cài
thường gặp nên chạy được ngay cả trong cửa sổ cũ.

### Đẩy lên máy

Dùng `deploy.py` thay vì `adb push` tay — nó tự dò thư mục nào ghi được rồi
đẩy vào tất cả, nên không phải đoán:

```bash
python deploy.py --status    # máy, ABI, quyền, thư mục ứng viên
python deploy.py --push      # đẩy (thêm --sng nếu bản plain không ăn)
python deploy.py --flags     # bật DebugTestMode / CloseGuide trong set.xgg
python deploy.py --log -f    # theo dõi offline.log
```

Ứng viên thư mục ghi đè, đọc từ `Cocos2dxHelper.init` trong dex bản VN:

| nguồn | đường dẫn |
|---|---|
| `getExternalFilesDir()` | `/sdcard/Android/data/com.cmn.buatanew/files` |
| `getExternalStorageState()` | `/sdcard` (app targetSdk 23 nên vẫn ghi được) |
| `getFilesDir()` | `/data/data/com.cmn.buatanew/files` — cần root |

Bật công tắc gỡ lỗi có sẵn, trong `set.xgg` ở thư mục ghi được của game:

```xml
<DebugTestMode>true</DebugTestMode>
<CloseGuide>true</CloseGuide>
```

## Cách làm tiếp

`offline.log` là danh sách việc, và nó tự sinh theo đúng thứ tự game cần. Mỗi
lần client gọi một API chưa có handler, dòng này xuất hiện:

```
[14:22:07] THIEU    G_ActivityStock.ClientBuyStock  module=5  args=["S001",10,99]
```

Hai loại dòng `WARN` cũng thuộc danh sách việc: *"khong tim thay handler nao"*
(tên client chờ không khớp ứng viên nào — phải truyền tên tay cho `ctx:reply`)
và *"client khong co ham nay"* (đã trả về một tên không tồn tại).

Cứ chơi, đọc log, viết handler cho cái xuất hiện, lặp lại. Tra chữ ký và hình
dạng phản hồi ở `../server-spec-vn/rpc-reference.html`; hình dạng payload chính
xác thì đọc thẳng hàm `On*` tương ứng trong mã client — mã nguồn client có đủ.

## Chưa kiểm chứng — phải thử trên máy trước

Toàn bộ ở trên mới chỉ chạy trong môi trường giả lập trên PC. Ba điều còn là
suy luận từ mã, chưa có bằng chứng chạy thật:

1. **Cổng đăng nhập SDK.** Kull SDK có thể chặn ngay trước khi Lua chạy. Nếu
   vậy phải vá ở tầng Java — dex bản VN không đóng gói nên sửa được.
2. **Đường ghi đè.** Đã thu hẹp còn 3 ứng viên (bảng ở trên) nhưng chưa biết
   `libgame.so` hỏi JNI cái nào. `deploy.py --push` đẩy vào tất cả nên không
   còn là rào cản, chỉ là chưa xác nhận cái nào ăn.
3. **File nguyên văn hay đã mã hoá.** Bộ nạp nhiều khả năng kiểm tra magic
   `sngFile` ở cuối để quyết định có giải mã không, nhưng đây là suy đoán từ
   định dạng. Thử `plain/` trước, không được thì `sng/`.

Việc đầu tiên đáng làm: cài bản VN, bật chế độ máy bay, xem nó chết ở đâu.
