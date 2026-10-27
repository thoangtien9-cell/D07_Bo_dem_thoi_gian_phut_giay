# D07 · Đường dữ liệu (Datapath)

---

## 1. Bốn vòng kín, không có nhánh cụt

```
                        ADV = enable & tick_1hz
                                │
        ┌───────────────────────┼───────────────────────────────────────┐
        │                       │                                       │
        ▼                       ▼                                       ▼
   ┌─────────┐   C0        ┌─────────┐   C1        ┌─────────┐  C2  ┌─────────┐
   │ +1 / 0  │────────────▶│ +1 / 0  │────────────▶│ +1 / 0  │─────▶│ +1 / 0  │
   └────┬────┘             └────┬────┘             └────┬────┘      └────┬────┘
        ▼                       ▼                       ▼                ▼
   ┌─────────┐            ┌─────────┐            ┌─────────┐       ┌─────────┐
   │ SU 4 FF │            │ ST 4 FF │            │ MU 4 FF │       │ MT 4 FF │
   └────┬────┘            └────┬────┘            └────┬────┘       └────┬────┘
        │  ╚═══ VÒNG 1 ════╝   │  ╚═══ VÒNG 2 ════╝   │ ╚═ VÒNG 3 ═╝   │ ╚═ VÒNG 4 ═╝
        ▼                      ▼                      ▼                ▼
  second_units[3:0]      second_tens[3:0]      minute_units[3:0]  minute_tens[3:0]
        ▲                      ▲                      ▲                ▲
        └──────────────────────┴──────────────────────┴────────────────┘
                    CỔNG RA = Q CỦA FF, KHÔNG QUA CELL NÀO
```

D07 khác hẳn D05 và D06 ở một điểm cấu trúc: **không có nhánh cụt**. Mọi flip-flop đều
xuất thẳng ra chân, và mọi logic đều nằm **bên trong** vòng hồi tiếp.

Hệ quả đo được trong `timing_report_max.txt`: **không có đường reg→out nào chứa cell logic**.
Ba đường xấu nhất đều là **in→reg** xuất phát từ `tick_1hz`. Đây là lý do toàn bộ ngân sách
thời gian của D07 dồn vào một chỗ duy nhất.

## 2. Bảng các đường dữ liệu

| Đường | Độ rộng | Từ | Đến | Bản chất |
|---|---:|---|---|---|
| `tick_1hz` | 1 | cổng vào | `_064_`, `_065_` (fanout **3** theo STA) | **Điều kiện tiến — startpoint của MỌI đường tới hạn** |
| `enable` | 1 | cổng vào | `_064_`, `_065_` | Điều kiện tiến |
| `_019_` = `ADV` | 1 | `and2_0 _064_` | nhánh tăng `SU` | Dạng thuận của điều kiện tiến |
| `_020_` = `~ADV` | 1 | `nand2_1 _065_` | `_067_`, `_068_`, `_069_`, `_072_`, `_109_` | Dạng đảo — **fanout 5**, nằm trên đường tới hạn |
| `_021_` = `~(SU≥9)` | 1 | `o31ai_1 _066_` | 5 nơi | Cờ "chữ số giây đầy" |
| `_016_`,`_018_` = `~(ST≥5)` | 1 mỗi dây | `_061_`, `_063_` | `_068_`, `_069_`, `_072_` | Cờ "chục giây đầy" |
| `_026_` = `~(MU≥9)` | 1 | `o31ai_1 _071_` | `_072_`, `_091_` | Cờ "đơn vị phút đầy" |
| `_022_` = **C0** | 1 | `nor2_1 _067_` | nhánh tăng `ST` | Carry giây → chục giây |
| `_023_`/`_024_` = **C1** | 1 mỗi dây | `_068_`/`_069_` | nhánh tăng `MU` | Carry chục giây → phút |
| **`_027_` = C2** | 1 | **`a2111oi_0 _072_`** | **fanout 7** — `_076_`, `_077_`, `_081_`, `_082_`, `_083_`, `_085_`, … | **Carry phút → chục phút. NÚT CỔ CHAI của cả thiết kế** |
| `second_units[3:0]` … `minute_tens[3:0]` | 4 mỗi nhóm | 16 FF | cổng ra + hồi tiếp | Trạng thái = giá trị thời gian |
| `rst_n` | 1 | cổng vào | đường `D` của 16 FF | Reset đồng bộ, gộp vào logic |

