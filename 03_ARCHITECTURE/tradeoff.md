# D07 · Đánh đổi kiến trúc (Trade-off Analysis)

---

## 1. Câu hỏi trung tâm của đề

> **Charter mục 2, câu 2:** *"Đếm dạng BCD hay nhị phân rồi chuyển — em chọn cách nào và nó
> đổi số ô nhớ ra sao?"*
>
> **Charter mục 9:** *"Kiểm trong báo cáo tổng số flip-flop và đối chiếu với ước lượng của
> mình; giải thích vì sao đếm tới 59 cần 6 bit chứ không phải 8."*

Hai câu này là **cùng một câu hỏi** nhìn từ hai phía. Hồ sơ có sẵn cả hai bản RTL, nên trả
lời được bằng cấu trúc; nhưng chỉ **một** bản được tổng hợp, nên phần con số phải trung
thực về chỗ nào có và chỗ nào chưa.

## 2. Số liệu thật của kiến trúc đã chọn

Kiến trúc A = **BCD bốn chữ số** (`d07_bcd_core.sv`), Yosys 0.33 + `sky130_fd_sc_hd`, góc
`tt_025C_1v80`:

| Chỉ số | Giá trị đo được | Nguồn |
|---|---:|---|
| Tổng số cell | **77** | `synth_stat.txt` |
| Flip-flop | **16** | `synth_stat.txt` |
| Diện tích | **665,6384 µm²** | `synth_stat.txt` |
| Độ sâu đường tới hạn | **4 cell** (3 logic + 1 FF) | `timing_report_max.txt` |
| Data arrival / Slack | **2,40 ns / 7,49 ns** | `timing_report_max.txt` |
| Startpoint → Endpoint | `tick_1hz` → `_125_` (= `minute_tens[3]`) | `sta/summary.txt` |
| WNS / TNS | **0,00 / 0,00** | `wns.txt`, `tns.txt` |
| Công suất tổng | **6,77e-05 W** | `power_report.txt` |
| Tỉ lệ tuần tự / tổ hợp | **97,3 % / 2,7 %** | `power_report.txt` |
| Ước lượng Charter | ~230–320 cell · 1×1 tile | Charter metadata |
| Ngân sách ô nhớ Charter mục 10 | "BCD: 14 đếm + 1 chọn xuất ≈ 15–17" | Charter mục 10 |

**Ba đối chiếu quan trọng:**

1. **77 cell so với ước lượng 230–320** — nhỏ hơn **3 lần**. Nguyên nhân chính là việc
   làm phẳng chuỗi tràn: cả bốn tầng `if` lồng nhau bị nén vào ba cổng phức hợp
   (`nor2`, `a211oi`, `a2111oi`) thay vì bốn khối logic riêng.
2. **16 FF nằm trong ngân sách 15–17** ✅ — nhưng **cấu thành khác ước lượng Charter**:
   14 bit đếm hữu ích + **2 bit hằng 0** + **0 bit chọn xuất** (bộ ghép kênh chưa hiện
   thực, xem cảnh báo C4-4/C4-5 ở `functional_spec.md`).
3. **97,3 % công suất ở nhóm tuần tự** — tỉ lệ cao nhất trong ba đề D05/D06/D07.

## 3. Trả lời Charter mục 9 — đối chiếu ước lượng với số đo

### 3.1 Vì sao đếm tới 59 cần **6** bit chứ không phải 8

```
    2⁵ = 32  <  60        → 5 bit KHÔNG ĐỦ để biểu diễn 60 giá trị (0…59)
    2⁶ = 64  ≥  60        → 6 bit ĐỦ, dư 4 mã (60…63) không dùng
    ⌈log₂ 60⌉ = 6
```

Con số **8** không đến từ bài toán mà đến từ **thói quen dùng byte**. Một bộ đếm 8 bit biểu
diễn được 256 giá trị, trong đó **196 giá trị vô dụng** — lãng phí đúng **2 flip-flop mỗi
bộ đếm**, tức 4 FF cho cả phút và giây.

### 3.2 Bốn phương án, đếm flip-flop chính xác

