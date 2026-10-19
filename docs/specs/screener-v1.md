# Spec — Strategy Screener v1 (R1) — APPROVED

**Status:** APPROVED โดย Owner 2026-10-19 (SC1–SC6 ตามที่เสนอ) • screen-list-v1 LOCKED
**เหตุผล:** 3 ตระกูล (EMA, S-A, S-B) ไม่ผ่าน bar • วงจร MT5 ต่อ 1 ไอเดีย ≈ ครึ่ง–1 วัน และทุก look บน research set เพิ่มโอกาสเจอผลบังเอิญ → คัดกรองหลายไอเดียแบบลงทะเบียนล่วงหน้าใน Python ครั้งเดียว แล้วส่งเฉพาะตัวที่ผ่านไปยืนยันใน MT5

## Pipeline (ห้ามข้ามขั้น)
1. **Export** (Claude/MT5): bar M15 XAUUSD (bid OHLC + spread ต่อแท่ง, server time) **2017-07-01 → 2022-12-31 เท่านั้น** — script ต้องปฏิเสธวันที่ > 2022-12-31 (กันการมองข้อมูล validation โดยไม่ตั้งใจ)
2. **Engine** (Codex): Python backtester แบบ bar-by-bar
3. **Calibration gate**: engine ต้องสร้างผลของ MT5 ที่รู้แล้วซ้ำได้ — **S-A A2** (1124 ไม้, PF 1.01) และ **S-B B2** (272 ไม้, PF 1.02) — เกณฑ์: จำนวนไม้ ±5%, PF ±0.05, net R ทิศทางเดียวกัน • ไม่ผ่าน = ห้ามใช้ screener
4. **Screen**: รันทุก hypothesis ใน screen-list-v1 **ครั้งเดียว** บน 2018-01-01 → 2022-12-31 → ตาราง + ตัดสินตาม screen bar
5. **MT5 confirm**: ตัวที่ผ่าน (สูงสุด 2 ตัว เรียงตาม PF stress) → spec ปกติ → implement → bar เดิมของ Phase 3 บน MT5
6. **Secondary check 2023–2024** (ใช้ไปแล้วกับ EMA เท่านั้น): PF ≥ 1.05 หลัง cost+swap → จากนั้นค่อยเข้า protocol validation 2025 (validation_looks)

## Engine rules (SC1–SC3)
- **SC1 Fill model:** สัญญาณคิดจากแท่งที่ **ปิดแล้ว** • เข้าที่ open แท่งถัดไป • BUY จ่าย ask = bid + spread ของแท่ง, SELL ได้ bid • SL/TP intra-bar ตรวจจาก high/low (BUY: low ≤ SL; SELL: high + spread ≥ SL) • **แท่งเดียวโดนทั้ง SL และ TP → นับเป็น SL** (มองแง่ร้าย) • gap ข้าม SL → fill ที่ราคาเปิด (ไม่ใช่ราคา SL)
- **SC2 Costs:** commission 7.0/lot round turn • swap จาก specs ปัจจุบัน: long −57.03 / short +39.77 points/lot/คืน (1 point = $1/lot) • triple swap วันพุธ (ตรวจกับ IC: ถ้า spec dump มี rollover3days ให้ใช้ค่านั้น) • stress = +20 points ต่อ round turn • ช่วงตลาดปิดรายวัน (≈ 00:00–01:00 server) ห้ามเข้าไม้ (ตรงกับ retcode 10018 ที่เห็นใน T-043)
- **SC3 Sizing:** risk 1% ของ equity ต่อไม้ แบบ compounding, lot = floor ตาม step 0.01, ต่ำกว่า 0.01 = ข้าม (เหมือน RiskManager) • daily loss 3% หยุดวัน (เหมือน EA) • 1 position ต่อเวลา ต่อ hypothesis • ผลแสดงทั้ง $ และ R

## Screen bar (SC4) — เข้มกว่า bar MT5 เพราะทดสอบหลายตัวพร้อมกัน
| เกณฑ์ | ค่า |
|---|---|
| PF หลัง commission + swap | **≥ 1.20** |
| PF stress (+20 pts) | **≥ 1.05** |
| จำนวนไม้ (5 ปี) | ≥ 150 |
| Max DD (equity, risk 1%) | ≤ 25% |
| ปีกำไร | ≥ 4/5 |
| PF long และ PF short (ถ้า hypothesis เทรดสองฝั่ง) | ≥ 1.0 ทั้งคู่ |
| Expectancy หลัง cost | ≥ +0.10R ต่อไม้ |
- ห้ามปรับพารามิเตอร์/เพิ่ม variant หลังเห็นผล • ตัวที่ "เกือบผ่าน" = ไม่ผ่าน • รายงานผลทุกตัว รวมตัวที่แย่

## Deliverables (SC5)
- `research/screener/` (Python 3, numpy/pandas อนุญาต — pin ใน `requirements.txt`) • hypothesis แต่ละตัว = 1 ฟังก์ชันใน `hypotheses.py` ชื่อ = ID ใน screen-list • unit test ของ fill model (SL/TP แท่งเดียว, gap, spread, swap พุธ, 10018) • `python -m research.screener --list screen-list-v1 --out docs/strategy/screen-results-v1.md`
- ข้อมูล export อยู่ `data/research/xauusd_m15_2017-07_2022-12.csv` (gitignored — ใหญ่) + checksum ใน md

## Owner ตัดสิน
| # | คำถาม | ข้อเสนอ |
|---|---|---|
| SC1 | fill model แง่ร้าย (SL ก่อน TP ในแท่งเดียว, ask จากสเปรดต่อแท่ง) | ตามที่เขียน |
| SC2 | ใช้ swap ปัจจุบันย้อนหลังทั้งช่วง | **ใช่** — เราจะเทรดที่ swap ปัจจุบัน (ฝั่ง long เสียเปรียบโครงสร้าง ต้องยอมรับ) |
| SC3 | sizing เหมือน EA | ตามที่เขียน |
| SC4 | screen bar ตามตาราง | ตามที่เขียน |
| SC5 | แบ่งงาน: export = Claude (MT5), engine + calibration + screen = Codex, review/merge = Claude | ตามที่เขียน |
| SC6 | รายการ hypothesis | `screen-list-v1.md` 8 ตัว / 14 variants — ล็อกก่อนเขียน engine |
