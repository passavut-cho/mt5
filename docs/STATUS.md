# Project Status

**Current phase:** 3 — Validation — Phase 2 gate ผ่าน 2026-10-12 (tag p2-done, Owner อนุมัติ)
**Last updated:** 2026-10-12
**validation_looks (2025):** 0 • **OOS (2026) looks:** 0
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

- **G1.3 implement แล้ว (2026-10-12):** D4 pre-trade check (`PreTradeOk` ใน CalcLot ปฏิเสธไม้ ไม่ลด lot) • D5 `CTradeManager::Open` ส่งครั้งเดียว + `retryable`, EA `OpenWithRetry` refresh ราคา→CanOpen→CalcLot ทุก attempt (สูงสุด 2 retry) และ log `actual_risk` หลัง fill • D6 netting fail closed + Warn ใน Init • CanOpen ปฏิเสธเมื่อ `TERMINAL_CONNECTED==0` นอก tester • breaker latch log Warn • D7 `InpMaxSpreadPoints=20` ใน `smoke.set`, `Leverage=500` ใน `smoke.ini`
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

- **T-012 (2026-10-12):** ตรวจ TP≠2×SL 24/440 ไม้ → ไม่ใช่บั๊ก: ต่างกัน 0.02 (2 tick) พอดีทุกไม้ จาก SL ปัดเข้าหา entry + TP ปัดใกล้สุดแยกกัน (fill = ask/bid ที่ใช้คำนวณ) • ไม่แก้โค้ด • `data/reports/docs/research/ema_v1.tp-check.md`

- **T-013 (2026-10-12):** `tests/python/report_stats.py` อ่าน report .htm (UTF-16) จับคู่ in/out แล้วหัก commission/lot → net/PF/DD/expectancy แยก long/short + รายปี • ทดสอบกับ ema_v1.htm ได้ net −3,780.30 (PF 0.82, 440 ไม้, comm −711.27) ตรง summary เดิม • เพิ่ม `OnTester()` ใน SmartEA.mq5 (net หลังหัก commission, หักเพิ่มเฉพาะเมื่อทั้ง run ไม่มี commission บันทึก, คืน −1e9 ถ้า HistorySelect ล้ม) • อัปเดต backtest-analyst.md ให้รันสคริปต์ทุกครั้ง • compile 0/0 • risk-guardian PASS • qa-reviewer no BLOCKER (MAJOR เรื่องหักซ้ำแก้แล้ว) • OnTester ยังไม่เคยรันจริงใน tester — จะเห็นผลที่ T-014

- **T-017 (2026-10-12):** Holiday filter S9 — `Signals/HolidayFilter.mqh` (CHolidayFilter) อ่าน `SmartEA\holidays.csv`, `#property tester_file`, input InpUseHolidayFilter/InpHolidayFile, บล็อกเฉพาะเปิดไม้ใหม่ (ไม่กระทบ exit), fail closed เมื่อไฟล์อ่านไม่ได้/ปีไม่อยู่ใน covered_years (Warn วันละครั้ง), log SKIP ทุกครั้ง • ไม่แตะ RiskManager/Config • compile 0/0 • risk-guardian PASS • qa-reviewer no BLOCKER • **ยังไม่ได้ยืนยันใน tester จริง** — T-014 ต้องเห็นบรรทัด "holiday filter: โหลด ... สำเร็จ" ใน journal ไม่งั้น EA ไม่เปิดไม้เลย • ค้าง MINOR: ไม่นับบรรทัด date เสีย, reload ล้มแล้วบล็อกทั้งวัน, SKIP log ทุกแท่งที่มีสัญญาณ

