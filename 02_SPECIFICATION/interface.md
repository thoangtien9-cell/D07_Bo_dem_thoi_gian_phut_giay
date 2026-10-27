# D07 · Giao diện (Interface)

---

## 1. Ánh xạ chân theo Charter (mục 4)

> Theo danh mục đề: uio_in[0]=xung 1 Hz · uio_in[1]=tạm dừng · uio_in[2]=đặt lại · uo_out[7:0]=BCD phút hoặc giây · uio_out[0]=đang xuất phút
> Ngân sách chân: 3 bit vào + 9 bit ra = 12 trên 24 chân.
> Lỗi ánh xạ cần sửa trước khi thiết kế: chân uio[0] bị gán vừa làm đầu vào vừa làm đầu ra. Tổng bit vẫn trong 24 chân nên chỉ cần đánh số lại.
> Một ô Tiny Tapeout có đúng 24 chân: ui_in 8 chỉ vào, uo_out 8 chỉ ra, uio 8 chọn chiều từng chân. uio_in và uio_out là cùng một bộ chân vật lý.

## 2. Bảng giao diện đã CHỐT — module `d07_bcd_core`

Bảng dưới đây **đọc trực tiếp từ RTL** (`04_IMPLEMENTATION/rtl/`), không phải chép tay,
nên luôn nhất quán với mã nguồn.

| Tín hiệu | Chiều | Độ rộng (bit) | Vai trò | Mức tích cực / giả định |
|---|---|---:|---|---|
| `clk` | input | 1 | clock | |
| `rst_n` | input | 1 | reset (đồng bộ hoá trạng thái) | |
| `tick_1hz` | input | 1 | dữ liệu vào | |
| `enable` | input | 1 | điều khiển | |
| `minute_tens[3:0]` | output | 4 | kết quả ra | |
| `minute_units[3:0]` | output | 4 | kết quả ra | |
| `second_tens[3:0]` | output | 4 | kết quả ra | |
| `second_units[3:0]` | output | 4 | kết quả ra | |

**Tổng hợp:** 4 cổng vào (4 bit) · 4 cổng ra (16 bit).

**Clock:** `clk`

**Reset:** `rst_n`

## 3. Ngân sách chân Tiny Tapeout

| Hạng mục | Số bit |
|---|---:|
| Tổng bit vào | **4** |
| Tổng bit ra | **16** |
| **Tổng cộng** | **20** |
| Ô Tiny Tapeout có | **24** |
| **Chênh lệch** | **4 chân còn dư** |

> Nhắc lại cấu trúc chân Tiny Tapeout: một ô có đúng 24 chân — `ui_in` 8 chỉ vào,
> `uo_out` 8 chỉ ra, `uio` 8 chọn chiều từng chân; **`uio_in` và `uio_out` là cùng một bộ
> chân vật lý**.

> ✅ Ngân sách chân **đủ**: tổng số bit logic nằm trong 24 chân vật lý, không cần
> nạp nhiều nhịp và không phải hy sinh tín hiệu nào.

## 4. Điều kiện hợp lệ của đầu vào

| Điều kiện | Ai bảo đảm |
|---|---|
| Các cổng vào không chứa `X`/`Z` khi lấy mẫu | Tầng ngoài |
| Tín hiệu vào đồng bộ với `clk` hoặc đã qua bộ đồng bộ | Tầng ngoài |
| Chuỗi reset được giữ đủ dài trước khi bắt đầu hoạt động | Tầng ngoài |

---

*Phiên bản: v1.0 · Ngày: 2026-09-24 · Truy vết: REQ-D07-002, AC-1.*
