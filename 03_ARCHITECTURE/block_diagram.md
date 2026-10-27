# D07 · Sơ đồ khối bên trong (Block Diagram)

---

## 1. Bốn bộ đếm chữ số nối theo chuỗi tràn, đọc từ `d07_bcd_core.sv`

```
   enable ──┐
   tick_1hz ┴─▶ ADV = enable & tick_1hz          (cell _064_ and2 / _065_ nand2)
                       │
       ┌───────────────┼───────────────┬───────────────┬────────────────┐
       ▼               ▼               ▼               ▼                │
  ┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐           │
  │① SU     │     │② ST     │     │③ MU     │     │④ MT     │           │
  │ mod-10  │ C0  │ mod-6   │ C1  │ mod-10  │ C2  │ mod-6   │ (C3 bị bỏ)│
  │ 4 FF    ├────▶│ 4 FF    ├────▶│ 4 FF    ├────▶│ 4 FF    ├───────╳   │
  │ 0…9     │     │ 0…5     │     │ 0…9     │     │ 0…5     │           │
  └────┬────┘     └────┬────┘     └────┬────┘     └────┬────┘           │
       │               │               │               │                │
       ▼               ▼               ▼               ▼                │
 second_units[3:0] second_tens[3:0] minute_units[3:0] minute_tens[3:0]   │
   (4 bit dùng)     (3 dùng + 1     (4 bit dùng)     (3 dùng + 1         │
                     HẰNG 0)                          HẰNG 0)           │
  rst_n ───────────────────────────────────────────────────────────────┘
        (AND vào đường D của cả 16 FF — reset ĐỒNG BỘ)

  ĐIỀU KIỆN CARRY (đây mới là phần đáng đọc — xem §3):
     C0 = ADV & (SU ≥ 9)
     C1 = C0  & (ST ≥ 5)          = ADV & (SU≥9) & (ST≥5)
     C2 = C1  & (MU ≥ 9)          = ADV & (SU≥9) & (ST≥5) & (MU≥9)
     C3 = C2  & (MT ≥ 5)          → không nối đi đâu: MT quay về 0, hết chuỗi
```

Không có cổng ra nào cần logic tổ hợp: **cổng ra chính là `Q` của flip-flop**. Netlist xác
nhận — `dfxtp_1 _122_ (.CLK(clk), .D(_000_), .Q(minute_tens[0]))`, `Q` nối thẳng ra chân.
Hệ quả: **không có đường reg→out nào có cell logic**, và không có glitch trên cổng ra.

## 2. Bảng ánh xạ cấu trúc RTL → phần cứng sinh ra

| Dòng RTL | Cấu trúc | Phần cứng thật trong netlist | Số cell |
|---|---|---|---:|
| 17 `enable && tick_1hz` | Điều kiện tiến | `and2_0 _064_` (dạng thuận) + `nand2_1 _065_` (dạng đảo) — tool sinh **cả hai** vì cả hai đều được dùng | **2** |
| 18 `second_units < 4'd9` | Phát hiện "SU đầy" | `o31ai_1 _066_` — **1 cell duy nhất** | **1** |
| 22 `second_tens < 4'd5` | Phát hiện "ST đầy" | `clkinv_1 _061_` (`~ST3`) + `o21ai_0 _063_` | **2** |
| 26 `minute_units < 4'd9` | Phát hiện "MU đầy" | `o31ai_1 _071_` + `o31a_1 _070_` (dạng thuận) | **2** |
| 30 `minute_tens < 4'd5` | Phát hiện "MT đầy" | `nor2_1 _073_` + `o21ai_0 _074_` + `nand2b_1 _075_` | **3** |
| **Toàn bộ `if` lồng 4 tầng** | **Các nút carry C0…C2** | `nor2_1 _067_`(C0) · `a211oi_1 _068_`+`a211o_1 _069_`(C1) · **`a2111oi_0 _072_`(C2)** | **4** |
| 19, 23, 27, 31 `+ 4'd1` | 4 bộ tăng BCD | `a21oi_1`×8, `o21ai_0`×8, `nor2_1`×~11, `and2_0`×4, `nand2_1`×4, `xnor2_1`×3, `a211o_1`, `o31ai_1`, `a31oi_1`, `a21bo_1`, `a21boi_0`, `and3b_1`, `nand4b_1`, `nor3_1`, `nor3b_1`, `or3_1`, `or4_1`, `lpflow_isobufsrc_1` | **≈ 47** |
| 11 `always_ff` | 16 thanh ghi | `dfxtp_1` × **16** | **16** |
| 12–16 `if (!rst_n)` | **Không FF có chân reset**; `rst_n` gộp vào logic `D` | nằm trong số cell ở trên | 0 riêng |
| | | **Tổng** | **77** |

Nguồn: `synth_stat.txt` + `netlist.v`. Phân bổ từng nhóm là **ước khi đọc netlist**; tổng
77 và 16 FF là số đo thật.

