# สรุป Backtest — SmartEA ema_v1 (EMA 9/21 + ADX, spec v1)

Report: `data/reports/SmartEA_ema_v1.htm` • ตีความตาม `docs/strategy/spec-ema-adx.md` ข้อ 9 (Acceptance Phase 2)

## เงื่อนไขการทดสอบ
| รายการ | ค่า |
|---|---|
| Symbol / TF | XAUUSD / M15 (ICMarketsSC-Demo, Raw Trading Ltd) |
| ช่วง | 2023.01.01 - 2024.12.31 (in-sample) |
| Model | 1-min OHLC (Model=1) — ยอมรับได้เฉพาะ Phase 2, **ห้ามใช้เป็นหลักฐาน gate Phase 3+** |
| History quality | 99% (ticks 2.82M) |
| Deposit / Leverage | 10,000 USD / 1:500 |
| Commission | **ไม่ถูกหักในรายงาน** (คอลัมน์ Commission = 0.00 ทุก deal; `InpCommissionPerLot=7` ใช้แค่คำนวณ lot) |
| Spread | ตาม spread จริงในข้อมูล (MaxSpread filter 20 points) |
| Inputs | ตรงกับ default ใน spec ข้อ 7 ทุกตัว, risk 1%, daily loss 3%, max pos 1 |

## Metric
| Metric | ค่า |
|---|---|
| Net profit | **-3,069.03** (-30.7%) — balance สุดท้าย 6,930.97 |
| Gross profit / loss | 17,685.86 / -20,754.89 |
| Profit Factor | **0.85** |
| Max DD (equity) | **38.00%** (4,056.97) • balance DD 37.28% |
| Recovery Factor | -0.76 |
| Sharpe | -3.93 |
| Total trades | 440 |
| Win rate | 33.18% (146 ชนะ / 294 แพ้) |
| Avg win / Avg loss | 121.14 / -70.59 (payoff 1.72) — breakeven win rate ที่ payoff นี้ ~36.8% จึงขาดทุน |
| Largest win / loss | 202.92 / -111.71 |
| ไม้กำไรสูงสุด % ของกำไรรวม | 1.14% (ไม่กระจุก) |
| Max consecutive loss | 12 ไม้ (-899.13) |
| Avg holding | 2:04 ชม. (max 32:04) |
| Swap รวม | -85.64 |
| ปี 2023 / 2024 | -1,530 / -1,453 (ขาดทุนทั้งสองปี) |

| ฝั่ง | ไม้ | Win% | Net (ประมาณจาก deals) | PF | Avg win / loss |
|---|---|---|---|---|---|
| Long | 202 | 37.62% | +1,242 | 1.15 | 128.91 / -67.90 |
| Short | 238 | 29.41% | -4,225 | 0.65 | 113.25 / -72.34 |

หมายเหตุ: net long/short คำนวณจาก profit ของ deal (ไม่รวม swap -85.64) ผลรวม -2,983 + swap = -3,069 ตรงกับ report

Commission ที่ควรหักเพิ่ม: 101.61 lot รวม x 7.0 round turn = ประมาณ **-711** → net จริงประมาณ **-3,780** (PF ลดต่ำกว่า 0.85 อีก)

## เกณฑ์ spec ข้อ 9
| เกณฑ์ | ผล | หลักฐาน |
|---|---|---|
| จำนวนไม้ in-sample >= 100 | **PASS** | 440 ไม้ |
| ไม่มีไม้เปิดนอก session (10-23 server) | **PASS** | ตรวจ 440 เวลาเปิด: นอก session = 0; เปิดศุกร์หลัง 20:00 = 0 (S7) |
| ไม่มีไม้ที่ไม่มี SL | **PASS** | ทั้ง 440 order มี S/L และ T/P ตั้งตอนส่ง; journal มี TRADE OPEN 440 = TRADE RISK 440 |
| ไม่มีไม้ข้าม 23:30 | **FAIL (5/440)** | ดูด้านล่าง |
| สุ่ม 10 ไม้ใน visual mode ตรง spec | **ไม่ได้ตรวจ (ต้องให้ Owner)** | รัน Visual=0 และห้ามรันใหม่; ตรวจแทนในเชิงข้อมูล: TP = 2 x SL ตรง 416/440, อีก 24 ไม้เบี่ยง >0.02 (น่าจะเกิดจาก fill/spread ต่างจากราคาอ้างอิงตอนคำนวณ SL/TP ควรให้ strategy-dev ยืนยัน) |

