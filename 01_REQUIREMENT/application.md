# D07 · Bối cảnh ứng dụng



| | |
|---|---|
| Mã đề | **D07** |
| Tên đề | Bộ đếm thời gian phút:giây từ xung 1 Hz |
| Nhóm đề | D · Bộ đếm và chia tần |
| Độ khó | Trung bình |
| Loại mạch | **Tuần tự** |
| Quy mô ước lượng (Charter) | ~230–320 cell · 1×1 tile |
| Nguồn gốc | Project Charter — D07, mục 1 |

---

## 1. Mục tiêu và bối cảnh ứng dụng

Trích nguyên văn Charter mục 1:

> Phân tích khối số “Bộ đếm thời gian phút:giây từ xung 1 Hz” ở mức khối. Bối cảnh ứng dụng: Khối đồng hồ bấm giờ cho máy tập thể dục, đếm phút:giây từ xung 1 Hz của bộ dao động thạch anh.

## 2. Vị trí khối D07 trong hệ thống

```
   ┌──────────────┐      ┌──────────────────────────────┐      ┌──────────────┐
   │  Nguồn tín   │─────▶│      ►►► KHỐI D07 ◄◄◄        │─────▶│  Tầng tiêu   │
   │  hiệu / dữ   │      │  Bộ đếm thời gian phút:giây t │      │  thụ kết quả │
   │  liệu vào    │      │  Loại mạch: Tuần tự          │      │              │
   └──────────────┘      └──────────────────────────────┘      └──────────────┘
```

> Sơ đồ chi tiết có chú thích: `03_ARCHITECTURE/system_diagram.md`.

## 3. Phân loại analog / digital / mixed

| Khối | Phân loại | Ghi chú |
|---|---|---|
| Cảm biến / nguồn tín hiệu vật lý (nếu có) | Analog | Đại lượng liên tục |
| Chuyển đổi ADC/DAC (nếu có) | Mixed-signal | Ranh giới analog–số |
| **D07 — Bộ đếm thời gian phút:giây từ xung 1 Hz** | **Digital, tuần tự** | Có ô nhớ, hoạt động theo cạnh clock |
| Tầng xử lý phía sau | Digital | Tiêu thụ kết quả của D07 |

Bằng chứng cho dòng phân loại của D07: tổng hợp thật cho **16 flip-flop**
(`06_GDSII/synthesis/synth_stat.txt`).

---

**Truy vết:** yêu cầu sinh từ tài liệu này được đánh số `REQ-D07-0xx` trong
`01_REQUIREMENT/requirements.md`, và truy vết đến bằng chứng trong `07_TRACEABILITY/RTM.csv`.

*Phiên bản: v1.0 · Ngày: 2026-09-24*
