# D07 — Bộ đếm thời gian phút:giây từ xung 1 Hz · Ghi chú thực hiện

## 1. Bài toán này thực chất là gì

Nhìn qua, D07 là "đồng hồ bấm giờ" — bài tập quen thuộc. Nhưng ba quyết định kiến trúc ẩn
trong đề mới là nội dung thật.

**Thứ nhất: `tick_1hz` là dữ liệu, không phải clock.** Cám dỗ lớn nhất của người mới là
viết `always_ff @(posedge tick_1hz)`. Làm vậy tạo ra **miền clock thứ hai** với chu kỳ
1 giây; STA sẽ phải `create_clock -period 1e9`, mọi ràng buộc thời gian trở nên vô nghĩa,
và ranh giới giữa hai miền cần xử lý CDC. RTL của đề làm đúng: một miền clock duy nhất,
`tick_1hz` là một điều kiện tiến được lấy mẫu đồng bộ. Netlist xác nhận — cả 16 `dfxtp_1`
đều nối `.CLK(clk)`.

**Thứ hai: BCD hay nhị phân không phải câu hỏi về tiết kiệm, mà về chỗ đặt chi phí.** Nhị
phân 6+6 bit dùng 12 flip-flop thay vì 16, nhưng cần một bộ chuyển đổi nhị phân → BCD để
hiển thị. Chi phí không mất đi, nó chỉ chuyển sang tầng ngoài.

**Thứ ba: hơn 94 % không gian mã hoá là bất hợp lệ.** `2¹⁶ = 65 536` tổ hợp, chỉ 3 600 hợp
lệ. Một thiết kế cẩu thả sẽ lock-up ở đó. RTL của đề xử lý được — **miễn phí** — nhờ một
lựa chọn cú pháp tưởng như thẩm mỹ.

## 2. Bản chất kỹ thuật — cơ chế hoạt động

**Cơ chế 1 — chuỗi tràn KHÔNG phải một chuỗi.** RTL viết bốn tầng `if` lồng nhau, đọc lên
nghe như một chuỗi phụ thuộc. Trong phần cứng thì không. Các cờ "chữ số đầy" đọc từ **bốn
thanh ghi khác nhau** nên tính được song song; chỉ phép AND cuối là chung, mà AND thì kết
hợp được nên gộp phẳng được. Kết quả: carry sâu nhất (`C2`) là **một cổng 5 đầu vào**, và
độ sâu của tràn 4 tầng **bằng đúng** độ sâu của tràn 1 tầng.

Đối chiếu với A01 (ripple-carry): ở đó `carry[i+1] = a&b | (a^b)&carry[i]` — phụ thuộc
thật sự, không gộp được, `O(N)`. Ở D07 không có phụ thuộc như vậy, `O(1)`. **Cùng gọi là
"chuỗi tràn" nhưng bản chất khác hẳn** — đây là điểm dễ nhầm nhất khi so hai đề.

**Cơ chế 2 — cái giá của gộp phẳng: một cổng chiếm 44 % thời gian.** Gộp phẳng đổi **độ
sâu** lấy **độ phức tạp cổng**. Cell `_072_ a2111oi_0` có 5 đầu vào, dùng biến thể `_0`
(drive nhỏ nhất thư viện), lái **7 tải**. STA đo: slew đầu ra **1,25 ns**, độ trễ cell
**1,05 ns** — bằng 44 % của arrival 2,40 ns, và 75 % của phần logic thật 1,40 ns. Nút thắt
của D07 **không phải độ sâu logic** mà là **khả năng lái của một cell**. Đây là loại vấn đề
mà đọc RTL không bao giờ thấy được.

**Cơ chế 3 — `<` thay vì `==` cho tự phục hồi miễn phí.** Với `SU = 12` (bất hợp lệ):
`12 < 9` sai → nhánh `else` → `SU ← 0` + phát carry. Phục hồi sau **1 bước tiến**. Nếu viết
`if (SU == 9) SU<=0 else SU<=SU+1`, thì `12 → 13 → 14 → 15 → 0` — quay vòng 16 thay vì 10,
**sai nhịp vĩnh viễn**. Netlist xác nhận tool hiện thực đúng `≥`:
`o31ai_1 _066_` cho `_021_ = ~((su2|su1|su0) & su3)`, bằng 0 đúng khi `su ∈ {9…15}`.

