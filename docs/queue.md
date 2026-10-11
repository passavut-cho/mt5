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
status: READY
needs: mt5-closed
depends: T-001
goal: สร้าง tests/tester-ini/core_smoke.ini (XAUUSD M15 2024.01.01-2024.12.31, Model=1, Leverage=500, Deposit=10000, ExpertParameters=core_smoke.set) + tests/setfiles/core_smoke.set (InpMaxSpreadPoints=20, ค่าอื่น default) แล้วรัน scripts/run_backtest.ps1 -Ini core_smoke จนได้ report ใน data/reports/ และไม่มีบรรทัด error/critical จาก SmartEA ใน tester journal; transcript ต้องแสดงบรรทัด "New day ... breaker ที่ equity<=" ของวันแรกที่ balance ต้นวัน = 10000; backtest-analyst สรุปลง data/reports/SmartEA_core_smoke.summary.md

## T-004 · P1 · /gate Phase 1
status: WAIT_OWNER
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
status: READY
needs: none
depends: T-004
goal: สร้าง src/Include/Signals/EMACrossSignal.mqh (CEMACrossSignal : CSignalBase รวม ADX+DI filter และ ATR SL ตาม spec ข้อ 2–4) และต่อเข้า SmartEA.mq5 ด้วย input ตาม spec ข้อ 7 รวม session S1, opposite-cross exit/reverse S3, SL<2×spread ไม่เข้า S4, time exit 23:30 S6, Friday cutoff S7 — ห้ามแตะ src/Include/Core/RiskManager.mqh และ Config/; ถ้าต้องแก้ Core ส่วนอื่นให้บันทึกเหตุผลใน ADR 0003 ก่อน. สร้าง tests/setfiles/ema_v1.set (InpMaxSpreadPoints=20) + tests/tester-ini/ema_v1.ini (XAUUSD M15 2023.01.01-2024.12.31, Model=1, Leverage=500, Deposit=10000). จบเมื่อ transcript แสดง compile.ps1 PASS 0/0, risk-guardian VERDICT: PASS, qa-reviewer ไม่มี BLOCKER, STATUS.md อัปเดต, git push สำเร็จพร้อม hash

## T-008 · P2 · Backtest ema_v1 in-sample + วิเคราะห์
status: READY
needs: mt5-closed
depends: T-007
goal: รัน scripts/run_backtest.ps1 -Ini ema_v1 ได้ report ใน data/reports/; backtest-analyst สรุปลง data/reports/SmartEA_ema_v1.summary.md ตาม spec ข้อ 9 (จำนวนไม้ ≥ 100?, ไม่มีไม้นอก session, ไม่มีไม้ข้าม 23:30, ทุกไม้มี SL) พร้อม metric ครบ; ห้ามปรับพารามิเตอร์เพื่อให้ผลดีขึ้น — ถ้าไม่ผ่านเกณฑ์ให้ BLOCKED แล้วรายงาน
