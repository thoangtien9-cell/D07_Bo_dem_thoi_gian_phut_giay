# D07 · Đặc tả chức năng (Functional Specification)

---

## ⚠️ CẢNH BÁO TUÂN THỦ — Charter mục 4 CHƯA THOẢ

Đối chiếu ánh xạ chân Charter mục 4 với danh sách cổng thật của
`04_IMPLEMENTATION/rtl/d07_bcd_core.sv` (dòng 1–10):

| # | Charter mục 4 yêu cầu | RTL `d07_bcd_core` thật có | Trạng thái |
|---|---|---|---|
| C4-1 | `uio_in[0]` = xung 1 Hz | `tick_1hz` | ✅ THOẢ |
| C4-2 | `uio_in[1]` = **tạm dừng** (pause) | `enable` = **cho phép** | ⚠️ **NGƯỢC CỰC** — `pause = ~enable` |
| C4-3 | `uio_in[2]` = đặt lại | `rst_n` (tích cực thấp, reset đồng bộ) | ⚠️ **NGƯỢC CỰC** |
| C4-4 | **`uo_out[7:0]` = BCD phút HOẶC giây** (ghép kênh) | **4 chữ số BCD xuất SONG SONG, 16 bit** | ❌ **CHƯA THOẢ** |
| C4-5 | **`uio_out[0]` = đang xuất phút** | **KHÔNG có cổng chọn kênh** | ❌ **CHƯA THOẢ** |
| C4-6 | Vỏ Tiny Tapeout (`ui_in`/`uo_out`/`uio_*`, `uio_oe`) | Không có module vỏ trong hồ sơ | ❌ **CHƯA THOẢ** |

**Bằng chứng C4-4 và C4-5:** RTL khai báo bốn cổng ra 4 bit độc lập
(`minute_tens`, `minute_units`, `second_tens`, `second_units`), tổng **16 bit ra song song**.
Netlist xác nhận: `module d07_bcd_core(clk, rst_n, tick_1hz, enable, minute_tens,
minute_units, second_tens, second_units);` — không có cổng `minute_sel` hay tương đương,
không có cell mux 2-1 nào chọn giữa phút và giây.

**Hệ quả ngân sách chân:**

| | Charter dự kiến | RTL thật |
|---|---:|---:|
| Bit vào | 3 | **4** (`clk` tính riêng: `rst_n`, `tick_1hz`, `enable`) |
| Bit ra | 9 | **16** |
| **Tổng** | **12** / 24 | **20** / 24 |

Vẫn nằm trong 24 chân nên **khả thi**, nhưng tốn thêm **8 chân** so với thiết kế Charter,
và **không** thực hiện phần "ghép kênh + bit báo đang xuất phút" mà Charter mục 4 yêu cầu.

**Hệ quả về số ô nhớ — liên quan trực tiếp Charter mục 9:** vì không có bộ ghép kênh, cũng
**không có flip-flop chọn kênh**. Charter mục 10 ước "14 ô nhớ đếm + 1 chọn xuất ≈ 15–17".
Đo được **16 FF**, nhưng cấu thành khác hẳn ước lượng: **14 bit đếm hữu ích + 2 bit hằng 0
bắt buộc do độ rộng cổng ra + 0 bit chọn kênh**. Xem §5 để biết bằng chứng.

**Không tự sửa RTL.** Bản vá tối thiểu đề xuất (chờ thầy duyệt):

```verilog
input  logic       show_minute;                    // hoặc tự sinh từ bộ chia tần nội bộ
output logic [7:0] bcd_out;
output logic       is_minute;
assign bcd_out   = show_minute ? {minute_tens, minute_units}
                               : {second_tens, second_units};
assign is_minute = show_minute;
```

Chi phí: **8 cell mux 2-1** cho phần ghép kênh, **0 FF** nếu `show_minute` do tầng ngoài
cấp; **+1 FF** nếu tự sinh bằng bộ lật trạng thái nội bộ (đúng bằng "1 chọn xuất" mà
Charter mục 10 dự tính). Về cực tính `enable`/`pause`: chỉ cần một cổng NOT ở vỏ, hoặc ghi
rõ trong bảng giao diện rằng `uio_in[1]` được nối vào `~enable`.

---

## 1. Phát biểu hành vi (độc lập với hiện thực)

