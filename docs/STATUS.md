# Project Status

**Current phase:** 1 — Core Framework (เริ่มตามคำสั่ง Owner 2026-10-12 ขณะที่ P0 gate ยังเหลือ 3 ข้อด้านล่าง)
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
- qa-reviewer MINOR ที่ยังไม่แก้ (deferred): SL normalize digits vs tick size, `actual_risk` ใช้ lot ที่ขอ (ไม่ใช่ `ResultVolume`) และไม่มี fallback ถ้า `ResultPrice()==0`, เคสขอบ D4 พึ่ง floating point, `intent.reason` เป็น order comment ควร ≤31 ตัวอักษร, `CountPositions` ซ้ำ 2 ที่, test D4/D6 ยังไม่ครอบคลุม end-to-end (CalcLot/ActualRisk/netting)

## Phase 1 — Next
1. 🔄 RiskSelfTest บน IC demo — **ต้องรันซ้ำ** (มี test D4 + เงื่อนไขชุด B เข้มขึ้น) ครั้งก่อน `SELFTEST: PASS` เป็นของโค้ดก่อน G1.3
1b. ✅ SymbolSpecDump v1.10 → `data/files/specs_ICMarketsSC-Demo.tsv` (HEDGING, 100 oz, spread p95 11 pts) — สรุปใน docs/research/broker-icmarkets.md
2. ✅ SmartEA บน IC demo → `live guard: OK (DEMO)`
2b. ✅ G1.3 (D4–D6 + connected guard) — ดูด้านบน
3. G1.2: backtest 1 ปีด้วย CSignalNone (`core_smoke.ini`/`.set`) — ต้องสร้างไฟล์ก่อน (ยังไม่มี) และปิด MT5 ก่อนรัน • ต้องตั้ง hedging ใน tester ไม่งั้น netting guard จะกันไม้ซ้ำ
4. ตรวจ journal: บรรทัด `New day ... breaker ที่ equity<=` ต้องมีค่าสมเหตุสมผล (day 1 ใน tester)
5. `/gate`

## Blockers / Open questions
- ✅ D4–D7 อนุมัติตามข้อเสนอ (ADR 0002 addendum) → Claude Code implement ด้วย goal G1.3 • D7 = 20 points
- `InpMaxPositions` ถูกล็อกที่ 1 (ADR: หนึ่ง position ต่อ magic+symbol)
- Deferred MINOR: SL normalize 3 จุด, `InpMaxSpreadPoints` default 0 (ทองควรมีค่า?), CTrade log ตรง, `CountPositions` ซ้ำ 2 ที่, breaker ตรวจเฉพาะตอนแท่งใหม่
- ✅ IC demo = HEDGING (ยืนยันแล้ว)
- ✅ D7: `InpMaxSpreadPoints = 20` สำหรับ XAUUSD (อนุมัติ 2026-10-12)
- Phase 0–2 ใช้ MetaQuotes-Demo ต่อได้ แต่ตัวเลข risk/spec ทั้งหมดต้องอ้าง IC

## Pre-registered thresholds (Phase 5)
_กำหนดก่อนเริ่ม Phase 5 ห้ามแก้ระหว่างทาง_
