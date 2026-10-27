# D07 — Bộ đếm thời gian phút:giây từ xung 1 Hz



| | |
|---|---|
| **Mã đề** | D07 |
| **Nhóm** | D · Bộ đếm và chia tần |
| **Độ khó** | Trung bình |
| **Loại mạch** | Tuần tự |
| **Quy mô ước lượng (Charter)** | ~230–320 cell · 1×1 tile |
| **Top module** | `d07_bcd_core` |
| **Phiên bản hồ sơ** | v1.0 · 2026-09-24 |

---

## 1. Tóm tắt kết quả

| Tầng | Trạng thái | Kết quả chính |
|---|---|---|
| 01 Yêu cầu | ✅ | Yêu cầu truy vết từ Charter D07 |
| 02 Đặc tả | ✅ | Giao diện đọc trực tiếp từ RTL; ràng buộc timing đã lập |
| 03 Kiến trúc | ✅ | Sơ đồ khối, datapath, điều khiển, đánh đổi |
| 04 Hiện thực | ✅ | RTL + SDC + 4 script chạy được |
| 05 Kiểm chứng | ✅ | ✅ PASS — testbench chạy hết, không có assertion nào vi phạm |
| 06 GDSII | 🟡 một phần | Synthesis ✅ · STA ✅ · Power ✅ · P&R ⬜ |
| 07 Truy vết | ✅ | RTM + chỉ mục bằng chứng + giới hạn |

### Số liệu đo được (không phải ước lượng)

| Chỉ số | Giá trị | Công cụ |
|---|---:|---|
| Mô hình chuẩn Python | PASS | CPython 3 |
| Mô phỏng RTL | PASS | Icarus Verilog 12.0 (stable) |
| Số cell | **77** | Yosys 0.33 (git sha1 2584903a060) |
| Flip-flop | **16** | như trên |
| Diện tích | **665,6384 µm²** | như trên |
| Đường tới hạn | `tick_1hz` → `_125_` | OpenSTA 3.1.0 |
| **Độ trễ** | **2,4 ns** | như trên |
| Công suất (ước lượng) | 6.77e-05 W | như trên |

## 2. Đọc từ đâu

| Bạn là | Đọc theo thứ tự |
|---|---|
| **Muốn nắm bản chất nhanh** | **[`implementation-notes_D07.md`](implementation-notes_D07.md)** — hoặc mở bản `.html` |
| **Giảng viên chấm bài** | `07_TRACEABILITY/limitations.md` → `RTM.csv` → `06_GDSII/physical_report.md` |
| **Sinh viên nhận đề** | `01_REQUIREMENT/application.md` → `02_SPECIFICATION/` → `03_ARCHITECTURE/` → `04_IMPLEMENTATION/README.md` |
| **Muốn chạy lại** | `07_TRACEABILITY/evidence_index.md` §5 |

## 3. Cây thư mục

```
D07/
├── implementation-notes_D07.md      ← phân tích bản chất + cách thực hiện
├── implementation-notes_D07.html    ← bản đọc trên trình duyệt (tự chứa)
├── 01_REQUIREMENT/     application · requirements · scope · acceptance_criteria
├── 02_SPECIFICATION/   functional_spec · interface · timing · corner_cases · parameters
├── 03_ARCHITECTURE/    system_diagram · block_diagram · datapath · control · fsm
│                       timing_diagram · tradeoff
├── 04_IMPLEMENTATION/  rtl/ · constraints/ · scripts/ · README
├── 05_VERIFICATION/    golden_model/ · testbench/ · assertions/ · waveforms/
│                       testplan · test_matrix.csv · verification_report
├── 06_GDSII/           synthesis/ sta/ power/ floorplan/ placement/ cts/
│                       routing/ drc/ lvs/ gds/ · physical_report
└── 07_TRACEABILITY/    RTM.csv · evidence_index · limitations
```

## 4. Chạy lại toàn bộ

```bash
python3 05_VERIFICATION/golden_model/reference_model.py
bash    04_IMPLEMENTATION/scripts/01_run_sim.sh
bash    04_IMPLEMENTATION/scripts/02_run_synth.sh
sta -no_splash -exit 04_IMPLEMENTATION/scripts/03_run_sta.tcl
bash    04_IMPLEMENTATION/scripts/04_run_librelane.sh     # cần PDK sky130A
```



---

*Nguồn chuẩn: `Project_Charter_80_De.docx` — mục D07. Gói nguồn: `D07_FINAL_MENTOR_PACKAGE_v1_0`.*
*Hồ sơ này không đưa ra khẳng định nào về sign-off, tape-out, chế tạo hay kiểm tra sau chế
tạo — những mục nằm ngoài phạm vi đề tài theo Charter mục 3.*