## 3. Đồ thị phụ thuộc

```
  MỨC 0  (sẵn sàng ngay từ đầu chu kỳ, hoặc từ Q của FF)
  ────────────────────────────────────────────────────────────
     tick_1hz ──┐                     SU[3:0] ──┐   ST[3:0] ──┐   MU[3:0] ──┐   MT[3:0]
     enable ────┤                               │             │             │
                │                               │             │             │
  MỨC 1  (song song — KHÔNG phụ thuộc nhau)     │             │             │
  ────────────────────────────────────────────────────────────────────────────
     _065_ nand2 → _020_ = ~ADV      _066_ o31ai → _021_    _061_/_063_ → _016_,_018_
     _064_ and2  → _019_ =  ADV                             _071_ o31ai → _026_
                │                        │                      │             │
                └────────┬───────────────┴──────────────────────┴─────────────┘
                         │
  MỨC 2  (gộp phẳng — mọi carry tính SONG SONG, không nối tiếp nhau)
  ────────────────────────────────────────────────────────────────────────────
     _067_ nor2      → _022_ = C0        (2 đầu vào)
     _068_ a211oi    → _023_ = C1        (4 đầu vào)
     _072_ a2111oi_0 → _027_ = C2        (5 đầu vào)  ◀── 1,05 ns, fanout 7
                         │
  MỨC 3  (bộ tăng của từng chữ số, dùng carry tương ứng)
  ────────────────────────────────────────────────────────────────────────────
     _085_ and3b → D của MT[3]           _076_ a21bo → … → D của MT[0]
     _082_ a21oi → D của MT[1]           _084_ nor2  → D của MT[2]
     _086_…_095_ → D của MU[3:0]         (dùng _023_/_024_)
     _096_…_110_ → D của ST[3:0]         (dùng _022_)
     _111_…_121_ → D của SU[3:0]         (dùng _019_/_020_)
                         │
  MỨC 4  (chốt)
  ────────────────────────────────────────────────────────────────────────────
     16 × dfxtp_1  (_122_ … _137_)
                         │
  MỨC 4 (cùng lúc)  CỔNG RA — 0 cell logic
```

**Điểm then chốt của đồ thị:** ba carry `C0`, `C1`, `C2` nằm ở **cùng một mức**, không phải
ba mức nối tiếp. Chúng dùng chung các cờ `_020_`, `_021_`, `_016_`, `_018_`, `_026_` nhưng
mỗi cái gộp các cờ đó trong **một** cổng của riêng mình. Đó là cái giá phải trả để có độ
sâu `O(1)`: **số đầu vào của cổng tăng theo số tầng tràn.**

## 4. Độ sâu logic của từng đầu ra

| Đích | Loại | Số cell logic | Arrival đo được |
|---|---|---:|---:|
| `D` của `minute_tens[3]` (`_125_`) | in→reg | **3** | **2,40 ns** ← **tới hạn** |
| `D` của `minute_tens[0]` (`_122_`) | in→reg | 4 (`_065_`→`_072_`→`_076_`→`_078_`) | **2,38 ns** |
| `D` của `minute_tens[2]` (`_124_`) | in→reg | 4 | (đường thứ 3, arrival ≈2,3 ns) |
| `D` của `second_units[*]` | in→reg | 2–3 | không trong top-3 (không qua `_072_`) |
| **Mọi cổng ra** | reg→out | **0** | — |

