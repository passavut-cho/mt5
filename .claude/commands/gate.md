---
description: ตรวจ exit gate ของ Phase ปัจจุบัน — ผ่านแล้วจึงเลื่อน Phase
---
ตรวจ exit criteria ของ Phase ปัจจุบันตาม docs/runbook.md อย่างเป็นทางการ:
1. รัน compile (scripts/compile.ps1) — ต้อง 0 errors, 0 warnings
2. เรียก risk-guardian และ qa-reviewer กับไฟล์ที่เปลี่ยนใน Phase นี้
3. ถ้า Phase ต้องการ backtest → เรียก backtest-analyst
4. สรุป "Phase X exit criteria: ครบ / ไม่ครบ" พร้อมหลักฐานแต่ละข้อ
ถ้าครบทุกข้อ → **ถามผู้ใช้ก่อน** แล้วจึงอัปเดต docs/STATUS.md ไป Phase ถัดไป, commit `[P<X>] chore: gate passed` + `git tag p<X>-done` แล้ว `git push origin main --tags`
ถ้าไม่ครบ → ห้ามเลื่อน Phase ระบุสิ่งที่ต้องทำ
