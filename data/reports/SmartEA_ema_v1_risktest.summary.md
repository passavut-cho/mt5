# SmartEA ema_v1_risktest — T-009 (XAUUSD M15, 2024.01.01–2024.03.31, Model=1)

**ผล: ไม่ผ่าน goal ของ T-009 → BLOCKED** (ไม่ใช่บั๊กของ EA — เป็นข้อจำกัดของการออกแบบ test)

## ข้อเท็จจริงจาก report/journal
- Total trades = 0, final balance 10,000.00, journal ไม่มี ERROR/CRITICAL/WARN, holiday filter โหลด 54 วัน
- มี signal 56 ครั้ง → `TRADE REJECT … D4 pre-trade` 55 ครั้ง (ที่เหลือ 1 ไม่ใช่การเปิดไม้) ไม่มี reject เหตุอื่น
- ตัวอย่าง: `2024.01.08 17:30 EMAX_ADX_BUY : D4 pre-trade: ถ้าโดน SL equity 10000.00 - 96.30 = 9903.70 <= limit รายวัน 9950.00 (0.50%)`
- breaker ที่ equity<=9950.00 ทำงานตามเจตนา (0.5% ของ 10,000)

## สาเหตุ
`InpRiskPct=1.0` (ความเสี่ยงต่อไม้ ≈ 96–100 USD) มากกว่างบ daily loss 0.5% (= 50 USD) → D4 ปฏิเสธทุกไม้ตั้งแต่ไม้แรก
จึงไม่มีไม้ให้ตรวจ (1) CalcLot 3 ไม้ (3) daily loss ≤0.5%+1 ไม้ (4) ทุก deal มี SL

## เกณฑ์ goal ที่ได้หลักฐาน
| ข้อ | สถานะ |
|---|---|
| (1) CalcLot 3 ไม้เทียบมือ | ❌ ไม่มีไม้ |
| (2) D4 ปฏิเสธอย่างน้อย 1 ครั้ง | ✅ 55 ครั้ง |
| (3) daily loss ไม่เกิน 0.5%+1 ไม้ | ❌ ไม่มีไม้ (ขาดทุน 0) |
| (4) ทุก deal มี SL | ❌ ไม่มี deal |

## ข้อเสนอ (ต้อง Owner/Cowork อนุมัติ — เปลี่ยนการออกแบบ test)
ตั้ง `InpRiskPct=0.25` คู่กับ `InpDailyLossPct=0.5` (ทั้งสองต่ำกว่าเพดาน 1%/3%) เพื่อให้เปิดไม้ได้ 1–2 ไม้ต่อวันก่อนชน breaker
