# T-021 สรุป: ema_v1 in-sample 2023–2024, "real ticks" (Model=4) เทียบ Model=1

คำตัดสิน: **GATE FAIL / BLOCKED (ไม่ใช่ real ticks จริง)** — ผลนี้ใช้เป็นหลักฐาน real-tick ของ Phase 3 ไม่ได้

## ⚠️ สิ่งผิดปกติหลัก
- report ระบุ **History Quality = 0% real ticks** (Ticks 61,579,928)
- tester journal (Tester\logs\20261012.log, run 15:24): `XAUUSD : 2023.01.01 00:00 - 2024.12.31 00:00  no real ticks, every tick generation used` (level 3) แม้เลือก "generating based on real ticks"
- tick cache ของ broker (bases\ICMarketsSC-Demo\ticks\XAUUSD) มีแค่ **202604–202610 (2026-04 ถึง 2026-10)** → **ไม่มี real ticks ในช่วง 2023–2024 เลย** (ช่วงที่มี: 2026-04 เป็นต้นไป ซึ่งห้ามรันตามกฎ holdout)
- ดังนั้น run นี้คือ "every tick" แบบ **สังเคราะห์** จากแท่ง M1 ไม่ใช่ข้อมูลตลาดจริง ผลจึงใกล้ Model=1 มาก (ไม่ได้ช่วยตรวจ slippage/spread จริง)
- ไม่มี error/critical ของ SmartEA ในทั้งสอง run (นับ 0 บรรทัด); มีแต่บรรทัด level 3 ข้างบน
- Model=1 report: History Quality 99%, ticks 2,824,068 (สังเคราะห์จาก M1 OHLC)

## ตารางเทียบ (หลังหัก commission $7/lot จาก report_stats.py)
| metric | Model=1 (T-014) | "Model=4" (จริงคือ every-tick สังเคราะห์) |
|---|---|---|
| ไม้ | 426 | 426 |
| Net ดิบ report (ก่อนหัก comm) | -3,099.43 | -3,140.97 |
| Net หลังหัก commission | -3,777.38 | -3,815.91 |
| PF | 0.82 | 0.81 |
| Max DD (balance) | 42.3% | 42.5% |
| Equity DD max (report) | 3,986.03 (37.34%) | 3,992.07 (37.52%) |
| Sharpe / Recovery (report) | -4.18 / -0.78 | -5.00 / -0.79 |
| Win rate | 32.9% | 32.9% (140 ชนะ / 286 แพ้) |
| avg win / avg loss (หลังหัก comm) | +119.95 / -71.92 | +119.65 / -71.91 |
| ไม้กำไรมากสุด % ของกำไรรวม | 1.19% | 1.17% |
| Long / Short net | (ดู ema_v1.stats.md) | +749.59 (PF 1.09) / -4,565.50 (PF 0.62) |
| รายปี 2023 / 2024 | — | -2,101.50 / -1,714.41 (PF 0.81 / 0.82) |
| Commission รวม | — | -674.94 (96.42 lot) |

## เทียบรายไม้
- เปิดเวลาเดียวกัน: **426/426**, ทิศเดียวกัน 426/426, entry price เท่ากัน 426/426, SL level เท่ากัน 426/426
- lot ต่างกัน: **43/426** (เป็นผลของ equity path ต่างเล็กน้อยสะสม)
- ประเภท exit (sl / tp / ปิดด้วยสัญญาณ) เท่ากัน 426/426 : SL 212, TP 92, อื่นๆ 122 (time exit 23:30 = 85, opposite cross = 37) → **ไม้ที่ SL/TP/exit ต่าง = 0**
- เวลาปิดต่างกัน 279/426 (ต่างระดับวินาทีภายในแท่ง) ; ราคาปิดต่างกัน 185/426 (ต่างเฉลี่ย 0.012 ราคา, สูงสุด 0.26) — run Model=1 ปิดที่ SL/TP พอดีทุกไม้ ส่วน run ที่สอง 185 ไม้ปิดคลาดจากระดับ SL/TP เล็กน้อย (สังเคราะห์ ไม่ใช่ slippage จริง)
- net รายไม้ต่างกัน 206 ไม้ ผลรวมต่าง -38.53, สูงสุดต่อไม้ 10.37
- slippage / TRADE RISK: actual_risk สูงสุด **1.000%** ทั้งสอง run, ไม้ที่เกิน 1.0% = **0**, เฉลี่ย 0.974% (ต่ำสุด 0.876%) → ผ่านกฎ ≤1%
- ทุกไม้มี SL: ใช่ (426/426 TRADE OPEN มี sl>0)
- 23:30: ไม่มีไม้ข้ามวัน/ข้าม 23:30 (0 ไม้) ; ไม้ปิดตอน 23:30 = 85 ; ไม่พบหลักฐานว่าต้องเพิ่มวันใน holidays.csv (covered_years 2023–2026)
- TRADE REJECT 3 (D4 pre-trade, 2023-05-09 และ 2023-06-14 x2), TRADE SKIP 15 (holiday) — เท่ากันทั้งสอง run

## ธงเตือนตาม checklist
- trades 426 >= 100 ผ่าน • PF 0.81 (ไม่ใช่ overfit แต่ขาดทุน) • **Max DD 42.5% > 20%** • กำไรไม่กระจุก (ไม้ใหญ่สุด 1.2%)
- **Model ไม่ใช่ real ticks** → ไม่ผ่านข้อกำหนด gate Phase 3 • commission ใส่ $7/lot ในสคริปต์แล้ว (tester ไม่หักเอง)
- Short ขาดทุนหนัก (PF 0.62) ขณะ long เกือบเสมอตัว (PF 1.09) — ข้อสังเกตสำหรับ spec v2 ไม่เกี่ยวกับ tick model

## สิ่งที่ต้องแก้ / ทางเลือกให้ Owner
1. ไม่มี real tick history ของ XAUUSD ปี 2023–2024 บน server IC Markets demo นี้ (ในเครื่องมีแค่ 2026-04+) → Owner ตัดสินว่าจะ (a) ยอมรับ Model=1/every-tick สังเคราะห์สำหรับ calibration ใน Phase 3 และบันทึกข้อจำกัด หรือ (b) นำเข้า tick data 2023–2024 จากแหล่งภายนอก (เช่น Dukascopy) เป็น custom symbol (ต้องตรวจ spread/commission ให้เทียบเท่า IC)
2. ผล "ticks" ซ้ำ Model=1 ได้ ±1% จึงไม่ใช่หลักฐานว่า strategy ทนต่อ slippage/spread จริง
3. ห้ามลองดึง real ticks ของ 2026 มาเทียบ (กฎ holdout)
