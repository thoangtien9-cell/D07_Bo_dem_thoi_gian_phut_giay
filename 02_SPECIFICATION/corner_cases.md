# D07 · Ca biên và ca kiểm thử (Corner Cases)

---

## 1. Đọc testbench thật — ba lỗ hổng, trong đó một lỗ hổng đúng vào ca Charter gọi tên

File: `05_VERIFICATION/testbench/d07_bcd_tb.sv` (51 dòng).

### 🔎 Phát hiện 1 — testbench **không instantiate mô hình chuẩn**

Tìm toàn file: chỉ có **một** instance duy nhất:

```verilog
d07_bcd_core dut(                                        // dòng 6–10
    .clk(clk), .rst_n(rst_n), .tick_1hz(tick_1hz), .enable(enable),
    .minute_tens(mt), .minute_units(mu),
    .second_tens(st), .second_units(su)
);
```

**Không có `d07_reference ref_i(...)`.** Khác hẳn D05 và D06 (cả hai đều đấu song song
DUT với mô hình chuẩn). Lý do kỹ thuật: `05_VERIFICATION/golden_model/d07_reference.sv`
khai báo cổng `minute[5:0]`, `second[5:0]` — giao diện **nhị phân**, không phải BCD. Nó là
mô hình của `d07_binary_core`, **không** của top. Hai giao diện không đấu được với nhau nếu
không có bộ chuyển đổi nhị phân → BCD, mà bộ đó không tồn tại trong hồ sơ.

Hệ quả: toàn bộ kiểm chứng của mô phỏng RTL nằm ở **4 câu `assert` hằng số**:

| Dòng | Assert | Kiểm gì |
|---:|---|---|
| 27 | `{mt,mu,st,su} == 16'h0000` | Trạng thái sau reset |
| 31 | `{mt,mu,st,su} == 16'h0059` | Đếm 59 bước → `00:59` |
| 35 | `{mt,mu,st,su} == 16'h0100` | Tràn 2 tầng → `01:00` |
| 40 | `{mt,mu,st,su} == 16'h0100` | Giữ khi `enable=0` |

Bốn assert này phủ **62 bước tiến đầu tiên** trong tổng **3602 bước** của lần chạy.

### 🔎 Phát hiện 2 — **ca `59:59 → 00:00` KHÔNG được thực hiện**, mô phỏng dừng đúng tại `59:59`

Đây là phát hiện quan trọng nhất của cả đề. Đếm lại bằng số:

```verilog
for(i=0;i<59;i=i+1) tick();        // dòng 30: 00:00 → 00:59     (59 bước)
tick();                            // dòng 34: 00:59 → 01:00     (1 bước)
enable=0; repeat(3) tick();        // dòng 38–39: giữ            (0 bước tiến)
enable=1;
for(i=0;i<59*60-1;i=i+1) tick();   // dòng 45: 3539 bước tiến
$display("D07 BCD TB PASS"); $finish;   // dòng 48–49
```

| Mốc | Số bước tiến tích luỹ | Thời gian đạt được |
|---|---:|---|
| Sau reset | 0 | `00:00` |
| Sau dòng 30 | 59 | `00:59` |
| Sau dòng 34 | 60 | `01:00` |
| Sau dòng 39 (`enable=0`) | 60 | `01:00` (giữ) |
| Sau dòng 45 (**+3539**) | **3599** | **`59:59`** |
| `$finish` | — | **`59:59`** ← dừng ở đây |

`3599` giây = `59 × 60 + 59` = **59:59**. Bước tiến thứ **3600** — bước duy nhất kiểm được
`59:59 → 00:00` — **không bao giờ được thực hiện**.

**Kiểm chứng bằng số liệu thật:** tổng số cạnh lên `clk` trong lần chạy là
`2 + 59 + 1 + 3 + 3539 = 3604`. Cạnh lên thứ `n` xảy ra tại `t = 5 + 10(n−1)`, nên cạnh lên
thứ 3604 tại `t = 36035`; task `tick()` có `#1` sau đó → **36036 ns**. Khớp **chính xác**
dòng cuối `simulation.log`: *"$finish called at 36036"*. Phép đếm trên là **đọc từ số liệu
thật**, không phải suy đoán.

Và dòng 46 ghi thẳng ra rằng tác giả đã biết chỗ thiếu:

```verilog
// Boundary checks are handled by reference/exhaustive model as well.
```

