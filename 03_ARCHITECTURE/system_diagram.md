# D07 · Sơ đồ hệ thống (System Diagram)

---

## 1. Bối cảnh ứng dụng — đồng hồ bấm giờ cho máy tập thể dục

Charter mục 1: *"Khối đồng hồ bấm giờ cho máy tập thể dục, đếm phút:giây từ xung 1 Hz của
bộ dao động thạch anh."*

```
   NGUỒN THỜI GIAN CHUẨN              MIỀN CLOCK HỆ THỐNG (một miền duy nhất)          HIỂN THỊ
   ═════════════════════              ══════════════════════════════════════          ══════════

  ┌──────────────┐                  ┌────────────────────────────────────────┐
  │ Thạch anh    │   32 768 Hz      │                                        │
  │ 32,768 kHz   ├─────────────┐    │   ┌────────────────────────────────┐   │
  └──────────────┘             │    │   │  ►► D07 ◄◄                     │   │
                               ▼    │   │  Bộ đếm phút:giây              │   │
  ┌──────────────────────────────┐  │   │                                │   │  16 bit
  │ Bộ chia tần ÷32768           │  │   │  ┌──────────┐  ┌────────────┐  │   │  SONG SONG
  │ (NGOÀI khối này)             ├──┼──▶│  │ giây     │─▶│ phút       │  ├───┼──┬──▶ ┌──────────────┐
  │ sinh xung rộng 1 CHU KỲ CLK  │  │   │  │ mod-60   │  │ mod-60     │  │   │  │    │ Giải mã 7 vạch│
  └──────────────────────────────┘  │   │  │ ST:SU    │  │ MT:MU      │  │   │  │    │ ×4 chữ số     │
         │ tick_1hz                 │   │  └──────────┘  └────────────┘  │   │  │    └───────┬───────┘
         └──────────────────────────┼──▶│                                │   │  │            ▼
                                    │   │  ✗ KHÔNG có bộ ghép kênh ra    │   │  │    ┌──────────────┐
  ┌──────────────┐  nút Start/Stop  │   │    (Charter mục 4 ĐÒI          │   │  │    │ LED 4 chữ số │
  │ Bàn phím máy ├──▶ chống rung ───┼──▶│     uo_out[7:0] ghép kênh +    │   │  │    │  MM:SS       │
  │ tập          │   (NGOÀI khối)   │   │     uio_out[0] "đang xuất phút")│  │  │    └──────────────┘
  └──────────────┘    enable        │   └────────────────────────────────┘   │  │
                                    │                                        │  └──▶ ┌──────────────┐
  ┌──────────────┐  clk ───────────▶│                                        │       │ Ghi kết quả  │
  │ PLL / dao    │                  │                                        │       │ buổi tập     │
  │ động hệ thống│  rst_n ─────────▶│                                        │       └──────────────┘
  └──────────────┘                  └────────────────────────────────────────┘
```

**Điểm kiến trúc quan trọng nhất của bức tranh này:** `tick_1hz` là **dữ liệu**, không phải
**clock**. Toàn bộ D07 nằm trong **một miền clock duy nhất** (`clk`). Netlist xác nhận: cả
16 `dfxtp_1` đều nối `.CLK(clk)`, không FF nào dùng `tick_1hz` làm clock.

Vì sao điều này quan trọng: nếu viết `always_ff @(posedge tick_1hz)`, thiết kế sẽ có **hai
miền clock**, cần phân tích ranh giới miền clock (đề J01), cần cây clock thứ hai, và STA sẽ
phải khai báo `create_clock` cho một tín hiệu 1 Hz — tức chu kỳ **1 giây**, làm mọi ràng
buộc thời gian trở nên vô nghĩa. Cách làm của RTL là cách đúng.

