---
description: ทำ 1 task จาก docs/queue.md ให้จบ (ใช้โดย /loop และ scripts/run_queue.ps1)
argument-hint: [T-NNN — ว่าง = task แรกที่ทำได้]
---
ทำตาม "Queue runner" ใน CLAUDE.md:

1. `git pull --rebase` แล้วอ่าน docs/STATUS.md และ docs/queue.md
2. เลือก task: $ARGUMENTS — ถ้าว่าง เลือก task แรกที่ `status: READY` + ทุก depends เป็น DONE + needs ทำได้:
   - `needs: owner` → ข้ามเสมอ
   - `needs: risk-edit` → ข้ามถ้ารันแบบ headless (`-p`) หรือ Owner ไม่ได้นั่งอยู่
   - `needs: mt5-closed` → ตรวจ `powershell -NoProfile -Command "Get-Process terminal64 -ErrorAction SilentlyContinue"` ต้องว่าง ไม่งั้นข้าม
3. ไม่มี task ที่ทำได้ → พิมพ์ `QUEUE: NOTHING RUNNABLE` + สรุปว่าแต่ละ task ติดอะไร แล้วหยุด (ไม่แก้ไฟล์ ไม่ commit)
4. ตั้ง `status: IN_PROGRESS` ใน queue.md (ยังไม่ต้อง commit)
5. ทำงานจน `goal:` ของ task ครบ พร้อมแสดงหลักฐานใน transcript (compile PASS, VERDICT ของ agent ฯลฯ ตาม Definition of Done)
6. จบ:
   - สำเร็จ → `status: DONE <short-hash>` (hash ของ commit งาน) • อัปเดต STATUS.md • commit `[P<n>] <type>: T-NNN <สรุป>` + push
   - ติด → `status: BLOCKED <เหตุผลสั้น>` (เช่น permission ถูกปฏิเสธ, ต้องให้ Owner ตัดสินใจ) • commit งานที่เสร็จแล้ว + push
7. พิมพ์ `QUEUE: T-NNN DONE <hash>` หรือ `QUEUE: T-NNN BLOCKED <เหตุผล>` แล้วตามด้วยรายงานท้ายรอบ
ห้ามทำเกิน 1 task ต่อการเรียก • ห้ามเพิ่ม/ลบ/เรียงลำดับ task เอง (เป็นหน้าที่ Cowork/Owner) ยกเว้นเพิ่ม task ย่อยที่จำเป็นต่อท้ายพร้อม `status: WAIT_OWNER` โดยใช้เลข = เลข T สูงสุดในไฟล์ + 1 (ห้ามใช้เลขซ้ำ) • ห้ามแก้บรรทัดตัวอย่างรูปแบบด้านบนของ queue.md
