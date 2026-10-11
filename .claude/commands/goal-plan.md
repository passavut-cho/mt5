---
description: ร่าง condition สำหรับ /goal ของงานถัดไปจาก STATUS.md (ไม่ได้สั่ง /goal เอง)
argument-hint: [งานที่อยากให้ทำ — ว่าง = งานถัดไปใน STATUS.md]
---
1. อ่าน docs/STATUS.md, docs/runbook.md (Phase ปัจจุบัน) และ docs/goals.md
2. เลือกงาน: $ARGUMENTS — ถ้าว่างให้ใช้งานถัดไปที่ทำได้โดยไม่ต้องให้ Owner เปิด MT5 ด้วยมือ
3. ตรวจ prerequisite (spec APPROVED? ADR Accepted? MT5 ต้องปิดไหม?) ถ้าไม่ครบให้บอกว่ายังสั่ง goal ไม่ได้เพราะอะไร
4. ร่าง condition ตามหลักใน docs/goals.md: หลักฐานที่ evaluator เห็นได้จาก transcript, ข้อห้าม, ทางออก BLOCKED, จำกัด turns, ≤ 4,000 ตัวอักษร
5. แสดงผลเป็น code block บรรทัดเดียวที่ขึ้นต้นด้วย `/goal ` ให้ Owner copy ไปวาง — **ห้ามเริ่มทำงานเอง**
