# Project Status

**Current phase:** 0 — Bootstrap
**Last updated:** 2026-10-12

## Done
- Scaffold โครงสร้าง, CLAUDE.md, 5 agents, 4 slash commands, settings.json
- scripts: setup.ps1, compile.ps1, run_backtest.ps1
- SmartEA.mq5 skeleton + live guard
- ADR 0001 (โครงสร้างโปรเจกต์)

## Next
1. ✅ `scripts/setup.ps1` — terminal D0E8209F77C8CF37AD8BF550E51FF075
2. `/compile` → ต้องได้ 0 errors, 0 warnings
3. ✅ `/backtest smoke` → report OK (2026-10-12): XAUUSD M15 2024-01..03, 1-min OHLC, history quality 100%, 5777 bars, 0 trades (ตามคาด)
4. `git init` + commit `[P0] bootstrap`
5. `/gate`

## Blockers / Open questions
- ตอนนี้ใช้ server `MetaQuotes-Demo` (Build 6255) — ไม่ใช่ broker จริง; spec ของ XAUUSD (spread, contract size, stops level, commission) อาจต่างจาก broker ที่จะใช้จริง → ต้องตัดสินใจก่อน Phase 3
- ยังไม่รู้ประเภทบัญชี (netting หรือ hedging) → ต้องใช้ใน Phase 1 (TradeManager)

## Pre-registered thresholds (Phase 5)
_กำหนดก่อนเริ่ม Phase 5 ห้ามแก้ระหว่างทาง_
