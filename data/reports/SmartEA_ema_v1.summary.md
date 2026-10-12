# SmartEA_ema_v1 — สรุป backtest (T-014, รันใหม่หลัง T-011/T-013/T-017)

## เงื่อนไขทดสอบ
- XAUUSD M15, 2023.01.01–2024.12.31 (in-sample), deposit 10,000, leverage 1:500, ICMarketsSC-Demo (Raw)
- **Model=1 (1-min OHLC)**, History quality 99%, ticks 2.82M — ยอมรับได้เฉพาะ Phase 2 (Phase 3 ขึ้นไปต้อง Model=4 real ticks)
- พารามิเตอร์เดิมทุกตัว (EMA 9/21, ADX14 >=25, ATR14x1.5, TP 2R, session 10-23, time exit 23:30, Fri cutoff 20, risk 1%, daily loss 3%, holiday filter on)
- Tester ไม่หัก commission → ใช้ `report_stats.py --commission 7` (stats: `data/reports/SmartEA_ema_v1.stats.md`)

## Metric (PF/DD/Net ไม่ใช่เกณฑ์ผ่านของ Phase 2 — ข้อมูลให้ Owner เท่านั้น)
| Metric | Report ดิบ (ไม่หัก comm) | หลังหัก comm $7/lot |
|---|---|---|
| Net profit | -3,099.43 | **-3,777.38** (comm -677.95 / 96.85 lot) |
| Profit Factor | 0.85 | **0.82** |
| Max DD | equity 37.34% (3,986) / balance 36.62% | balance (ปิดไม้) 42.3% (4,459) |
| Recovery Factor | -0.78 | ติดลบ |
| Sharpe | -4.18 | — |
| จำนวนไม้ | 426 | 426 |
| Win rate | 32.86% | 32.9% |
| Avg win / avg loss | 121.47 / -70.30 | PF 0.82, expectancy -8.87/ไม้ |
| ไม้กำไรมากสุด | 202.92 (1.19% ของกำไรรวมหลังหัก comm) | — |

แยกฝั่ง (หลังหัก comm): long 197 ไม้ net +791.96 PF 1.09 • short 229 ไม้ net -4,569.34 PF 0.62
รายปี: 2023 -2,057.27 (PF 0.81) • 2024 -1,720.11 (PF 0.82)
OnTester = -3777.38, final balance 6900.57 ตรงกับ journal

## ตรวจเกณฑ์ข้อ 9 / ความถูกต้อง (จาก report 426 ไม้ + journal หลัง 10:33:48)
| ข้อ | ผล |
|---|---|
| จำนวนไม้ >= 100 | PASS 426 |
| ไม่มีไม้เปิดนอก session 10:00–22:59 | PASS 0 ไม้ผิด |
| ไม่มีไม้ข้าม 23:30 / ค้างข้ามวัน | PASS 0 ไม้ (ทุกไม้ปิดวันเดียวกัน, ไม่มีเวลาปิดหลัง 23:30; time exit 85 ไม้) |
| 5 วันเดิม 2023.11.23, 2024.02.19, 2024.06.19, 2024.11.28, 2024.12.24 | PASS ไม่มีไม้เปิด/ปิดในวันนั้น (journal: TRADE SKIP วันหยุด ทั้ง 5 วัน) |
| ไม่มีไม้เปิดในวันที่อยู่ใน holidays.csv | PASS 0 ไม้ตรงวันใน csv; filter โหลด 54 วัน; SKIP 15 ครั้ง / 12 วันหยุดต่างกัน |
| ทุกไม้มี SL | PASS 426/426 entry order มี S/L (และ TP) ตั้งตั้งแต่ส่ง order |
| ไม้ใกล้ Friday cutoff | PASS ไม่มีไม้เปิดวันศุกร์ >= 20:00 |
| risk/ไม้ <= 1% | PASS actual_risk สูงสุด 104.50 (journal ต่ำสุด 64.26); ที่พิมพ์ใน journal max 1.000% (ตัวอย่างวัน 2024.12.04 0.982–1.000%) |
| daily loss <= 3% | PASS ตามนิยาม EA/tester (ไม่มี commission): วันแย่สุด 2024.12.04 ขาดทุน 3 ไม้ gross -204.9 จาก balance ต้นวัน 7,101.01 = 2.89%, equity ต่ำสุดยังเหนือ breaker 6,887.98 |
| visual 10 ไม้ | ไม่ได้ตรวจ (ยกเว้นตามคำสั่ง) |

หมายเหตุ: ตัวเลข daily loss 3.2% ที่คำนวณจาก balance หลังหัก commission เป็นผลของการที่ tester ไม่หัก commission (balance ต้นวันใน report ต่างจากที่หัก comm); ไม่ใช่การละเมิด

## ธง
- PF 0.82 < 1, net ลบ, DD 42% > 20% — ยังไม่ใช่เกณฑ์ Phase 2 แต่ถ้าไปต่อ Phase 3 ต้องพิจารณา (short ขาดทุนหนัก: PF 0.62, long PF 1.09)
- ไม่ใช่สัญญาณ overfit (PF < 2.5); ไม้กำไรสูงสุด 1.2% ของกำไรรวม ไม่กระจุก
- Model=1 — ตัวเลข exit ที่ SL/TP อาจต่างจาก real ticks; ต้องรันซ้ำ Model=4 ใน Phase 3
- ไม่มี commission ใน tester report ดิบ ใช้ตัวเลขหลังหักด้านบนเสมอ

## Verdict
**GATE (เกณฑ์ข้อ 9 ยกเว้นข้อ visual): PASS** — ระบบทำงานตาม spec: ไม้ 426 >= 100, ไม่มีไม้นอก session, ไม่มีไม้ข้าม 23:30, ไม่มีไม้ในวันหยุด, ทุกไม้มี SL, risk <= 1%, daily loss <= 3%
ที่ยังค้างก่อนปิด Phase 2: สุ่มตรวจ 10 ไม้ใน visual mode (Owner) และการเลื่อน Phase เป็นสิทธิ์ Owner (`/gate`)