**Cơ chế 4 — đường tới hạn kết thúc ở một flip-flop không bao giờ đổi.** Endpoint `_125_`
là `minute_tens[3]`. Vì `MT ≤ 5`, bit 3 luôn bằng 0. Netlist cho thấy vì sao nó vĩnh viễn 0:
`minute_tens[3]next = rst_n & minute_tens[3] & ~C2` — vế phải nhân với chính nó.

## 3. Đọc mã nguồn: RTL làm gì, từng dòng quan trọng

```verilog
end else if (enable && tick_1hz) begin              // d07_bcd_core.sv, dòng 17
    if (second_units < 4'd9) begin                  // dòng 18
        second_units <= second_units + 4'd1;
    end else begin
        second_units <= 4'd0;
        if (second_tens < 4'd5) begin               // dòng 22
```

**Dòng 17** gộp hai điều kiện thành một. Netlist sinh **cả hai dạng**:
`and2_0 _064_` (thuận) và `nand2_1 _065_` (đảo), vì các cell sau dùng cả hai. Từ điểm này
trở đi, phần còn lại của thiết kế **không phân biệt** `enable` với `tick_1hz` — chúng hoàn
toàn đối xứng về logic. Đó cũng chính là gốc rễ của một lỗ hổng kiểm thử (xem §9).

**Dòng 18, 22, 26, 30** đều dùng `<`, không dùng `==`. Bốn dòng này quyết định tính tự phục
hồi từ 61 936 trạng thái bất hợp lệ (cơ chế 3).

**Cấu trúc `if` lồng 4 tầng** dòng 18–36 là cách diễn đạt trực quan nhất của "tràn phân
cấp". Nó **không** sinh ra bốn tầng logic — xem cơ chế 1.

```verilog
always_ff @(posedge clk) begin                      // dòng 11
    if (!rst_n) begin                               // dòng 12
```

Không có `rst_n` trong danh sách nhạy → reset **đồng bộ**. Netlist: không cell `dfrtp_*`;
`rst_n` là toán hạng của cổng cuối trên mọi đường `D`, ví dụ
`and3b_1 _085_ (.A_N(_027_), .B(rst_n), .C(minute_tens[3]), .X(_003_))`.

**Điều RTL KHÔNG có:** không `always_comb` nào. Bốn cổng ra được gán thẳng trong
`always_ff`, nên `Q` của flip-flop **chính là** chân ra. Hệ quả đo được: trong
`timing_report_max.txt` **không có một đường reg→out nào**. Đây là Moore ở dạng thuần khiết
nhất, và nó bảo đảm **không có glitch** trên cổng ra.

## 4. Vì sao chọn kiến trúc này

Ba căn cứ, theo thứ tự ràng buộc:

1. **Ứng dụng cần hiển thị.** Charter mục 1 nói rõ: đồng hồ bấm giờ cho máy tập. Đầu ra đi
   thẳng tới bộ giải mã 7 vạch. Với BCD, chi phí giải mã là **0**; với nhị phân, cần một
   bộ chia cho 10 hoặc double-dabble — chi phí không mất đi mà chỉ dời sang tầng ngoài.
2. **Charter mục 10 chốt ngân sách** "BCD: 14 đếm + 1 chọn xuất ≈ 15–17 ô nhớ". Đo được
   **16** → nằm trong khoảng.
3. **Một miền clock duy nhất.** `tick_1hz` phải là dữ liệu. Mọi kiến trúc dùng nó làm clock
   đều bị loại ngay từ đầu, bất kể tiết kiệm được bao nhiêu FF.

## 5. Cách thực hiện — lộ trình 8 bước từ đặc tả tới GDSII