**Hệ quả kèm theo (nghĩa vụ tầng ngoài):** bộ chia tần bên ngoài phải sinh ra một xung rộng
**đúng một chu kỳ clock**, không phải một mức cao dài 1 giây. D07 **không** có bộ phát hiện
sườn. Nếu tầng ngoài cấp mức dài, đồng hồ chạy nhanh gấp `f_clk` lần — và testbench hiện
tại **không phát hiện được** (xem `corner_cases.md` §1, phát hiện 3).

## 2. Ranh giới khối — cái gì thuộc D07, cái gì không

| Thành phần | Thuộc D07? | Ghi chú |
|---|:-:|---|
| 4 thanh ghi BCD (16 FF) | ✅ | `dfxtp_1` × 16 |
| Logic tràn `SU→ST→MU→MT` | ✅ | ≈ 61 cell tổ hợp |
| Logic tự phục hồi trạng thái BCD bất hợp lệ | ✅ | Miễn phí, nhờ dùng `<` thay `==` |
| Bộ dao động thạch anh 32,768 kHz | ❌ | Ngoài chip |
| **Bộ chia tần ÷32768 sinh `tick_1hz`** | ❌ | Tầng ngoài. D07 **chỉ tiêu thụ** xung, không sinh ra nó |
| Bộ phát hiện sườn cho `tick_1hz` | ❌ **nhưng ứng dụng cần** | Không có trong RTL; nghĩa vụ tầng ngoài |
| Chống rung nút Start/Stop | ❌ | Tầng ngoài |
| **Bộ ghép kênh phút/giây ra 8 chân** | ❌ **nhưng Charter mục 4 ĐÒI** | Xem cảnh báo C4-4/C4-5 ở `functional_spec.md` |
| Giải mã BCD → 7 vạch | ❌ | Tầng ngoài. **BCD làm phần này rẻ đi rất nhiều** — xem `tradeoff.md` |
| Lưu kết quả buổi tập | ❌ | Tầng ngoài |
| Đếm giờ, ngày, lịch | ❌ | Charter mục 3: ngoài phạm vi |

**Nghĩa vụ hợp đồng của tầng ngoài:**

1. Giữ `rst_n = 0` qua **ít nhất một cạnh lên `clk`** (reset đồng bộ).
2. `tick_1hz` phải là **xung một chu kỳ clock**, đồng bộ với `clk`.
3. Nếu `tick_1hz` đến từ miền clock khác, **bắt buộc** đồng bộ 2 tầng + phát hiện sườn.
4. `enable` ổn định quanh cạnh lên.
5. Tự thực hiện phần ghép kênh hiển thị nếu cần tiết kiệm chân (D07 hiện xuất song song 16 bit).

## 3. Phân loại analog / digital / mixed

**Digital thuần.** Toàn bộ 77 cell trong `06_GDSII/synthesis/netlist.v` thuộc thư viện
standard cell số `sky130_fd_sc_hd`; `power_report.txt` có hàng `Macro` = 0,0 % → không macro
analog.

Phần **analog** của hệ thống — mạch dao động thạch anh — nằm **ngoài** khối. Đó là chỗ duy
nhất trong ba đề D05/D06/D07 mà độ chính xác cuối cùng của sản phẩm do một linh kiện analog
quyết định: sai số của đồng hồ = sai số của tinh thể thạch anh (thường ±20 ppm ≈ ±1,7 giây
mỗi ngày), **không phụ thuộc** vào bất cứ điều gì D07 làm.

## 4. Vòng đời RTL → GDSII — trạng thái thật từng bước