- **T-014 (2026-10-12): DONE** — ema_v1 in-sample ซ้ำ (พารามิเตอร์เดิม): 426 ไม้, เกณฑ์ spec ข้อ 9 ครบ (ยกเว้น visual) • 0 ไม้ข้าม 23:30 (5 วันเดิมถูก holiday filter ข้าม, journal โหลด holidays 54 วัน, SKIP 15 ครั้ง) • ไม่มีไม้นอก session/วันหยุด • ทุกไม้มี SL • risk/ไม้ สูงสุด 1.000% • daily loss สูงสุด 2.89% • OnTester net −3,777.38 ตรง report_stats.py • ข้อมูลให้ Owner (ไม่ใช่เกณฑ์ P2): net หลังหัก comm −3,777.38, PF 0.82, balance DD 42.3%; long PF 1.09 / short PF 0.62 • สรุป `data/reports/SmartEA_ema_v1.summary.md` (gitignored) • **รอ Owner: T-016 visual 10 ไม้ แล้ว /gate; ผลขาดทุนต้องพิจารณาก่อน Phase 3**

- **T-009 (2026-10-12): BLOCKED** — risktest Q1 2024 (DailyLoss 0.5%) → 0 ไม้: signal 56 ครั้ง, D4 ปฏิเสธ 55 ครั้ง เพราะ risk/ไม้ 1% (~97 USD) > งบรายวัน 0.5% (50 USD) • (2) D4 reject ยืนยันแล้ว, (1)(3)(4) ตรวจไม่ได้เพราะไม่มีไม้ • journal สะอาด • ข้อเสนอ T-019: InpRiskPct=0.25 คู่ DailyLoss 0.5 (รอ Owner) • สรุป `data/reports/SmartEA_ema_v1_risktest.summary.md`

- **T-009 รอบ 2 (2026-10-12): BLOCKED** — risktest (Risk 0.5/DailyLoss 1.5, Q1 2024, Model=1): 55 ไม้, net หลังหัก comm +199.43, PF 1.15 • (1) lot ตรงสูตรมือ 55/55, actual_risk ≤0.497% ✅ (3) ไม่มีวันเกิน 1.5% (สูงสุด 03-19 −1.466%) ✅ (4) ทุกไม้มี SL, journal สะอาด ✅ • **(2) ไม่มี D4 reject/breaker** (headroom ต่ำสุด +5.51) → reject path ยังไม่พิสูจน์ใน tester • CalcLot log เป็น DEBUG ไม่ขึ้นใน tester (ใช้ TRADE OPEN/RISK แทน) • รอ Owner: เลือกค่า test ที่บังคับ reject (DailyLoss ~0.75–1.0 คู่ Risk 0.5) แทน T-019 • สรุป `data/reports/SmartEA_ema_v1_risktest.summary.md`

- **T-009 รอบ 3 (2026-10-12): DONE** — risktest ทั้งปี 2024 (Risk 0.5 / DailyLoss 1.0, Model=1): 206 ไม้, lot ตรงสูตรมือ (3 ไม้ตัวอย่าง), actual_risk 0.48–0.50% • D4 pre-trade reject 6 ครั้ง (เช่น 2024.03.19 16:45 ขาดทุนสะสม 0.955% ก่อน reject) • ไม่มีวันขาดทุน realized ถึง 1.0% (สูงสุด 09.16 −0.992% หลังหัก comm, headroom ~$0.8) • 0/206 sl=0, journal สะอาด • net หลังหัก comm −800.96, PF 0.86 (ใช้ยืนยัน risk เท่านั้น) • สรุป `data/reports/SmartEA_ema_v1_risktest.summary.md`

## Phase 2 — GATE PASSED (2026-10-12)
- compile 0/0 (4 ไฟล์) • BOM ครบ 13 ไฟล์ • risk-guardian PASS • qa-reviewer no BLOCKER • backtest-analyst ผ่าน (426 ไม้ in-sample 2023–2024, spec ข้อ 9 ครบ, visual 10 ไม้ T-016)
- ⚠️ ข้อมูลให้ Phase 3: net หลังหัก comm −3,777.38, PF 0.82, balance DD 42.3%, ขาดทุนทั้ง 2 ปี • long PF 1.09 / short PF 0.62 → ต้องตัดสิน spec v2 • Model=1 เท่านั้น → Phase 3 ต้อง Model=4 + commission 7.0
- qa MAJOR ค้าง: `Evaluate()` คืน false → ข้าม S3 ในแท่งนั้น (S6 ยังปิดที่ 23:30)
- Owner อนุมัติ: default `InpMaxSpreadPoints` = 20 (ADR 0002 D7 แก้ไข, symbol อื่นต้องตั้งใน .set) — commit แยกหลัง gate

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

