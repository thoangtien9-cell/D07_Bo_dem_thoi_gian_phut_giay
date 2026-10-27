# D07 · Phần điều khiển (Control)

---

## 1. Ba tín hiệu điều khiển, không có bộ điều khiển

D07 có 16 flip-flop, nhưng cả 16 bit đều là **dữ liệu** (giá trị thời gian). Không bit nào
mã hoá "đang ở bước xử lý nào". Ba tín hiệu điều khiển đều là **mức**, tác động trực tiếp.

| Tín hiệu | Tích cực | Tác dụng | Dòng RTL | Hiện thực netlist | Fanout |
|---|---|---|---|---|---:|
| `rst_n` | thấp | Ép cả 4 chữ số về 0 tại cạnh lên kế | 12–16 | Gộp vào `D` của cả 16 FF (`o21ai_0`×8, `and2_0`, `nand2_1`, `a21bo_1`, `and3b_1`…) | 16+ |
| `enable` | cao | Cho phép tiến | 17 | `and2_0 _064_`, `nand2_1 _065_` | 2 |
| `tick_1hz` | cao | Cho phép tiến | 17 | `and2_0 _064_`, `nand2_1 _065_` | **3** (STA) |

**Điểm đặc biệt của D07:** `enable` và `tick_1hz` được AND lại **ngay lập tức** thành một
tín hiệu duy nhất, rồi chỉ tín hiệu gộp đó mới đi tiếp:

```verilog
end else if (enable && tick_1hz) begin          // d07_bcd_core.sv, dòng 17
```

```verilog
sky130_fd_sc_hd__and2_0  _064_ (.A(enable), .B(tick_1hz), .X(_019_));   //  ADV
sky130_fd_sc_hd__nand2_1 _065_ (.A(enable), .B(tick_1hz), .Y(_020_));   // ~ADV
```

Tool sinh **cả hai** dạng (thuận và đảo) vì cả hai đều được dùng ở các cell sau. Từ điểm
này trở đi, phần còn lại của thiết kế **không phân biệt** `enable` với `tick_1hz` — chúng
hoàn toàn đối xứng về mặt logic.

> ⚠️ **Đây chính là gốc rễ của lỗ hổng kiểm thử ở `corner_cases.md` §1, phát hiện 3.**
> Vì hai tín hiệu đối xứng, một testbench chỉ kiểm `enable = 0` (TB làm ở dòng 38–40) sẽ
> phủ **đúng cùng một đường logic** mà ca `tick_1hz = 0` phủ. Nhưng chúng **không** tương
> đương về mặt **hệ thống**: `enable` đến từ nút bấm, `tick_1hz` đến từ bộ chia tần. Một
> DUT bỏ hẳn `tick_1hz` vẫn PASS testbench hiện tại, và sẽ chạy nhanh gấp `f_clk` lần.

## 2. Bảng tín hiệu điều khiển và tác dụng đầy đủ

| `rst_n` | `enable` | `tick_1hz` | Tại cạnh lên | Được kiểm? |
|:-:|:-:|:-:|---|---|
| 0 | × | × | Cả 4 chữ số ← 0 | ✅ TB dòng 27 (nhưng chỉ từ `00:00`) |
| 1 | 0 | 0 | Giữ nguyên | ❌ không kiểm |
| 1 | 0 | 1 | Giữ nguyên | ✅ TB dòng 38–40 |
| 1 | 1 | 0 | Giữ nguyên | ❌ **không kiểm** — INV-5 trắng |
| 1 | 1 | 1 | Tiến một giây | ✅ TB (3599 lần) |

**Bằng chứng `rst_n` ưu tiên tuyệt đối:** trong netlist, `rst_n` là toán hạng của cổng
**cuối cùng** trên mọi đường `D`. Ví dụ đường tới hạn:

```verilog
sky130_fd_sc_hd__and3b_1 _085_ (.A_N(_027_), .B(rst_n), .C(minute_tens[3]), .X(_003_));
```

`rst_n = 0` ⇒ `_003_ = 0` bất kể `_027_`. Đúng ngữ nghĩa `if (!rst_n) … else if …` của RTL
dòng 12–17.

## 3. Quan hệ điều khiển ↔ datapath

```
           ĐIỀU KHIỂN                                  DATAPATH
   ┌──────────────────────────┐          ┌──────────────────────────────────────┐
   │  KHÔNG có FSM            │          │                                      │
   │  KHÔNG có ô nhớ điều khiển│ enable ─┐│                                      │
   │  KHÔNG có bộ đếm phụ     │          ├─▶ _064_/_065_ → ADV, ~ADV            │
   │  KHÔNG có handshake      │tick_1hz ─┘│         │                            │
   │                          │           │         ├──▶ _067_ → C0 → bộ tăng ST │
   │  Chỉ là 2 DÂY + rst_n    │           │         ├──▶ _068_ → C1 → bộ tăng MU │
   │       2 cell             │           │         ├──▶ _072_ → C2 → bộ tăng MT │
   └──────────────────────────┘           │         └──▶ nhánh tăng SU           │
                                          │                                      │
                              rst_n ──────┼──▶ AND vào D của cả 16 FF            │
                                          └──────────────────────────────────────┘
```

