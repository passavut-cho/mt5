---
description: Compile SmartEA และแก้จน 0 errors, 0 warnings
---
รัน `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/compile.ps1 $ARGUMENTS`
ถ้ามี error/warning: อ่าน log, แก้ทีละจุด, compile ซ้ำ จนสะอาด — ห้ามซ่อน warning ด้วย #pragma
ถ้าแก้ต้องแตะ Config/ หรือ RiskManager.mqh ให้ถามผู้ใช้ก่อน
