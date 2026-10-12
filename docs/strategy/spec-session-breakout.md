# Strategy Spec — Session Breakout (S-A) v1

**Status:** APPROVED for research (Owner 2026-10-12: N1–N3 ตามที่เสนอ) • Signal class ใหม่ `CSessionBreakoutSignal` — **ไม่แตะ Core / RiskManager**
**Data:** research set **2010-01-01 → 2022-12-31** (Model=1 + cost stress +20) • 2023–2024 = ตรวจรอง • 2025 validation • 2026 OOS (ห้ามแตะ)

## Hypothesis (เขียนก่อนรัน)
ทองช่วงเอเชีย (server 01:00–09:59) เคลื่อนในกรอบแคบ ส่วนช่วง London/NY มีแรงซื้อขายหลัก → **การทะลุกรอบเอเชียครั้งแรกของวันมีทิศทางต่อเนื่องพอให้ expectancy เป็นบวกหลังหักต้นทุน** และต้องเป็นจริง **ทั้งฝั่ง long และ short และในหลาย regime** (ไม่ใช่แค่ขาขึ้น)

## Rules
| ส่วน | กติกา | ค่า (fixed ยกเว้นระบุ) |
|---|---|---|
| กรอบเอเชีย | high/low ของแท่ง M15 ที่เปิดตั้งแต่ 01:00 ถึง 09:45 server ของวันนั้น (ต้องมี ≥ 30 แท่ง ไม่งั้นข้ามวัน) | — |
| กรองวัน | ข้ามวันที่ความกว้างกรอบ > `1.5 × ATR(14, D1)[1]` (ตลาดวิ่งไปแล้ว) • holiday filter • news filter ±30m ตามเดิม | 1.5 fixed |
| Entry | ช่วง **10:00–20:59 server**: แท่ง M15 ที่ **ปิด** เหนือ high → BUY / ต่ำกว่า low → SELL ที่ open แท่งถัดไป • **สูงสุด 1 ไม้ต่อวัน** (breakout แรกเท่านั้น) | — |
| SL | ตาม variant (ด้านล่าง) • ไม่เข้าถ้า SL < 2 × spread ปัจจุบัน (เหมือน v1 S4) | — |
| Exit | ตาม variant • time exit 23:30 + ไม้ค้างข้ามวันปิดทันที (T-011) • Friday cutoff 20:00 ตามเดิม | — |
| Risk | RiskManager เดิมทั้งหมด (1%, 3%, D4, commission, max spread 20) | — |

## Variants (ทดสอบครบ 4 ตัว — 2 มิติ × 2 ค่า, ห้ามเพิ่ม)
| ID | SL | Exit |
|---|---|---|
| A1 | ฝั่งตรงข้ามของกรอบ | time exit 23:30 เท่านั้น (ปล่อยวิ่ง) |
| A2 | ฝั่งตรงข้ามของกรอบ | TP = 2R |
| A3 | กลางกรอบ (½ ความกว้าง) | time exit 23:30 เท่านั้น |
| A4 | กลางกรอบ | TP = 2R |

## Pre-validation bar (รอบนี้ — ต้องผ่านทุกข้อบน research set 2010–2022)
- PF หลังหัก commission **≥ 1.1** และ PF ภายใต้ stress +20 **≥ 1.0**
- trades ≥ 100 • MaxDD ≤ 25%
- **ปีที่กำไร ≥ 60%** (≥ 8 จาก 13 ปี) • **long PF ≥ 1.0 และ short PF ≥ 1.0** (กัน regime bias)
- ผ่าน → ตรวจรองบน 2023–2024 (ต้องไม่ขาดทุนเกิน 10%) → ค่อยเปิด 2025 (validation_looks +1)

## Inputs ใหม่
`InpStrategy` (enum: EMA_ADX=0, SESSION_BREAKOUT=1, DONCHIAN=2) • `InpAsiaStartHour=1`, `InpAsiaEndHour=10`, `InpEntryEndHour=21`, `InpMaxRangeATR=1.5`, `InpSLMode` (OPPOSITE=0, MID=1), `InpUseTP` (bool), `InpTPRMult=2.0`