| Phương án | Giây | Phút | **Tổng FF** | Ghi chú |
|---|---:|---:|---:|---|
| Nhị phân 6 bit × 2 (tối ưu lý thuyết) | 6 | 6 | **12** | `d07_binary_core.sv` — ⬜ chưa tổng hợp |
| Nhị phân 8 bit × 2 (theo thói quen) | 8 | 8 | 16 | Không ai chọn, nêu để so sánh |
| BCD tối thiểu 4+3 bit | 7 | 7 | **14** | Bằng đúng ước lượng Charter mục 10 |
| **BCD 4+4 bit (D07 hiện tại)** | **8** | **8** | **16 — ĐO ĐƯỢC** | 14 hữu ích + 2 hằng 0 |
| BCD 4+4 + 1 bit chọn xuất (theo Charter mục 4) | 8 | 8 | **17** | Charter dự trù; **chưa hiện thực** |

### 3.3 Hai bit chênh lệch nằm ở đâu — bằng chứng cấu trúc

`second_tens` và `minute_tens` chỉ đếm `0…5`, cần **3 bit**, nhưng được khai báo
`output logic [3:0]` → **4 bit**. Bit 3 của cả hai là **hằng 0** trong mọi trạng thái đạt
tới được.

```verilog
// minute_tens[3] — cũng chính là ENDPOINT của đường tới hạn
sky130_fd_sc_hd__and3b_1 _085_ (.A_N(_027_), .B(rst_n), .C(minute_tens[3]), .X(_003_));
sky130_fd_sc_hd__dfxtp_1 _125_ (.CLK(clk), .D(_003_), .Q(minute_tens[3]));
//  ⇒ minute_tens[3]_next = rst_n & minute_tens[3] & ~C2   →  0 vĩnh viễn nếu đang là 0
```

Yosys **không xoá được** hai FF này vì chúng là **cổng ra chính** — công cụ tổng hợp không
được phép đổi giao diện module, và nó cũng không thực hiện phân tích khả đạt (reachability)
để chứng minh `MT ≤ 5`.

**Cái giá đo được của hai bit thừa:**

| Hạng mục | Chi phí | Cách tính |
|---|---:|---|
| Flip-flop | **+2** trên 16 | đo trực tiếp |
| Công suất | **≈ 8,2e-06 W = 12 %** tổng | `2 × (6,59e-05 / 16)` — **ngoại suy** từ đơn giá đo được |
| Diện tích | ⬜ chưa tách riêng được | cần `stat -liberty` với phân tích từng cell |
| Chân ra | +2 bit | 20 chân thay vì 18 |

**Kết luận đối chiếu:** ước lượng 14 FF là **đúng về mặt lý thuyết**, số đo 16 FF **đúng về
mặt hiện thực**, và chênh lệch 2 FF có **nguyên nhân cấu trúc rõ ràng**: độ rộng cổng ra
BCD chuẩn 4 bit. Đây là kiểu chênh lệch phải **giải thích**, không phải **giấu đi**.

## 4. So bốn kiến trúc đếm phút:giây

| # | Kiến trúc | Ô nhớ | Logic tràn | Chi phí giải mã hiển thị | Khi nào nên dùng |
|---|---|---:|---|---|---|
| **A** | **BCD 4 chữ số** (đang dùng) | **16** ✅ | So sánh `<9` / `<5` trên từng chữ số — rẻ | **0** — mỗi chữ số đã sẵn sàng cho LED 7 vạch | Khi phải hiển thị. Đây là trường hợp của D07 |
| B | Nhị phân 6+6 (`d07_binary_core.sv`) | **12** | So sánh `<59` trên 6 bit — sâu hơn một chút | **Cần bộ chia cho 10** — rất đắt (hoặc double-dabble, hoặc bảng tra) | Khi **không** cần hiển thị, chỉ cần giá trị cho phần mềm |
| C | BCD tối thiểu 4+3 bit | 14 | Như A | 0, nhưng phải đệm bit 3 = 0 khi xuất | Khi tiết kiệm FF quan trọng hơn tính đều đặn giao diện |
| D | Bộ đếm nhị phân đơn 12 bit (0…3599) | 12 | Chỉ **một** so sánh `< 3600` | **Cần chia cho 60 VÀ chia cho 10** — đắt nhất | Khi chỉ cần tổng số giây trôi qua |

### 4.1 Phân tích cốt lõi: chi phí bị **dịch chỗ**, không bị **loại bỏ**

Đây là điểm quan trọng nhất của toàn bộ phân tích đánh đổi D07:

