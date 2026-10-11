# Project Status

**Current phase:** 1 — Core Framework (เริ่มตามคำสั่ง Owner 2026-10-12 ขณะที่ P0 gate ยังเหลือ 3 ข้อด้านล่าง)
**Last updated:** 2026-10-12
**Broker เป้าหมาย:** IC Markets (Raw Trading Ltd, FSA Seychelles) — demo บัญชี Raw

## Phase 0 — ค้าง (ต้องปิดก่อน /gate ของ Phase 1)
- [x] `scripts/setup.ps1` — terminal D0E8209F77C8CF37AD8BF550E51FF075 (MetaQuotes-Demo)
- [x] `/backtest smoke` → report OK: XAUUSD M15 2024-01..03, 1-min OHLC, quality 100%, 5777 bars, 0 trades
- [x] `compile.ps1` PASS — SmartEA + SymbolSpecDump: 0 errors, 0 warnings (IC terminal, 2026-10-12)
- [ ] live guard บน demo chart → `live guard: OK (DEMO)`
- [ ] `git init` + commit `[P0] bootstrap`

## Phase 1 — Done
- Research IC Markets → `docs/research/broker-icmarkets.md`
- ADR 0002 Core framework (interface + flow) — Accepted → `docs/decisions/0002-core-framework.md`
- `src/Scripts/SymbolSpecDump.mq5` — compile 0/0
- `setup.ps1` เพิ่ม junction `MQL5\Files\SmartEA → data\files`

- Core implement ตาม ADR 0002 (2026-10-12): `src/Include/Core/{Types,Logger,BarClock,SignalBase,RiskManager,TradeManager}.mqh`, `Signals/SignalNone.mqh`, ต่อเข้า `SmartEA.mq5`, `src/Scripts/RiskSelfTest.mq5`
- compile 0/0 ทั้ง SmartEA, RiskSelfTest, SymbolSpecDump • BOM ครบ • risk-guardian PASS (หลังแก้ 2 finding) • qa-reviewer no BLOCKER (หลังแก้ day-start balance ไม่นับ deposit)
- `smoke.set` ระบุ input ครบ

## Phase 1 — Next
1. Phas: ลาก `RiskSelfTest` ลง chart (IC demo) → ต้องได้ `SELFTEST: PASS` (รัน tester ไม่ได้เพราะเป็น script) แล้ววางผลกลับ
2. Phas: ลาก SmartEA ลง demo chart → `live guard: OK (DEMO)` (ปิดข้อ P0 ค้างด้วย)
3. G1.2: backtest 1 ปีด้วย CSignalNone (`core_smoke.ini`/`.set`) — ต้องปิด MT5 ก่อน
4. ตรวจ journal: บรรทัด `New day ... breaker ที่ equity<=` ต้องมีค่าสมเหตุสมผล (day 1 ใน tester)
5. `/gate`

## Blockers / Open questions
- **Owner ตัดสินใจ (risk logic — Claude ไม่แก้เอง):** (#3) breaker เช็กแค่ equity ปัจจุบัน อาจเลย 3% ได้ ~1 ไม้ — ต้องการ `equity − risk_money ≤ limit` ไหม • (#4) lot/SL เพี้ยนเล็กน้อยตอน retry/slippage • (#5) netting: market order รวมกับ position ต่าง magic
- `InpMaxPositions` ถูกล็อกที่ 1 (ADR: หนึ่ง position ต่อ magic+symbol)
- Deferred MINOR: SL normalize 3 จุด, `InpMaxSpreadPoints` default 0 (ทองควรมีค่า?), CTrade log ตรง, `CountPositions` ซ้ำ 2 ที่, breaker ตรวจเฉพาะตอนแท่งใหม่
- ประเภทบัญชี IC demo (hedging/netting) → จะรู้จาก SymbolSpecDump
- Phase 0–2 ใช้ MetaQuotes-Demo ต่อได้ แต่ตัวเลข risk/spec ทั้งหมดต้องอ้าง IC

## Pre-registered thresholds (Phase 5)
_กำหนดก่อนเริ่ม Phase 5 ห้ามแก้ระหว่างทาง_
