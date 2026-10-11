# /goal templates — SmartEA

`/goal <condition>` (built-in ของ Claude Code) ทำให้ Claude ทำงานต่อเองทุก turn จนกว่า evaluator จะตัดสินว่า condition ครบ
ใช้ `/goal-plan` ให้ Claude ร่าง condition ของงานถัดไปจาก `docs/STATUS.md` หรือ copy template ข้างล่างไปแก้

## หลักเขียน condition ของโปรเจกต์นี้
1. **Evaluator อ่านได้แค่ transcript** → ระบุหลักฐานที่ต้อง "แสดงออกมา" เช่น บรรทัด `PASS` ของ compile.ps1, `VERDICT: PASS`, hash ที่ push
2. **มีทางออกเสมอ** → "หรือ Claude รายงาน `BLOCKED: ต้องให้ Owner ตัดสินใจ`" กันไม่ให้วนเดาค่า risk/spec เอง
3. **จำกัดรอบ** → "หรือครบ N turns"
4. **ไม่ข้าม gate** → goal หนึ่งอันจบที่ "พร้อมให้ Owner รัน `/gate`" ไม่ใช่ "เลื่อน Phase"
5. เขียนข้อห้ามซ้ำใน condition (ไม่แก้ค่า risk, ไม่ force push)

## ก่อนสั่ง /goal
- `git status` สะอาด หรือให้ Claude sync งาน Cowork ก่อน
- ถ้าจะปล่อยทิ้งไว้: เปิด auto mode (`/goal` ไม่เปลี่ยน permission mode เอง) — แต่ไฟล์ `Config/**` และ `RiskManager.mqh` ตั้งเป็น `ask` ไว้ **จะหยุดรอให้กดอนุญาตเสมอ** โดยตั้งใจ
- งานที่ต้องเปิด MT5 ด้วยมือ (ลาก script ลง chart, ทดสอบ demo) ทำใน goal ไม่ได้ → ให้จบด้วย BLOCKED
- `run_backtest.ps1` ต้องปิด MT5 ก่อน

---

## G1.1 — Phase 1 Core implement
```
/goal Implement Phase 1 Core ตาม docs/decisions/0002-core-framework.md ให้ครบ: src/Include/Core/{Types,Logger,BarClock,SignalBase,RiskManager,TradeManager}.mqh, src/Include/Signals/SignalNone.mqh, ต่อเข้า src/Experts/SmartEA/SmartEA.mq5 และสร้าง src/Scripts/RiskSelfTest.mq5. จบเมื่อ transcript แสดงครบทุกข้อ: (1) ผล scripts/compile.ps1 ล่าสุดเป็น PASS ทุกไฟล์ 0 errors 0 warnings (2) risk-guardian ตอบ VERDICT: PASS กับไฟล์ Core ล่าสุด (3) qa-reviewer ไม่มีรายการ BLOCKER (4) docs/STATUS.md อัปเดตแล้ว (5) git push origin main สำเร็จพร้อม short hash. ข้อห้าม: ไม่แก้ค่า risk default (1% / 3% ทั้งบัญชี / commission 7.0), ไม่แก้ docs/decisions/0002 ส่วน Owner decisions, ไม่ force push. หรือจบเมื่อ Claude รายงาน "BLOCKED: ต้องให้ Owner ตัดสินใจ" หรือครบ 40 turns
```

## G1.3 — ADR 0002 addendum D4–D7
```
/goal แก้ Core ตาม docs/decisions/0002-core-framework.md ส่วน "Addendum" + "Owner decisions (2026-10-12)": D4 pre-trade check ไม่เปิดไม้ที่ถ้าโดน SL แล้ว equity จะ <= limit 3%, D5 retry คำนวณราคา/SL/lot ใหม่ผ่าน RiskManager และ log actual_risk หลัง fill, D6 netting ถ้ามี position ของ symbol นี้ทุก magic ให้ไม่เปิด + Warn ใน OnInit, และ CanOpen ปฏิเสธเมื่อ TERMINAL_CONNECTED == 0 นอก tester. เพิ่ม test case ของ D4 ใน src/Scripts/RiskSelfTest.mq5. D7: ใส่ InpMaxSpreadPoints=20 ในทุก .set ของ XAUUSD ใน tests/setfiles/ (default ในโค้ดคง 0) และเปลี่ยน Leverage=500 ใน tests/tester-ini/*.ini ให้ตรงกับ IC demo. ห้ามแก้ค่า risk default. จบเมื่อ transcript แสดง: (1) compile.ps1 PASS ทุกไฟล์ 0/0 (2) risk-guardian VERDICT: PASS (3) qa-reviewer ไม่มี BLOCKER (4) STATUS.md อัปเดต (5) git push สำเร็จพร้อม short hash. หรือรายงาน "BLOCKED: ต้องให้ Owner ตัดสินใจ" หรือครบ 30 turns
```

## G1.2 — Phase 1 smoke 1 ปี (ต้องปิด MT5 ก่อน)
```
/goal สร้าง tests/tester-ini/core_smoke.ini (XAUUSD M15 2024.01.01-2024.12.31, Model=1) + tests/setfiles/core_smoke.set แล้วรัน scripts/run_backtest.ps1 -Ini core_smoke จนได้ report ใน data/reports/ และไม่มีบรรทัด error/critical จาก SmartEA ใน tester journal; ให้ backtest-analyst สรุปลง data/reports/SmartEA_core_smoke.summary.md; commit + push สำเร็จพร้อม short hash. หรือจบเมื่อรายงาน "BLOCKED: ต้องให้ Owner ตัดสินใจ" หรือครบ 15 turns
```

## G2.1 — Phase 2 implement (ใช้ได้หลัง Owner อนุมัติ spec เท่านั้น)
```
/goal Implement CEMACrossSignal + CADXFilter ตาม docs/strategy/spec-ema-adx.md ที่ Status = APPROVED เท่านั้น (ถ้ายังไม่ APPROVED ให้หยุดและรายงาน BLOCKED ทันที). ไม่แตะไฟล์ใน src/Include/Core/. จบเมื่อ transcript แสดง: compile.ps1 PASS 0/0, risk-guardian PASS, qa-reviewer ไม่มี BLOCKER, มี tests/setfiles/ema_v1.set และ tests/tester-ini/ema_v1.ini, STATUS.md อัปเดต, git push สำเร็จพร้อม hash. หรือ BLOCKED หรือครบ 40 turns
```

## Template ว่าง
```
/goal <งาน> ตาม <ไฟล์ spec/ADR>. จบเมื่อ transcript แสดง: (1) compile.ps1 PASS 0/0 (2) <agent> PASS (3) STATUS.md อัปเดต (4) git push สำเร็จพร้อม hash. ข้อห้าม: <...>. หรือจบเมื่อรายงาน "BLOCKED: ต้องให้ Owner ตัดสินใจ" หรือครบ <N> turns
```

คำสั่งที่เกี่ยวข้อง: `/goal` (ดูสถานะ) • `/goal clear` (ยกเลิก)
