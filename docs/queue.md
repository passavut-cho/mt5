# Work Queue — SmartEA

> **Cowork เขียน/จัดลำดับ task • CLI runner หยิบไปทำทีละ task • Owner ทำ task ที่ needs: owner**
> กติกาเต็มอยู่ใน `CLAUDE.md` หัวข้อ "Queue runner"

## รูปแบบ task
```
## T-NNN · P<phase> · <ชื่อสั้น>
status: READY | IN_PROGRESS | DONE <hash> | BLOCKED <เหตุผล> | WAIT_OWNER
needs: none | mt5-closed | owner | risk-edit
depends: T-xxx, T-yyy  (หรือ —)
goal: <เงื่อนไขจบที่ตรวจได้จาก transcript>
```
- `needs: none` — runner ทำได้เลย
- `needs: mt5-closed` — runner ทำได้เฉพาะเมื่อไม่มี process `terminal64` (Strategy Tester)
- `needs: owner` — ต้องให้ Phas ทำมือ (ลาก script ลง chart, ทดสอบ demo, ตัดสินใจ) → runner **ข้าม**
- `needs: risk-edit` — แตะ `RiskManager.mqh` / `Config/**` ซึ่งตั้ง `ask` ไว้ → รันได้เฉพาะ session แบบ interactive ที่ Owner นั่งอยู่ → runner headless **ข้าม**
- runner เลือก task แรก (บนลงล่าง) ที่ `status: READY`, ทุก `depends` เป็น DONE และ `needs` ทำได้

---

## T-001 · P1 · G1.3 ADR 0002 D4–D7
status: DONE 7e8c242
needs: risk-edit
depends: —
goal: ดู docs/goals.md G1.3

## T-002 · P1 · RiskSelfTest รอบ 2 บน IC demo
status: DONE (Owner 2026-10-12: pass=42 fail=0 → SELFTEST: PASS)
needs: owner
depends: T-001
goal: Phas ลาก RiskSelfTest ลง chart XAUUSD (IC demo) → `SELFTEST: PASS` แล้ววางผลให้ Cowork/Code บันทึกใน STATUS.md

## T-003 · P1 · G1.2 core smoke backtest 1 ปี
status: DONE 19bb831
needs: mt5-closed
depends: T-001
goal: สร้าง tests/tester-ini/core_smoke.ini (XAUUSD M15 2024.01.01-2024.12.31, Model=1, Leverage=1:500, Deposit=10000, ExpertParameters=core_smoke.set) + tests/setfiles/core_smoke.set (InpMaxSpreadPoints=20, ค่าอื่น default) แล้วรัน scripts/run_backtest.ps1 -Ini core_smoke จนได้ report ใน data/reports/ และไม่มีบรรทัด error/critical จาก SmartEA ใน tester journal; transcript ต้องแสดงบรรทัด "New day ... breaker ที่ equity<=" ของวันแรกที่ balance ต้นวัน = 10000; backtest-analyst สรุปลง data/reports/SmartEA_core_smoke.summary.md

## T-004 · P1 · /gate Phase 1
status: DONE c341365
needs: owner
depends: T-002, T-003
goal: Owner สั่ง `/gate` ใน session interactive — gate ต้องถามยืนยันก่อนเลื่อน Phase เสมอ

## T-005 · P2 · ร่าง spec EMA+ADX v1 (Cowork)
status: DONE (spec APPROVED 2026-10-12)
needs: owner
depends: —
goal: Cowork เติม docs/strategy/spec-ema-adx.md ให้ครบทุก ❓ พร้อมข้อเสนอ (รวม swap ทอง/การถือข้ามคืน) → Owner อนุมัติ → Status = APPROVED