| # | Bước | Trạng thái | Bằng chứng |
|---|---|:-:|---|
| 1 | Chốt đặc tả và invariant từ Charter mục 1/4/8/9 | ✅ | `02_SPECIFICATION/functional_spec.md` |
| 2 | Mô hình chuẩn Python kiểm **3600 trạng thái duy nhất** + các mốc biên | ✅ | `python_reference_run.log` — PASS |
| 3 | RTL: 4 bộ đếm BCD nối theo chuỗi tràn, một miền clock | ✅ | `d07_bcd_core.sv` (39 dòng) |
| 4 | Mô phỏng RTL | ⚠️ **PASS nhưng thiếu ca bắt buộc** | `simulation.log`, `$finish` tại 36036 |
| 5 | Tổng hợp Yosys 0.33 + `sky130_fd_sc_hd` | ✅ | 77 cell · 16 FF · 665,6384 µm² |
| 6 | STA với SDC clock thật | ✅ | slack 7,49 ns · WNS/TNS 0,00 |
| 7 | Ước lượng công suất | ✅ | 6,77e-05 W · 97,3 % / 2,7 % |
| 8 | Physical design (floorplan → GDS) bằng LibreLane + sky130A | ⬜ | cần PDK; `scripts/04_run_librelane.sh` |

> Bước 4 được đánh ⚠️ **có chủ ý**: log ghi PASS, nhưng độ phủ **chưa đạt** yêu cầu Charter
> mục 8 (thiếu ca `59:59 → 00:00`). Ghi ✅ ở đây sẽ là phát biểu vượt mức.

## 6. Số liệu thật đã đo được và cách đọc chúng

| Chỉ số | Giá trị | **Chứng minh** gì | **Không chứng minh** gì |
|---|---:|---|---|
| 77 cell | 77 | Nhỏ hơn **3 lần** ước lượng Charter (230–320), nhờ chuỗi tràn được gộp phẳng | Không nói gì về tốc độ |
| 16 FF | 16 | Nằm trong ngân sách Charter mục 10 (15–17) | **Không** khớp về **cấu thành**: 14 hữu ích + 2 hằng 0 + 0 chọn xuất, so với ước lượng 14 + 1 chọn xuất |
| 665,6384 µm² | | Diện tích logic sau tổng hợp | **Không** phải diện tích die — chưa floorplan |
| slack 7,49 ns | | Với chu kỳ giả định 10 ns, IO delay 1 ns, clock lý tưởng, netlist đáp ứng setup | **Không** cho phép nói "chạy được ở 100 MHz". Chưa RC dây, chưa CTS, một góc PVT |
| arrival 2,40 ns | | Đường tới hạn, gồm **1,00 ns giả định `input_delay`** | Logic thật chỉ **1,40 ns** |
| **1,05 ns trên `_072_`** | | **44 % arrival trong MỘT cell** — nút thắt là fanout/drive, không phải độ sâu | Không phải lỗi RTL; là việc của bước physical design |
| 3 cell trên đường tới hạn | | Nông nhất trong ba đề D05/D06/D07 | Nhưng **chậm nhất** — độ sâu không quyết định tốc độ |
| Endpoint = `minute_tens[3]` | | STA phân tích **cấu trúc**, không phân tích **giá trị** | Đường này **không bao giờ chuyển mạch thật** — là false path về mặt chức năng, nhưng chưa khai báo trong SDC |
| WNS/TNS 0,00 | | Không đường nào âm slack | Chỉ ở góc `tt_025C_1v80` |
| 6,77e-05 W | | Ước lượng sau tổng hợp | **Không** phải công suất chip thật — chưa có clock tree (hàng `Clock` = 0,0 %) |
| 97,3 % tuần tự | | 1 FF ≈ **140** cell tổ hợp. Hai bit hằng 0 đang tốn ≈ **12 %** tổng công suất | Không bao gồm công suất cây clock |
| Mô phỏng PASS | | 4 assert đúng, phủ 62 bước tiến đầu; 3599 bước chạy không lỗi | **Không** phủ ca `59:59→00:00`, **không** phủ `tick_1hz=0`, **không** đấu mô hình chuẩn vào DUT |

