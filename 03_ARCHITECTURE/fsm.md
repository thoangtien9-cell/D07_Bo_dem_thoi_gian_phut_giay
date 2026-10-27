# D07 · Máy trạng thái (FSM)

---

## 1. D07 **có** máy trạng thái — đây là đề "FSM nhất" trong nhóm D

Không giống D05 (một vòng tròn đơn) hay D06 (hai máy độc lập), D07 có một máy trạng thái
**phân cấp bốn tầng** với chuyển trạng thái phụ thuộc lẫn nhau. Theo định nghĩa:

| Thành phần FSM | D07 có gì | Bằng chứng RTL |
|---|---|---|
| Tập trạng thái `S` | `{(MT,MU,ST,SU)}` — **3600 trạng thái hợp lệ** trong không gian mã hoá `2¹⁶ = 65 536` | 4 cổng ra 4 bit, dòng 6–9 |
| Trạng thái đầu `S₀` | `(0,0,0,0)` = `00:00` | dòng 12–16 |
| Hàm chuyển `δ(s, ADV)` | `δ(s,0) = s`; `δ(s,1)` = tiến một giây, có tràn phân cấp | dòng 17–37 |
| Hàm ra `λ(s)` | **Ánh xạ đồng nhất** — trạng thái *chính là* đầu ra | cổng ra = `Q` của FF |
| Thanh ghi trạng thái | 16 × `dfxtp_1` | `netlist.v`, `_122_`…`_137_` |

**Điểm khác biệt so với một FSM điều khiển cổ điển:** hàm chuyển có cấu trúc **số học phân
cấp** (bốn bộ đếm modulo lồng nhau), nên được hiện thực bằng bốn bộ tăng + ba nút carry,
chứ không bằng bảng tra trạng thái. Đây là **counter-style FSM phân cấp**.

**Yosys không kích hoạt `fsm_detect`.** `synth_stat.txt` không báo máy trạng thái nào được
nhận diện hay mã hoá lại; 16 FF được xếp vào loại thanh ghi dữ liệu vì chúng tham gia phép
`+ 4'd1`. Điều đó **không** có nghĩa là không có FSM — chỉ có nghĩa là công cụ không cần
xử lý nó như FSM.

## 2. Mealy hay Moore — kết luận và bằng chứng

**Moore, ở dạng thuần khiết nhất có thể.** Đầu ra không chỉ là hàm của trạng thái — nó
**chính là** trạng thái.

**Bằng chứng RTL:** trong `d07_bcd_core.sv` **không có khối `always_comb` nào**. Bốn cổng
ra được khai báo `output logic [3:0]` và gán trực tiếp trong `always_ff`. Không có biểu
thức tổ hợp nào giữa trạng thái và cổng ra.

**Bằng chứng netlist (mạnh hơn):** mọi cổng ra được lái **trực tiếp bởi chân `Q` của
flip-flop**, không qua cell nào:

```verilog
sky130_fd_sc_hd__dfxtp_1 _122_ (.CLK(clk), .D(_000_), .Q(minute_tens[0]));
sky130_fd_sc_hd__dfxtp_1 _125_ (.CLK(clk), .D(_003_), .Q(minute_tens[3]));
sky130_fd_sc_hd__dfxtp_1 _132_ (.CLK(clk), .D(_011_), .Q(second_tens[3]));
```

**Kiểm chứng ngược qua STA:** trong `timing_report_max.txt`, **không có một đường reg→out
nào** — ba đường xấu nhất đều là in→reg. Nếu có bất kỳ logic tổ hợp nào giữa FF và cổng ra,
STA bắt buộc phải liệt kê đường reg→out tương ứng.

| Hệ quả thực tế của Moore thuần | Giải thích |
|---|---|
| **Không có glitch trên cổng ra** | `Q` chuyển mạch sạch một lần mỗi chu kỳ |
| Bộ giải mã 7 vạch bên ngoài an toàn | Có thể lấy mẫu bất kỳ lúc nào sau `clk→Q` |
| Không có đường Mealy để lo | Khác D06, nơi `invert` tạo một đường Mealy |
| Đổi lại: **mọi** ngân sách thời gian dồn vào in→reg | Xem `datapath.md` §1 |