ไม้ที่ข้าม 23:30 (เปิดวันหนึ่ง ปิดวันถัดไป):
| เปิด | ปิด | วิธีปิด |
|---|---|---|
| 2023.11.23 11:30 | 2023.11.24 01:15 | opposite cross (S3) |
| 2024.02.19 20:45 | 2024.02.20 01:39 | SL |
| 2024.06.19 19:15 | 2024.06.20 03:30 | opposite cross (S3) |
| 2024.11.28 17:15 | 2024.11.29 03:30 | SL |
| 2024.12.24 19:00 | 2024.12.26 03:04 | TP |

ทั้ง 5 วันตรงกับวันหยุด/ตลาดปิดเร็วของ US (Thanksgiving x2, Presidents Day, Juneteenth, Christmas Eve) สาเหตุที่เป็นไปได้ที่สุดคือไม่มีแท่ง/tick ที่ 23:30 ตามที่ time exit (S6) ทำงานบนแท่งใหม่ จึงไม่ได้ปิด นี่เป็นช่องโหว่ของ logic S6 ที่ต้องแก้ (ควรปิดทันทีที่ tick/แท่งแรกหลังเลย 23:30 และเปิดไม้ไม่ได้ถ้าใกล้ปิดตลาด) ไม่ใช่การปรับพารามิเตอร์ — ไม่ได้แก้เองตามคำสั่ง

## ตรวจเพิ่ม
| หัวข้อ | ผล |
|---|---|
| Risk ต่อไม้ <= 1% รวม commission | **PASS** — คำนวณจาก (ระยะ SL x 100 x lot + 7 x lot) / balance ก่อนเข้า: สูงสุด 1.0000%, เฉลี่ย 0.975%, เกิน 1% = 0 ไม้ |
| Daily loss 3% | PASS — ขาดทุนรายวันสูงสุด -294.77 (2023.05.09, ~2.9% ของ balance ต้นวัน 10,258) ไม่ทะลุ; D4 pre-trade reject 4 ครั้ง ทำงานถูกต้อง |
| Journal tester (SmartEA, รอบ 09:39 ของวันที่ 2026.10.12) | PASS — ไม่มี ERROR/CRITICAL/WARN; มีเฉพาะ INFO 2,705, TRADE OPEN 440, TRADE CLOSE 127 (time exit/opposite cross), TRADE REJECT 4 (D4 pre-trade) live guard OK (TESTER) |
| ไม้เดียว/เดือนเดียวครองกำไร | ไม่ใช่ (ไม้ใหญ่สุด 1.14% ของกำไรรวม; ผลรวมขาดทุน) |

## ธงเตือน
- Max DD 38% > 20% (ธงแดง) และ PF 0.85 < 1 — กลยุทธ์ v1 ไม่มี edge ใน in-sample นี้ (ขาดทุนทั้ง 2023 และ 2024; short ขาดทุนหนักกว่า long มาก)
- ไม่มี commission ใน report → net ดูดีกว่าความจริง ~711 USD
- Model=1 (1-min OHLC) ใช้ได้เฉพาะ Phase 2
- ไม่ใช่ overfit (PF < 2.5, trades > 100) — ปัญหาตรงข้าม คือไม่มี edge

## คำตัดสิน
**GATE FAIL (Phase 2 acceptance ข้อ 9)**
- ผ่าน 3/5 เกณฑ์ข้อมูล (>=100 ไม้, ไม่มีนอก session, ทุกไม้มี SL) และผ่านตรวจ risk/daily loss/journal
- ตก 1 เกณฑ์ชัดเจน: ไม้ข้าม 23:30 จำนวน 5 ไม้ (บั๊ก S6 ช่วงตลาดปิดเร็ว)
- 1 เกณฑ์ยังไม่ครบ: visual 10 ไม้ ต้องให้ Owner ตรวจ

สิ่งที่ต้องแก้/ตัดสินใจ (ยังไม่ได้ทำ ตามคำสั่งห้ามปรับ/รันใหม่)
1. แก้ S6 ให้ปิดทุก position เมื่อเวลา >= 23:30 บน tick/แท่งแรกที่มี (ไม่พึ่งแท่ง 23:30 พอดี) แล้วรันซ้ำ
2. ยืนยันสาเหตุ 24 ไม้ที่ TP != 2 x SL
3. ให้ tester ใส่ commission จริง (หรือหักในการวิเคราะห์) ก่อนตัดสิน Phase 3
4. Owner ตรวจ visual 10 ไม้
5. เรื่องไม่มี edge (PF 0.85, DD 38%) เป็นประเด็นของ spec v2 ที่ Owner ต้องอนุมัติ ห้ามไล่ปรับพารามิเตอร์เองใน in-sample
