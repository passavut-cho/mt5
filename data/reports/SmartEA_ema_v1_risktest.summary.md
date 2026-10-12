# T-009 risktest — SmartEA ema_v1 (InpRiskPct=0.5, InpDailyLossPct=1.5)

คำตัดสิน: **T-009 GATE FAIL (หลักฐานไม่ครบ ข้อ 2)** — ข้อ 1, 3, 4 ผ่าน แต่ไม่มี D4/breaker reject แม้ครั้งเดียวใน journal  
(Phase 2 gate ไม่ใช่ gate profit; ข้อสรุปนี้เป็นของ T-009 เท่านั้น)

## เงื่อนไขการทดสอบ
- XAUUSD M15, 2024.01.01 – 2024.03.31 (journal: ไม้สุดท้าย/OnTester 2024.03.28), deposit 10000, leverage 1:500
- Set: `tests/setfiles/ema_v1_risktest.set` (Risk 0.5, DailyLoss 1.5, MaxPos 1, Commission 7.0/lot, magic 260101)
- **Model=1 (1-min OHLC)** — journal `1 minutes OHLC ticks generating`, 345,635 ticks. ใช้ได้กับ Phase 2 / T-009 (ทดสอบ logic) แต่ **ใช้เป็น gate Phase 3 ไม่ได้** (ต้อง Model=4)
- Journal: `%APPDATA%\MetaQuotes\Tester\010E0471...\Agent-127.0.0.1-3000\logs\20261012.log` รันล่าสุดเริ่ม 10:50:06 (decode UTF-16LE)
- Commission: Tester ไม่หัก -> ใช้ตัวเลขจาก `report_stats.py` ($7/lot round turn), stats ที่ `SmartEA_ema_v1_risktest.stats.md`

## Metric (หลังหัก commission เทียบ report ดิบ)
| Metric | Report ดิบ | หลังหัก commission |
|---|---|---|
| Net profit | 256.83 | **199.43** (commission -57.40 / 8.20 lot) |
| Profit Factor | 1.19 | **1.15** |
| Max DD | equity 340.96 (3.29%), balance 241.64 (2.35%) | balance 263.98 (2.6%) |
| Recovery Factor | 0.75 | ~0.76 (199.43/263.98 คำนวณเอง; ไม่ใช่ค่า equity DD) |
| Sharpe (ดิบ) | 4.23 | ไม่คำนวณใหม่ (sample 3 เดือน ไม่น่าเชื่อถือ) |
| Trades | 55 | 55 (long 25 / short 30) |
| Win rate | 38.18% | 38.2% |
| Avg win / Avg loss | 75.80 / -39.26 | (ดิบ) |
| Expectancy/ไม้ | 4.67 | 3.63 |
| Long / Short net | | +519.87 (PF 2.23) / -320.44 (PF 0.66) |
| ไม้กำไรมากสุด / gross profit | 98.28 / 1591.82 | 6.2% |

## (1) Lot calc เทียบมือ — ผ่าน 55/55
`CalcLot` เป็น `m_log.Debug` (RiskManager.mqh:454) และ DEBUG ถูกปิดใน tester -> **ไม่มีบรรทัด CalcLot ใน journal** ใช้บรรทัด `TRADE OPEN` + `TRADE RISK` แทน  
สูตรมือ: risk = 0.5% x balance ก่อนเปิด (flat จึง = equity), loss/lot = |entry-SL| x 100 (XAUUSD contract 100 oz), lot = floor(risk/(loss/lot+7) / 0.01) x 0.01

| ไม้ | บรรทัด journal | balance | risk | loss/lot | มือ | EA |
|---|---|---|---|---|---|---|
| 1 | `2024.01.08 17:30:00 TRADE OPEN \| BUY lot=0.09 price=2030.49 sl=2025.21` | 10000.00 | 50.00 | 528 | 50/(528+7)=0.0935 -> 0.09 | 0.09 |
| 2 | `2024.01.08 21:00:00 TRADE OPEN \| SELL lot=0.14 price=2026.59 sl=2029.96` | 9964.90 | 49.82 | 337 | 49.82/344=0.1448 -> 0.14 | 0.14 |
| 3 | `2024.01.08 22:00:00 TRADE OPEN \| BUY lot=0.18 price=2029.44 sl=2026.85` | 9925.00 | 49.63 | 259 | 49.63/266=0.1866 -> 0.18 | 0.18 |

`TRADE RISK` ยืนยัน: `actual_risk=48.15 (0.482% ของ equity) lot=0.09`, `48.16 (0.483%) lot=0.14`, `47.88 (0.482%) lot=0.18` — ทั้ง 55 ไม้ actual risk <= 0.5% (สูงสุด 0.497% ไม้ 2024.01.10 10:15)

