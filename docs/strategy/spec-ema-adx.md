# Strategy Spec — EMA 9/21 Cross + ADX Filter (v1)

**Status:** APPROVED — Owner อนุมัติ S1–S8 ตามที่เสนอ 2026-10-12 (แก้ spec หลังจากนี้ต้องให้ Owner อนุมัติใหม่)
**Owner ของ spec:** Phas • **ร่างโดย:** Cowork 2026-10-12 • **Broker อ้างอิง:** IC Markets Raw (ICMarketsSC-Demo)

> เป้าหมายของ v1 ไม่ใช่ "กำไร" แต่เป็น **กลยุทธ์อ้างอิงที่เรียบง่าย ทดสอบได้ และวัดผลได้ตรงไปตรงมา** — จำนวนพารามิเตอร์น้อยที่สุดเพื่อลดโอกาส overfit ใน Phase 4

## 0. ข้อเท็จจริงที่ spec นี้อ้าง
- XAUUSD @ IC: 100 oz/lot, $1 move = $100/lot, digits 2, spread median 6 / p95 11 points, swap long ≈ −$57 / short ≈ +$40 ต่อ lot ต่อคืน (พุธ ×3) — `docs/research/broker-icmarkets.md`
- **Server time ของ IC = GMT+2 (หน้าหนาว) / GMT+3 (ช่วง US DST)** — ตามเวลา New York ดังนั้น 00:00 server = 17:00 New York (rollover) เสมอ ([IC blog](https://www.ic.com/blog/us-daylight-savings-server-time-changing-to-gmt3-2024/))
  - เวลาไทย = server + 5 ชม. (หน้าหนาว) / + 4 ชม. (US DST)
- Risk ทั้งหมดมาจาก RiskManager (ADR 0002): 1%/ไม้ รวม commission, daily loss 3% ทั้งบัญชี + pre-trade check, max 1 position, max spread 20 points — **spec นี้ห้ามกำหนด risk ใหม่**

## 1. ตลาดและกรอบเวลา
- Symbol: `_Symbol` (ทดสอบหลัก XAUUSD) • Timeframe: `_Period` (ทดสอบหลัก M15)
- **S1 — ช่วงเวลาเปิดไม้ใหม่:** 10:00–22:59 server time (= London 08:00 → ก่อน rollover 1 ชม.)
  - เหตุผล: ใช้ช่วงสภาพคล่องสูงสุดของทอง (London + NY) และหลบช่วง rollover/daily break ที่ spread กว้าง (เห็นได้จาก spread 40–50 points ตอนเปิดตลาด) • เพราะ server time ผูกกับ NY จึงไม่ต้องแก้ตาม DST
  - input: `InpSessionStartHour = 10`, `InpSessionEndHour = 23` (เปิดไม้ได้ถ้า start ≤ hour < end)

## 2. Signal (คำนวณที่ **แท่งปิดแล้ว** เมื่อเกิดแท่งใหม่เท่านั้น)
- `EMA_fast = EMA(close, 9)`, `EMA_slow = EMA(close, 21)`
- **Cross ขึ้น (BUY):** `fast[2] <= slow[2]` และ `fast[1] > slow[1]`
- **Cross ลง (SELL):** `fast[2] >= slow[2]` และ `fast[1] < slow[1]`
- **S2 — ADX filter:** `ADX(14)[1] >= 25` และยืนยันทิศด้วย DI: BUY ต้อง `+DI[1] > −DI[1]`, SELL ต้อง `−DI[1] > +DI[1]`
  - เหตุผล: 25 คือค่ามาตรฐาน "มีเทรนด์" ที่คนใช้กันแพร่หลาย (ไม่ใช่ค่าที่ fit มา) • DI ไม่เพิ่มพารามิเตอร์ แต่กัน cross ที่สวนแรงกดของเทรนด์
- ข้อมูลไม่พร้อม (`BarsCalculated` < ที่ต้องใช้ หรือ `CopyBuffer` ล้มเหลว) → `Evaluate()` คืน false = ไม่ทำอะไร

## 3. Entry
- Market order ทันทีที่ประเมินแท่งใหม่ (≈ open ของแท่งถัดจาก cross)
- เงื่อนไขก่อนเข้า: อยู่ใน session (S1) • `RiskManager.CanOpen()` ผ่าน (spread ≤ 20, breaker, max position, connected) • ไม่มี position ของ EA นี้อยู่
- **S3 — มี position อยู่แล้วและเกิด cross ฝั่งตรงข้าม:** ปิด position เดิม (exit ตามข้อ 4) แล้ว **เข้าไม้ใหม่ฝั่งตรงข้ามเฉพาะถ้าผ่าน filter ทุกข้อ** (ADX/DI/session/risk) — ถ้าไม่ผ่านก็แค่ปิด
- cross ทิศเดียวกับ position ที่ถืออยู่ → ไม่ทำอะไร (ห้ามเพิ่มไม้)

## 4. Exit
- **S4 — SL:** `ATR(14)[1] × 1.5` จากราคาเข้า (ส่งพร้อม order เสมอ)
  - ตัวอย่าง: ATR M15 ≈ $4 → SL $6 → บัญชี $10,000 risk $100 → lot = 100 / (600 + 7) ≈ 0.16
  - ถ้า SL < 2 × spread ปัจจุบัน → ไม่เข้า (SL แคบเกินจน spread กิน)
- **S5 — TP:** `2.0 × ระยะ SL` (2R) ส่งพร้อม order
- **Exit เพิ่มเติม:** cross ฝั่งตรงข้าม (S3) → ปิดที่ market
- **S6 — Time exit (กัน swap + rollover):** ปิดทุก position ของ EA ที่ **23:30 server time** ทุกวัน
  - เหตุผล: swap long ≈ −$57/lot/คืน ≈ 9% ของ risk ต่อไม้ที่ 0.16 lot และพุธ ×3 ≈ 27% • spread ช่วง rollover กว้าง • v1 จึงเป็น **intraday ล้วน** — ตัดตัวแปร swap ออกจากผลทดสอบ
- **S7 — ศุกร์:** ไม่เปิดไม้ใหม่หลัง 20:00 server time วันศุกร์ (กัน gap สุดสัปดาห์ร่วมกับ S6)
- **S8 — Trailing / breakeven:** **ไม่มีใน v1** (เพิ่มพารามิเตอร์และ path ที่ต้องทดสอบ — พิจารณาใน v2 หลังรู้ baseline)

## 5. Risk
มาจาก RiskManager ทั้งหมด (ADR 0002) — spec ส่งให้ Risk แค่ `SSignalIntent { dir, sl_distance = ATR×1.5, tp_distance = 2×sl, reason }`

## 6. Edge cases
| กรณี | พฤติกรรม |
|---|---|
| แท่งไม่พอสำหรับ EMA21 / ADX14 / ATR14 | ไม่เทรด (Evaluate คืน false) |
| เปิดตลาดวันจันทร์ (gap) | อยู่นอก session S1 อยู่แล้ว (ตลาดเปิด ~01:00 server) + spread filter |
| ข่าวแรง (NFP, CPI, FOMC) | **v1 ไม่มี news filter** — บันทึกเป็นข้อจำกัด; spread filter ช่วยได้บางส่วน |
| EA restart ขณะมี position | นับ position เดิม (magic+symbol) และใช้ exit rule ต่อ (S3/S6) |
| Order ถูกปฏิเสธ / requote | ตาม TradeManager (D5 retry 2 ครั้ง คำนวณใหม่) |
| ช่วง DST ไม่ตรงกันระหว่าง US/EU (~3 สัปดาห์/ปี) | session เลื่อน 1 ชม. เทียบ London — ยอมรับใน v1 |

## 7. Inputs
| Input | Default | Optimize range (Phase 4 — ≤ 3 ตัว) |
|---|---|---|
| InpFastEMA | 9 | 5–15 step 2 |
| InpSlowEMA | 21 | 15–40 step 5 |
| InpADXPeriod | 14 | fixed |
| InpADXMin | 25 | 20–30 step 5 |
| InpATRPeriod | 14 | fixed |
| InpSLATRMult | 1.5 | fixed ใน v1 |
| InpTPRMult | 2.0 | fixed ใน v1 |
| InpSessionStartHour | 10 | fixed |
| InpSessionEndHour | 23 | fixed |
| InpTimeExitHHMM | 2330 | fixed |
| InpFridayCutoffHour | 20 | fixed |

## 8. แผนข้อมูลทดสอบ (ล็อกไว้ตั้งแต่ตอนนี้ — กัน look-ahead ระดับโปรเจกต์)
| ชุด | ช่วง | ใช้ใน |
|---|---|---|
| In-sample | 2023-01-01 → 2024-12-31 | Phase 2 (ตรวจว่าทำงานตาม spec), Phase 4 optimize |
| Validation | 2025-01-01 → 2025-12-31 | Phase 3 walk-forward |
| **Out-of-sample (ห้ามแตะ)** | 2026-01-01 → 2026-09-30 | Phase 4 ตรวจรอบสุดท้ายครั้งเดียว |
- Phase 2 = 1-min OHLC ได้ • Phase 3 ขึ้นไป = real ticks (Model=4) + commission 7.0

## 9. Acceptance ของ Phase 2 (ไม่ใช่เรื่องกำไร)
- สุ่ม 10 ไม้ใน visual mode: entry/SL/TP/exit ตรงข้อ 2–4 ทุกไม้
- ไม่มีไม้เปิดนอก session, ไม่มีไม้ข้าม 23:30, ไม่มีไม้ที่ไม่มี SL
- จำนวนไม้ใน in-sample ≥ 100 (ถ้าน้อยกว่า = filter แน่นเกิน ต้องรายงาน ไม่ปรับเอง)

## 10. Owner decisions — อนุมัติทั้งหมดตามที่เสนอ (2026-10-12)
| # | เรื่อง | ข้อเสนอ |
|---|---|---|
| S1 | session | 10:00–22:59 server |
| S2 | ADX | ≥ 25 + DI ยืนยันทิศ |
| S3 | cross สวนทาง | ปิด + กลับฝั่งถ้าผ่าน filter |
| S4 | SL | ATR(14) × 1.5 (ไม่เข้าถ้า SL < 2×spread) |
| S5 | TP | 2R |
| S6 | time exit | ปิดทุกไม้ 23:30 server (intraday ล้วน) |
| S7 | ศุกร์ | ไม่เปิดใหม่หลัง 20:00 server |
| S8 | trailing/BE | ไม่มีใน v1 |
