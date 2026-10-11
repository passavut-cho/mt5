รัน /run-task (ไม่ระบุ id) หนึ่งครั้ง ตามกติกา "Queue runner" ใน CLAUDE.md
- ถ้าผลคือ `QUEUE: NOTHING RUNNABLE` หรือ `BLOCKED` → สรุปสั้นๆ ว่ารอ Owner/Cowork เรื่องอะไร แล้ว **หยุด loop** (ไม่ต้องตั้ง wakeup ต่อ)
- ถ้าผลคือ `DONE` → ตั้ง wakeup รอบถัดไปภายใน 1–2 นาทีเพื่อหยิบ task ถัดไป
- ห้ามทำงานนอก queue