## T-006 · P2 · Demo account balance ให้ตรงกับแผนทดสอบ
status: WAIT_OWNER
needs: owner
depends: —
goal: Owner รีเซ็ต/เปิด IC demo ใหม่ให้ balance = 10,000 USD, leverage 1:500, Raw, hedging (ตอนนี้ 500 USD → ทองเปิดไม่ได้เลยที่ SL ≥ $5 เพราะ lot < 0.01) แล้วแจ้ง Cowork

## T-007 · P2 · Implement EMA+ADX v1 ตาม spec
status: DONE 320854f
needs: none
depends: T-004
goal: สร้าง src/Include/Signals/EMACrossSignal.mqh (CEMACrossSignal : CSignalBase รวม ADX+DI filter และ ATR SL ตาม spec ข้อ 2–4) และต่อเข้า SmartEA.mq5 ด้วย input ตาม spec ข้อ 7 รวม session S1, opposite-cross exit/reverse S3, SL<2×spread ไม่เข้า S4, time exit 23:30 S6, Friday cutoff S7 — ห้ามแตะ src/Include/Core/RiskManager.mqh และ Config/; ถ้าต้องแก้ Core ส่วนอื่นให้บันทึกเหตุผลใน ADR 0003 ก่อน. สร้าง tests/setfiles/ema_v1.set (InpMaxSpreadPoints=20) + tests/tester-ini/ema_v1.ini (XAUUSD M15 2023.01.01-2024.12.31, Model=1, Leverage=1:500, Deposit=10000). จบเมื่อ transcript แสดง compile.ps1 PASS 0/0, risk-guardian VERDICT: PASS, qa-reviewer ไม่มี BLOCKER, STATUS.md อัปเดต, git push สำเร็จพร้อม hash

## T-008 · P2 · Backtest ema_v1 in-sample + วิเคราะห์
status: BLOCKED ไม่ผ่านเกณฑ์ spec ข้อ 9: 5 ไม้ข้าม 23:30, PF 0.85, DD 38% (ดู data/reports/SmartEA_ema_v1.summary.md)
needs: mt5-closed
depends: T-007
goal: รัน scripts/run_backtest.ps1 -Ini ema_v1 ได้ report ใน data/reports/; backtest-analyst สรุปลง data/reports/SmartEA_ema_v1.summary.md ตาม spec ข้อ 9 (จำนวนไม้ ≥ 100?, ไม่มีไม้นอก session, ไม่มีไม้ข้าม 23:30, ทุกไม้มี SL) พร้อม metric ครบ; ห้ามปรับพารามิเตอร์เพื่อให้ผลดีขึ้น — ถ้าไม่ผ่านเกณฑ์ให้ BLOCKED แล้วรายงาน

## T-009 · P2 · Integration test: risk ทำงานจริงเมื่อมีไม้
status: READY
needs: mt5-closed
depends: T-014
goal: สร้าง tests/setfiles/ema_v1_risktest.set (เหมือน ema_v1.set แต่ InpDailyLossPct=0.5 เพื่อบังคับให้ breaker ทำงานบ่อย — ค่านี้ต่ำกว่าเพดาน 3% จึงไม่ฝ่ากฎ) + tests/tester-ini/ema_v1_risktest.ini (ช่วง 2024.01.01-2024.03.31) แล้วรัน backtest; transcript ต้องแสดงจาก journal: (1) ตัวอย่างบรรทัด CalcLot ที่ lot = floor(risk/(loss_per_lot+7)) ถูกต้อง 3 ไม้ (คำนวณมือเทียบ) (2) บรรทัด daily loss breaker / D4 pre-trade ปฏิเสธไม้อย่างน้อย 1 ครั้ง (3) ไม่มีวันไหนที่ขาดทุนเกิน 0.5% + 1 ไม้ (4) ทุก deal มี SL; backtest-analyst สรุปลง data/reports/SmartEA_ema_v1_risktest.summary.md