## 3. Sơ đồ trạng thái ASCII

3600 nút không vẽ được. Nhưng cấu trúc phân cấp vẽ được — và chính cấu trúc đó là nội dung
cần dạy:

```
  ╔══════════════════════════════════════════════════════════════════════════════════╗
  ║  MÁY CON ① — second_units (SU): vòng mod-10                                      ║
  ║                                                                                   ║
  ║        ADV=0 ⟳      ADV=0 ⟳                              ADV=0 ⟳                  ║
  ║          ╭╮          ╭╮                                    ╭╮                     ║
  ║          ▼│  ADV=1   ▼│  ADV=1              ADV=1          ▼│                     ║
  ║       ┌────┐ ────▶ ┌────┐ ────▶  …  ────▶ ┌────┐                                 ║
  ║       │SU=0│       │SU=1│                 │SU=9│                                  ║
  ║       └────┘       └────┘                 └─┬──┘                                  ║
  ║          ▲                                  │ ADV=1 · phát C0 · SU←0              ║
  ║          ╰──────────────────────────────────╯                                     ║
  ╚═══════════════════════════════════════════════════│═══════════════════════════════╝
                                                      │ C0
  ╔═══════════════════════════════════════════════════▼═══════════════════════════════╗
  ║  MÁY CON ② — second_tens (ST): vòng mod-6                                        ║
  ║       ┌────┐ ─C0─▶ ┌────┐ ─C0─▶  …  ─C0─▶ ┌────┐                                 ║
  ║       │ST=0│       │ST=1│                 │ST=5│                                  ║
  ║       └────┘       └────┘                 └─┬──┘                                  ║
  ║          ▲                                  │ C0 · phát C1 · ST←0                 ║
  ║          ╰──────────────────────────────────╯                                     ║
  ╚═══════════════════════════════════════════════════│═══════════════════════════════╝
                                                      │ C1
  ╔═══════════════════════════════════════════════════▼═══════════════════════════════╗
  ║  MÁY CON ③ — minute_units (MU): vòng mod-10                                      ║
  ║       ┌────┐ ─C1─▶  …  ─C1─▶ ┌────┐                                              ║
  ║       │MU=0│                 │MU=9│                                               ║
  ║       └────┘                 └─┬──┘                                               ║
  ║          ▲                     │ C1 · phát C2 · MU←0                              ║
  ║          ╰─────────────────────╯                                                  ║
  ╚═══════════════════════════════════════════════════│═══════════════════════════════╝
                                                      │ C2
  ╔═══════════════════════════════════════════════════▼═══════════════════════════════╗
  ║  MÁY CON ④ — minute_tens (MT): vòng mod-6                                        ║
  ║       ┌────┐ ─C2─▶  …  ─C2─▶ ┌────┐                                              ║
  ║       │MT=0│                 │MT=5│                                               ║
  ║       └────┘                 └─┬──┘                                               ║
  ║          ▲                     │ C2 · MT←0 · (C3 = C2 & MT≥5 — KHÔNG nối ra)      ║
  ║          ╰─────────────────────╯  ◀── ĐÂY LÀ BƯỚC 59:59 → 00:00                   ║
  ╚═══════════════════════════════════════════════════════════════════════════════════╝

  rst_n = 0  ⇒  MỌI máy con về trạng thái 0, từ BẤT KỲ trạng thái nào
```

**Điểm dễ hiểu sai nhất:** sơ đồ trên vẽ bốn máy con **nối tiếp về mặt logic**, nhưng trong
phần cứng chúng được tính **song song trong cùng một chu kỳ clock** — `C0`, `C1`, `C2` là
ba cổng ở **cùng một mức**, không phải ba mức nối tiếp (xem `block_diagram.md` §3). Toàn bộ
bước `59:59 → 00:00` xảy ra trong **một** cạnh lên, không phải bốn.

## 4. Bảng chuyển trạng thái đầy đủ

Dạng tổng quát (đúng cho cả 3600 trạng thái hợp lệ):

