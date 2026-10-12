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
status: DONE 4e86b35 (รอบ 3: D4 reject 6 ครั้ง, ไม่มีวันขาดทุนถึง 1.0%)
needs: mt5-closed
depends: T-014
goal: [รอบ 3 — แก้โดย Cowork 2026-10-12] รอบ 1: daily 0.5% < risk 1% → D4 ปฏิเสธทุกไม้ • รอบ 2: risk 0.5% / daily 1.5% ช่วง 3 เดือน → risk จริงต่อไม้ ~0.48% จึงขาดทุน 3 ไม้แล้วยังไม่ถึง 1.5% ไม่มี reject เลย (วัน 2024.03.19 เหลือ headroom 5.51) • **รอบ 3: ใช้ tests/setfiles/ema_v1_risktest.set ที่ Cowork แก้แล้ว (InpRiskPct=0.5, InpDailyLossPct=1.0) และ ini ช่วง 2024.01.01–2024.12.31** — ห้ามแก้ค่าเพิ่ม: ขาดทุน 2 ไม้ (~0.96%) แล้ว D4 ต้องปฏิเสธไม้ถัดไปในวันนั้น. รัน backtest แล้ว transcript ต้องแสดงจาก journal: (1) ตัวอย่าง TRADE OPEN + TRADE RISK 3 ไม้ที่ lot = floor(risk/(loss_per_lot+7)/0.01)×0.01 ถูกต้อง (คำนวณมือเทียบ) (2) บรรทัด `TRADE REJECT ... D4 pre-trade` หรือ daily loss breaker อย่างน้อย 1 ครั้ง พร้อมยืนยันว่าเป็นวันที่ขาดทุนสะสมใกล้ 1% จริง (3) ไม่มีวันไหนขาดทุน realized เกิน 1.0% ของ balance ต้นวัน (ยกเว้น slippage/gap ต้องรายงานเป็นรายวัน) (4) ทุก entry มี SL; ใช้ report_stats.py; backtest-analyst สรุปลง data/reports/SmartEA_ema_v1_risktest.summary.md (เขียนทับรอบก่อน). ถ้าทั้งปีไม่มี reject เลย → BLOCKED พร้อมรายงานวันที่ headroom น้อยสุด 3 วัน

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
status: DONE 5eeca53
needs: mt5-closed
depends: T-011, T-012, T-013, T-015, T-017
goal: เหมือน T-008 ทุกข้อ (พารามิเตอร์เดิมทั้งหมด ห้ามปรับ) + ใช้ tests/python/report_stats.py รายงาน metric หลังหัก commission. เกณฑ์ spec ข้อ 9 (ตามที่ Owner อนุมัติใน S9). **PF/DD ไม่ใช่เกณฑ์ Phase 2** — รายงานเป็นข้อมูลให้ Owner เท่านั้น. ถ้าเกณฑ์ข้อ 9 ครบยกเว้นข้อ visual → DONE แล้วให้ T-016 ต่อ

## T-015 · P2 · Owner ตัดสิน S9 (วันตลาดปิดเร็ว)
status: DONE (Owner 2026-10-12: S9 = (b) + กฎอัปเดตวันหยุดทุกปี)
needs: owner
depends: —
goal: ดู docs/strategy/spec-ema-adx.md ข้อ 11 แล้วตอบ S9

## T-016 · P2 · Owner ตรวจ visual 10 ไม้
status: DONE (2026-10-12: journal 10/10 + Owner screenshot ยืนยัน EMA cross — data/reports/SmartEA_ema_v1.visual-check.md)
needs: owner
depends: T-014
goal: Owner เปิด Strategy Tester แบบ Visual กับ ema_v1 แล้วดู 10 ไม้นี้ (Cowork สุ่มจาก report T-014, seed 42, แยกตามวิธีปิด) ว่า entry/SL/TP/exit ตรง spec ข้อ 2–4 — ตอบ ✅/❌ รายไม้
| # | เปิด (server) | ฝั่ง | lot | entry | ปิด | exit | ตรวจอะไร |
|---|---|---|---|---|---|---|---|
| 1 | 2023.01.19 12:45 | sell | 0.27 | 1907.72 | 14:36 @1911.25 | SL | EMA9 ตัดลง EMA21 ที่แท่ง 12:30, ADX≥25, −DI>+DI |
| 2 | 2023.04.26 18:30 | sell | 0.14 | 1995.36 | 23:30 @1989.60 | time exit | ปิดตอน 23:30 พอดี |
| 3 | 2023.05.03 16:45 | buy | 0.25 | 2018.11 | 16:59 @2014.05 | SL | SL = ATR×1.5 |
| 4 | 2023.05.10 21:30 | buy | 0.24 | 2031.06 | 23:30 @2031.14 | time exit | เข้า 21:30 ยังอยู่ใน session (<23:00) |
| 5 | 2023.05.31 10:45 | sell | 0.29 | 1956.77 | 14:45 @1959.63 | opposite cross | มี cross ขึ้นที่แท่ง 14:30 แต่ไม่กลับฝั่ง (filter ไม่ผ่าน?) |
| 6 | 2023.08.17 17:45 | sell | 0.20 | 1895.36 | 20:02 @1887.23 | TP | TP = 2×SL |
| 7 | 2023.08.24 12:45 | sell | 0.38 | 1919.68 | 15:06 @1915.20 | TP | lot ใหญ่ (SL แคบ) |
| 8 | 2023.10.06 15:30 | sell | 0.34 | 1819.46 | 15:30:40 @1814.96 | TP | **วัน NFP — เข้าตรงเวลาข่าว ถึง TP ใน 40 วินาที** |
| 9 | 2024.07.09 13:15 | buy | 0.23 | 2363.98 | 14:08 @2360.67 | SL | |
| 10 | 2024.11.01 11:00 | sell | 0.20 | 2749.70 | 11:15 @2752.54 | opposite cross | cross สวนภายใน 1 แท่ง (เข้า 11:00 ปิด 11:15) |

