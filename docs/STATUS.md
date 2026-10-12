# Project Status

**Current phase:** 2 — Strategy v1 (EMA 9/21 + ADX) — Phase 1 gate ผ่าน 2026-10-12 (tag p1-done, Owner อนุมัติ)
**Last updated:** 2026-10-12
**Broker เป้าหมาย:** IC Markets (Raw Trading Ltd, FSA Seychelles) — demo บัญชี Raw

## Phase 0 — ค้าง (ต้องปิดก่อน /gate ของ Phase 1)
- [x] `scripts/setup.ps1` — terminal D0E8209F77C8CF37AD8BF550E51FF075 (MetaQuotes-Demo)
- [x] `/backtest smoke` → report OK: XAUUSD M15 2024-01..03, 1-min OHLC, quality 100%, 5777 bars, 0 trades
- [x] `compile.ps1` PASS — SmartEA + SymbolSpecDump: 0 errors, 0 warnings (IC terminal, 2026-10-12)
- [x] live guard บน IC demo chart → `live guard: OK (DEMO)` (2026-10-12)
- [x] `git init` + commit `[P0] bootstrap` (5df3790) → **Phase 0 ครบทุกข้อ**

## Phase 1 — Done
- Research IC Markets → `docs/research/broker-icmarkets.md`
- ADR 0002 Core framework (interface + flow) — Accepted → `docs/decisions/0002-core-framework.md`
- `src/Scripts/SymbolSpecDump.mq5` — compile 0/0
- `setup.ps1` เพิ่ม junction `MQL5\Files\SmartEA → data\files`

- Core implement ตาม ADR 0002 (2026-10-12): `src/Include/Core/{Types,Logger,BarClock,SignalBase,RiskManager,TradeManager}.mqh`, `Signals/SignalNone.mqh`, ต่อเข้า `SmartEA.mq5`, `src/Scripts/RiskSelfTest.mq5`
- compile 0/0 ทั้ง SmartEA, RiskSelfTest, SymbolSpecDump • BOM ครบ • risk-guardian PASS (หลังแก้ 2 finding) • qa-reviewer no BLOCKER (หลังแก้ day-start balance ไม่นับ deposit)
- `smoke.set` ระบุ input ครบ

- **G1.3 implement แล้ว (2026-10-12):** D4 pre-trade check (`PreTradeOk` ใน CalcLot ปฏิเสธไม้ ไม่ลด lot) • D5 `CTradeManager::Open` ส่งครั้งเดียว + `retryable`, EA `OpenWithRetry` refresh ราคา→CanOpen→CalcLot ทุก attempt (สูงสุด 2 retry) และ log `actual_risk` หลัง fill • D6 netting fail closed + Warn ใน Init • CanOpen ปฏิเสธเมื่อ `TERMINAL_CONNECTED==0` นอก tester • breaker latch log Warn • D7 `InpMaxSpreadPoints=20` ใน `smoke.set` (ค่า default ในโค้ดคง 0), `Leverage=500` ใน `smoke.ini`
- G1.3: compile 0/0 ทั้ง 3 ไฟล์ • risk-guardian PASS • qa-reviewer ไม่มี BLOCKER • เพิ่ม test D4 (7 เคส สูตรล้วน) ใน RiskSelfTest
- qa-reviewer MINOR ที่ยังไม่แก้ (deferred): `actual_risk` ใช้ lot ที่ขอ (ไม่ใช่ `ResultVolume`) และไม่มี fallback ถ้า `ResultPrice()==0`, เคสขอบ D4 พึ่ง floating point, `intent.reason` เป็น order comment ควร ≤31 ตัวอักษร, `CountPositions` ซ้ำ 2 ที่, test D4/D6 ยังไม่ครอบคลุม end-to-end (CalcLot/ActualRisk/netting)

## Phase 1 — GATE PASSED (2026-10-12)
- compile 0/0 • RiskSelfTest 42/0 • core_smoke 1 ปี (0 trades, journal สะอาด, breaker 9700) • risk-guardian PASS • qa-reviewer no BLOCKER

## Phase 1 — Next (เก็บไว้อ้างอิง)
> ตั้งแต่ 2026-10-12 งานของ Code/CLI ย้ายไปอยู่ใน `docs/queue.md` (T-002 … T-005) — ส่วนนี้เป็นสรุป
1. ✅ RiskSelfTest รอบ 2 (หลัง G1.3) บน IC demo → pass=42 fail=0 `SELFTEST: PASS` (2026-10-12) รวมชุด D4 7 กรณี
1b. ✅ SymbolSpecDump v1.10 → `data/files/specs_ICMarketsSC-Demo.tsv` (HEDGING, 100 oz, spread p95 11 pts) — สรุปใน docs/research/broker-icmarkets.md
2. ✅ SmartEA บน IC demo → `live guard: OK (DEMO)`
2b. ✅ G1.3 (D4–D6 + connected guard) — ดูด้านบน
3. ✅ G1.2 (T-003, 2026-10-12): core_smoke XAUUSD M15 2024 → 0 trades, final 10000, SmartEA ERROR/CRITICAL = 0 • report `data/reports/SmartEA_core_smoke.htm` + `.summary.md`
4. ✅ journal: `New day 2024.01.01: balance ต้นวัน=10000.00 breaker ที่ equity<=9700.00`
5. `/gate`

- **T-010 (2026-10-12):** SL ปัดเข้าหา entry บน tick grid ด้วย helper เดียว `NormalizeSlPrice` (Types.mqh) ใช้ทั้ง CalcLot และ Open • compile 0/0 • risk-guardian PASS • qa-reviewer no BLOCKER • commit 64bbf9b • **รอ Owner รัน RiskSelfTest บน IC demo** (ชุด T-010 + ชุด B ใช้ helper ใหม่)