| `rst_n` | `ADV` | `SU` | `ST` | `MU` | `MT` | `SU'` | `ST'` | `MU'` | `MT'` | Lớp tràn |
|:-:|:-:|---|---|---|---|---|---|---|---|---|
| 0 | × | × | × | × | × | 0 | 0 | 0 | 0 | reset |
| 1 | 0 | `su` | `st` | `mu` | `mt` | `su` | `st` | `mu` | `mt` | giữ |
| 1 | 1 | `<9` | `st` | `mu` | `mt` | `su+1` | `st` | `mu` | `mt` | **T0** |
| 1 | 1 | `≥9` | `<5` | `mu` | `mt` | 0 | `st+1` | `mu` | `mt` | **T1** |
| 1 | 1 | `≥9` | `≥5` | `<9` | `mt` | 0 | 0 | `mu+1` | `mt` | **T2** |
| 1 | 1 | `≥9` | `≥5` | `≥9` | `<5` | 0 | 0 | 0 | `mt+1` | **T3** |
| 1 | 1 | `≥9` | `≥5` | `≥9` | `≥5` | 0 | 0 | 0 | 0 | **T4** |

`ADV = enable & tick_1hz`.

Các hàng đặc trưng với giá trị cụ thể:

| Trạng thái | + 1 bước tiến | Lớp | Số lần trong 3600 bước | Kiểm trong TB? |
|---|---|---|---:|:-:|
| `00:00` → `00:01` | tăng `SU` | T0 | 3240 | ✅ |
| `00:09` → `00:10` | tràn 1 tầng | T1 | 300 | ✅ |
| `00:58` → `00:59` | tăng `SU` | T0 | — | ✅ assert dòng 31 |
| **`00:59` → `01:00`** | **tràn 2 tầng** | **T2** | 54 | ✅ **assert dòng 35** |
| `09:59` → `10:00` | tràn 3 tầng | **T3** | 5 | ⚠️ có xảy ra, **không assert** |
| **`59:59` → `00:00`** | **tràn 4 tầng** | **T4** | **1** | ❌ **KHÔNG BAO GIỜ xảy ra** |
| `01:00` (`enable=0`) → `01:00` | giữ | — | 3 | ✅ assert dòng 40 |

Tổng: `3240 + 300 + 54 + 5 + 1 = 3600` ✅

> ❗ Hàng **T4** là ca Charter mục 8 liệt kê **bắt buộc** và Charter mục 10 gọi là "chỗ hay
> tắc". Testbench dừng đúng tại `59:59` (bằng chứng số học ở `corner_cases.md` §1, phát
> hiện 2). **Nhánh chuyển trạng thái này chưa từng được thực thi trên RTL.**

## 5. Mã hoá trạng thái

| Máy con | Mã hoá | Số bit **cần** | Số bit **thật** | Bit thừa |
|---|---|---:|---:|---:|
| ① `SU` (mod-10) | **BCD** (nhị phân 0…9) | 4 | 4 | 0 |
| ② `ST` (mod-6) | **BCD** (nhị phân 0…5) | 3 | **4** | **1 — hằng 0** |
| ③ `MU` (mod-10) | **BCD** | 4 | 4 | 0 |
| ④ `MT` (mod-6) | **BCD** | 3 | **4** | **1 — hằng 0** |
| | | **14** | **16** | **2** |

**Vì sao chọn mã hoá BCD 4 bit mỗi chữ số thay vì mã hoá tối thiểu?**

| Tiêu chí | BCD 4-4-4-4 (hiện tại) | BCD 4-3-4-3 (tối thiểu) | Nhị phân 6+6 |
|---|---:|---:|---:|
| Flip-flop | **16** (đo được) | 14 | 12 |
| Chi phí giải mã ra 7 vạch | **0** — mỗi chữ số đã sẵn | 0, nhưng phải đệm bit 3 = 0 | **cần bộ chia cho 10** — rất đắt |
| Độ rộng cổng ra | 16 bit, chia 4 nhóm đều | 14 bit, không đều — khó ghép kênh | 12 bit, phải chuyển đổi |
| Khớp chuẩn công nghiệp | ✅ BCD chuẩn | ⚠️ phi chuẩn | ❌ |

Kết luận: **2 flip-flop thừa là cái giá trả cho tính đều đặn của giao diện.** Với Charter
mục 10 cho ngân sách 15–17 ô nhớ, chi phí đó nằm trong phạm vi cho phép.