## T-017 · P2 · Holiday filter (spec S9)
status: DONE 5259387
needs: none
depends: T-011
goal: implement ตาม spec ข้อ 11 "S9 — Owner อนุมัติ": อ่าน MQL5\Files\SmartEA\holidays.csv (ข้ามบรรทัด #, parse `# covered_years:`), `#property tester_file "SmartEA\\holidays.csv"`, input InpUseHolidayFilter/InpHolidayFile, ไม่เปิดไม้ใหม่ในวันที่อยู่ในไฟล์, fail closed เมื่อปีไม่อยู่ใน covered_years หรืออ่านไฟล์ไม่ได้ (Warn วันละครั้ง). ใส่ logic ใน Signals/ หรือ Expert — ห้ามแตะ RiskManager/Config. log ทุกครั้งที่ข้ามสัญญาณเพราะวันหยุด. จบเมื่อ compile 0/0, qa-reviewer ไม่มี BLOCKER, risk-guardian PASS, push สำเร็จพร้อม hash

## T-018 · ทุกปี · อัปเดต holidays.csv สำหรับปี 2027
status: WAIT_OWNER
needs: owner
depends: —
goal: ภายใน 2026-12-15: Cowork ดึง CME holiday calendar 2027 (COMEX metals) + ตรวจกับประกาศ IC → เพิ่มแถว 2027 + covered_years ใน data/files/holidays.csv → Owner รับทราบ → Code commit `data: holidays 2027` (สร้าง T ใหม่ของปีถัดไปทุกครั้งที่ปิดงานนี้)

## T-020 · P2 · แก้ design T-009: ลด InpRiskPct ใน risktest.set (เดิมใช้เลข T-019 ซ้ำ — Cowork เปลี่ยนเลข 2026-10-12)
status: DONE (ยกเลิก — ไม่จำเป็น: T-009 รอบ 3 ผ่านด้วย 0.5%/1.0%, D4 reject 6 ครั้ง)
needs: owner
depends: —
goal: Owner/Cowork อนุมัติให้ ema_v1_risktest.set ใช้ InpRiskPct=0.25 คู่ InpDailyLossPct=0.5 (ทั้งคู่ต่ำกว่าเพดาน 1%/3%) แล้วรัน T-009 ซ้ำ

## T-019 · P2 · สี EMA ใน visual tester (Owner ขอ 2026-10-12) — display only
status: DONE ea8e5da (426 ไม้, net −3,777.38 เท่าเดิม; ต้องยืนยันสีเส้นใน visual run โดย Owner)
needs: mt5-closed
depends: —
goal: ให้ visual mode แสดง EMA9 กับ EMA21 คนละสี **โดยไม่เปลี่ยน logic การเทรด**: (1) สร้าง src/Indicators/SmartEA_EMAPair.mq5 — indicator บน chart หลัก 2 plot: EMA fast (input period, default 9) สี clrDodgerBlue width 2, EMA slow (default 21) สี clrOrange width 2, คำนวณ EMA ของ close เหมือน iMA(MODE_EMA, PRICE_CLOSE) (2) ใน CEMACrossSignal::Init (EMACrossSignal.mqh:120-121) ถ้า MQLInfoInteger(MQL_VISUAL_MODE): เรียก TesterHideIndicators(true) ก่อนสร้าง iMA 2 ตัว และ TesterHideIndicators(false) หลังสร้าง (ADX/ATR ยังแสดงตามเดิม) แล้วสร้าง handle iCustom ของ "SmartEA\\SmartEA_EMAPair" ด้วย period เดียวกันเพื่อ "แสดงผลอย่างเดียว" — ห้ามใช้ค่าจาก iCustom ตัดสินใจเทรด, release handle ใน Deinit (3) SmartEA.mq5 เพิ่ม `#property tester_indicator "SmartEA\\SmartEA_EMAPair.ex5"` (4) junction MQL5\Indicators\SmartEA ต้องมีอยู่ (setup.ps1 ใหม่สร้างให้ — ถ้าไม่มีให้ BLOCKED "Owner ต้องรัน scripts/setup.ps1 ใหม่"). Acceptance: compile.ps1 PASS 0/0 ทุกไฟล์ (indicator compile ก่อน EA แล้ว), qa-reviewer ไม่มี BLOCKER, รัน run_backtest.ps1 -Ini ema_v1 แล้ว report_stats ต้องได้ **426 ไม้ และ net หลังหัก commission −3,777.38 เท่าเดิม** (พิสูจน์ว่าไม่กระทบ logic), push สำเร็จพร้อม hash

## T-021 · P3 · 3a Calibration: v1 in-sample ด้วย real ticks (Model=4)
status: BLOCKED ไม่มี real ticks XAUUSD ช่วง 2023–2024 บน IC demo (มีแค่ 2026-04..2026-10 ซึ่งห้ามรัน) — Model=4 ตกเป็น every-tick สังเคราะห์ ผลซ้ำ Model=1 (ดู data/reports/SmartEA_ema_v1_ticks.summary.md)
needs: mt5-closed
depends: —
goal: สร้าง tests/tester-ini/ema_v1_ticks.ini (เหมือน ema_v1.ini แต่ Model=4, report SmartEA_ema_v1_ticks) ใช้ ema_v1.set เดิม ห้ามแก้พารามิเตอร์ → รัน (real ticks ครั้งแรกอาจโหลดนานมาก — ใช้ -TimeoutMin 240 ถ้าจำเป็น) → report_stats.py หัก commission → backtest-analyst เทียบกับ Model=1 (T-014): จำนวนไม้, PF, net, DD, avg win/loss, จำนวนไม้ที่ SL/TP ต่างกัน, slippage จาก TRADE RISK • สรุปลง data/reports/SmartEA_ema_v1_ticks.summary.md • **ห้ามรันช่วง 2025/2026** • ถ้า history real ticks ของ IC ไม่ครบช่วง 2023–2024 (ดู "History Quality"/journal) ให้ BLOCKED พร้อมรายงานช่วงที่มี

## T-022 · P3 · Owner เลือก variant ของ spec v2
status: DONE (Owner 2026-10-12: V1–V3 ตามที่เสนอ → spec-ema-adx-v2.md)
needs: owner
depends: —
goal: อ่าน docs/strategy/v2-options.md แล้วตอบ V1–V3 → Cowork เขียน spec-ema-adx-v2.md + docs/strategy/experiments.md + งาน implement/backtest ลงคิว

## T-023 · P3 · ตรวจ news.csv 2023–2024 กับแหล่งทางการ
status: READY
needs: none
depends: —
goal: data/files/news.csv (64 แถว: NFP 24, CPI 24, FOMC 16) Cowork เขียนจากความจำ — ตรวจทุกแถวกับ BLS release calendar (Employment Situation, CPI) และ federalreserve.gov FOMC calendars ปี 2023–2024 ด้วย WebSearch/WebFetch • แก้วันที่ผิดได้ (เป็นข้อมูล ไม่ใช่ค่า risk) แล้วเปลี่ยน verified เป็น `bls` / `fed` • ระวัง: FOMC 2024-11-07 เป็นวันพฤหัส, 2024-06-12 มีทั้ง CPI และ FOMC • ถ้าเข้าเว็บแหล่งทางการไม่ได้ให้ BLOCKED (ห้ามเดา) • บันทึกลิงก์แหล่งใน docs/research/news-calendar.md • จบเมื่อ push สำเร็จพร้อม hash

## T-024 · P3 · Implement v2 feature flags (default = v1)
status: READY
needs: mt5-closed
depends: T-023
goal: implement ตาม docs/strategy/spec-ema-adx-v2.md ทุก flag (V2a HTF ใช้แท่ง H4 ที่ปิดแล้ว, V2b news filter + tester_file + fail closed, V2c no-reverse + re-entry bars, V2d opposite exit switch) ห้ามแตะ RiskManager/Config • สร้าง tests/setfiles/ema_v2a.set, ema_v2b.set, ema_v2c.set, ema_v2d.set (เปิดทีละ flag) • **Regression:** flags default + ema_v1.ini (Model=1) ต้องได้ 426 ไม้ net −3,777.38 เท่า T-014 • compile 0/0, risk-guardian PASS, qa-reviewer ไม่มี BLOCKER, push พร้อม hash

## T-025 · P3 · Experiments E2–E5 (in-sample, real ticks)
status: READY
needs: mt5-closed
depends: T-021, T-024
goal: รัน ema_v2a/b/c/d.set แต่ละตัวบน in-sample 2023–2024 Model=4 (ini ใหม่แบบ ema_v1_ticks.ini) • report_stats.py หัก commission • เติมแถว E2–E5 ใน docs/strategy/experiments.md (trades, PF, net, MaxDD, ผลเทียบ E1 ตาม hypothesis) • **ห้ามแตะ 2025/2026, ห้ามปรับพารามิเตอร์, ห้ามสร้าง variant เพิ่ม** • จบเมื่อ push สำเร็จพร้อม hash (E6 = Owner/Cowork ตัดสินว่ารวม flag ไหน)
