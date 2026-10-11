# Project Status

**Current phase:** 1 — Core Framework (เริ่มตามคำสั่ง Owner 2026-10-12 ขณะที่ P0 gate ยังเหลือ 3 ข้อด้านล่าง)
**Last updated:** 2026-10-12
**Broker เป้าหมาย:** IC Markets (Raw Trading Ltd, FSA Seychelles) — demo บัญชี Raw

## Phase 0 — ค้าง (ต้องปิดก่อน /gate ของ Phase 1)
- [x] `scripts/setup.ps1` — terminal D0E8209F77C8CF37AD8BF550E51FF075 (MetaQuotes-Demo)
- [x] `/backtest smoke` → report OK: XAUUSD M15 2024-01..03, 1-min OHLC, quality 100%, 5777 bars, 0 trades
- [ ] `compile.ps1` PASS หลังแก้ `#property version` (ยังไม่ได้ยืนยัน)
- [ ] live guard บน demo chart → `live guard: OK (DEMO)`
- [ ] `git init` + commit `[P0] bootstrap`

## Phase 1 — Done
- Research IC Markets → `docs/research/broker-icmarkets.md`
- ADR 0002 Core framework (interface + flow) — Accepted → `docs/decisions/0002-core-framework.md`
- `src/Scripts/SymbolSpecDump.mq5` (ยังไม่ได้ compile)
- `setup.ps1` เพิ่ม junction `MQL5\Files\SmartEA → data\files`

## Phase 1 — Implemented (2026-10-11, ยังไม่ผ่าน gate)
- Core ตาม ADR 0002: Types, Logger, BarClock, SignalBase, SignalNone, RiskManager, TradeManager (+ LiveGuard ย้ายจาก SmartEA.mq5), ต่อเข้า SmartEA.mq5
- `src/Scripts/RiskSelfTest.mq5`, `tests/setfiles/core-signalnone.set`, `tests/tester-ini/core-signalnone.ini`
- ⚠️ **ยังไม่ได้ compile** (session นี้เป็น Linux ไม่มี MetaEditor) — Phas ต้องรัน `compile.ps1` แล้ววางผลกลับมา
- risk-guardian รอบ 1 = REJECT → แก้แล้ว (Owner อนุมัติ 2026-10-11): เพดาน max positions = 1, balance ต้นวันคำนวณไม่ได้ = fail-closed; ต้องส่งตรวจซ้ำหลัง compile
- qa-reviewer: รอผล

## Phase 1 — Next
1. ✅ D1–D3 ตัดสินแล้ว: daily loss ทั้งบัญชี / หยุดเปิดไม้ใหม่ / นับ commission (default 7.0)
2. ติดตั้ง IC Markets MT5 + login demo Raw → รัน `setup.ps1` ใหม่ (เลือก terminal ของ IC)
3. compile + รัน `SymbolSpecDump` บน XAUUSD (IC) → ได้ `data/files/specs_<server>.tsv`
4. Claude Code: implement Core ตาม ADR 0002 (Types, Logger, BarClock, SignalBase, SignalNone, RiskManager, TradeManager) + `RiskSelfTest.mq5`
5. backtest smoke 1 ปีด้วย CSignalNone, risk-guardian + qa-reviewer → `/gate`

## Blockers / Open questions
- ประเภทบัญชี IC demo (hedging/netting) → จะรู้จาก SymbolSpecDump
- Phase 0–2 ใช้ MetaQuotes-Demo ต่อได้ แต่ตัวเลข risk/spec ทั้งหมดต้องอ้าง IC

## Pre-registered thresholds (Phase 5)
_กำหนดก่อนเริ่ม Phase 5 ห้ามแก้ระหว่างทาง_