D07 là **hai bộ đếm modulo-60 lồng nhau**, mỗi bộ được biểu diễn bằng **hai chữ số BCD**.
Gọi `MT, MU, ST, SU` là bốn chữ số (chục phút, đơn vị phút, chục giây, đơn vị giây).

```
  Điều kiện tiến: ADV = enable AND tick_1hz         (lấy mẫu tại cạnh lên clk)

  Tại mỗi cạnh lên clk:
    rst_n = 0  →  MT ← 0 , MU ← 0 , ST ← 0 , SU ← 0
    rst_n = 1 và ADV = 1 :
        SU < 9  →  SU ← SU + 1                                   (không tràn)
        SU ≥ 9  →  SU ← 0 ,   VÀ:
             ST < 5  →  ST ← ST + 1                              (tràn 1 tầng)
             ST ≥ 5  →  ST ← 0 ,   VÀ:
                  MU < 9  →  MU ← MU + 1                         (tràn 2 tầng)
                  MU ≥ 9  →  MU ← 0 ,   VÀ:
                       MT < 5  →  MT ← MT + 1                    (tràn 3 tầng)
                       MT ≥ 5  →  MT ← 0                         (tràn 4 tầng: 59:59 → 00:00)
    rst_n = 1 và ADV = 0  →  giữ nguyên tất cả
```

> **Lưu ý về cách viết điều kiện:** RTL dùng `<` (nhỏ hơn) chứ **không** dùng `==` (bằng).
> Đây không phải chi tiết phong cách — nó quyết định hành vi ở trạng thái bất hợp lệ
> (xem §7). Mọi phát biểu trong tài liệu này dùng `≥` để phản ánh đúng mã nguồn.

## 2. Miền giá trị và ý nghĩa

| Chữ số | Miền hợp lệ | Số bit **cần** | Độ rộng cổng RTL | Bit thừa |
|---|---|---:|---:|---:|
| `second_units` (SU) | 0…9 | **4** | 4 | 0 |
| `second_tens` (ST) | 0…5 | **3** | 4 | **1** |
| `minute_units` (MU) | 0…9 | **4** | 4 | 0 |
| `minute_tens` (MT) | 0…5 | **3** | 4 | **1** |
| | | **14** | **16** | **2** |

Thời gian biểu diễn được: `00:00` … `59:59`, tổng **3600 trạng thái**, chu kỳ đúng **1 giờ**.
Mô hình chuẩn Python kiểm đúng điều này: `reference_model.py` dòng 14–19 —
`assert len(seen) == 3600` và `assert (m, s) == (0, 0)`.

## 3. Ràng buộc cấu trúc bắt buộc

Tên đề "Bộ đếm thời gian phút:giây từ xung 1 Hz" **không chỉ định** BCD hay nhị phân.
Charter mục 2 câu 2 đưa việc chọn thành **câu hỏi phải trả lời**, và Charter mục 10 chốt
dấu hiệu cho phương án BCD: *"BCD: 4+3+4+3 = 14 ô nhớ đếm + 1 chọn xuất ≈ 15–17 ô nhớ"*.

Hồ sơ có **cả hai** bản RTL:

| Cách | Trạng thái lưu | Số FF suy từ RTL | Có trong hồ sơ |
|---|---|---:|---|
| **(A) BCD 4 chữ số** | `MT, MU, ST, SU` × 4 bit | **16** (đo được) | `d07_bcd_core.sv` — **đang là top** |
| (B) Nhị phân 6 bit × 2 | `minute[5:0]`, `second[5:0]` | **12** (suy từ RTL) | `d07_binary_core.sv` — **không được instantiate**, ⬜ chưa tổng hợp |

Ràng buộc bắt buộc thật sự: **`tick_1hz` phải là điều kiện tiến, không phải clock.** RTL
làm đúng — chỉ có **một** miền clock (`clk`), `tick_1hz` là tín hiệu dữ liệu được lấy mẫu
đồng bộ. Netlist xác nhận: mọi `dfxtp_1` đều nối `.CLK(clk)`, không FF nào dùng `tick_1hz`
làm clock. Nếu viết `always_ff @(posedge tick_1hz)` sẽ sinh ra một miền clock thứ hai,
không tổng hợp được sạch và không phân tích STA được.