Nhưng như phát hiện 1 đã chỉ ra, **mô hình chuẩn không được đấu vào mô phỏng RTL**. Ca
`59:59 → 00:00` chỉ tồn tại trong `reference_model.py` dòng 23
(`assert step(59, 59, True, True) == (0, 0)`) — tức là **trên mô hình Python, không phải
trên RTL**.

> ❗ Charter mục 8 liệt kê *"chuyển 59:59→00:00"* là ca **bắt buộc**, và Charter mục 10
> gọi đúng nó là **"chỗ hay tắc"**: *"Ca 59:59→00:00 là ca duy nhất kiểm được cả hai tầng
> tràn cùng lúc — hay bị bỏ."* Dự đoán của Charter **đã thành hiện thực** trong chính hồ
> sơ này. Đây là bằng chứng dạy học có giá trị cao nhất của đề D07.

### 🔎 Phát hiện 3 — `tick_1hz` **luôn bằng 1** tại mọi cạnh lên sau reset

```verilog
task tick;                                    // dòng 14–20
    begin
        tick_1hz = 1;
        @(posedge clk); #1;
        tick_1hz = 0;
    end
endtask
```

`tick_1hz` xuống 0 tại `t = cạnh_lên + 1`, nhưng lời gọi `tick()` kế tiếp đặt lại `= 1`
**tại cùng thời điểm mô phỏng đó**. Giữa hai cạnh lên liên tiếp, `tick_1hz` bằng 0 trong
**0 đơn vị thời gian**. Kết quả: tại **mọi** cạnh lên sau reset, `tick_1hz = 1`.

Hệ quả nghiêm trọng: **một DUT bỏ hoàn toàn điều kiện `tick_1hz` vẫn PASS testbench này.**

```verilog
end else if (enable && tick_1hz) begin    // RTL thật, dòng 17
end else if (enable) begin                // biến thể SAI — vẫn PASS
```

Biến thể sai đó sẽ đếm mỗi chu kỳ clock thay vì mỗi giây — tức là đồng hồ chạy nhanh gấp
`f_clk` lần. **Chức năng cốt lõi của đề ("từ xung 1 Hz") chưa có bằng chứng.**

### 🔎 Phát hiện 4 — không có kiểm INV-1 (miền giá trị BCD)

Suốt 3599 bước tiến, không assert nào kiểm `ST ≤ 5` hay `SU ≤ 9`. Nếu một chữ số rơi ra
ngoài miền BCD, testbench chỉ phát hiện được nếu lỗi đó **tình cờ** làm sai một trong 4
mốc hằng số đã kiểm.

## 2. Ca bắt buộc của Charter mục 8

| Ca | Charter yêu cầu | Lý do kỹ thuật vì sao được chọn | TB SV? | Python? |
|---|---|---|---|---|
| **CC-1** | Chuyển `58→59→00` ở giây (phải tăng phút) | Tràn **2 tầng**. Đây là ca ngắn nhất chứng minh chuỗi tràn có hoạt động — nếu carry từ `SU` không tới `MU`, ca này lộ ngay | ✅ dòng 30–35 | ✅ dòng 21–22 |
| **CC-2** | Chuyển `59:59 → 00:00` | Tràn **4 tầng cùng lúc** — ca **duy nhất** kích hoạt đồng thời cả bốn điều kiện `SU≥9 & ST≥5 & MU≥9 & MT≥5`. Không ca nào khác chạm được cổng `_085_ and3b` với `_027_ = 1` | ❌ **KHÔNG** (§1, phát hiện 2) | ✅ dòng 23 |
| **CC-3** | Tạm dừng giữa chừng | Kiểm `enable` là điều kiện tiến, không phải điều kiện xuất. Đặt ở `01:00` — một mốc đã biết chắc — nên sai lệch phát hiện được ngay | ✅ dòng 38–40 | ✅ dòng 25 |
| **CC-4** | Đặt lại | Kiểm reset ép cả 4 chữ số về 0 | ⚠️ **chỉ ở trạng thái `00:00`** — xem §4 TC-C | ❌ mô hình Python không có tham số `rst_n` riêng |

## 3. Phân loại ca theo tiêu chí kỹ thuật riêng của D07 — **số tầng tràn**

Đây là trục phân loại đúng bản chất, vì chi phí và rủi ro của mỗi bước tiến phụ thuộc vào
**bao nhiêu chữ số phải đổi cùng lúc**.

