# Dịch ngược APK "Búa Tạ"

Hai bản của cùng một game, dịch ngược song song để đối chiếu.

| | bản CN | bản VN |
|---|---|---|
| File gốc | `OAR1_XGSDK_1.25_jinshan_gwbb_sec.apk` (83 MB) | `Búa+Tạ+-+Siêu+Anh+Hùng_1.26.81485_APKPure.xapk` (252 MB) |
| Package | `com.xh.dachui.xsj` — *dachui* = 大锤 = **búa tạ** | `com.cmn.buatanew` |
| Version | 1.25.78923 (build 2017-10-25) | 1.26.81485 |
| SDK | Kingsoft Passport, XGSDK, Umeng, iFlytek, Bugly/TPNS | Kull SDK, Facebook, Google Play, Bugly/TPNS |
| Bảo vệ | **SecNeo** (`libDexHelper.so`) — chỉ gói lớp Java riêng của app | **không có** |
| Lua | 952 file | 973 file |

Chung: Cocos2d-x + Lua 5.2.3, lớp engine riêng tiền tố `sng`, `libgame.so` (ARMv7) + FMOD Studio.

## Kết quả

```
work/
  apk/, vn/apk/, vn/obb/      APK / OBB giải nén nguyên trạng
  decrypted/                  bản CN đã giải mã
    AndroidManifest.xml       đã giải nhị phân → XML đọc được
    assets/                   3984 file (242 MB)
      sc/                     952 file .lua — TOÀN BỘ logic game, mã nguồn gốc
      config/, conf/          bảng số liệu game (JSON / XML / nhị phân)
      map/, img_all/          atlas, plist, dữ liệu màn chơi
      *.pkm                   texture ETC1 (đã về đúng định dạng PKM 10)
  vn/decrypted/               bản VN đã giải mã — 10090 file, 973 .lua

  sng_decrypt.py              bộ giải mã tài nguyên
  axml.py                     bộ giải mã AndroidManifest nhị phân
  dexinfo.py                  đo mức độ bị đóng gói của classes.dex
  extract_api.py              quét lời gọi RPC trong Lua
  build_spec.py               sinh đặc tả server
  diff_api.py                 so hai đặc tả (API, chữ ký, enum, mã lỗi)
  inventory.py                so kho tài nguyên hai bản

  server-spec/                đặc tả bản CN — 584 API
  server-spec-vn/             đặc tả bản VN — 614 API
    SERVER_API.md             đặc tả đầy đủ
    server_api.json           bản máy đọc được
    rpc-reference.html        bản tra cứu có tìm kiếm
  inventory.json, api_diff.json
```

## Đặc tả server

Dựng tự động từ mã Lua, mọi số liệu đến từ chính mã nguồn, không suy đoán.

| | CN 1.25 | VN 1.26 |
|---|---:|---:|
| Hàm server client gọi tới | **584** | **614** |
|  — khai báo trực tiếp `CallServer("Tên", …)` | 484 | 487 |
|  — sinh lúc chạy qua `bindRpcToEvent` ⟳ | 100 | 127 |
| Dò được handler trả về | 392 | 415 |
| Callback chiều ngược | 388 | 410 |
| Nhóm mã lỗi | 59 | 62 |

Giao thức: envelope protobuf `GameActionData`, payload **JSON thuần**, định tuyến
**theo tên hàm** ở cả hai chiều — client gửi thẳng tên hàm server cần chạy, server
trả kết quả bằng một RPC ngược gọi hàm `On*` của client.

```bash
python build_spec.py                                            # → server-spec/
python build_spec.py --assets vn/decrypted/assets --out server-spec-vn
cd server-spec && python build_page.py && python build_page.py ../server-spec-vn
python diff_api.py server-spec server-spec-vn                   # → api_diff.json
```

### Hai cách mã nguồn phát sinh lời gọi

Quét `CallServer` không đủ. `CUIAssist.bindRpcToEvent` (`sc/user/UI/CUIAssist.lua:335`)
sinh hàm **lúc chạy** từ một bảng sự kiện:

```lua
CUIAssist.bindRpcToEvent(self, "G_ActivityStock", EventManagerLogicEvent.Stock,
                         "Client%s", "OnClient%s")
-- với mỗi khoá k trong bảng:
--   self[reqFmt % k] = function(...) CallServer(GAME_LOGIC, obj, reqFmt % k, ...) end
```

Tên hàm chỉ tồn tại sau khi `string.format` chạy, nên **không xuất hiện dưới dạng
chuỗi ở bất kỳ đâu trong mã nguồn**. 11 module đi hoàn toàn bằng đường này
(StateWar, Pet, XingHun, JFZY, Stock, RedPacket, GuildContest, HeroPK, Tongque,
ShuaShuaLe, SysExchange). `extract_api.resolve_bound()` nở chúng ra từ
`EventManagerLogicEventDef` trong `sc/share/EventManager.lua`; chữ ký tham số
lấy từ nơi gọi thật, mô tả lấy từ comment cuối dòng của chính khoá sự kiện.

Sau bước này **không còn API nào chưa giải được**: 2 mục còn lại trong `dynamic`
(`rpc.lua`, `CUIAssist._addRpcFunc`) đều là tầng vận chuyển, không phải API.

## Khác biệt VN so với CN

`api_diff.json` — **thêm 30 API, bỏ 0**, không API nào đổi chữ ký:

| đối tượng server | số API mới | nội dung |
|---|---:|---|
| `G_JiuFaZhongyuan` | 15 | 九伐中原 — phó bản trận doanh mới |
| `G_ActivityStock` | 8 | chơi cổ phiếu |
| `G_ServerStateWarProtocol` | 5 | quốc chiến: đường di chuyển, công cáo |
| `G_RechargeLogic` | 2 | cổng thanh toán AiBei |

