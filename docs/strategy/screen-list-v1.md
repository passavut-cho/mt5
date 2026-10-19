# Screen list v1 — ลงทะเบียนล่วงหน้า (pre-registered)

**Status:** 🔒 LOCKED 2026-10-19 (Owner อนุมัติ SC6) • ห้ามเพิ่ม/ลบ/แก้ค่า จนกว่าจะรันครบ 1 รอบ
**Data:** XAUUSD 2018-01-01 → 2022-12-31 (server time = NY+7) • ทุกตัวใช้ engine rules SC1–SC3 • รวม **14 variants**
**ไม่อยู่ในรายการ (ทดสอบไปแล้ว):** EMA cross + ADX, Asian range breakout (S-A), Donchian 20/10 H4 (S-B)

| ID | ตระกูล | กติกา (สรุป) | Variants | เหตุผลที่อาจมี edge |
|---|---|---|---|---|
| H1 | Mean reversion ในเทรนด์ | H1: close > SMA200(H1) → BUY เมื่อ RSI(2) < 10; close < SMA200 → SELL เมื่อ RSI(2) > 90 • SL 1.5×ATR(14,H1) • ออกเมื่อ RSI(2) ข้าม 50 หรือครบ 24 แท่ง | a: ตามนี้ • b: RSI 5/95 | pullback สั้นในเทรนด์ใหญ่ — ตระกูลที่ต่างจาก breakout ที่ล้มมาแล้ว |
| H2 | Time-of-day drift | ถือตามช่วงเวลา: BUY 03:00 → 10:00 server ทุกวัน • SL 1×ATR(14,H1) | a: long Asia 03–10 • b: short NY 17–23 | รูปแบบรายชั่วโมงของทอง (เอเชีย/ลอนดอนขึ้น, NY อ่อน) ที่มีรายงานในงานวิจัย — ทดสอบว่ารอดต้นทุนไหม |
| H3 | Previous-day range breakout (ถือภายในวัน) | BUY stop ที่ high ของ D1 เมื่อวาน / SELL stop ที่ low • เข้าได้ 10:00–20:00 • SL กลางกรอบเมื่อวาน • ปิด 23:30 | a: ตามนี้ • b: กรองเฉพาะวันที่ range เมื่อวาน < ATR(14,D1) | breakout จากกรอบใหญ่กว่า S-A (กรอบเอเชีย) |
| H4 | Inside-day breakout | D1 เมื่อวานเป็น inside bar → order stop ทั้งสองฝั่ง วันนี้ 01:00–20:00 • SL ขอบตรงข้าม • TP 2R หรือปิด 23:30 | a: ตามนี้ | การบีบตัวก่อนขยาย (volatility contraction) |
| H5 | Volatility squeeze H1 | Bollinger(20,2) width ต่ำสุดใน 120 แท่ง → เข้าเมื่อ close ทะลุ band • SL band กลาง • trailing ขอบ band ตรงข้าม | a: ตามนี้ • b: TP 2R | เหมือน H4 แต่ intraday |
| H6 | Trend + pullback | D1 close > EMA50(D1) → BUY เมื่อ H1 แตะ EMA20(H1) แล้วปิดกลับเหนือ; SELL กลับด้าน • SL ใต้ swing low 10 แท่ง H1 • TP 2R | a: TP 2R • b: ปิดครึ่ง +1R + BE (บทเรียน B2) | เข้าตามเทรนด์ใหญ่แต่ราคาดีกว่า breakout |
| H7 | Post-news continuation | วัน NFP/CPI (`data/files/news.csv`): ดูแท่ง M15 15:30–15:45 → เข้าตามทิศ ณ 15:45 • SL อีกฝั่งของแท่งข่าว • ปิด 23:30 | a: ตามนี้ • b: เข้า 16:30 (รอสเปรดแคบ) | ข่าวใหญ่สร้างทิศทางที่ต่อเนื่องภายในวัน • ไม้น้อย (~120 ใน 5 ปี) → เสี่ยงไม่ถึง 150 ไม้ = FAIL ตาม bar |
| H8 | Monday reversal ของ weekly gap | ใช้ gap จาก T-042 • |gap| > 0.3×ATR(14,H4) → เข้าสวน gap ที่ 01:15 จันทร์ • TP = ปิด gap • SL 1×ATR(H4) | a: ตามนี้ | gap มักถูกปิด • ไม้น้อย (~60) → เกือบแน่นอนว่า FAIL ด้วยจำนวนไม้ — เก็บไว้เป็น control ของ engine |

- เวลาทั้งหมดเป็น server time • "SL" ส่งพร้อมเข้าไม้เสมอ • ไม่มี grid/martingale/averaging ในทุก hypothesis
- H7/H8 คาดว่าจะไม่ถึงจำนวนไม้ขั้นต่ำ — อยู่ในรายการเพื่อให้ engine ทดสอบ news/gap path และเพื่อบันทึกว่าลองแล้ว