| Lớp | Số tầng tràn | Điều kiện | Ví dụ | Số lần trong 3600 bước | Kiểm bằng |
|---|---:|---|---|---:|---|
| **T0** | 0 | `SU < 9` | `00:00 → 00:01` | **3240** | ✅ TB (rất nhiều lần) |
| **T1** | 1 | `SU≥9`, `ST<5` | `00:09 → 00:10` | **300** | ✅ TB (dòng 30) |
| **T2** | 2 | `SU≥9`, `ST≥5`, `MU<9` | `00:59 → 01:00` | **54** | ✅ TB (dòng 34, có assert) |
| **T3** | 3 | `SU≥9`, `ST≥5`, `MU≥9`, `MT<5` | `09:59 → 10:00` | **5** | ⚠️ có xảy ra trong dòng 45, **không assert** |
| **T4** | **4** | `SU≥9`, `ST≥5`, `MU≥9`, `MT≥5` | **`59:59 → 00:00`** | **1** | ❌ **KHÔNG BAO GIỜ xảy ra** |

Kiểm tổng: `3240 + 300 + 54 + 5 + 1 = 3600` ✅

> Lớp **T4 chỉ xảy ra 1 lần trong 3600 bước** — xác suất bắt được bằng phép thử ngẫu nhiên
> ngắn là `1/3600`. Đó chính xác là lý do Charter mục 8 **gọi tên** ca này thay vì để tự do,
> và là lý do Charter mục 10 cảnh báo nó "hay bị bỏ".

**Đối chiếu với đường tới hạn thật** (`06_GDSII/sta/timing_report_max.txt`): endpoint là
`_125_` = `minute_tens[3]`, và cell quyết định trên đường đó là `_072_ a2111oi_0` — chính
là cell tính `_027_`, tức **carry vào `minute_tens`**, chỉ tích cực ở lớp T3 và T4. Vậy lớp
T4 vừa là ca **khó nhất về chức năng**, vừa là ca **duy nhất kích hoạt đầy đủ đường tới
hạn**. Bỏ nó là bỏ cả hai thứ cùng lúc.

Trục phân loại thứ hai, theo **tính hợp lệ của trạng thái**:

| Lớp | Trạng thái | Số tổ hợp | Kiểm bằng |
|---|---|---:|---|
| V-hợp lệ | `SU≤9, ST≤5, MU≤9, MT≤5` | **3600** | ✅ `reference_model.py` dòng 14–18 |
| V-bất hợp lệ | mọi tổ hợp còn lại trong `2¹⁶` | **61 936** | ❌ chưa kiểm — nhưng RTL **tự phục hồi** (xem `functional_spec.md` §7) |

## 4. Ca tự xây dựng bổ sung (Charter mục 8 yêu cầu ≥ 2, có ca biên)

| Ca | Kịch bản | Vì sao cần | Trạng thái |
|---|---|---|---|
| **TC-A (ca biên)** | Thêm **đúng 1 bước tiến** sau dòng 45 và assert `{mt,mu,st,su} == 16'h0000` | Thực hiện lớp **T4** — ca Charter mục 8 bắt buộc, hiện **hoàn toàn trắng**. Sửa **2 dòng** | ⬜ chưa có |
| **TC-B (ca biên)** | `enable=1, tick_1hz=0` trong 10 chu kỳ clock, assert giữ nguyên | Phủ **INV-5**. Không có ca này, một DUT bỏ hẳn `tick_1hz` vẫn PASS | ⬜ chưa có |
| **TC-C (ca biên)** | Chạy tới `37:42` rồi hạ `rst_n` 1 chu kỳ, assert `00:00` | TB hiện chỉ reset khi đồng hồ **vốn đã** ở `00:00` → **không phân biệt được** "reset về 0" với "chưa bao giờ rời 0" | ⬜ chưa có |
| **TC-D** | Assert miền BCD `(su<=9)&&(st<=5)&&(mu<=9)&&(mt<=5)` **sau mỗi bước tiến** | Phủ **INV-1**; biến 3600 bước từ "chạy cho có" thành 3600 điểm kiểm thật | ⬜ chưa có |
| **TC-E** | Ép `second_units = 12` qua `force`, tiến 1 bước, assert về `0` và có carry | Phủ **INV-9** — chứng minh tính tự phục hồi do dùng `<` thay `==` | ⬜ chưa có |
| **TC-F** | Kiểm mốc `09:59 → 10:00` (lớp **T3**) | T3 có xảy ra trong dòng 45 nhưng **không assert**; 5 lần trôi qua mà không ai nhìn | ⬜ chưa có |

### Bản vá tối thiểu cho TC-A (chưa áp dụng — chờ thầy duyệt)

