# Strategy Spec — Donchian Breakout H4 (S-B) v1 — APPROVED

**Status:** APPROVED โดย Owner 2026-10-19 (O1–O5 ตามที่เสนอใน r2) • ค่าเกณฑ์ weekend lock (O2) จะใส่หลัง T-042 ในหัวข้อ "O2 final" ด้านล่าง

### O2 final
- `InpWeekendLockATR` = **(รอ T-042)** — 0 = ถือข้ามสุดสัปดาห์เมื่อ SL ≥ breakeven; >0 = SL ต้องล็อกกำไร ≥ ค่านี้ × ATR(14,H4)
**Data:** research set **2018-01-01 → 2022-12-31** เหมือน S-A (แก้ก่อนรันใดๆ: IC มี M1 ครบตั้งแต่กลางปี 2017 เท่านั้น) • คาด ~150–250 ไม้ใน 5 ปี — ถ้าต่ำกว่า 100 = FAIL ห้ามขยายช่วงข้อมูลหลังเห็นผล
**Bar:** เหมือน S-A (PF≥1.1 หลัง commission • stress +20 pts PF≥1.0 • DD≤25% • ≥3/5 ปีกำไร • long & short PF≥1.0) **+ ทุกตัวเลขรวม swap จริงแล้ว**

## Hypothesis
trend following แบบ breakout บน H4 จับเทรนด์หลายวัน–หลายสัปดาห์ของทอง → expectancy บวกจากไม้ชนะใหญ่ไม่กี่ไม้ แม้ win rate ต่ำ • ต้นทุนต่อไม้ (spread+commission) เล็กเมื่อเทียบกับระยะที่ถือ ซึ่งเป็นจุดที่ S-A/EMA ล้ม
คำถามรอง (จาก Owner): การปิดทำกำไรเป็นระยะช่วยหรือทำลาย edge ของ trend following?

## Rules (คงที่ทุก variant)
- TF H4 • Entry: แท่ง H4 **ปิด** เหนือ highest high **20** แท่งก่อนหน้า → BUY / ต่ำกว่า lowest low 20 → SELL • 1 position ต่อ magic+symbol (กฎเดิม)
  - ตัด 55 แท่งออกจากร่างแรก: 5 ปีน่าจะได้ไม้ไม่ถึง 100
- SL เริ่มต้น: 2 × ATR(14, H4) จากราคาเข้า (ส่งพร้อม order) → **1R** = ระยะนี้ • lot จาก RiskManager 1% ตามเดิม
- Trailing: Donchian exit — SL ตามขอบ lowest low (BUY) / highest high (SELL) **10** แท่ง H4 ที่ปิดแล้ว เลื่อนได้ทางเดียว (ลด risk เท่านั้น)
- holiday/news filter ใช้กับ **การเปิดไม้ใหม่** เท่านั้น
- ห้ามเพิ่ม position / ห้าม scale-in (ข้อ 2 กฎเหล็ก)

## Exit variants (≤ 4) — ตอบคำขอ Owner "มี TP หรือปิดทำกำไรเป็นระยะ"
| ID | การทำกำไร | สมมติฐานที่ทดสอบ |
|---|---|---|
| B1 | ไม่มี TP — trailing อย่างเดียว | baseline trend following แท้ |
| B2 | ปิด 50% ที่ +1R แล้วเลื่อน SL ส่วนที่เหลือมา breakeven • ที่เหลือ trailing | ทำกำไรเร็ว ล็อกต้นทุนเร็ว |
| B3 | ปิด 50% ที่ +2R แล้วเลื่อน SL มา breakeven • ที่เหลือ trailing | ทำกำไรช้ากว่า ให้ไม้วิ่งมากขึ้น |
| B4 | TP เต็มจำนวนที่ +3R (trailing ยังทำงานก่อนถึง TP) | ปิดหมดเป้าตายตัว |

- Partial close: ปริมาณ = floor(volume × 50% / volume_step) × step • ถ้าส่วนที่ปิดหรือส่วนที่เหลือ < volume_min → **ไม่ partial** (ถือทั้งไม้ต่อด้วย trailing) และนับใน report ว่าเกิดกี่ครั้ง
- การเลื่อน SL มา breakeven = ราคาเข้า (ไม่บวก commission) • ถ้า trailing อยู่ดีกว่า breakeven แล้วใช้ค่าที่ดีกว่า
- partial และ SL→BE **ลด** risk เท่านั้น ไม่ใช่ averaging/scale-in

## Weekend / overnight
- O1: ถือข้ามคืนได้ (S-B เท่านั้น)
- O2 (r2 แทนร่างเดิม "ปิดทุกศุกร์"): ศุกร์ **20:00 server** ตรวจทุกไม้ของ S-B
  - SL อยู่ที่ breakeven หรือดีกว่า (ล็อกกำไรแล้ว) → **ถือข้ามสุดสัปดาห์**
  - SL ยังอยู่ฝั่งขาดทุน → **ปิด** (gap วันจันทร์อาจทะลุ SL → เสียเกิน 1%)
  - ค่านี้ล็อกหลัง T-042 วัดขนาด gap: ถ้า gap > 1×ATR(14,H4) บ่อยกว่า 5% ของสัปดาห์ → ต้องให้ SL ล็อกกำไร ≥ 1×ATR ก่อนถือข้ามสุดสัปดาห์ (Cowork เสนอ Owner อีกครั้งก่อน implement)
- ไม่เปิดไม้ใหม่หลังศุกร์ 20:00 server

## Report ที่ต้องมี (เพิ่มจาก S-A)
- swap รวมแยก long/short • จำนวนคืนที่ถือเฉลี่ย • จำนวนไม้ที่ถือข้ามสุดสัปดาห์ + ผลของไม้เหล่านั้น • gap loss เกิน 1R กี่ครั้ง
- จำนวน partial ที่ทำได้ / ทำไม่ได้เพราะ volume_min
- report_stats.py ต้องรวม deal ขาออกหลายตัวต่อ 1 position (partial) เป็น 1 ไม้ — ตรวจก่อนรัน

## Owner ตัดสิน
| # | คำถาม | ข้อเสนอ |
|---|---|---|
| O1 | ถือข้ามคืน | **ได้** สำหรับ S-B เท่านั้น |
| O2 | ถือข้ามสุดสัปดาห์ | **ถือได้เฉพาะไม้ที่ SL ล็อกกำไรแล้ว** (ดูหัวข้อ Weekend) — เกณฑ์สุดท้ายหลัง T-042 |
| O3 | swap | ให้ tester คิด swap จริงของ IC และรายงานแยก • ไม่บวกเข้า risk 1% ตอนเปิดไม้ |
| O4 | ทำกำไร | 4 variants B1–B4 ตามตาราง • entry 20 / trailing 10 คงที่ |
| O5 | ทุนทดสอบ | deposit 10,000 ใน tester • บน demo ต้องทำ T-006 ก่อน (ทุน $500 → lot 0.01 แทบทุกไม้ = partial ไม่ได้) |
