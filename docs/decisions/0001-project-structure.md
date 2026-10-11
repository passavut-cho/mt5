# ADR 0001 — โครงสร้างโปรเจกต์และการเชื่อมกับ MT5

**Status:** Accepted • **Date:** 2026-10-12

## Context
MetaEditor compile ได้เฉพาะไฟล์ใต้ `MQL5/` ของ terminal data folder แต่เราต้องการเก็บ source ใน repo เดียวที่ใช้ git และ Claude Code ได้

## Decision
1. Source อยู่ใน `src/` ของ repo, ใช้ **directory junction** (`mklink /J` — ไม่ต้องใช้ Admin ต่างจาก symlink) เชื่อมเข้า terminal:
   - `MQL5\Experts\SmartEA` → `src\Experts\SmartEA`
   - `MQL5\Include\SmartEA` → `src\Include`
   - `MQL5\Scripts\SmartEA` → `src\Scripts` (สำหรับ self-test script)
2. Path ของ terminal เก็บใน `scripts/config.local.ps1` (gitignored) สร้างอัตโนมัติโดย `setup.ps1`
3. Phase ปัจจุบันเก็บใน `docs/STATUS.md` เพื่อให้ทุก session เริ่มจากจุดเดิม
4. Live guard ตรวจ `ACCOUNT_TRADE_MODE` แทนการบล็อกการเทรดทั้งหมด — tester และ demo ต้องทำงานได้ ไม่งั้นทดสอบไม่ได้
5. กฎ "ห้ามแก้ risk โดยไม่ถาม" บังคับซ้ำด้วย `ask` permission ใน `.claude/settings.json` ไม่พึ่งแค่ข้อความใน CLAUDE.md

## Alternatives
- Symlink: ต้องใช้ Admin/Developer Mode — ตัดทิ้ง
- เขียนตรงใน terminal folder: ไม่มี git, path ยาวและผูกกับ terminal ID — ตัดทิ้ง

## Consequences
- ลบ junction ต้องใช้ `rmdir` (ไม่ใช่ลบไฟล์ข้างใน) ไม่งั้น source ใน repo หายด้วย
- ถ้าเปลี่ยน terminal/broker ต้องรัน `setup.ps1` ใหม่