## 7. Trả lời các câu hỏi kỹ thuật của Charter (mục 2)

**Câu 1 — Chuỗi tràn giây→phút hiện ra trong phần cứng như thế nào?**
**Không phải như một chuỗi.** Netlist cho thấy ba nút carry nằm ở **cùng một mức logic**,
mỗi nút là **một cổng phức hợp** gộp tất cả các điều kiện cần:

```verilog
nor2_1     _067_ (.A(_020_), .B(_021_), .Y(_022_));                       // C0: 2 đầu vào
a211oi_1   _068_ (.A1(_016_),.A2(_018_),.B1(_020_),.C1(_021_),.Y(_023_)); // C1: 4 đầu vào
a2111oi_0  _072_ (.A1(_016_),.A2(_018_),.B1(_020_),.C1(_021_),
                  .D1(_026_), .Y(_027_));                                  // C2: 5 đầu vào
```

`_027_ = 1 ⟺ enable & tick_1hz & (SU≥9) & (ST≥5) & (MU≥9)`. Bốn tầng `if` lồng nhau của
RTL trở thành **một cổng AND-OR-Invert 5 đầu vào**. Độ sâu của tràn 4 tầng **bằng** độ sâu
của tràn 1 tầng. Cái giá: số đầu vào của cổng tăng theo số tầng, và cell 5 đầu vào drive
nhỏ nhất với fanout 7 chính là nút cổ chai của thiết kế (1,05 ns).

**Câu 2 — Đếm BCD hay nhị phân, chọn cách nào và nó đổi số ô nhớ ra sao?**
Chọn **BCD**, đo được **16 FF**. Bản nhị phân (`d07_binary_core.sv`) dùng **12 FF** — suy
chắc chắn từ RTL (`minute[5:0]` + `second[5:0]`), nhưng **⬜ chưa tổng hợp** nên chưa có số
cell/diện tích/slack để so.
Lý do chọn BCD: chi phí không mất đi mà chỉ **dời chỗ**. Nhị phân tiết kiệm 4 FF trong khối
nhưng cần một bộ chuyển đổi nhị phân → BCD ở tầng ngoài để hiển thị. Với ứng dụng có LED
7 vạch, BCD thắng. Với ứng dụng chỉ ghi log, nhị phân thắng.

**Câu 3 — Tổng ô nhớ dự đoán là bao nhiêu?**
Dự đoán lý thuyết: **14** (`4+3+4+3`). Đo được: **16**. Chênh lệch **2 bit** nằm ở
`second_tens[3]` và `minute_tens[3]` — hai flip-flop **hằng 0** tồn tại chỉ vì cổng ra rộng
4 bit theo chuẩn BCD. Yosys không xoá được vì chúng là cổng ra chính.

## 8. Trả lời câu phân tích riêng (Charter mục 9)

> *"Có hai bộ đếm module-60 lồng nhau. Kiểm trong báo cáo tổng số flip-flop và đối chiếu
> với ước lượng của mình; giải thích vì sao đếm tới 59 cần 6 bit chứ không phải 8."*

**Phần a — vì sao 6 bit:**
`2⁵ = 32 < 60` → 5 bit không đủ. `2⁶ = 64 ≥ 60` → 6 bit đủ, dư 4 mã.
`⌈log₂ 60⌉ = 6`. Con số **8** đến từ thói quen dùng byte, không từ bài toán: một bộ đếm
8 bit biểu diễn 256 giá trị, thừa **196 giá trị vô dụng**, lãng phí **2 flip-flop mỗi bộ
đếm**.

**Phần b — đối chiếu ước lượng với số đo:**

| | Ước lượng | Đo được | Chênh |
|---|---:|---:|---|
| Bit đếm hữu ích | 14 (`4+3+4+3`) | **14** | ✅ khớp |
| Bit hằng 0 do độ rộng cổng ra | 0 | **2** | ❌ **+2** |
| Bit chọn kênh xuất (Charter mục 4) | 1 | **0** | ❌ **−1** — **chưa hiện thực** |
| **Tổng** | **15** | **16** | +1 |