```diff
     // Fast-forward from 01:00 to 59:59 by simulation.
     for(i=0;i<59*60-1;i=i+1) tick();
-    // Boundary checks are handled by reference/exhaustive model as well.
+    assert({mt,mu,st,su} == 16'h5959)
+        else $fatal(1, "Khong dat toi 59:59, dang o %h", {mt,mu,st,su});
+
+    // Ca Charter muc 8: 59:59 -> 00:00 (tran ca 4 tang)
+    tick();
+    assert({mt,mu,st,su} == 16'h0000)
+        else $fatal(1, "Quay vong 59:59->00:00 SAI, dang o %h", {mt,mu,st,su});
 
     $display("D07 BCD TB PASS"); $finish;
```

**Chi phí: 2 dòng assert + 1 lời gọi `tick()`.** Đổi lại: phủ được ca bắt buộc quan trọng
nhất của Charter mục 8, và kích hoạt đầy đủ đường tới hạn của thiết kế.

### Bản vá tối thiểu cho TC-B

```verilog
// Kiem rang tick_1hz that su la dieu kien tien
enable = 1; tick_1hz = 0;
repeat(10) @(posedge clk);
#1;
assert({mt,mu,st,su} == 16'h0100)
    else $fatal(1, "Dem khi tick_1hz=0 — DUT bo qua dieu kien tick!");
```

## 5. Ca **KHÔNG** áp dụng cho đề này

| Ca thường gặp | Vì sao không áp dụng | Bằng chứng |
|---|---|---|
| Giờ, ngày, lịch | Charter mục 3 liệt **ngoài phạm vi**; RTL dừng ở phút | Charter mục 3; RTL không có `hour` |
| Đồng bộ thời gian ngoài (NTP, RTC) | **Ngoài phạm vi**; không có cổng nạp giá trị | Charter mục 3; danh sách cổng RTL |
| Đếm lùi (đồng hồ đếm ngược) | Không yêu cầu; RTL chỉ có `+ 4'd1` | `d07_bcd_core.sv` dòng 19, 23, 27, 31 |
| Nạp giá trị đầu (đặt giờ) | Không có cổng `load`/`data_in` | Danh sách cổng RTL |
| Năm nhuận, giây nhuận | Ngoài phạm vi tuyệt đối | Charter mục 3 |
| Ca glitch của mạch tổ hợp | Cổng ra **chính là** `Q` của FF — không có logic tổ hợp nào giữa FF và chân ra | Netlist: `Q(minute_tens[0])` nối thẳng cổng ra |
| Ca xung `tick_1hz` nhanh hơn `clk` | Vô nghĩa vật lý: 1 Hz ≪ tần số clock | Charter mục 1 |
| Số âm / bù 2 | Thời gian là đại lượng không dấu | RTL dùng `logic [3:0]` |

## 6. Ca phải bổ sung khi chuyển sang gate-level / post-layout

| Ca | Vì sao chỉ xuất hiện ở tầng sau | Cần gì |
|---|---|---|
| Mô phỏng gate-level lớp **T4** trên `netlist.v` | Đây là lần duy nhất `_072_ a2111oi_0` (cell **1,05 ns**, chậm nhất thiết kế) lan tới `_085_` và `_125_`. Mô phỏng RTL zero-delay không thấy | Icarus + `sky130_fd_sc_hd.v` + netlist |
| Kiểm slew trên nút `_027_` | STA báo slew đầu ra của `_072_` là **1,25 ns** với fanout 7 — rất xấu. Sau routing, RC dây sẽ làm tệ thêm | STA post-route với SPEF |
| Kiểm hai FF hằng 0 (`second_tens[3]`, `minute_tens[3]`) | Ở RTL chúng "vô hại". Ở gate-level chúng vẫn tiêu công suất clock và chiếm diện tích | Gate-level sim + power post-CTS |
| Vi phạm setup trên `tick_1hz` | `tick_1hz` là startpoint của đường tới hạn (arrival **2,40 ns**). Nếu nó đến từ bộ dao động ngoài chip, độ trễ thật có thể khác giả định 1,00 ns | STA với `set_input_delay` thật |
| Hold ở góc nhanh | `timing_report_min.txt` hiện chỉ có góc `tt` | STA `ss`, `ff` |
| Skew giữa 16 FF sau CTS | `clock network delay (ideal)` = 0,00 — cây clock chưa tồn tại | LibreLane tới CTS |
| X-propagation sau bật nguồn | 16 FF khởi tạo X; cần chứng minh **một** cạnh lên với `rst_n=0` xoá hết | Gate-level sim `+define+XPROP` |

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