## (2) D4 pre-trade / daily breaker — ไม่พบหลักฐาน (FAIL)
- grep `D4|daily loss breaker|REJECT|WARN|ERROR|CRITICAL` ใน journal รอบนี้ = **0 บรรทัด** (โค้ด reject: SmartEA.mq5:333 `g_log.Trade("REJECT", ...)`, breaker RiskManager.mqh:307 `m_log.Warn`)
- ไม่มี signal ที่ผ่านฟิลเตอร์แล้วถูก risk ปฏิเสธเลย: signal 56 = TRADE OPEN 55 + TRADE SKIP 1 (`2024.02.19 20:45:00 TRADE SKIP | EMAX_ADX_BUY : วันหยุด 20240219 Presidents Day` = holiday filter ไม่ใช่ risk)
- ใกล้ที่สุด (headroom = equity - worst_loss - limit): ไม้ `2024.03.19 16:45:00 SELL lot=0.12` equity ~10161.02, worst loss 49.92, limit 10105.59 (`New day 2024.03.19: balance ต้นวัน=10259.48 breaker ที่ equity<=10105.59`) -> เหลือ **+5.51** ผ่านแบบฉิวเฉียด; รองลงมา 2024.01.08 22:00 เหลือ +27.12
- ผล: ตรรกะ D4 ยังไม่ถูก "พิสูจน์ใน journal" ว่าปฏิเสธได้ในการรันจริง (รัน T-009 ครั้งก่อนที่ D4 ปฏิเสธทุกไม้ = 0 trades คือ config อื่น)
- สิ่งที่ต้องแก้ (ให้ Owner ตัดสิน เพราะเป็นค่า risk): ต้องมีรันที่บังคับให้ D4/breaker ทำงานจริงอย่างน้อย 1 ครั้ง เช่น ลด InpDailyLossPct ให้ต่ำลง (เช่น 1.0 หรือ 0.75) ในไฟล์ test set เท่านั้น หรือรัน RiskSelfTest.mq5 ที่ยืนยัน PreTradeOk แยก — ผมไม่ได้แก้พารามิเตอร์ใดๆ

## (3) ขาดทุนรายวัน เทียบ 1.5% ของ balance ต้นวัน — ไม่มีวันที่เกิน
ขาดทุนรับรู้ (realized, หลังหัก commission $7/lot) ต่อวันปิดไม้:
| วัน | balance ต้นวัน | ขาดทุน | % | หมายเหตุ |
|---|---|---|---|---|
| 2024.03.19 | 10259.48 | -150.41 (-147.54 ก่อน comm) | -1.466% | 4 ไม้ติด SL (0.16, 0.13, 0.12...) ใกล้ 1.5% มาก; breaker 10105.59, equity ปิดวัน ~10111.94 (ตาม balance tester ไม่มี comm) |
| 2024.01.08 | 10000.00 | -124.49 | -1.245% | 3 ไม้ SL |
| 2024.02.21 | 10119.35 | -98.55 | -0.97% | |
| 2024.02.14 | 10201.98 | -76.38 | -0.75% | |
- ไม่มีวันเกิน 1.5% (realized). ข้อจำกัด: ใช้ realized จาก deals ไม่ใช่ equity intraday (report ไม่มี) — equity DD สูงสุดทั้งช่วง 3.29% เป็น DD สะสม ไม่ใช่รายวัน
- ข้อสังเกต: balance ของ tester ไม่หัก commission แต่ pre-trade check ของ EA รวม commission ในค่า worst_loss -> ถ้ารวม commission ที่จ่ายจริง วัน 03-19 เหลือ headroom ราว 3.5 จาก limit; ควรให้ risk-guardian พิจารณาว่า day_balance/equity ใน live (ที่ commission ถูกหักจริง) สอดคล้องกัน

## (4) SL / errors / จำนวนไม้
- Orders table: entry order 55 ใบ **ทุกใบมี S/L** (ไม่มี S/L ว่าง 0 ใบ); ใบที่ไม่มี S/L คือ order ปิดตำแหน่ง (55 ใบ) ตามปกติ; ทุก `market buy/sell ... sl: ... tp: ...` ใน journal ส่ง SL มาพร้อม order
- Journal ERROR/CRITICAL ของ SmartEA = **0**; มี `live guard: OK (TESTER)`, `init OK`, `OnTester: net=199.43 (หัก commission เพิ่ม 57.40 จาก 55 ไม้ 8.20 lot)` (ตรงกับ report_stats.py)
- จำนวนไม้ 55 (TRADE OPEN 55, close 55: SL/TP/time exit)

## 🚩 คำเตือน
- trades 55 < 100 -> sample ไม่พอสรุป edge (ไม่ใช่เป้าหมายของ T-009)
- Model=1 (1-min OHLC) ไม่ใช่ real ticks
- กำไรเดือน 2024.02 = +304.24 เทียบ net 199.43 (153% ของ net; ม.ค. -86.00, มี.ค. -18.81) -> เกิน 30% ของเดือนเดียว (ถ้าประเมิน edge)
- short ขาดทุน (PF 0.66) ขณะ long PF 2.23 — ไม่ใช่ประเด็นของ T-009 แต่ควรบันทึก
- Max DD 3.29% (equity) < 20% ผ่าน; PF 1.15 < 2.5 ไม่น่าสงสัย look-ahead