Con số tổng nằm trong ngân sách Charter mục 10 (15–17), nhưng **cấu thành khác hẳn**.
Báo cáo "16 FF, khớp ước lượng" mà không nói ba dòng trên là **báo cáo thiếu**.

**Bằng chứng hai bit hằng 0:**

```verilog
// second_tens[3]
clkinv_1 _061_ (.A(second_tens[3]), .Y(_016_));
o21ai_0  _109_ (.A1(_020_), .A2(_021_), .B1(rst_n), .Y(_053_));
nor2_1   _110_ (.A(_016_), .B(_053_), .Y(_011_));
dfxtp_1  _132_ (.CLK(clk), .D(_011_), .Q(second_tens[3]));
//  ⇒ _011_ = second_tens[3] & rst_n & ~C0   →  0 vĩnh viễn nếu đang là 0

// minute_tens[3] — cũng là ENDPOINT của đường tới hạn
and3b_1  _085_ (.A_N(_027_), .B(rst_n), .C(minute_tens[3]), .X(_003_));
dfxtp_1  _125_ (.CLK(clk), .D(_003_), .Q(minute_tens[3]));
//  ⇒ _003_ = minute_tens[3] & rst_n & ~C2   →  0 vĩnh viễn
```

**Cái giá đo được của 2 bit thừa:** ≈ `2 × (6,59e-05 / 16) = 8,2e-06 W`, tức **12 %** tổng
công suất, để lưu hai giá trị luôn bằng 0. Đây là **ngoại suy từ đơn giá đo được**, không
phải số đo trực tiếp.

## 9. Những chỗ sinh viên hay sai và cách phát hiện

| Sai lầm | Hậu quả | Phát hiện bằng bằng chứng nào |
|---|---|---|
| **Coi PASS là đã phủ ca `59:59→00:00`** | Bỏ đúng ca Charter mục 8 bắt buộc và Charter mục 10 gọi là "chỗ hay tắc" | Đếm bước tiến: `59 + 1 + 0 + 3539 = 3599` → dừng tại `59:59`. Bước 3600 không tồn tại. Kiểm chứng: `2+59+1+3+3539 = 3604` cạnh lên → `$finish` tại **36036 ns**, khớp log |
| Tưởng mô hình chuẩn được đấu vào DUT | Không có kiểm chứng độc lập nào trong mô phỏng RTL | `grep d07_reference d07_bcd_tb.sv` → **0 kết quả**. `d07_reference.sv` dùng giao diện nhị phân, không ghép được với top BCD |
| Tưởng `tick_1hz` đã được kiểm | DUT bỏ hẳn `tick_1hz` vẫn PASS → đồng hồ chạy nhanh gấp `f_clk` lần | Đọc task `tick`: `tick_1hz=0` chỉ tồn tại **0 đơn vị thời gian** giữa hai lời gọi. Tại mọi cạnh lên sau reset, `tick_1hz = 1` |
| Tưởng ca `enable=0` phủ luôn ca `tick_1hz=0` | Hai tín hiệu vào cùng cổng AND nên phủ cùng đường **logic**, nhưng không chứng minh DUT dùng `tick_1hz` | `and2_0 _064_ (.A(enable), .B(tick_1hz))` — đối xứng về logic, **không** đối xứng về hệ thống |
| Tưởng chuỗi tràn là 4 tầng nối tiếp | Ước sai độ sâu (8–12 thay vì 3), ước sai đường tới hạn | STA đếm được **3 cell**; netlist cho thấy `a2111oi_0` gộp cả 4 tầng |
| Nghĩ đường tới hạn chậm vì logic sâu | Chữa sai chỗ | `_072_` chiếm **1,05/1,40 = 75 %** phần logic; nó là cell 5 đầu vào, drive `_0`, fanout 7, slew ra 1,25 ns |
| Đi tìm ý nghĩa của endpoint `_125_` | Bối rối vì nó là bit hằng 0 | `_125_` = `minute_tens[3]`; `MT ≤ 5` nên bit 3 không bao giờ bằng 1 |
| Viết `if (SU == 9)` cho gọn | Mất tự phục hồi từ 61 936 trạng thái bất hợp lệ; `SU=12` sẽ quay vòng 16 | So hai cách viết trên giấy với `SU = 12`; netlist `o31ai_1 _066_` hiện thực `SU ≥ 9`, không phải `SU == 9` |
| Dùng `tick_1hz` làm clock | Hai miền clock, STA vô nghĩa, cần CDC | Netlist thật: cả 16 `dfxtp_1` đều `.CLK(clk)` |
| Tưởng reset là bất đồng bộ | Bỏ cạnh clock lúc `rst_n=0` → 16 FF giữ `x` | Netlist không có `dfrtp_*` |
| Coi `d07_binary_core.sv` là một phần thiết kế | Lẫn lộn số liệu 12 FF với 16 FF | Không module nào instantiate nó; `synth_stat.txt` chỉ có `=== d07_bcd_core ===` |
| Báo "16 FF khớp ước lượng" mà dừng ở đó | Khớp con số, khác cấu thành | Bảng đối chiếu ở §8 phần b |
| Nói Charter mục 4 đã thoả | Thiếu bộ ghép kênh và bit "đang xuất phút" | Danh sách cổng RTL: 16 bit ra song song, không có `minute_sel` |