> ⚠️ **`d07_reference.sv` là mô hình nhị phân, KHÔNG phải mô hình của top.** Nó dùng
> `minute[5:0]`, `second[5:0]` — cùng giao diện với `d07_binary_core`, **không** cùng giao
> diện với `d07_bcd_core`. Vì vậy nó **không thể** được đấu song song với DUT, và testbench
> **không** instantiate nó (xem `corner_cases.md` §1).

## 4. Tính chất bất biến (invariants)

| # | Phát biểu | Kiểm bằng |
|---|---|---|
| **INV-1** | `SU ≤ 9`, `ST ≤ 5`, `MU ≤ 9`, `MT ≤ 5` ở mọi trạng thái đạt tới được sau reset | Suy từ RTL; ❌ **không có assertion nào kiểm** |
| **INV-2** | Chu kỳ lặp đúng **3600** bước tiến | `reference_model.py` dòng 14–19 ✅ |
| **INV-3** | Sau cạnh lên có `rst_n=0`: cả bốn chữ số = 0 | TB dòng 27 ✅ |
| **INV-4** | `enable = 0` ⇒ giữ nguyên bất kể `tick_1hz` | TB dòng 38–40 ✅ |
| **INV-5** | `tick_1hz = 0` ⇒ giữ nguyên bất kể `enable` | ❌ **KHÔNG kiểm** — `tick_1hz` luôn bằng 1 tại mọi cạnh lên sau reset |
| **INV-6** | Từ `00:59` bước tiếp phải cho `01:00` (tràn 2 tầng) | TB dòng 31–35 ✅ |
| **INV-7** | Từ `59:59` bước tiếp phải cho `00:00` (tràn 4 tầng) | ❌ **KHÔNG kiểm trong RTL** — chỉ có `reference_model.py` dòng 23. Xem §8 |
| **INV-8** | `minute_tens[3]` và `second_tens[3]` **hằng 0** sau reset | Cấu trúc netlist ✅ — xem §5 |
| **INV-9** | Mọi trạng thái BCD bất hợp lệ tự phục hồi trong **1 bước tiến** | Cấu trúc RTL (`<` thay vì `==`) ✅ — xem §7 |

> ❗ **INV-7 là ca mà Charter mục 8 liệt kê bắt buộc và Charter mục 10 gọi là "chỗ hay tắc"**
> (*"Ca 59:59→00:00 là ca duy nhất kiểm được cả hai tầng tràn cùng lúc — hay bị bỏ"*).
> Testbench hiện tại **dừng đúng tại 59:59** mà không bước tiếp. Chi tiết và bằng chứng ở
> `corner_cases.md` §1.

## 5. Vì sao đo được 16 flip-flop chứ không phải 14 — bằng chứng cấu trúc

Charter mục 9 đòi *"kiểm trong báo cáo tổng số flip-flop và đối chiếu với ước lượng"*.
Đo được: **16 `dfxtp_1`** (`06_GDSII/synthesis/synth_stat.txt`). Ước lượng lý thuyết là
**14**. Hai bit chênh lệch nằm đúng ở `second_tens[3]` và `minute_tens[3]`.

**Bằng chứng từ netlist — hai flip-flop này KHÔNG THỂ đổi giá trị:**

```verilog
// minute_tens[3], FF _125_ — chính là ENDPOINT của đường tới hạn
sky130_fd_sc_hd__and3b_1 _085_ (.A_N(_027_), .B(rst_n), .C(minute_tens[3]), .X(_003_));
sky130_fd_sc_hd__dfxtp_1 _125_ (.CLK(clk), .D(_003_), .Q(minute_tens[3]));
```

Khai triển: `minute_tens[3]next = rst_n & minute_tens[3] & ~carry`. Vế phải chứa
`minute_tens[3]` **nhân với** các điều kiện khác — nên nếu bit đang là 0, nó **vĩnh viễn**
là 0. Sau reset nó bằng 0. ⇒ **hằng 0**.

```verilog
// second_tens[3], FF _132_
sky130_fd_sc_hd__clkinv_1 _061_ (.A(second_tens[3]), .Y(_016_));
sky130_fd_sc_hd__o21ai_0  _109_ (.A1(_020_), .A2(_021_), .B1(rst_n), .Y(_053_));
sky130_fd_sc_hd__nor2_1   _110_ (.A(_016_), .B(_053_), .Y(_011_));
sky130_fd_sc_hd__dfxtp_1  _132_ (.CLK(clk), .D(_011_), .Q(second_tens[3]));
```