- **T-019 (2026-10-12): DONE** — สี EMA ใน visual tester: `src/Indicators/SmartEA_EMAPair.mq5` (fast น้ำเงิน / slow ส้ม), `TesterHideIndicators` + iCustom handle (display only) ใน CEMACrossSignal, `tester_indicator` ใน SmartEA.mq5 • compile 0/0 ทั้ง 4 ไฟล์ • risk-guardian PASS • qa-reviewer no BLOCKER • ema_v1 ซ้ำ: 426 ไม้ net −3,777.38 เท่าเดิม • commit ea8e5da • **รอ Owner ยืนยันใน visual run ว่าเห็น 2 เส้นคนละสี** (ถ้าไม่เห็น อาจต้อง ChartIndicatorAdd) • MINOR: EMA seed ต่างจาก iMA ช่วงแท่งแรกๆ, ต้อง compile indicator ก่อน backtest ใน clone ใหม่

- **T-021 (2026-10-12): BLOCKED** — ema_v1 Model=4 ช่วง 2023–2024: report History Quality 0% real ticks, journal `no real ticks, every tick generation used`; tick cache ของ IC มีเฉพาะ 2026-04..2026-10 (ห้ามรัน holdout) • ผลเทียบ Model=1: 426 ไม้เท่ากัน, SL/TP/exit ต่าง 0 ไม้, net หลังหัก comm −3,815.91 (vs −3,777.38), PF 0.81, DD 42.5%, actual_risk สูงสุด 1.000% • ไม่ใช่หลักฐาน real-tick ของ Phase 3 • **รอ Owner ตัดสิน:** (a) ยอมรับ every-tick สังเคราะห์สำหรับ calibration พร้อมบันทึกข้อจำกัด หรือ (b) นำเข้า tick 2023–2024 จากภายนอก (เช่น Dukascopy) เป็น custom symbol • เพิ่ม `tests/tester-ini/ema_v1_ticks.ini` • T-025 ที่ depends T-021 จึงยังรันไม่ได้ • สรุป `data/reports/SmartEA_ema_v1_ticks.summary.md` (gitignored)

- **T-023 (2026-10-12): DONE** — ตรวจ news.csv 64 แถวกับ BLS (NFP/CPI) และ federalreserve.gov (FOMC): ถูกต้องทุกแถว, verified → bls/fed • `docs/research/news-calendar.md` • T-024 ปลดล็อกแล้ว

- **T-024 (2026-10-12): DONE** — v2 feature flags (default = v1): V2a HTF (`CEMACrossSignal::ConfigureHTF`, H4 EMA50 shift 1, fail closed), V2b `Signals/NewsFilter.mqh` (news.csv, ±30m, fail closed, tester_file), V2c no-reverse + InpReentryBars, V2d InpUseOppositeExit • ema_v2a/b/c/d .set + .ini • **Regression: flags default → 426 ไม้ net −3,777.38 เท่า T-014** • smoke ทีละ flag (ไม่ใช่ผล E2–E5 ทางการ): v2a 183 ไม้, v2b 419 (news SKIP 9 ครั้ง, journal โหลด 64 เหตุการณ์), v2c 416, v2d 415 • compile 0/0 • risk-guardian PASS • qa-reviewer ไม่มี BLOCKER • ไม่แตะ RiskManager/Config • qa MINOR ค้าง: V2c `iBarShift`=-1 ทำให้ fail open, news retry เมื่อโหลดพลาดทั้งวัน, log HTF ใช้ %.2f ตายตัว, NewsFilter ไม่มี include guard
