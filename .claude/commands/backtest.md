---
description: รัน backtest ตาม ini ใน tests/tester-ini/ แล้วให้ backtest-analyst ตีความ
argument-hint: <ini-name เช่น ema_v1>
---
1. ตรวจว่ามี tests/tester-ini/$ARGUMENTS.ini และ .set ที่อ้างถึง
2. compile ก่อน (scripts/compile.ps1) — ถ้าไม่ผ่านห้ามรัน backtest
3. รัน `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_backtest.ps1 -Ini $ARGUMENTS`
4. เรียก backtest-analyst ตีความ report และเทียบ exit criteria ของ Phase ปัจจุบัน