Nghịch lý đáng chú ý: đường **ít cell nhất** (3) lại là đường **chậm nhất**. Lý do hoàn
toàn nằm ở một cell — xem §5.

## 5. Dự đoán đường tới hạn từ RTL, rồi đối chiếu STA thật

### 5.1 Dự đoán khi chỉ đọc RTL

Đọc `d07_bcd_core.sv` dòng 17–37 (bốn tầng `if` lồng nhau), dự đoán tự nhiên là:

> "Chuỗi tràn 4 tầng là một chuỗi nối tiếp: `SU` đầy → `ST` đầy → `MU` đầy → `MT`. Đường
> tới hạn đi qua **4 tầng carry nối tiếp**, kết thúc ở `minute_tens`. Tổng độ sâu khoảng
> 8–12 cổng."

### 5.2 STA thật nói gì

| Dự đoán | STA thật | Đúng/Sai |
|---|---|:-:|
| Đường tới hạn kết thúc ở `minute_tens` | ✅ `_125_` = `minute_tens[3]` | ✅ |
| Xuất phát từ một flip-flop (reg→reg) | ❌ **in→reg**, startpoint là cổng `tick_1hz` | ❌ |
| Độ sâu 8–12 cổng | ❌ **3 cell** | ❌ |
| Chuỗi tràn là 4 tầng nối tiếp | ❌ Gộp phẳng thành **1 cổng 5 đầu vào** | ❌ |
| Nút thắt là **độ sâu logic** | ❌ Nút thắt là **khả năng lái của 1 cell** | ❌ |
| Endpoint là một bit có ý nghĩa | ❌ Là bit **hằng 0** | ❌ |

Năm trong sáu dự đoán sai — **và mọi dự đoán sai đều theo hướng bi quan**. Bài học chung:
đọc RTL cho ước lượng độ sâu **quá lớn**, vì công cụ làm phẳng những phụ thuộc mà mắt người
tưởng là nối tiếp.

### 5.3 Giải thích bốn chỗ lệch

**(a) Vì sao in→reg chứ không reg→reg.** SDC đặt `set_input_delay 1.0 -clock clk
[all_inputs]`, nên `tick_1hz` "xuất phát" tại **1,00 ns**, trong khi một FF xuất phát tại
`clk→Q` ≈ 0,3–0,4 ns. Vì `tick_1hz` là đầu vào của **mọi** carry (qua `_065_`), nó thắng
mọi đường reg→reg đi qua cùng chuỗi cell. Đây là **hệ quả của giả định phân tích**, không
phải của thiết kế.

**(b) Vì sao 3 cell chứ không phải 8–12.** Các điều kiện "chữ số đầy" đọc từ **bốn thanh
ghi khác nhau** nên tính song song được; chỉ phép AND cuối là chung, mà AND kết hợp được.
Chi tiết ở `block_diagram.md` §3.

**(c) Vì sao vẫn chậm nhất trong ba đề.** Cell `_072_ a2111oi_0`:

| Thuộc tính | Giá trị | Vì sao xấu |
|---|---|---|
| Số đầu vào | **5** | Chuỗi transistor nối tiếp dài trong mạng pull-down/pull-up |
| Biến thể drive | **`_0`** — nhỏ nhất trong họ | Dòng lái yếu nhất thư viện có |
| Fanout | **7** | Phải sạc/xả 7 cổng tải |
| Điện dung tải | 0,02 pF | Lớn nhất trong các nút của đường |
| → **Slew đầu ra** | **1,25 ns** | Sườn rất chậm, cell kế tiếp cũng chậm theo |
| → **Độ trễ cell** | **1,05 ns** | **44 % arrival của cả đường** |

Đây là bài toán **sizing/buffering**, không phải bài toán kiến trúc. Nó được giải ở bước
physical design (OpenROAD `repair_design`, `set_max_fanout` trong SDC), **chưa chạy** trong
hồ sơ này.