## T-010 · P2 · ปรับการ normalize SL ให้ใช้ฟังก์ชันเดียว (minor จาก gate review P1)
status: DONE 64bbf9b (RiskSelfTest บน IC demo pass=70 fail=0 — 2026-10-12)
needs: risk-edit
depends: T-004
goal: RiskManager.CalcLot (RiskManager.mqh:404) ใช้ NormalizeDouble(digits) แต่ TradeManager ใช้ NormPrice (ปัดตาม tick_size) → ให้ทั้งสองชั้นใช้ helper เดียวที่ปัดตาม tick_size แบบ **ห่างจาก entry ไม่ได้** (ปัด SL เข้าหา entry หรือคำนวณ lot จาก SL ที่ normalize แล้วจริง) เพื่อไม่ให้ risk เกิน 1% บน symbol ที่ tick_size ≠ point; XAUUSD ที่ IC (tick 0.01 = point) ไม่เปลี่ยนผล. เพิ่ม test ใน RiskSelfTest ด้วย tick_size สมมุติ 0.05. จบเมื่อ compile 0/0, risk-guardian PASS, push สำเร็จพร้อม hash — ทำใน session interactive (ไฟล์ risk ตั้ง ask)

<!-- 2026-10-12 Cowork: ผลจาก T-008 BLOCKED — แยกเป็นงานแก้ระบบ (ไม่แตะพารามิเตอร์กลยุทธ์) -->

## T-011 · P2 · แก้บั๊ก S6: position ข้ามวันไม่ถูกปิด
status: DONE 285cbf3
needs: none
depends: —
goal: สาเหตุ (Cowork ตรวจโค้ด): `CEMACrossSignal::TimeExitDue()` (EMACrossSignal.mqh:181) เช็คแค่ `hour*100+min >= 2330` ของ "วันนี้" — วันตลาดปิดเร็ว (Thanksgiving, Juneteenth, Christmas Eve, Presidents Day) ไม่มี tick หลัง 23:30 พอ tick แรกของวันถัดไป (~01:00) ค่า 0100 < 2330 จึงไม่ปิด. แก้: time exit ต้องเป็นจริงเมื่อ (a) เวลา server >= InpTimeExitHHMM **หรือ** (b) มี position ของ EA ที่เปิดก่อน 00:00 server ของวันนี้ → ปิดทันทีที่ tick แรก. ห้ามแก้พารามิเตอร์กลยุทธ์อื่น. จบเมื่อ compile 0/0, qa-reviewer ไม่มี BLOCKER, push สำเร็จพร้อม hash

## T-012 · P2 · ตรวจ 24 ไม้ที่ TP ≠ 2 × SL
status: DONE 64be455 (ผล: docs/research/ema_v1.tp-check.md — data/reports ถูก gitignore)
needs: none
depends: —
goal: อ่าน data/reports/SmartEA_ema_v1.htm + โค้ด แล้วอธิบายสาเหตุที่ 24/440 ไม้มี |TP − 2×SL| > 0.02 (สมมุติฐาน: SL/TP คิดจากราคาอ้างอิงตอนคำนวณ แต่ fill ต่าง หรือผลจาก T-010 ที่ปัด SL เข้าหา entry แต่ไม่ได้ปัด TP ให้สอดคล้อง). ถ้าเป็นบั๊ก → แก้ให้ TP = entry_จริง ± 2 × |entry_จริง − SL| บน tick grid (ไม่แตะ RiskManager — ถ้าต้องแตะให้ BLOCKED). บันทึกผลลง data/reports/SmartEA_ema_v1.tp-check.md. จบเมื่อ compile 0/0 (ถ้าแก้โค้ด), push สำเร็จพร้อม hash

