# Strategy Spec — Donchian Breakout H4 (S-B) v1 — DRAFT

**Status:** DRAFT — รอ Owner ตัดสิน O1–O3 (การถือข้ามคืนขัดกับ S6 ของกลยุทธ์ intraday)
**Data:** research set 2010–2022 เหมือน S-A • ไม่ถึง 100 ไม้ใน 2 ปีแน่นอน — ต้องใช้ข้อมูลยาว

## Hypothesis
trend following แบบ breakout บนกรอบเวลาใหญ่จับเทรนด์ยาวของทองได้ทั้งขาขึ้นและขาลง (2010–11 ขึ้น, 2013–15 ลง, 2019–20 ขึ้น) → expectancy บวกจากไม้ชนะใหญ่ไม่กี่ไม้ แม้ win rate ต่ำ

## Rules (ร่าง)
- Entry: แท่ง H4 **ปิด** เหนือ highest high 20 แท่งก่อนหน้า → BUY / ต่ำกว่า lowest low 20 → SELL
- SL เริ่มต้น: 2 × ATR(14, H4) • Trailing: lowest low/highest high 10 แท่ง (Donchian exit)
- ไม่มี TP • holiday/news filter ใช้กับ **การเปิดไม้ใหม่** เท่านั้น
- variants (≤ 4): entry 20 vs 55 แท่ง × trailing 10 vs ATR×3

## Owner ตัดสิน
| # | คำถาม | ข้อเสนอ |
|---|---|---|
| O1 | ถือข้ามคืนได้ไหม (S-B ไม่มี time exit 23:30) | **ได้** สำหรับ S-B เท่านั้น — เพราะเป็นธรรมชาติของ trend following |
| O2 | ถือข้ามสุดสัปดาห์ได้ไหม | **ไม่ได้** — ปิดทุกไม้ศุกร์ 20:00 server (gap วันจันทร์ข้าม SL ได้ → risk เกิน 1%) |
| O3 | swap | ปล่อยให้ tester คิด swap จริงของ IC (long ≈ −$57/lot/คืน, short ≈ +$40) และรายงานแยก — ไม่บวกเข้า risk 1% ตอนเปิดไม้ (ไม่รู้ล่วงหน้าว่าถือกี่คืน) |
