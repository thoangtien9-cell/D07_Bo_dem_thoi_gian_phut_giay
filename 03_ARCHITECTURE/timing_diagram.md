# D07 · Giản đồ thời gian (Timing Diagram)

---

## 1. Điều phải nói trước mọi giản đồ

Waveform dưới đây dựng lại từ **chính** `05_VERIFICATION/testbench/d07_bcd_tb.sv` và ngữ
nghĩa của `d07_bcd_core.sv`, đối chiếu với `simulation.log` (`$finish` tại **36036**).

> ❗ Đây là mô phỏng **hành vi (behavioural, zero-delay)**. Mọi tín hiệu đổi mức **đúng tại**
> cạnh lên clock. Giản đồ này **không** minh hoạ được: cell `_072_ a2111oi_0` mất **1,05 ns**
> với slew đầu ra **1,25 ns**, `clk→Q` của `dfxtp_1`, hay vi phạm setup trên `tick_1hz`.
> Muốn thấy phải mô phỏng **gate-level** trên `06_GDSII/synthesis/netlist.v` — **chưa chạy**.

Quy ước: chu kỳ clock = 10 ns (`always #5 clk=~clk`), cạnh lên thứ `n` tại `t = 5 + 10(n−1)`.

**Cảnh báo về tỉ lệ thời gian:** trong ứng dụng thật, `tick_1hz` xuất hiện **một lần mỗi
giây**, tức cách nhau hàng chục nghìn chu kỳ clock. Testbench **nén** tỉ lệ đó xuống: nó
cấp `tick_1hz = 1` tại **mọi** cạnh lên, nên một "giây mô phỏng" chỉ dài 10 ns. Giản đồ
dưới đây theo tỉ lệ của testbench, **không** theo tỉ lệ thật.

## 2. Pha reset và bốn mốc kiểm (cạnh lên 1–3)

```
 cạnh lên     │   1     │   2     │   3     │   4     │
 t (ns)       0    5    10   15   20   25   30   35   40
              ┌────┐    ┌────┐    ┌────┐    ┌────┐
 clk     ─────┘    └────┘    └────┘    └────┘    └────
                   ▲         ▲         ▲         ▲
 rst_n   ────────────────────┐
              (=0)           └──────────────────────────  (=1 ngay sau cạnh lên 2)
 enable  ─┬────────────────────────────────────────────   (=1 SUỐT, trừ 3 tick ở §4)
          │
 tick_1hz ─────────────────────┌───────────────────────   (=1 từ lời gọi tick() đầu tiên,
              (=0 lúc reset)   └                           và GIỮ =1 tại MỌI cạnh lên sau)

 MT:MU:ST:SU  ══ xxxx ══╪══ 0000 ══╪══ 0000 ══╪══ 0001 ══
                        ▲          ▲          ▲
                        │          │          └─ bước tiến thứ 1: 00:00 → 00:01
                        │          └─ assert dòng 27: {mt,mu,st,su} == 16'h0000 ✅
                        └─ cạnh lên 1: rst_n=0 → xoá X ở cả 16 FF
```

**Đọc gì:** reset **đồng bộ** — 16 FF chỉ về 0 nhờ có cạnh lên. Chú ý `tick_1hz = 0` trong
pha reset, đó là **hai cạnh lên duy nhất** trong toàn bộ mô phỏng có `tick_1hz = 0`, và
chúng nằm trong lúc `rst_n = 0` nên không chứng minh được gì về INV-5.

## 3. Giao dịch điển hình — tràn 2 tầng `00:59 → 01:00` (lớp T2)

Đây là ca Charter mục 8 (*"chuyển 58→59→00 ở giây, phải tăng phút"*), và là ca duy nhất có
assert cho một bước tràn.

```
 bước tiến     …   57       58       59       60      (tạm dừng — xem §4)
 cạnh lên      …   59       60       61       62       63
                 ┌────┐   ┌────┐   ┌────┐   ┌────┐   ┌────┐
 clk       ──────┘    └───┘    └───┘    └───┘    └───┘    └───
                      ▲        ▲        ▲        ▲        ▲
 tick_1hz  ═══════════1════════1════════1════════1════════1═══   (LUÔN bằng 1)
 enable    ═══════════1════════1════════1════════1════════0═══

 SU        ══ 6 ══╪══ 7 ══╪══ 8 ══╪══ 9 ══╪══ 0 ══╪══ 0 ══
 ST        ══ 5 ══╪══ 5 ══╪══ 5 ══╪══ 5 ══╪══ 0 ══╪══ 0 ══
 MU        ══ 0 ══╪══ 0 ══╪══ 0 ══╪══ 0 ══╪══ 1 ══╪══ 1 ══
 MT        ══ 0 ══╪══ 0 ══╪══ 0 ══╪══ 0 ══╪══ 0 ══╪══ 0 ══
 hiển thị   00:56   00:57   00:58   00:59   01:00   01:00
                                      ▲        ▲
                    assert dòng 31: 16'h0059 ✅ │
                                   assert dòng 35: 16'h0100 ✅

 Nút carry trong CÙNG cạnh lên đó:
   ADV = 1                  ← enable & tick_1hz
   _021_ = 0  (SU ≥ 9)      ← o31ai_1 _066_
   C0 = 1                   ← nor2_1 _067_    ⇒ ST phải đổi
   _016_&_018_ = 0 (ST ≥ 5) ← clkinv _061_ + o21ai _063_
   C1 = 1                   ← a211oi_1 _068_  ⇒ MU phải đổi
   _026_ = 1  (MU < 9)      ← o31ai_1 _071_
   C2 = 0                   ← a2111oi_0 _072_ ⇒ MT GIỮ NGUYÊN
                              ▲
                              └── ba carry này được tính SONG SONG,
                                  không phải nối tiếp. Toàn bộ tràn 2 tầng
                                  hoàn tất trong MỘT cạnh lên.
```