Khác với D05 và D06, ở D07 tín hiệu điều khiển **không hoà tan hoàn toàn** vào datapath —
nó được **vật chất hoá** thành hai cell riêng (`_064_`, `_065_`) rồi phân phối đi. Lý do:
`ADV` được dùng ở **bốn** nhánh tăng khác nhau, nên tính một lần rồi chia sẻ rẻ hơn nhiều
so với lặp lại ở mỗi nhánh.

Cái giá của việc chia sẻ đó: `_020_` (~ADV) có **fanout 5**, và nó là đầu vào của `_072_` —
cell cổ chai. Chia sẻ logic tiết kiệm diện tích nhưng **tập trung tải vào ít nút hơn**, và
đó chính là điều đang xảy ra ở D07 (xem `datapath.md` §5.3).

## 4. Những cơ chế điều khiển D07 **không** có, và ai chịu trách nhiệm

| Cơ chế | Có? | Ai lo |
|---|:-:|---|
| FSM / thanh ghi trạng thái điều khiển | ❌ | Không cần — xem `fsm.md` |
| **Phát hiện sườn cho `tick_1hz`** | ❌ **nhưng ứng dụng cần** | **Tầng ngoài.** Nếu `tick_1hz` là mức dài 1 giây thay vì xung 1 chu kỳ, D07 đếm mỗi chu kỳ clock |
| Đồng bộ hoá `tick_1hz` từ miền clock khác | ❌ | Tầng ngoài — bắt buộc nếu bộ dao động chạy miền riêng |
| Chống rung nút Start/Stop cho `enable` | ❌ | Tầng ngoài |
| **Bộ ghép kênh xuất phút/giây** | ❌ **nhưng Charter mục 4 ĐÒI** | Chưa có ai — xem cảnh báo C4-4/C4-5 |
| Nạp giá trị đầu (đặt giờ) | ❌ | Không có trong Charter |
| Đếm lùi (countdown) | ❌ | Không có trong Charter |
| Cờ báo tràn giờ (`hour_tick`) | ❌ | Charter mục 3: giờ nằm ngoài phạm vi. Nhưng nút `_027_ & (MT≥5)` **đã tồn tại trong netlist** — chỉ cần nối ra là có |
| `start`/`done`/`busy` | ❌ | Khối chạy liên tục |

> 💡 **Quan sát đáng giá khi bảo vệ:** tín hiệu "tràn giờ" (`C3 = C2 & (MT ≥ 5)`) **đã được
> tính sẵn** trong phần cứng — nó là điều kiện quyết định `MT ← 0` thay vì `MT ← MT+1`.
> Nếu sau này cần mở rộng sang đếm giờ, chi phí là **0 cell logic mới**, chỉ cần một cổng
> ra. Nhưng Charter mục 3 liệt giờ vào **ngoài phạm vi**, nên chỉ được ghi chú, không làm.

## 5. Nghĩa vụ hợp đồng của tầng ngoài — phát biểu chặt

| # | Nghĩa vụ | Hậu quả nếu vi phạm |
|---|---|---|
| OB-1 | Giữ `rst_n = 0` qua **ít nhất 1 cạnh lên `clk`** | 16 FF giữ `x` sau bật nguồn; cả 4 chữ số = X |
| OB-2 | **`tick_1hz` phải là xung rộng ĐÚNG 1 chu kỳ clock** | Đồng hồ chạy nhanh gấp `f_clk` lần. **Đây là rủi ro hệ thống số 1 của đề**, và nó **chưa được kiểm** |
| OB-3 | `tick_1hz` và `enable` đồng bộ với `clk`, ổn định quanh cạnh lên | Vi phạm setup → FF chốt metastable → thời gian nhảy sang giá trị bất kỳ |
| OB-4 | Nếu `tick_1hz` từ miền clock khác: đồng bộ 2 tầng **rồi** phát hiện sườn | Đếm nhảy bước hoặc bỏ giây |
| OB-5 | Tự giải mã BCD → 7 vạch | D07 chỉ xuất BCD thô |
| OB-6 | Nếu cần tiết kiệm chân: tự ghép kênh phút/giây | D07 xuất song song 16 bit (Charter dự kiến 9) |
| OB-7 | Chấp nhận rằng trạng thái bất hợp lệ tự phục hồi sau **1 bước tiến**, không có cờ báo | Nếu cần phát hiện lỗi, tầng ngoài phải tự kiểm miền BCD |

**Ghi chú về OB-7 — một tính chất tốt được cho không:** vì RTL viết điều kiện bằng `<` chứ
không phải `==`, mọi chữ số rơi vào vùng bất hợp lệ sẽ về 0 và phát carry ngay ở bước tiến
kế tiếp. Chi tiết và bằng chứng netlist ở `functional_spec.md` §7. Tầng ngoài **không cần**
mạch phục hồi riêng — nhưng cũng **không nhận được cảnh báo** rằng đã có lỗi xảy ra.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