## 10. Câu hỏi mentor nên đặt khi bảo vệ

| # | Câu hỏi | Đáp án mong đợi |
|---|---|---|
| 1 | Mô phỏng của em có chạy qua `59:59 → 00:00` không? Chứng minh bằng số | **Không.** `59 + 1 + 3539 = 3599` bước tiến → dừng tại `59:59`. `$finish` tại 36036 ns = 3604 cạnh lên. Bước 3600 chưa bao giờ chạy |
| 2 | Cần sửa bao nhiêu dòng để phủ ca đó? | 3 dòng: một `tick()` + một `assert(... == 16'h0000)` + (tuỳ chọn) một assert kiểm đã tới `59:59` |
| 3 | Chuỗi tràn hiện ra trong netlist như thế nào? | **Không phải chuỗi.** Ba carry ở cùng một mức; `C2` là một cổng `a2111oi_0` 5 đầu vào gộp cả 4 tầng |
| 4 | Đường tới hạn có mấy cell? Vì sao vẫn chậm nhất trong ba đề D? | **3 cell**, arrival 2,40 ns. Vì `_072_` một mình chiếm 1,05 ns — cell 5 đầu vào, drive `_0`, fanout 7, slew ra 1,25 ns |
| 5 | Endpoint `_125_` là bit nào? Nó có ý nghĩa gì? | `minute_tens[3]` — bit **hằng 0**, vì `MT ≤ 5`. Đường có slack nhỏ nhất kết thúc ở một FF không bao giờ đổi giá trị |
| 6 | Vì sao Yosys không xoá hai FF hằng 0 đó? | Chúng là **cổng ra chính**; tool không được đổi giao diện module và không phân tích khả đạt |
| 7 | Tổng FF là bao nhiêu? Đối chiếu với ước lượng 14 | **16** = 14 hữu ích + 2 hằng 0 + **0** chọn xuất. Khớp ngân sách 15–17 nhưng khác cấu thành |
| 8 | Vì sao đếm tới 59 cần 6 bit chứ không phải 8? | `2⁵=32 < 60 ≤ 64=2⁶` → `⌈log₂60⌉ = 6`. Con số 8 đến từ thói quen dùng byte |
| 9 | Vì sao RTL viết `SU < 9` mà không viết `SU == 9`? | Để tự phục hồi từ **61 936** trạng thái BCD bất hợp lệ trong 1 bước tiến. Và còn rẻ hơn: `o31ai_1` một cell |
| 10 | Testbench có chứng minh DUT dùng `tick_1hz` không? | **Không.** `tick_1hz = 1` tại mọi cạnh lên sau reset. Một DUT bỏ hẳn điều kiện đó vẫn PASS |
| 11 | Đầu ra là Mealy hay Moore? Bằng chứng ở tầng nào? | **Moore thuần** — cổng ra **chính là** `Q` của FF. Bằng chứng STA: **không có đường reg→out nào** trong report |
| 12 | Nếu chuyển sang bản nhị phân 6+6 thì tiết kiệm được gì? | 12 FF thay vì 16. Nhưng cần bộ chuyển nhị phân → BCD ở tầng ngoài. Số cell của bản đó **⬜ chưa chạy** |
| 13 | Muốn mở rộng đếm giờ thì tốn bao nhiêu logic mới? | Tín hiệu `C3 = C2 & (MT≥5)` **đã tồn tại** trong netlist; chi phí nối ra là 0 cell logic. Nhưng Charter mục 3 liệt giờ vào ngoài phạm vi |
| 14 | Charter mục 4 đã thoả chưa? | **Chưa** — thiếu bộ ghép kênh `uo_out[7:0]` (phút HOẶC giây) và bit `uio_out[0]` "đang xuất phút". Dùng 20 chân thay vì 12 |

