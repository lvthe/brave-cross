# brave-cross

Dịch ngược game **"Búa Tạ / Siêu Anh Hùng"** (Cocos2d-x + Lua, 2017) và dựng lại
nó thành game chơi offline — game đã đóng cửa, không còn server.

Hai bản được phân tích song song: bản CN `com.xh.dachui.xsj` 1.25.78923 và bản
VN `com.cmn.buatanew` 1.26.81485.

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
offline. Muốn chạy lại thì tự lấy APK về, đặt vào thư mục gốc, làm theo mục
"Cách chạy lại từ đầu" trong [`work/README.md`](work/README.md).

## Trạng thái

Đã xong:

* Phá lớp mã hoá tài nguyên `sngFile` (many-time pad trên 952 file Lua dùng
  chung keystream) — giải và mã hoá ngược đều trùng từng byte
* Rút đặc tả server tự động từ mã Lua: 584 API (CN) / 614 API (VN), gồm cả 100+
  API mà quét thông thường bỏ sót vì tên hàm chỉ sinh ra lúc chạy
* Lớp offline: chặn ở `CallServer`/`CallLocal`, tái dùng chính luật chơi client
  đã mang sẵn, kho dữ liệu 33 bảng lưu ra JSON

Đang làm: **9/614 handler**. Chuỗi đăng nhập → bắt tay → vào game đã chạy thông
trong môi trường test (23/23), chưa kiểm chứng trên máy Android thật.