**Điểm phải nhấn mạnh:** `SU: 9→0`, `ST: 5→0`, `MU: 0→1` xảy ra **đồng thời** tại cùng một
cạnh lên. Không có trạng thái trung gian `00:00` hay `01:59` nào tồn tại, dù chỉ một chu kỳ.

## 4. Ca "tạm dừng" — `enable = 0` (cạnh lên 63–65)

```
 cạnh lên       │  62   │  63   │  64   │  65   │  66   │
                ┌────┐  ┌────┐  ┌────┐  ┌────┐  ┌────┐
 clk       ─────┘    └──┘    └──┘    └──┘    └──┘    └──
                     ▲       ▲       ▲       ▲       ▲
 enable    ══════1═══╪═══0═══╪═══0═══╪═══0═══╪═══1═══╪══
                     │       └───────┬───────┘       │
 tick_1hz  ══════1═══╪═══1═══╪═══1═══╪═══1═══╪═══1═══╪══
                     │   (tick_1hz VẪN bằng 1 — chỉ enable hạ xuống)
 ADV       ══════1═══╪═══0═══╪═══0═══╪═══0═══╪═══1═══╪══

 MT:MU:ST:SU  01:00 ╪ 01:00 ╪ 01:00 ╪ 01:00 ╪ 01:01 ╪
                            └───────┬───────┘
                          assert dòng 40: vẫn 16'h0100 ✅
```

> ⚠️ **Ca đối xứng KHÔNG tồn tại trong testbench.** Không có đoạn nào hạ `tick_1hz` xuống 0
> trong khi `enable = 1`. Vì `enable` và `tick_1hz` đi vào cùng một cổng AND
> (`and2_0 _064_`), ca trên phủ đúng cùng một đường **logic**, nhưng **không** chứng minh
> được rằng DUT thực sự dùng `tick_1hz`. Xem `corner_cases.md` §1 phát hiện 3 và §4 TC-B.

## 5. Ca `59:59 → 00:00` — **KHÔNG CÓ trong mô phỏng**, chỉ dựng lại từ RTL

Đây là ca Charter mục 8 bắt buộc. Mô phỏng dừng **đúng tại** `59:59` (bằng chứng ở
`corner_cases.md` §1). Giản đồ dưới là **suy từ mã nguồn**, không phải quan sát từ log:

```
 bước tiến      …  3598     3599    │  3600  ←── BƯỚC NÀY KHÔNG ĐƯỢC THỰC HIỆN
 cạnh lên       …  3603     3604    │  3605  (mô phỏng $finish tại 36036 ns = sau cạnh 3604)
                  ┌────┐   ┌────┐   │ ┌────┐
 clk       ───────┘    └───┘    └───┼─┘    └───
                       ▲        ▲   │      ▲
 tick_1hz  ════════════1════════1═══│══════?
                                    │
 SU        ══ 7 ══╪══ 8 ══╪══ 9 ════│══ 0 ══     ← tất cả bốn chữ số đổi
 ST        ══ 5 ══╪══ 5 ══╪══ 5 ════│══ 0 ══        CÙNG MỘT cạnh lên
 MU        ══ 9 ══╪══ 9 ══╪══ 9 ════│══ 0 ══
 MT        ══ 5 ══╪══ 5 ══╪══ 5 ════│══ 0 ══
 hiển thị   59:57   59:58   59:59   │  00:00
                              ▲     │    ▲
                              │     │    └─ ⬜ CHƯA BAO GIỜ QUAN SÁT ĐƯỢC
                              └─ $finish ở đây, KHÔNG có assert

 Nút carry của bước 3600 (suy từ netlist):
   ADV   = 1
   _021_ = 0   (SU ≥ 9)  ──┐
   _016_ = 1, _018_ = 0    │  ← o31ai_1 _066_, clkinv _061_, o21ai_0 _063_
      ⇒ ST ≥ 5            │
   _026_ = 0   (MU ≥ 9)  ──┤  ← o31ai_1 _071_
                           │
   C2 = _027_ = 1  ────────┘  ← a2111oi_0 _072_  ⇒ MT phải đổi
                              ▲
                              └── LẦN DUY NHẤT trong 3600 bước mà _027_ = 1
                                  ĐỒNG THỜI với (MT ≥ 5)
   MT ≥ 5  ⇒  and3b_1 _085_: A_N(_027_)=0  ⇒  _003_ = 0  ⇒  MT[3] ← 0
   (và các cell _081_…_084_ ép MT[2:0] ← 0)
```