- **T-007 (2026-10-12):** CEMACrossSignal (Signals/EMACrossSignal.mqh) + ต่อเข้า SmartEA: S1 session, S2 ADX/DI, S3 ปิดสวนทางแล้วเข้าใหม่ถ้าผ่าน filter, S4 ATR SL (ไม่เข้าถ้า <2×spread), S5 2R, S6 time exit 23:30 (ตรวจทุก tick), S7 ศุกร์ • ไม่แตะ RiskManager/Config/Core (ไม่ต้องมี ADR 0003) • compile 0/0 • risk-guardian PASS • qa-reviewer no BLOCKER • commit 320854f • ema_v1.set + ema_v1.ini พร้อม รอ T-008
- qa MINOR ที่ยังไม่แก้: time exit ไม่ทำงานถ้าถือข้ามเที่ยงคืน (hhmm>=2330 เท่านั้น), Configure ไม่เตือนเมื่อ exit < session end, ไม่มี log DEBUG ตอน CopyBuffer ล้มเหลว

- **T-008 (2026-10-12): BLOCKED** — backtest ema_v1 in-sample 2023–2024 (Model=1) รันได้ report จริง: 440 ไม้, net −3,069 (ก่อนหัก commission ~−711), PF 0.85, DD equity 38%, win 33% • long PF 1.15 / short PF 0.65 • risk/ไม้ ≤1.0000% ✅, daily loss สูงสุด ~2.9% ✅, D4 reject 4 ครั้ง, journal สะอาด, ทุกไม้มี SL, ไม่มีไม้นอก session • **FAIL: 5 ไม้ข้าม 23:30** (2023.11.23, 2024.02.19, 2024.06.19, 2024.11.28, 2024.12.24 — น่าจะ S6 ไม่ปิดเมื่อไม่มีแท่ง/tick ที่ 23:30 ยังไม่ยืนยันในโค้ด) • TP≠2×SL 24 ไม้ (ต้องให้ strategy-dev ยืนยัน) • ไม่ได้ปรับพารามิเตอร์ • สรุป `data/reports/SmartEA_ema_v1.summary.md`
- **รอ Owner:** (1) ตัดสินแก้ S6 (bug logic ใน EMACrossSignal) และ spec v2 เพราะไม่มี edge ใน in-sample (short ขาดทุนหนัก) (2) ตรวจ visual 10 ไม้ (3) T-009 depends T-008 จึงยังไม่ทำ

- **T-011 (2026-10-12):** แก้ S6 — `CheckTimeExit` (SmartEA.mq5) ปิด position เมื่อเวลา >= InpTimeExitHHMM **หรือ** มี position ที่เปิดก่อน 00:00 server ของวันนี้ (`HeldFromBeforeToday`) • compile 0/0 • risk-guardian PASS • qa-reviewer no BLOCKER • commit 285cbf3 • qa MINOR ค้าง: ไม่ตรวจ return CloseAll ที่ call site, last_try ใช้ TimeCurrent คนละ clock, loop position 2 รอบ, spec S6 ควรเติม "หรือถือข้ามวัน"

## Blockers / Open questions
- ✅ RiskSelfTest หลัง T-010 บน IC demo: pass=70 fail=0 (2026-10-12)
- ✅ S9 = (b) holiday file `data/files/holidays.csv` (2023–2026) + กฎอัปเดตทุกปี (CLAUDE.md) → T-017 implement, T-018 ปี 2027 ภายใน 15 ธ.ค.
- ℹ️ Tester ini ต้องเขียน `Leverage=1:500` (รูปแบบ `Leverage=500` ถูกเพิกเฉย → core_smoke รันที่ 1:100) — แก้ ini ทุกไฟล์แล้ว 2026-10-12; ไม่กระทบผล G1.2 เพราะ 0 ไม้
- ℹ️ Model=1 ใช้ได้เฉพาะ smoke; gate Phase 3+ ต้อง real ticks (Model=4)
- ⚠️ IC demo balance = **500 USD** (จาก RiskSelfTest ชุด B) → ที่ risk 1% ทองเปิดไม้ไม่ได้ถ้า SL ≥ ~$5 (lot < 0.01) → T-006 ให้ Owner ตั้งเป็น 10,000 ก่อน Phase 5
- ✅ Spec EMA+ADX v1 APPROVED (S1–S8) — implement ได้หลัง `/gate` Phase 1 (T-007)
- ✅ D4–D7 อนุมัติตามข้อเสนอ (ADR 0002 addendum) → Claude Code implement ด้วย goal G1.3 • D7 = 20 points
- `InpMaxPositions` ถูกล็อกที่ 1 (ADR: หนึ่ง position ต่อ magic+symbol)
- Deferred MINOR: `InpMaxSpreadPoints` default 0 (ทองควรมีค่า?), CTrade log ตรง, `CountPositions` ซ้ำ 2 ที่, breaker ตรวจเฉพาะตอนแท่งใหม่
- ✅ IC demo = HEDGING (ยืนยันแล้ว)
- ✅ D7: `InpMaxSpreadPoints = 20` สำหรับ XAUUSD (อนุมัติ 2026-10-12)
- Phase 0–2 ใช้ MetaQuotes-Demo ต่อได้ แต่ตัวเลข risk/spec ทั้งหมดต้องอ้าง IC

## Pre-registered thresholds (Phase 5)
_กำหนดก่อนเริ่ม Phase 5 ห้ามแก้ระหว่างทาง_