**(d) Vì sao endpoint là bit hằng 0.** Xem `block_diagram.md` §5. Tóm tắt: `minute_tens[3]`
là cổng ra chính nên Yosys không xoá được; STA phân tích cấu trúc nên vẫn tính đường tới
nó; và SDC không khai báo nó là false path.

## 6. So sánh ba đề cùng nhóm D — số liệu thật

| | D05 (Gray) | D06 (PWM) | **D07 (BCD)** |
|---|---:|---:|---:|
| Cell | 40 | 80 | **77** |
| Flip-flop | 8 | 16 | **16** |
| Diện tích (µm²) | 369,104 | 751,9712 | **665,6384** |
| Cell/FF | 5,0 | 5,0 | **4,8** |
| Cell trên đường tới hạn | 4 | 6 | **3** ← nông nhất |
| Arrival (ns) | 1,60 | 1,32 | **2,40** ← chậm nhất |
| Độ trễ logic thuần (ns) | 0,60 | 0,98 | **1,40** |
| Trung bình mỗi cell (ns) | 0,15 | 0,16 | **0,47** ← gấp 3 |
| Slack (ns) | 8,28 | 7,68 | **7,49** ← nhỏ nhất |
| Công suất (W) | 3,62e-05 | 8,02e-05 | **6,77e-05** |
| % tuần tự | 94,6 | 86,8 | **97,3** ← cao nhất |

> Bảng này là bằng chứng gọn nhất cho luận điểm trung tâm: **độ sâu logic không phải là chỉ
> số quyết định tốc độ.** D07 nông nhất mà chậm nhất, vì một cell duy nhất bị quá tải.

## 7. Công suất: **1 flip-flop ≈ 140 cell tổ hợp**

| Nhóm | Tổng công suất | Số cell | Trung bình mỗi cell |
|---|---:|---:|---:|
| Sequential (16 × `dfxtp_1`) | 6,59e-05 W | 16 | **≈ 4,12e-06 W** |
| Combinational (61 cell còn lại) | 1,80e-06 W | 61 | **≈ 2,95e-08 W** |
| | | **Tỉ lệ** | **≈ 140 ×** |

Tỉ lệ **cao nhất trong ba đề** (D05: 70×, D06: 26×). Lý do cấu trúc: logic tổ hợp của D07
hầu như **không chuyển mạch** — các cờ `SU≥9`, `ST≥5`, `MU≥9` chỉ đổi giá trị ở 10 %, 1,7 %
và 0,17 % số bước. Trong khi đó 16 flip-flop **luôn** tiêu công suất clock ở mỗi chu kỳ,
kể cả khi không có `tick_1hz`.

**Hệ quả thiết kế rút ra được từ con số này:** với D07, việc **giảm số flip-flop** là đòn
bẩy công suất mạnh hơn nhiều so với tối ưu logic. Hai bit hằng 0 (`second_tens[3]`,
`minute_tens[3]`) đang tốn ≈ `2 × 4,12e-06 = 8,2e-06 W`, tức **12 % tổng công suất**, để
lưu hai giá trị luôn bằng 0. Đổi sang bản nhị phân 6 bit (12 FF) sẽ tiết kiệm nhiều hơn nữa
— xem `tradeoff.md`.

## 8. Vì sao không có thanh ghi nào khác

| Câu hỏi | Trả lời |
|---|---|
| Có cần thanh ghi cho cổng ra? | Không — `Q` đã là cổng ra, không có logic tổ hợp nào ở giữa, không có glitch |
| Có cần FF chọn kênh xuất? | **Có, theo Charter mục 4** (`uio_out[0]` = đang xuất phút) — hiện **chưa có**. Charter mục 10 đã dự trù "+1 chọn xuất" |
| Có cần FF phát hiện sườn `tick_1hz`? | Ứng dụng cần, Charter không đòi. Sẽ tốn **+1 FF** (`tick_q`) và một cổng AND |
| Có pipeline không? | Không — toàn bộ chuỗi tràn hoàn tất trong **một** chu kỳ clock |

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