Khai triển: `_011_ = second_tens[3] & rst_n & ~carry_từ_SU`. Cùng dạng ⇒ **hằng 0**.

**Vì sao Yosys không xoá chúng?** Vì chúng là **cổng ra chính (primary output)**. Công cụ
tổng hợp không được phép thay đổi giao diện module — nó không biết tầng ngoài có đọc bit đó
hay không. Nếu đổi độ rộng cổng thành `output logic [2:0] second_tens`, hai FF này sẽ biến
mất và tổng còn **14**.

| Cấu thành 16 FF | Số bit | Ghi chú |
|---|---:|---|
| `second_units[3:0]` | 4 | đủ dùng (0…9) |
| `second_tens[2:0]` | 3 | đủ dùng (0…5) |
| `second_tens[3]` | **1** | **hằng 0** — chỉ tồn tại vì độ rộng cổng ra |
| `minute_units[3:0]` | 4 | đủ dùng (0…9) |
| `minute_tens[2:0]` | 3 | đủ dùng (0…5) |
| `minute_tens[3]` | **1** | **hằng 0** |
| bit chọn kênh xuất | **0** | **chưa hiện thực** (cảnh báo C4-5) |
| **Tổng** | **16** | khớp `synth_stat.txt` |

## 6. Vì sao đếm tới 59 cần 6 bit chứ không phải 8 — trả lời Charter mục 9

Phép đếm tới `N` giá trị cần `⌈log₂ N⌉` bit. Với `N = 60` (giá trị `0…59`):

```
  2⁵ = 32  <  60        → 5 bit KHÔNG ĐỦ
  2⁶ = 64  ≥  60        → 6 bit ĐỦ, dư 4 mã (60…63)
  ⌈log₂ 60⌉ = 6
```

Con số **8** đến từ thói quen dùng byte, không từ bài toán. Một bộ đếm 8 bit cho `0…255`
— thừa 196 giá trị vô dụng, tức **2 flip-flop lãng phí mỗi bộ đếm**, 4 FF cho cả hai.

| Phương án | FF cho giây | FF cho phút | Tổng |
|---|---:|---:|---:|
| Nhị phân 6 bit (đúng lý thuyết) | 6 | 6 | **12** |
| Nhị phân 8 bit (thói quen) | 8 | 8 | 16 |
| **BCD 4+4 bit (D07 hiện tại)** | 8 | 8 | **16 — đo được** |
| BCD tối ưu 4+3 bit | 7 | 7 | 14 |

Nhận xét đáng lưu ý: BCD với cổng ra 4 bit mỗi chữ số **tốn đúng bằng** nhị phân 8 bit về
số flip-flop (16), nhưng đổi lại **không cần mạch chuyển đổi nhị phân → BCD để hiển thị**.
Đó mới là lý do chọn BCD — xem `tradeoff.md`.

## 7. Xử lý trạng thái bất hợp lệ — hệ quả của việc dùng `<` thay vì `==`

RTL viết `if (second_units < 4'd9)`, **không** viết `if (second_units == 4'd9)`. Khác biệt
này quyết định điều gì xảy ra nếu một flip-flop bị lật do nhiễu và chữ số rơi vào vùng bất
hợp lệ (`SU ∈ 10…15` hoặc `ST ∈ 6…15`):

| Cách viết | Nếu `SU = 12` | Kết quả |
|---|---|---|
| `if (SU < 9) SU <= SU+1; else SU <= 0;` | `12 < 9` **sai** → nhánh `else` | **`SU ← 0` + phát carry** → phục hồi sau 1 bước tiến ✅ |
| `if (SU == 9) SU <= 0; else SU <= SU+1;` | `12 == 9` sai → nhánh tăng | `SU ← 13 → 14 → 15 → 0` — quay vòng 16, **sai nhịp vĩnh viễn** ❌ |

**Bằng chứng netlist rằng công cụ hiện thực đúng `≥`, không phải `==`:**

```verilog
sky130_fd_sc_hd__o31ai_1 _066_ (.A1(second_units[2]), .A2(second_units[1]),
                                 .A3(second_units[0]), .B1(second_units[3]), .Y(_021_));
```

