# AGENTS.md — สำหรับ Codex (SmartEA)

> **อ่านและทำตาม `CLAUDE.md` ทั้งไฟล์** — เป็นแหล่งกฎเดียวของโปรเจกต์ (กฎเหล็ก, scope XAUUSD-only, coding standard, Definition of Done, holiday/news calendar, รูปแบบรายงาน)
> ที่ CLAUDE.md เขียนว่า "Claude Code" / "Code" ให้หมายถึงตัวคุณ **ยกเว้นหัวข้อ Git และ Queue runner ซึ่ง Codex ใช้กติกาด้านล่างแทน**
> ห้ามคัดลอกกฎจาก CLAUDE.md มาไว้ที่นี่ (เคยทำแล้วตกรุ่น — ADR 0003 M1) • สำเนาเก่าเก็บที่ `.codex/AGENTS.migrated-backup.md`

## Codex lane (ADR 0003)
1. **ทำงานใน worktree `D:\Claude Projects\MT5-codex` เท่านั้น** บน branch `codex/T-NNN` — ห้าม checkout/commit/push `main`
2. **งานที่ทำได้:** task ใน `docs/queue.md` ที่มี `agent: codex` หรือ `agent: any` ที่ไม่ต้องใช้ MT5 (`needs: none`) — Python tooling, unit tests, ตรวจ/เติม holidays & news calendar จากแหล่งทางการ, วิเคราะห์ report ที่มีอยู่, **review แบบอ่านอย่างเดียว**
3. **ห้ามใช้ MT5:** ห้ามรัน `scripts/compile.ps1`, `scripts/run_backtest.ps1`, `terminal64.exe`, `metaeditor64.exe` (มี terminal เดียว ใช้โดย Claude lane) • ห้ามแก้ `src/**/*.mq5|mqh` เว้นแต่ task ระบุชัด — และถึงจะแก้ก็ห้าม compile เอง ให้ระบุใน PR ว่า "ต้อง compile ฝั่ง Claude"
4. **ห้ามแตะไฟล์ risk** (`src/Include/Core/RiskManager.mqh`, `src/Include/Config/**`) และ **ห้ามตั้ง `SMARTEA_RISK_EDIT`** หรือใช้ `git commit --no-verify` ไม่ว่ากรณีใด
5. **ห้ามแก้ `docs/queue.md` และ `docs/STATUS.md`** — รายงานผลใน PR description (ใช้รูปแบบรายงานท้ายรอบใน CLAUDE.md โดย header เป็น `[Codex · Phase N]`)
6. ส่งงาน: commit บน branch → `git push -u origin codex/T-NNN` → `gh pr create` (title `[P<n>] <type>: T-NNN ...`) → Claude Code ตรวจ (qa-reviewer, + risk-guardian ถ้าแตะ Trade/Expert) แล้ว merge
7. **Review lane:** ถ้าถูกขอให้ review diff ของ Claude ให้รายงาน `BLOCKER / MAJOR / MINOR` พร้อม file:line — ห้ามแก้โค้ดเอง
8. Subagents ของ Codex (`.codex/agents/*.toml`) เป็นสำเนาของ `.claude/agents/*.md` — ถ้าขัดกัน ให้ถือ `.claude/agents/` เป็นหลัก