> ❗ Lớp T4 xảy ra **đúng 1 lần trong 3600 bước** (xem `corner_cases.md` §3) và là **lần duy
> nhất** đường tới hạn `tick_1hz → _065_ → _072_ → _085_ → _125_` được kích hoạt đầy đủ.
> Bỏ ca này là bỏ đồng thời **ca chức năng khó nhất** và **ca thời gian xấu nhất**.
> Bản vá 3 dòng để có nó: `corner_cases.md` §4.

## 6. Quan hệ giữa waveform và số liệu STA thật

Waveform zero-delay giấu những con số sau:

| Sự kiện trong waveform | Thời gian thật sau mốc `clk` | Nguồn |
|---|---:|---|
| `tick_1hz` khả dụng (giả định `input_delay`) | **1,00 ns** | `design.sdc` |
| `_020_` = `~ADV` sẵn sàng (`_065_ nand2_1`) | 1,07 ns (+0,07) | `timing_report_max.txt` |
| **`_027_` = C2 sẵn sàng (`_072_ a2111oi_0`)** | **2,13 ns (+1,05)** | **cell chậm nhất thiết kế** |
| `D` của `minute_tens[3]` sẵn sàng (`_085_ and3b_1`) | **2,40 ns (+0,27)** | `data arrival time` |
| Lề setup còn lại (chu kỳ 10 ns) | **7,49 ns** | `slack (MET)` |
| Mọi cổng ra sau `clk→Q` | ≈ 0,3–0,4 ns, **0 cell logic** | không có đường reg→out |

### Giản đồ lan truyền của đường tới hạn (phóng to trục thời gian)

```
  t (ns):  0        0,5       1,0       1,5       2,0       2,5
           ├─────────┼─────────┼─────────┼─────────┼─────────┤
  clk  ────┐
           └──────────────────────────────────────────────────

  tick_1hz ░░░░░░░░░░░░░░░░░░░░┃━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                          1,00 ┃  ← giả định set_input_delay
                               ┃
  _020_    ░░░░░░░░░░░░░░░░░░░░░░┃━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                            1,07┃  +0,07 (nand2_1 — nhanh)
                                ┃
  _027_    ░░░░░░░░░░░░░░░░░░░░░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓┃━━━━━━━━
                                │◀──── +1,05 ns ────▶│2,13
                                │  a2111oi_0, 5 đầu vào, drive _0, fanout 7
                                │  slew đầu ra 1,25 ns — sườn RẤT CHẬM
                                                     ┃
  _003_    ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▓▓▓▓┃━━
                                                     │+0,27│2,40
                                                           ┃
                                                           ▼
                                              setup tại _125_/D
                                              required 9,88 → slack 7,49

  ░ = chưa hợp lệ    ▓ = đang chuyển (vùng chưa ổn định)    ━ = đã ổn định
```

**Kết luận đọc được từ giản đồ này mà không đọc được từ waveform hành vi:** đường tới hạn
của D07 chỉ có **3 cell**, nhưng **một cell chiếm 44 % thời gian đến**. Đây là vấn đề
**sizing và fanout**, không phải vấn đề kiến trúc, và nó được giải ở bước physical design
(`repair_design` của OpenROAD, hoặc `set_max_fanout` trong SDC) — **chưa chạy**.

## 7. Bảng tổng kết các mốc trong lần chạy thật

| Cạnh lên | Bước tiến tích luỹ | Sự kiện | Dòng TB | Thời gian hiển thị |
|---:|---:|---|---|---|
| 1–2 | 0 | Reset tích cực, `tick_1hz=0` | 23–24 | `00:00` (sau cạnh 1) |
| — | 0 | `rst_n` nhả + assert | 25–27 | `00:00` ✅ |
| 3–61 | 59 | 59 bước tiến + assert | 30–31 | `00:59` ✅ |
| 62 | 60 | Tràn 2 tầng + assert | 34–35 | `01:00` ✅ |
| 63–65 | 60 | `enable=0`, 3 nhịp + assert | 38–40 | `01:00` ✅ |
| 66–3604 | **3599** | 3539 bước tiến, **không assert nào** | 45 | **`59:59`** ⬜ |
| — | 3599 | `$display` + `$finish` tại **36036 ns** | 48–49 | dừng tại `59:59` |
| *(3605)* | *(3600)* | **`59:59 → 00:00`** | — | ❌ **không thực hiện** |

Kiểm chứng: `2 + 59 + 1 + 3 + 3539 = 3604` cạnh lên → `t = 5 + 10 × 3603 = 36035`, cộng
`#1` của `tick()` = **36036 ns**. Khớp chính xác `simulation.log`.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