Thêm 3 nhóm mã lỗi (`JFZY`, `Stock`, `ChargeSign`), 22 callback mới.
Kho tài nguyên: chỉ CN 125 file, chỉ VN 6231, chung 3859 (giống hệt 3506, khác 353).
Chênh lệch gần như toàn bộ nằm ở `.pkm` (chỉ VN có 5837 file) và `.bank` âm thanh (299).

## Cơ chế mã hoá tài nguyên (đã phá)

Mọi file tài nguyên kết thúc bằng magic ASCII `sngFile` (7 byte):

```
file    = payload || b"sngFile"
payload[0:256] = plaintext XOR KEY32          (khoá 32 byte lặp lại)
payload[256:]  = plaintext XOR 0xFF
```

`KEY32 = 5e44dddb bfa6b416 84c7cb83 47a3ec3d 5fcecb86 07ad0d2e 12379d79 ed0fb468`

Sau khi giải mã, các file `.pkm/.plist/.xgg/.xml/.json` còn được nén **gzip** thêm một lớp.

Khoá được khôi phục bằng tấn công *many-time pad*: 952 file `.lua` dùng chung một
keystream, chấm điểm từng vị trí theo tiêu chí "byte giải ra phải là text hợp lệ"
cho ra khoá duy nhất, và lộ ra chu kỳ lặp 32 byte. Bản VN dùng **cùng khoá**.

## Còn lại 3 định dạng nhị phân riêng (chưa giải cấu trúc)

| Magic | Số file | Nội dung |
|---|---|---|
| `xgg5.0` | 278 | dump struct C++ của cảnh/màn chơi (`BattleField_*`, `UI_*`) |
| `sngXml` | 493 | plist atlas đã biên dịch sẵn |
| `sngXgg` | 6 | bảng cấu hình đã biên dịch sẵn |

Đây là bản dump bộ nhớ struct từ công cụ editor (thấy rõ byte đệm `0xCD` của MSVC).
Muốn đọc phải lấy layout struct từ `libgame.so` bằng IDA/Ghidra.
Phần lớn dữ liệu quan trọng đã có sẵn ở dạng JSON/XML nên không chặn việc đọc hiểu game.

## Phần Java (classes.dex)

Đo bằng `python dexinfo.py apk/classes.dex vn/apk/classes.dex`:

| | CN | VN |
|---|---:|---:|
| class | 3353 | 9021 |
| method | 22746 | 55929 |
| — có bytecode | 20832 | 50533 |
| — bị xoá thân | **0** | **0** |

**Cả hai dex đều hợp lệ và decompile được bình thường** bằng jadx/dex2jar —
header không hỏng, `file_size` khớp đúng kích thước file, không method nào bị
rút ruột. Toàn bộ lớp SDK đọc được: `kingsoft_pass` 254 class, `xgsdk` 195,
`iflytek` 159, `zxing` 223, `fastjson` 183.

SecNeo ở bản CN **không** làm rối cả dex — nó chỉ **bỏ hẳn ~20 lớp riêng của app**
ra ngoài (`com.xh.dachui.xsj.*` chỉ còn `R$*` và `CallbackActivity`, mất
MainActivity), rồi `libDexHelper.so` nạp lại chúng trong RAM lúc chạy.

Bản VN **không đóng gói gì cả**: không có `com/secneo`, `com.cmn.buatanew` +
`com.kull.sdk` (299 class) + Facebook SDK đọc được hết. Cần xem lớp Java thì lấy
từ bản VN, không phải dump bộ nhớ.

Dù sao **logic game không nằm ở Java**. Java chỉ là launcher + SDK (đăng nhập,
thanh toán, thống kê, push). Toàn bộ gameplay nằm ở Lua (đã có đủ) và C++ trong
`libgame.so`.

## Lớp offline

`offline/` — bộ giả lập server chạy ngay trong client, để chơi được khi game đã
đóng cửa. Chặn ở `CallServer`/`CallLocal` (hai hàm Lua toàn cục), dùng lại
`sc/share/` làm luật chơi, thay `CDataManager:initUserDataFromDB` bằng một kho
JSON cục bộ. Hiện chạy được chuỗi đăng nhập → bắt tay → vào game với đủ 33 bảng
dữ liệu; 9/614 handler. Xem `offline/README.md`.

`sng_encrypt.py` — mã hoá ngược về định dạng `sngFile`, để nhét file đã sửa trở
lại game. Round-trip trùng từng byte trên cả 973 file Lua gốc:

```bash
python sng_encrypt.py --selftest vn/obb/assets/sc
cd offline && python run_tests.py && python build.py
```

## Ghi chú

* Comment trong `.lua` trộn cả UTF-8 lẫn GBK (tiếng Trung) tuỳ file.
* Điểm vào: `sc/game.lua`; bảng số liệu: `config/share/KDBGame*.xgg` (JSON).
* Định nghĩa protocol mạng: `conf/*.proto` (protobuf, đã ở dạng text).

## Cách chạy lại từ đầu

```bash
python sng_decrypt.py apk/assets decrypted/assets "**/*"
python axml.py apk/AndroidManifest.xml > decrypted/AndroidManifest.xml
python sng_decrypt.py vn/obb/assets vn/decrypted/assets "**/*"
python sng_decrypt.py vn/apk/assets vn/decrypted/apk_assets "**/*"
python axml.py vn/apk/AndroidManifest.xml > vn/AndroidManifest.xml

python inventory.py                                             # → inventory.json
python build_spec.py
python build_spec.py --assets vn/decrypted/assets --out server-spec-vn
cd server-spec && python build_page.py && python build_page.py ../server-spec-vn
cd .. && python diff_api.py server-spec server-spec-vn
```
