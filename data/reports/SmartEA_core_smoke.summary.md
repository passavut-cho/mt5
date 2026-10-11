# สรุป SmartEA_core_smoke (G1.2 smoke test)

## เงื่อนไขการทดสอบ
| รายการ | ค่า |
|---|---|
| Expert | SmartEA (CSignalNone, ไม่มีสัญญาณเข้า) |
| Symbol / TF | XAUUSD / M15 |
| ช่วงวันที่ | 2024.01.01 - 2024.12.31 |
| Model | 1 = 1-minute OHLC (ไม่ใช่ real ticks) |
| History quality | 100% |
| Bars / Ticks | 23,644 bars / 1,416,323 ticks |
| Deposit / Leverage | 10,000 USD / 1:100 |
| Server | ICMarketsSC-Demo (Build 6255) |
| Inputs | AllowLive=false, Magic=260101, Risk=1.0%, DailyLoss=3.0%, MaxPos=1, Commission=7.0/lot, MaxSpread=20, Deviation=20 |

## ผลลัพธ์
| Metric | ค่า |
|---|---|
| Total trades / deals | 0 / 0 (ตรงตามคาด) |
| Net profit | 0.00 |
| Final balance | 10,000.00 USD (journal: `final balance 10000.00 USD`) |
| PF / Recovery / Sharpe | 0.00 (ไม่มีไม้ ไม่มีความหมาย) |
| Max DD | 0.00% |

## Tester journal (run ล่าสุด 03:38:56 - 03:39:04, ไฟล์ 20261012.log)
- บรรทัดจาก SmartEA ใน run นี้: 263 บรรทัด; ERROR/CRITICAL จาก SmartEA = **0**
- มี `live guard: OK (TESTER)`, `Risk init: ...`, `init OK: signal=None tf=PERIOD_M15`, `deinit reason=1`
- บรรทัด "New day" รวม 259 วัน (ราว 1 ต่อวันทำการ) balance ต้นวันคงที่ 10000.00 ทุกวัน ตามที่ควรเป็นเมื่อไม่มีไม้
- ตัวอย่าง:
  - `2024.01.01 00:00:00 [SmartEA magic=260101 XAUUSD] INFO New day 2024.01.01: balance ต้นวัน=10000.00  breaker ที่ equity<=9700.00`
  - `2024.01.02 01:15:00 ... New day 2024.01.02: balance ต้นวัน=10000.00  breaker ที่ equity<=9700.00`
  - `2024.12.30 01:00:00 ... New day 2024.12.30: balance ต้นวัน=10000.00  breaker ที่ equity<=9700.00`
- Test passed ใน 0.130 วินาที

## ข้อสังเกต
- journal ไฟล์เดียวกันมีบรรทัด level 2 `tester not started because the account is not specified` 3 ครั้ง (03:08 น.) เป็นความพยายามรันก่อนหน้า ไม่เกี่ยวกับ run นี้ แต่แสดงว่ามีการรันที่ล้มเหลวมาก่อน (ปัญหา account ใน ini)
- ไม่มี warning อื่นใน run ล่าสุด
- Report ระบุ Company = "Raw Trading Ltd" แต่ server = ICMarketsSC-Demo ตามปกติของ IC Markets (ไม่น่ากังวล)
- Backtest 0 ไม้ ดังนั้นไม่ได้ทดสอบ logic เข้าไม้/ปิดไม้/commission/pre-trade check เลย ผลนี้พิสูจน์ได้เพียง init, live guard, day-rollover, deinit
- วัน 2024.01.01 ถูก log ตอน init (00:00) ส่วนวัน 01.02 log ที่ 01:15 และวันถัดไป 01:00 ซึ่งสอดคล้องกับ server time ที่เริ่มแท่งแรกของวันที่ 01:00

## ข้อควรระวัง (flags)
- trades < 100: ไม่ใช่ประเด็น เพราะเป็น smoke test ของ framework ไม่ใช่ strategy gate
- Model=1 (1-min OHLC): ยอมรับได้สำหรับ G1.2 แต่ **ใช้เป็น gate Phase 3 ขึ้นไปไม่ได้** ต้องใช้ real ticks (Model=4)
- ยังไม่ได้เทียบ exit criteria ของ G1.2 กับ docs/runbook.md ฉบับจริง (ไม่ได้เปิดอ่านตามขอบเขตงานนี้) verdict อิงตามเกณฑ์ที่ผู้ใช้ระบุ

## Verdict: G1.2 GATE PASS (เฉพาะขอบเขต smoke test)
เหตุผล: รันจบสมบูรณ์ ครบทั้งปี 100% quality, 0 ไม้ตามคาด, balance คงที่ 10,000, 0 ERROR/CRITICAL จาก SmartEA, live guard ทำงานใน TESTER, breaker คำนวณ 9700.00 (97% ของ 10000) ถูกต้องทุกวัน

สิ่งที่ยังต้องทำก่อนเลื่อนต่อ: ทดสอบ logic ที่เกิดไม้จริง (risk sizing, commission, D4 pre-trade, breaker ทริกเกอร์) ด้วย signal ทดสอบ/RiskSelfTest