```
   PHƯƠNG ÁN B (nhị phân 6+6)                  PHƯƠNG ÁN A (BCD, đang dùng)
   ═══════════════════════════                 ════════════════════════════
   ┌──────────────┐                            ┌──────────────┐
   │ 12 FF        │  ← tiết kiệm 4 FF          │ 16 FF        │
   │ second[5:0]  │                            │ SU ST MU MT  │
   │ minute[5:0]  │                            └──────┬───────┘
   └──────┬───────┘                                   │
          │                                           ▼
          ▼                                    ┌──────────────┐
   ┌──────────────────────────┐                │ LED 7 vạch   │
   │ BỘ CHUYỂN NHỊ PHÂN → BCD │ ← CHI PHÍ      │ (tầng ngoài) │
   │ (double-dabble / chia 10)│   CHUYỂN       └──────────────┘
   │ ≈ 40–80 cell, NẰM Ở      │   SANG ĐÂY
   │   TẦNG NGOÀI             │
   └──────┬───────────────────┘
          ▼
   ┌──────────────┐
   │ LED 7 vạch   │
   └──────────────┘
```

Phương án B tiết kiệm **4 flip-flop** bên trong khối, nhưng **đẩy một bộ chuyển đổi nhị
phân → BCD sang tầng ngoài**. Ở mức hệ thống, điều đó có thể **đắt hơn**, vì:

| Yếu tố | Lập luận, dựa trên số liệu D07 |
|---|---|
| Đơn giá công suất đo được | **1 FF ≈ 140 cell tổ hợp** (`6,59e-05/16` so với `1,80e-06/61`). 4 FF ≈ 560 cell tổ hợp về công suất |
| Bộ chuyển đổi nhị phân→BCD | Cần khoảng vài chục cell tổ hợp (⬜ chưa đo). Rẻ hơn 4 FF về **công suất** theo đơn giá trên |
| Nhưng nó cũng cần thanh ghi | Double-dabble tuần tự cần thêm FF; bản tổ hợp thuần thì không, nhưng sâu hơn |
| Và nó nằm **ngoài** khối | Không còn là bài toán của D07, nhưng vẫn là bài toán của hệ thống |

> **Kết luận trung thực:** với ứng dụng *đồng hồ bấm giờ có hiển thị số*, **BCD là lựa chọn
> đúng**, vì bộ chuyển đổi mà phương án nhị phân cần sẽ không bao giờ được tiết kiệm — nó
> chỉ được dời đi. Nếu ứng dụng **không** hiển thị (chỉ ghi log dạng nhị phân), phương án B
> thắng rõ ràng.

### 4.2 Số liệu cho phương án B — **chưa có**

| Hạng mục | Kiến trúc A (BCD) | Kiến trúc B (nhị phân) |
|---|---:|---|
| Flip-flop | **16** (đo được) | **12** (suy chắc chắn từ RTL: `minute[5:0]` + `second[5:0]`) |
| Số cell | **77** (đo được) | ⬜ **CHƯA CHẠY** |
| Diện tích | **665,6384 µm²** | ⬜ **CHƯA CHẠY** |
| Slack | **7,49 ns** | ⬜ **CHƯA CHẠY** |
| Công suất | **6,77e-05 W** | ⬜ **CHƯA CHẠY** |

**Cần gì để có số cho B:** chạy Yosys với `-top d07_binary_core` trên
`04_IMPLEMENTATION/rtl/d07_binary_core.sv`; script mẫu ở
`04_IMPLEMENTATION/scripts/02_run_synth.sh` (đổi biến top). **Không được suy đoán con số
cell, diện tích hay slack.**

Dự đoán **định tính** duy nhất được phép phát biểu: B có **12 FF thay vì 16**, và logic
tràn của nó là hai phép so sánh `< 59` trên 6 bit thay vì bốn phép so sánh 3–4 bit. Việc
tổng số cell nhỏ hơn hay lớn hơn **chưa xác định được** — phải chạy mới biết.

**Ghi chú về `d07_reference.sv`:** file mô hình chuẩn trong hồ sơ dùng đúng giao diện của
phương án B (`minute[5:0]`, `second[5:0]`), **không** phải của top. Đó là lý do testbench
không đấu nó vào DUT được (xem `corner_cases.md` §1, phát hiện 1). Nếu chạy tổng hợp cho B,
`d07_reference.sv` sẽ trở thành mô hình chuẩn dùng được ngay.

## 5. Đánh đổi thứ hai: giải quyết nút cổ chai `_072_`