## 3. Phát hiện quan trọng nhất: chuỗi tràn 4 tầng bị **làm phẳng thành cổng đơn** — trả lời Charter mục 2 câu 1

> **Charter mục 2, câu 1:** *"Chuỗi tràn giây→phút hiện ra trong phần cứng như thế nào?"*

Câu trả lời trực giác — "một chuỗi 4 tầng carry nối tiếp, giống ripple-carry" — **sai**.
Đọc netlist:

```verilog
// Tầng chung: các điều kiện "chữ số đầy", tính SONG SONG
sky130_fd_sc_hd__nand2_1 _065_ (.A(enable), .B(tick_1hz), .Y(_020_));          // ~ADV
sky130_fd_sc_hd__o31ai_1 _066_ (.A1(su[2]), .A2(su[1]), .A3(su[0]), .B1(su[3]), .Y(_021_));  // ~(SU≥9)
sky130_fd_sc_hd__clkinv_1 _061_ (.A(st[3]), .Y(_016_));                        // ~ST3
sky130_fd_sc_hd__o21ai_0 _063_ (.A1(st[1]), .A2(st[0]), .B1(st[2]), .Y(_018_));
sky130_fd_sc_hd__o31ai_1 _071_ (.A1(mu[2]), .A2(mu[1]), .A3(mu[0]), .B1(mu[3]), .Y(_026_));  // ~(MU≥9)

// CARRY C0 — 1 cell
sky130_fd_sc_hd__nor2_1 _067_ (.A(_020_), .B(_021_), .Y(_022_));

// CARRY C1 — 1 cell (4 đầu vào)
sky130_fd_sc_hd__a211oi_1 _068_ (.A1(_016_), .A2(_018_), .B1(_020_), .C1(_021_), .Y(_023_));

// CARRY C2 — 1 cell (5 đầu vào)  ← CẢ BỐN TẦNG TRÀN TRONG MỘT CỔNG
sky130_fd_sc_hd__a2111oi_0 _072_ (.A1(_016_), .A2(_018_), .B1(_020_),
                                   .C1(_021_), .D1(_026_), .Y(_027_));
```

`_027_ = ~((_016_ & _018_) | _020_ | _021_ | _026_)` — khai triển ra:

```
   _027_ = 1  ⟺  enable & tick_1hz  &  (SU ≥ 9)  &  (ST ≥ 5)  &  (MU ≥ 9)
```

**Toàn bộ bốn tầng `if` lồng nhau của RTL trở thành MỘT cổng AND-OR-Invert 5 đầu vào.**
Không có chuỗi nối tiếp, không có ripple. Lý do: các điều kiện "chữ số đầy" **không phụ
thuộc lẫn nhau** — `SU ≥ 9` và `ST ≥ 5` đọc từ hai thanh ghi khác nhau, tính được song
song. Chỉ phép **AND** cuối cùng là chung, và AND thì kết hợp được nên gộp phẳng được.

Đối chiếu với đề A01 (ripple-carry): ở đó `carry[i+1]` cần `carry[i]` **đã ổn định** vì
`carry[i+1] = a&b | (a^b)&carry[i]` — phụ thuộc thật sự. Ở D07 không có phụ thuộc như vậy.
**Cùng gọi là "chuỗi tràn", nhưng một cái `O(N)` và một cái `O(1)` về độ sâu.**

> Đây là câu trả lời đầy đủ cho Charter mục 2 câu 1: *chuỗi tràn hiện ra trong phần cứng
> **không phải** như một chuỗi, mà như một **cây điều kiện phẳng**; độ sâu logic của tràn
> 4 tầng bằng đúng độ sâu của tràn 1 tầng.*

## 4. Phát hiện thứ hai: cái giá của việc gộp phẳng — **một cổng chiếm 44 % đường tới hạn**

Gộp phẳng không miễn phí. Cell `_072_ a2111oi_0` có 5 đầu vào, dùng biến thể **`_0` (drive
nhỏ nhất)**, và lái **7 tải**. STA đo được:

```
     7    0.02    1.25    1.05    2.13 ^ _072_/Y (sky130_fd_sc_hd__a2111oi_0)
   ▲      ▲       ▲       ▲
   │      │       │       └── ĐỘ TRỄ CỦA RIÊNG CELL NÀY: 1,05 ns
   │      │       └────────── slew đầu ra: 1,25 ns  (rất xấu)
   │      └────────────────── điện dung tải: 0,02 pF
   └───────────────────────── fanout: 7
```

So với toàn bộ đường tới hạn:

| Chặng | Độ trễ | % của arrival 2,40 ns |
|---|---:|---:|
| `set_input_delay` (giả định) | 1,00 ns | 41,7 % |
| `_065_ nand2_1` | 0,07 ns | 2,9 % |
| **`_072_ a2111oi_0`** | **1,05 ns** | **43,8 %** |
| `_085_ and3b_1` | 0,27 ns | 11,3 % |
| **Tổng arrival** | **2,40 ns** | 100 % |