## 11. Giới hạn: đã chứng minh được gì, chưa chứng minh được gì

**Đã chứng minh, có bằng chứng lưu trong hồ sơ:**
mô hình Python kiểm **3600 trạng thái phút:giây duy nhất** và chu kỳ khép kín về `(0,0)`,
cùng bốn mốc biên gồm `59:59 → 00:00` (PASS); mô phỏng RTL chạy 3599 bước tiến không lỗi,
với 4 assert đúng tại các mốc `00:00`, `00:59`, `01:00` và `01:00` (giữ khi `enable=0`);
RTL tổng hợp ra 77 standard cell sky130 với đúng **16** flip-flop, nằm trong ngân sách
Charter mục 10; STA sau tổng hợp không có đường nào âm slack ở góc `tt_025C_1v80` với chu
kỳ giả định 10 ns; thiết kế dùng **một miền clock duy nhất**, `tick_1hz` là dữ liệu chứ
không phải clock; đầu ra là Moore thuần, không có đường reg→out nào.

**Chưa chứng minh được:**
(1) **ca `59:59 → 00:00`** — ca Charter mục 8 liệt kê **bắt buộc** và Charter mục 10 gọi là
"chỗ hay tắc"; mô phỏng dừng đúng tại `59:59`, bước quay vòng **chưa từng được thực hiện
trên RTL** (chỉ có trên mô hình Python);
(2) rằng DUT thực sự dùng `tick_1hz` — tín hiệu này bằng 1 tại **mọi** cạnh lên sau reset;
(3) reset từ một trạng thái khác `00:00` — TB chỉ reset khi đồng hồ vốn đã ở `00:00`;
(4) tính tự phục hồi từ trạng thái BCD bất hợp lệ (INV-9) — suy được từ cấu trúc, **chưa mô
phỏng**;
(5) miền giá trị BCD (INV-1) — không assert nào kiểm trong suốt 3599 bước;
(6) lớp tràn T3 (`09:59 → 10:00`) — có xảy ra 5 lần nhưng **không assert**;
(7) chi phí thật của bản nhị phân `d07_binary_core.sv` — **chưa tổng hợp**;
(8) hành vi ở mức gate-level, kể cả ảnh hưởng thật của slew 1,25 ns trên `_072_`;
(9) mọi kết quả vật lý: floorplan, placement, CTS, routing, DRC, LVS, GDS đều **chưa chạy**;
(10) các góc PVT khác `tt`.

**Phát biểu không được dùng:** "đã sign-off", "đã tape-out", "chạy được ở 100 MHz", "đã
kiểm đủ các ca Charter mục 8". Câu đúng: *"sau tổng hợp logic, với các giả định ở
`02_SPECIFICATION/timing.md` §3, thiết kế đáp ứng setup với slack 7,49 ns; mô phỏng chức
năng PASS trên 3599 bước tiến nhưng **chưa phủ ca quay vòng `59:59 → 00:00`**, cần bổ sung
3 dòng testbench trước khi kết luận đạt Charter mục 8."*

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