`_021_ = ~((SU2 | SU1 | SU0) & SU3)`. Vế `_021_ = 0` (nghĩa là "đã đầy") đúng khi
`SU3 = 1` **và** ít nhất một trong `SU2, SU1, SU0` bằng 1 — tức `SU ∈ {9,10,…,15}`, đúng
bằng `SU ≥ 9`. Nếu RTL viết `== 9`, cell này sẽ phải giải mã chính xác tổ hợp `1001` và
cần thêm cổng đảo cho `SU2`, `SU1`.

Cùng dạng cho `second_tens`: `_016_ = ~ST3`, `_018_ = ~((ST1|ST0) & ST2)`, và điều kiện
"đầy" là `_016_ & _018_ = 0`, tức `ST ≥ 5`. ✅

**Kết luận INV-9:** mọi trạng thái BCD bất hợp lệ tự phục hồi trong **đúng 1 bước tiến**,
không cần nhánh `default`, không cần logic phát hiện lỗi. Đây là một tính chất **được
cho không** nhờ cách viết điều kiện — và là điểm đáng dạy nhất về phong cách viết RTL trong
cả đề này.

## 8. Điều kiện biên và hành vi không xác định

| Tình huống | Hành vi | Xác định? |
|---|---|---|
| Trước cạnh lên đầu tiên | Cả 16 FF = `x` | ❌ Cần ≥1 cạnh lên với `rst_n=0` |
| `rst_n=0` không có cạnh lên | Giữ nguyên | ✅ Reset **đồng bộ** |
| `rst_n=0` cùng `enable=1, tick=1` | `rst_n` thắng (dòng 12 đứng trước) | ✅ |
| `enable=1, tick_1hz=0` | Giữ nguyên | ✅ nhưng **chưa được kiểm** (INV-5) |
| `tick_1hz` giữ mức 1 nhiều chu kỳ clock | **Đếm mỗi chu kỳ clock**, không phải mỗi giây | ✅ Xác định — là **nghĩa vụ tầng ngoài** |
| `59:59` + 1 bước tiến | `00:00`, tràn **cả 4 tầng** cùng lúc | ✅ Xác định · ❌ **chưa mô phỏng** |
| Chữ số ở giá trị bất hợp lệ | Phục hồi trong 1 bước tiến (§7) | ✅ |
| `tick_1hz` = X/Z | X lan vào toàn bộ 16 FF | ❌ Nghĩa vụ tầng ngoài |

> ⚠️ **Nghĩa vụ hợp đồng quan trọng nhất:** `tick_1hz` phải là **xung rộng đúng một chu kỳ
> clock**, không phải một mức giữ suốt 1 giây. RTL không có bộ phát hiện sườn
> (`tick & ~tick_q`). Nếu tầng ngoài cấp một mức cao dài, D07 sẽ đếm mỗi chu kỳ clock.
> Và tình huống này **chưa bao giờ được kiểm** vì testbench luôn để `tick_1hz = 1` tại mọi
> cạnh lên (xem `corner_cases.md` §1).

## 9. Độ trễ từ đầu vào tới đầu ra (mạch tuần tự)

| Đường | Độ trễ |
|---|---|
| `tick_1hz` & `enable` tại cạnh `t` → chữ số đổi | **1 chu kỳ clock** |
| Chữ số (thanh ghi) → cổng ra | **0 chu kỳ** — cổng ra **chính là** `Q` của FF |
| `rst_n=0` → cả bốn chữ số = 0 | **1 chu kỳ clock** |
| Tràn 1 tầng (`SU` → `ST`) | **0 chu kỳ thêm** — xảy ra trong cùng một cạnh lên |
| Tràn 4 tầng (`59:59` → `00:00`) | **0 chu kỳ thêm** — vẫn chỉ **một** cạnh lên |
| Một phút thời gian thực | **60 xung** `tick_1hz` |
| Một chu kỳ đầy đủ | **3600 xung** `tick_1hz` = 1 giờ |

> Điểm dễ hiểu sai: chuỗi tràn 4 tầng **không** tốn 4 chu kỳ clock. Toàn bộ chuỗi được tính
> **tổ hợp trong một chu kỳ**, và netlist cho thấy nó được làm phẳng thành các cổng đơn lẻ
> chứ không phải chuỗi nối tiếp (xem `block_diagram.md` §3).

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
