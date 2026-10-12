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
**งาน** (ADR 0002 = interface + flow — implement ตามนั้น)
- `SymbolSpecDump.mq5` — ดึง spec ของ broker จริงมาใช้ตรวจสูตร (เสร็จแล้ว รอ compile)
- `Types.mqh` (SSignalIntent), `BarClock.mqh` (new bar detection)
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
> **แก้ไข 2026-10-12 (Cowork เสนอ, Owner อนุมัติพร้อม gate P2):** v1 ไม่มี edge ใน in-sample (PF หลังหัก comm 0.82) → Phase 3 แบ่งเป็น 3 ขั้น และ **ห้ามแตะ validation (2025) จนผ่านขั้น 3b**
> - **3a Calibration** — รัน v1 in-sample ด้วย Model=4 (real ticks) เทียบ Model=1 → รู้ว่า 1-min OHLC คลาดเท่าไร (ข้อมูลเท่านั้น)
> - **3b Strategy research (in-sample 2023–2024 เท่านั้น)** — spec v2 จาก `docs/strategy/v2-options.md`; ทุก variant ต้องเขียน hypothesis ก่อนรัน และบันทึกผลทุกตัว (รวมที่แพ้) ใน `docs/strategy/experiments.md` • จำกัด ≤ 6 variants ต่อรอบ
> - **Pre-validation bar** (ต้องผ่านก่อนเปิด 2025): in-sample **Model=1** หลังหัก commission **PF ≥ 1.1 และ PF ภายใต้ cost stress +20 points ≥ 1.0, trades ≥ 100, MaxDD ≤ 25%**
> - **Real ticks (R1–R3, 2026-10-12):** IC มี real ticks ทองเฉพาะ 2026-04→ — Phase 3 ใช้ Model=1 + stress • real ticks ใช้ใน Phase 4 (OOS 2026-04→09 รันครั้งเดียว) + Phase 5 demo • ยังไม่นำเข้า tick data ภายนอก
> - **3c Validation** — เปิด 2025 ได้เฉพาะ variant ที่ผ่าน bar • **ทุกครั้งที่รันบน 2025 ต้องบวก `validation_looks` ใน STATUS.md** • ถ้า looks > 3 ให้ถือว่า 2025 ปนเปื้อน ต้องใช้ OOS 2026 ตัดสินแทน (และ OOS ยังห้ามแตะจน Phase 4)

**งาน (3c)**
- ทดสอบด้วย Model=1 + cost stress (real ticks ไม่มีในช่วงนี้ — ดู R1–R3) + commission
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