**Một cổng duy nhất chiếm 44 % thời gian đến, và 75 % phần độ trễ logic thật (1,05/1,40).**

So sánh với hai đề cùng nhóm để thấy mức bất thường:

| Đề | Số cell trên đường tới hạn | Độ trễ logic thuần | Trung bình mỗi cell |
|---|---:|---:|---:|
| D05 | 4 | 0,60 ns | 0,15 ns |
| D06 | 6 | 0,98 ns | 0,16 ns |
| **D07** | **3** | **1,40 ns** | **0,47 ns** ← **gấp 3 lần** |

> **Kết luận kỹ thuật:** D07 có đường tới hạn **nông nhất** (3 cell logic) nhưng **chậm
> nhất** trong ba đề. Nút thắt **không phải độ sâu logic** mà là **khả năng lái của một
> cell** — cell `_0` nhỏ nhất với 5 đầu vào và fanout 7. Đây là vấn đề mà **chỉ đọc RTL
> không bao giờ thấy được**.
>
> Cách sửa thuộc về công cụ, không thuộc về RTL: thêm bước `buffer`/`upsize` trong
> `abc`/OpenROAD, hoặc đặt `set_max_fanout` trong SDC. **Không được sửa netlist bằng tay**
> (Charter mục 3: ngoài phạm vi).

## 5. Phát hiện thứ ba: đường tới hạn kết thúc ở một flip-flop **không bao giờ đổi giá trị**

```
Startpoint: tick_1hz      Endpoint: _125_      Slack: 7,49 ns (MET)
```

Tra netlist: `_125_` chính là **`minute_tens[3]`**.

```verilog
sky130_fd_sc_hd__and3b_1 _085_ (.A_N(_027_), .B(rst_n), .C(minute_tens[3]), .X(_003_));
sky130_fd_sc_hd__dfxtp_1 _125_ (.CLK(clk), .D(_003_), .Q(minute_tens[3]));
```

`minute_tens[3]next = rst_n & minute_tens[3] & ~C2`. Vế phải **nhân với chính nó** — nếu
bit đang là 0, nó vĩnh viễn là 0. Sau reset nó bằng 0. Vì `MT ≤ 5` nên bit 3 **không bao
giờ cần** bằng 1.

**Đường có slack nhỏ nhất trong toàn thiết kế kết thúc ở một flip-flop hằng 0.**

| Câu hỏi | Trả lời |
|---|---|
| Vì sao Yosys không xoá FF này? | Vì `minute_tens` là **cổng ra chính** — công cụ không được đổi giao diện module. Nó cũng không chứng minh được `MT ≤ 5` nếu không phân tích khả đạt (reachability), điều mà tổng hợp logic thông thường không làm |
| Vì sao OpenSTA vẫn tính đường này? | STA là phân tích **cấu trúc**, không phân tích **giá trị**. Có đường vật lý từ `tick_1hz` tới `D` của `_125_` thì nó phải được tính |
| Đây có phải "đường giả" (false path) không? | **Có, theo nghĩa chức năng** — nhưng nó **không** được khai báo là false path trong SDC, nên tool coi là thật. Khai báo false path cho nó là **hợp lệ và đúng**, nhưng phải có lập luận chặt |
| Nếu bỏ hai bit hằng 0 thì sao? | Đổi cổng ra thành `[2:0]` → mất 2 FF (còn **14**), mất luôn đường tới hạn hiện tại. Nhưng vi phạm định dạng BCD 4 bit chuẩn cho giải mã 7 vạch |

Cùng dạng cho `second_tens[3]` (FF `_132_`):
`_011_ = nor2(~second_tens[3], ~((~ADV | ~(SU≥9)) & rst_n))` = `second_tens[3] & rst_n & ~C0`
→ cũng **hằng 0**.

## 6. Khối con nào nằm trên đường tới hạn?

| Khối con | Trên đường tới hạn? | Bằng chứng |
|---|:-:|---|
| Logic `ADV = enable & tick_1hz` | ✅ (`_065_`) | cell thứ 1 |
| Phát hiện "chữ số đầy" (`_016_`,`_018_`,`_021_`,`_026_`) | ✅ (là đầu vào của `_072_`) | cell thứ 2 |
| **Cây carry gộp phẳng (`_072_`)** | ✅ **chiếm 44 % thời gian** | cell thứ 2, delay 1,05 ns |
| Bộ tăng `minute_tens` (`_085_`) | ✅ | cell thứ 3 |
| Bộ tăng `second_units`, `second_tens`, `minute_units` | ❌ | không xuất hiện trong 3 đường xấu nhất |
| Đường reg→out | ❌ **không tồn tại cell nào** | `Q` nối thẳng cổng ra |

Ba đường xấu nhất (slack 7,49 / 7,50 / …) **đều** bắt đầu từ `tick_1hz` và **đều** đi qua
`_065_ → _072_`. Tức là `_072_` là nút cổ chai duy nhất của toàn thiết kế.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