```
   ┌──────────────────────────────────────────────────────────────────────────────┐
   │  ✅ 1. Đặc tả       Charter mục 1/4/8/9 → 01_REQUIREMENT, 02_SPECIFICATION   │
   └──────────────────────────────────┬───────────────────────────────────────────┘
                                      ▼
   ┌──────────────────────────────────────────────────────────────────────────────┐
   │  ✅ 2. Mô hình chuẩn Python      reference_model.py → PASS                    │
   │        "3600 unique minute:second states verified"                            │
   │        Bằng chứng: 05_VERIFICATION/python_reference_run.log                   │
   └──────────────────────────────────┬───────────────────────────────────────────┘
                                      ▼
   ┌──────────────────────────────────────────────────────────────────────────────┐
   │  ✅ 3. RTL   d07_bcd_core.sv (top)  +  d07_binary_core.sv (đối chứng, KHÔNG   │
   │              được instantiate, KHÔNG tổng hợp)                               │
   └──────────────────────────────────┬───────────────────────────────────────────┘
                                      ▼
   ┌──────────────────────────────────────────────────────────────────────────────┐
   │  ⚠️ 4. Mô phỏng RTL  Icarus Verilog → **PASS**, không lỗi biên dịch           │
   │        "D07 BCD TB PASS" · $finish tại 36036 (= 3604 cạnh lên × 10 ns + 1 ns) │
   │        ⚠ PASS này CHƯA phủ ca 59:59→00:00 (Charter mục 8 BẮT BUỘC)           │
   │        ⚠ PASS này CHƯA phủ tick_1hz=0, và KHÔNG đấu mô hình chuẩn vào DUT     │
   └──────────────────────────────────┬───────────────────────────────────────────┘
                                      ▼
   ┌──────────────────────────────────────────────────────────────────────────────┐
   │  ✅ 5. Tổng hợp  Yosys 0.33 + sky130_fd_sc_hd → 77 cell · 16 FF · 665,6384 µm²│
   └──────────────────────────────────┬───────────────────────────────────────────┘
                                      ▼
   ┌──────────────────────────────────────────────────────────────────────────────┐
   │  ✅ 6. STA sau tổng hợp  OpenSTA 3.1.0 → PASS · slack 7,49 ns · WNS/TNS 0,00  │
   │        Đường tới hạn: tick_1hz → … → _125_ (= minute_tens[3], FF HẰNG 0!)    │
   └──────────────────────────────────┬───────────────────────────────────────────┘
                                      ▼
   ┌──────────────────────────────────────────────────────────────────────────────┐
   │  ✅ 7. Ước lượng công suất  6,77e-05 W (tuần tự 97,3 % · tổ hợp 2,7 %)        │
   └──────────────────────────────────┬───────────────────────────────────────────┘
                                      ▼
   ┌──────────────────────────────────────────────────────────────────────────────┐
   │  ⬜ 8. Floorplan   ⬜ 9. Placement   ⬜ 10. CTS   ⬜ 11. Routing               │
   │  ⬜ 12. DRC        ⬜ 13. LVS        ⬜ 14. GDS                                │
   │        Cần: PDK sky130A + LibreLane/OpenROAD                                  │
   │        Lệnh có sẵn: 04_IMPLEMENTATION/scripts/04_run_librelane.sh             │
   └──────────────────────────────────┬───────────────────────────────────────────┘
                                      ▼
   ┌──────────────────────────────────────────────────────────────────────────────┐
   │  ⬛ 15. Sign-off · tape-out · chế tạo · đo sau chế tạo                        │
   │        KHÔNG ÁP DỤNG — Charter mục 3 liệt kê ngoài phạm vi                    │
   └──────────────────────────────────────────────────────────────────────────────┘
```

Nguồn: `06_GDSII/physical_report.md` §1 và BRIEF D07.

| Ký hiệu | Nghĩa | Số bước |
|---|---|---:|
| ✅ | đã chạy thật, có log | **6** |
| ⚠️ | đã chạy và PASS, **nhưng độ phủ chưa đủ theo Charter mục 8** | **1** (bước 4) |
| ⬜ | chưa chạy, thiếu điều kiện | **7** |
| ⬛ | không áp dụng (ngoài phạm vi Charter) | **1** |

> ❗ Ký hiệu ⚠️ ở bước 4 là **có chủ ý**. Log ghi PASS, nhưng PASS đó không bao gồm ca
> `59:59 → 00:00` mà Charter mục 8 liệt kê bắt buộc. Ghi ✅ ở đây sẽ là phát biểu vượt mức.
> Chi tiết và bản vá 3 dòng ở `corner_cases.md` §4.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