**Không có mã hoá one-hot** — sẽ cần `10 + 6 + 10 + 6 = 32` FF, gấp đôi.
**Không có mã hoá Gray** — sẽ cản phép so sánh `< 9` / `< 5` vốn là trung tâm của thiết kế
(cùng lý do như ở D06, xem `fsm.md` của D06 §6).

## 6. Xử lý trạng thái bất hợp lệ — **có, và được xử lý tốt**

Đây là đề duy nhất trong ba đề D05/D06/D07 **thực sự có** trạng thái bất hợp lệ:

| | Số tổ hợp |
|---|---:|
| Không gian mã hoá `2¹⁶` | **65 536** |
| Trạng thái hợp lệ (`SU≤9, ST≤5, MU≤9, MT≤5`) | **3 600** |
| **Trạng thái BẤT HỢP LỆ** | **61 936** (94,5 %) |

Hơn 94 % không gian mã hoá là bất hợp lệ. Một FSM one-hot hay một FSM mã hoá thưa với tỉ lệ
này **bắt buộc** phải có nhánh phục hồi, nếu không sẽ lock-up.

**D07 xử lý được — miễn phí — nhờ cách viết điều kiện:**

```verilog
if (second_units < 4'd9) second_units <= second_units + 4'd1;   // dòng 18–19
else begin second_units <= 4'd0; ... end                         // dòng 20–21
```

Dùng `<` chứ **không** dùng `==`. Với `SU = 12`: `12 < 9` sai → nhánh `else` → `SU ← 0` và
phát carry. **Phục hồi trong đúng 1 bước tiến.**

**Bằng chứng netlist rằng tool hiện thực đúng `≥`:**

```verilog
sky130_fd_sc_hd__o31ai_1 _066_ (.A1(su[2]), .A2(su[1]), .A3(su[0]), .B1(su[3]), .Y(_021_));
// _021_ = ~((su2 | su1 | su0) & su3)
// _021_ = 0 ("đầy")  ⟺  su3 = 1 VÀ (su2|su1|su0) = 1  ⟺  su ∈ {9,10,…,15}  ⟺  su ≥ 9
```

Cùng dạng cho `ST`: `_016_ = ~st3`, `_018_ = ~((st1|st0) & st2)`, "đầy" khi `st ≥ 5`.

| Nếu viết thế này | `SU = 12` sẽ đi đâu | Hậu quả |
|---|---|---|
| `if (SU < 9) … else SU<=0` (**RTL thật**) | `SU ← 0` + carry | ✅ Phục hồi 1 bước, sai lệch ≤ 1 giây |
| `if (SU == 9) SU<=0 else SU<=SU+1` | `13 → 14 → 15 → 0` | ❌ Quay vòng 16 thay vì 10, **sai nhịp vĩnh viễn** |
| `case (SU) … 9: SU<=0; endcase` không `default` | latch hoặc giữ nguyên | ❌ Có thể **lock-up** |

**Thời gian phục hồi xấu nhất:** một chữ số bất hợp lệ về 0 sau 1 bước tiến. Nếu cả bốn
chữ số bất hợp lệ cùng lúc, chúng vẫn được đánh giá **song song** trong cùng một cạnh lên
→ toàn bộ máy về trạng thái hợp lệ sau **1 bước tiến**, tức ≤ 1 giây thời gian thực.

> **Đây là điểm dạy học đáng giá nhất về phong cách viết RTL trong cả ba đề:** một lựa chọn
> tưởng như thẩm mỹ (`<` thay vì `==`) quyết định việc mạch có tự phục hồi từ 61 936 trạng
> thái lỗi hay không. Và nó **không tốn thêm một cell nào** — ngược lại, `o31ai_1` một cell
> còn rẻ hơn bộ giải mã chính xác `== 9`.

**Hạn chế phải nêu:** máy tự phục hồi nhưng **không báo** đã có lỗi. Không có cờ
`bcd_error`. Nếu ứng dụng cần biết, tầng ngoài phải tự kiểm miền BCD. Và **ca này chưa từng
được mô phỏng** — xem `corner_cases.md` §4, TC-E.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