Cell `a2111oi_0 _072_` chiếm **1,05 ns / 44 %** thời gian đến của đường tới hạn
(`datapath.md` §5.3). Ba cách xử lý:

| Cách | Chi phí | Hiệu quả dự kiến | Được phép? |
|---|---|---|---|
| **Để công cụ tự sửa**: thêm `set_max_fanout` vào SDC, hoặc chạy `repair_design` của OpenROAD | 0 công sức thiết kế, +1–2 cell đệm | Giảm slew 1,25 ns → giảm đáng kể độ trễ cell | ✅ **Cách đúng** — thuộc về bước physical design, ⬜ chưa chạy |
| Sửa netlist bằng tay (thay `_0` bằng `_4`) | — | — | ❌ **CẤM** — Charter mục 3 liệt "tự tối ưu netlist bằng tay" vào ngoài phạm vi |
| Viết lại RTL để cắt fanout (tách `_027_` thành 2 nhánh) | Sửa RTL, tổng hợp lại toàn bộ | Không chắc — tool có thể gộp lại | ⚠️ Được phép nhưng **chống lại công cụ**, không khuyến khích |

> Đây là bài học về **phân công trách nhiệm giữa các tầng**: vấn đề của D07 là vấn đề
> **physical**, và nó phải được giải ở tầng physical. Sửa RTL để bù cho một cell bị quá tải
> là chữa triệu chứng ở sai tầng.

## 6. Ràng buộc phạm vi — kiến trúc chỉ được so trên giấy

| Kiến trúc / tính năng | Charter mục 3 xếp loại | Được làm gì |
|---|---|---|
| Đếm **giờ** | **Ngoài phạm vi** | Chỉ thảo luận. Ghi chú: tín hiệu `C3 = C2 & (MT≥5)` **đã tồn tại** trong netlist, chi phí nối ra là 0 cell logic |
| Ngày, lịch | **Ngoài phạm vi** | Chỉ thảo luận |
| Đồng bộ thời gian ngoài (RTC/NTP) | **Ngoài phạm vi** | Chỉ thảo luận |
| Tự tối ưu netlist bằng tay | **Ngoài phạm vi** (mọi đề) | **Không được** sửa `netlist.v` |
| Physical design, sign-off, tape-out | **Ngoài phạm vi** | Không được phát biểu "đã sign-off" |

## 7. Những đánh đổi **KHÔNG được phép** trong đề này

| Đánh đổi | Vì sao cấm | Điều khoản |
|---|---|---|
| Đổi top sang `d07_binary_core` để có 12 FF | Làm vô hiệu toàn bộ số liệu đã chạy; và ứng dụng cần hiển thị BCD | Tính nhất quán hồ sơ + Charter mục 1 |
| Thu cổng ra về `[2:0]` cho hai chữ số chục để bớt 2 FF | Phá chuẩn BCD 4 bit, làm bộ giải mã 7 vạch bên ngoài phức tạp hơn | Charter mục 4 (`uo_out[7:0]` = BCD) |
| Dùng `tick_1hz` làm clock (`always_ff @(posedge tick_1hz)`) | Sinh miền clock thứ hai với chu kỳ 1 giây → STA vô nghĩa, cần CDC | Nguyên tắc thiết kế đồng bộ; xem `system_diagram.md` §1 |
| Viết `if (SU == 9)` thay vì `if (SU < 9)` | Mất tính tự phục hồi từ **61 936** trạng thái bất hợp lệ | `fsm.md` §6 |
| Sửa `netlist.v` để thay cell `_072_` bằng biến thể drive mạnh hơn | Tự tối ưu netlist bằng tay | Charter mục 3 |
| **Kết thúc mô phỏng tại `59:59` và coi là đã phủ ca quay vòng** | Ca `59:59→00:00` là ca **bắt buộc** của Charter mục 8 và là "chỗ hay tắc" của Charter mục 10. Nó **chưa được thực hiện** | Charter mục 8 + mục 10 |
| Coi Charter mục 4 đã thoả | Thiếu bộ ghép kênh `uo_out[7:0]` và bit `uio_out[0]` "đang xuất phút" | Charter mục 4 |
| Báo "16 FF, khớp ước lượng" mà không giải thích | Khớp về **con số** nhưng khác về **cấu thành** (14+2+0 so với 14+0+1) | Charter mục 9 đòi "đối chiếu" |

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