## T-013 · P2 · หัก commission ในผลวิเคราะห์ backtest
status: DONE 27a08f2
needs: none
depends: —
goal: Strategy Tester ไม่หัก commission ของ IC Raw (คอลัมน์ Commission = 0) → สร้าง tests/python/report_stats.py ที่อ่าน report .htm ของ MT5 (UTF-16) แล้วคำนวณ net/PF/DD/expectancy **หลังหัก InpCommissionPerLot × volume ต่อไม้** + แยก long/short + รายปี, ออกเป็น markdown; และเพิ่ม `OnTester()` ใน SmartEA.mq5 คืนค่า net หลังหัก commission (ใช้เป็นเกณฑ์ optimize ใน Phase 4). ทดสอบกับ SmartEA_ema_v1.htm ต้องได้ net ≈ −3,780 (ตาม summary เดิม). backtest-analyst ต้องใช้สคริปต์นี้ทุกครั้งหลังจากนี้ (อัปเดต .claude/agents/backtest-analyst.md). จบเมื่อ compile 0/0, push สำเร็จพร้อม hash

## T-014 · P2 · รัน ema_v1 in-sample ซ้ำหลังแก้ระบบ
status: READY
needs: mt5-closed
depends: T-011, T-012, T-013, T-015, T-017
goal: เหมือน T-008 ทุกข้อ (พารามิเตอร์เดิมทั้งหมด ห้ามปรับ) + ใช้ tests/python/report_stats.py รายงาน metric หลังหัก commission. เกณฑ์ spec ข้อ 9 (ตามที่ Owner อนุมัติใน S9). **PF/DD ไม่ใช่เกณฑ์ Phase 2** — รายงานเป็นข้อมูลให้ Owner เท่านั้น. ถ้าเกณฑ์ข้อ 9 ครบยกเว้นข้อ visual → DONE แล้วให้ T-016 ต่อ

## T-015 · P2 · Owner ตัดสิน S9 (วันตลาดปิดเร็ว)
status: DONE (Owner 2026-10-12: S9 = (b) + กฎอัปเดตวันหยุดทุกปี)
needs: owner
depends: —
goal: ดู docs/strategy/spec-ema-adx.md ข้อ 11 แล้วตอบ S9

## T-016 · P2 · Owner ตรวจ visual 10 ไม้
status: WAIT_OWNER
needs: owner
depends: T-014
goal: Owner เปิด Strategy Tester แบบ Visual กับ ema_v1 แล้วสุ่มดู 10 ไม้ (Cowork จะเลือกวันที่ให้จาก report ของ T-014) ว่า entry/SL/TP/exit ตรง spec ข้อ 2–4

## T-017 · P2 · Holiday filter (spec S9)
status: READY
needs: none
depends: T-011
goal: implement ตาม spec ข้อ 11 "S9 — Owner อนุมัติ": อ่าน MQL5\Files\SmartEA\holidays.csv (ข้ามบรรทัด #, parse `# covered_years:`), `#property tester_file "SmartEA\\holidays.csv"`, input InpUseHolidayFilter/InpHolidayFile, ไม่เปิดไม้ใหม่ในวันที่อยู่ในไฟล์, fail closed เมื่อปีไม่อยู่ใน covered_years หรืออ่านไฟล์ไม่ได้ (Warn วันละครั้ง). ใส่ logic ใน Signals/ หรือ Expert — ห้ามแตะ RiskManager/Config. log ทุกครั้งที่ข้ามสัญญาณเพราะวันหยุด. จบเมื่อ compile 0/0, qa-reviewer ไม่มี BLOCKER, risk-guardian PASS, push สำเร็จพร้อม hash

## T-018 · ทุกปี · อัปเดต holidays.csv สำหรับปี 2027
status: WAIT_OWNER
needs: owner
depends: —
goal: ภายใน 2026-12-15: Cowork ดึง CME holiday calendar 2027 (COMEX metals) + ตรวจกับประกาศ IC → เพิ่มแถว 2027 + covered_years ใน data/files/holidays.csv → Owner รับทราบ → Code commit `data: holidays 2027` (สร้าง T ใหม่ของปีถัดไปทุกครั้งที่ปิดงานนี้)
