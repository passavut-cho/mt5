# Development Phases — SmartEA

> กติกา: ทำทีละ Phase • ห้ามข้าม gate • จบ Phase ด้วย `/gate` • ทุก Phase commit ด้วย prefix `[P<n>]`
> สถานะปัจจุบันอยู่ที่ `docs/STATUS.md`

---

## Phase 0 — Bootstrap
**งาน**
- [x] scaffold folders, CLAUDE.md, agents, commands, settings.json
- [x] `scripts/setup.ps1` (หา terminal + สร้าง junction + config.local.ps1)
- [x] `scripts/compile.ps1`, `scripts/run_backtest.ps1`
- [x] `SmartEA.mq5` ว่าง ที่มี live guard
- [ ] ผู้ใช้รัน `scripts/setup.ps1` บนเครื่อง
- [ ] `git init` + commit แรก

**Exit gate**
- `compile.ps1` → `0 errors, 0 warnings`
- ลาก SmartEA ลง chart บัญชี demo → log `live guard: OK (DEMO)`, ไม่มีการเทรด
- รัน `run_backtest.ps1 -Ini smoke` ได้ report ใน `data/reports/`

## Phase 1 — Core Framework
**งาน** (เรียก `mql5-architect` ทำ ADR + interface ก่อน)
- `CLogger` — level (DEBUG/INFO/WARN/ERROR), prefix ด้วย magic+symbol, ปิด DEBUG ใน tester ได้
- `CRiskManager` — lot จาก %risk + ระยะ SL, normalize volume (ปัดลง), daily loss breaker (balance ต้นวัน server time), max open positions
- `CTradeManager` — ห่อ `CTrade`: open พร้อม SL/TP + magic, close, modify, จัดการ retcode, filling mode อัตโนมัติ
- `CSignalBase` — abstract: `Init()`, `Deinit()`, `Evaluate()` → คืน `SignalIntent { dir, slPoints, tpPoints, reason }`
- `CSignalNone` — signal ที่ไม่ทำอะไร สำหรับ smoke test

**Exit gate**
- compile สะอาด
- backtest ด้วย `CSignalNone` 1 ปี ผ่านโดยไม่มี error ใน journal
- unit-check ของ RiskManager ผ่าน script `Scripts/SmartEA/RiskSelfTest.mq5` (คำนวณ lot หลายกรณี: XAUUSD, EURUSD, SL แคบ/กว้าง, ต่ำกว่า VOLUME_MIN)
- `risk-guardian` PASS + `qa-reviewer` ไม่มี blocker

## Phase 2 — Strategy v1 (EMA 9/21 + ADX filter)
**งาน**
- เติม `docs/strategy/spec-ema-adx.md` ให้ครบทุกหัวข้อ → **ผู้ใช้อนุมัติ spec** ก่อนเขียนโค้ด
- implement `CEMACrossSignal` + `CADXFilter` (strategy-dev)
- `.set` + `.ini` สำหรับ XAUUSD M15

**Exit gate**
- backtest XAUUSD M15 2 ปี (in-sample เท่านั้น — กันช่วงหลังไว้เป็น out-of-sample ตั้งแต่ตอนนี้)
- `backtest-analyst` รายงาน metric ครบ (ยังไม่ต้องกำไร — gate นี้คือ "ระบบทำงานถูกต้องตาม spec")
- สุ่มตรวจ 10 ไม้ในกราฟ visual mode ว่าเข้า/ออกตรง spec

## Phase 3 — Validation
**งาน**
- ทดสอบด้วย **real ticks (Model=4)** + spread/commission สมจริง
- walk-forward (`tests/python/walk_forward.py`): แบ่ง train / validate / test ไม่ทับกัน
- หลาย symbol / ช่วงเวลา (trend vs sideway)
- sensitivity: ขยับ input หลัก ±20% → ผลต้องไม่พลิกจากกำไรเป็นขาดทุนหนัก

**Exit gate**: PF ≥ 1.3 • MaxDD ≤ 20% • trades ≥ 100 • ไม่มีไม้/เดือนเดียวทำกำไร > 30%

## Phase 4 — Optimization (ระวัง overfit)
**งาน**: optimize ด้วย parameter range แคบ, จำนวน parameter ที่ optimize ≤ 3, เลือก "ที่ราบ" ไม่ใช่ "ยอดเขา"
**Exit gate**: ผล out-of-sample ต่างจาก in-sample ไม่เกิน 30% (PF และ DD)

## Phase 5 — Demo Forward Test
**งาน**: รันบัญชี demo ≥ 4 สัปดาห์ (หรือ ≥ 30 ไม้), log ทุกไม้, เทียบกับ backtest ช่วงเดียวกัน
**Exit gate**: slippage เฉลี่ย, จำนวนไม้, win rate ไม่เบี่ยงจาก backtest เกินที่กำหนดไว้ล่วงหน้าใน STATUS.md

## Phase 6 — หยุดรอคำตัดสินมนุษย์
⛔ Claude ห้ามเปิด `InpAllowLive`, ห้ามแนะนำ/เตรียมการขึ้น live เอง — เป็นการตัดสินใจของผู้ใช้เท่านั้น
