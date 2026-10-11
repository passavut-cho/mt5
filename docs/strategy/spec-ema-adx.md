# Strategy Spec — EMA 9/21 Cross + ADX Filter (v1)

**Status:** DRAFT — ต้องให้ผู้ใช้อนุมัติก่อน Phase 2 implement
หัวข้อที่มี ❓ = ยังต้องตัดสินใจ

## 1. ตลาดและกรอบเวลา
- Symbol: XAUUSD (input) • Timeframe: M15 (input)
- ช่วงเวลาเทรด: ❓ (ทั้งวัน / เฉพาะ London+NY / ตัดช่วง rollover)

## 2. Signal
- Fast EMA 9, Slow EMA 21 บน close — คำนวณที่แท่งปิดแล้ว (shift 1 เทียบ shift 2)
- Long: EMA9 ตัดขึ้นเหนือ EMA21 • Short: ตัดลง
- ADX filter: ADX(14) ≥ ❓ (เช่น 20 หรือ 25) ที่ shift 1
- ใช้ +DI/−DI ยืนยันทิศด้วยไหม: ❓

## 3. Entry
- เข้าด้วย market order ที่ open ของแท่งถัดไป
- Spread สูงสุดที่ยอมเข้า: ❓ points
- มีไม้ค้างทิศเดียวกันอยู่ → ไม่เข้าเพิ่ม • ทิศตรงข้าม → ❓ (ปิดแล้วกลับทิศ / ปิดอย่างเดียว / ไม่ทำอะไร)

## 4. Exit
- SL: ❓ (ATR(14) × k / swing low-high / fixed points)
- TP: ❓ (R-multiple เช่น 2R / ไม่มี TP ใช้ cross กลับ)
- Trailing / breakeven: ❓

## 5. Risk (จาก RiskManager — ห้ามกำหนดใหม่ใน spec)
- 1% ต่อไม้, daily loss 3%, max open positions = 1

## 6. Edge cases
- แท่งไม่พอสำหรับ EMA21/ADX → ไม่เทรด
- Gap เปิดตลาดวันจันทร์ → ❓
- ข่าวแรง → v1 ไม่มี news filter (บันทึกไว้เป็นข้อจำกัด)

## 7. Inputs
| Input | Default | Optimize range (Phase 4) |
|---|---|---|
| InpFastEMA | 9 | 5–15 |
| InpSlowEMA | 21 | 15–40 |
| InpADXPeriod | 14 | fixed |
| InpADXMin | ❓ | ❓ |
