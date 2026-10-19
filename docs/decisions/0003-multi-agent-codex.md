# ADR 0003 — ให้ Codex ทำงานขนานกับ Claude อย่างปลอดภัย

**Status:** Accepted — Owner อนุมัติ M1–M4 ตามที่เสนอ (2026-10-19)

## Context
- Owner ติดตั้ง Codex ไว้แล้ว: `AGENTS.md`, `.codex/agents/*.toml` (5 agents), `.agents/skills/` (gate, status) — เป็นการแปลงอัตโนมัติจากไฟล์ของ Claude
- ปัญหาที่พบ:
  1. **`AGENTS.md` เป็นสำเนา CLAUDE.md รุ่นเก่า** (แทนคำว่า Claude → Codex ทั้งไฟล์ เช่น "Codex.ai") และ **ตกรุ่นแล้ว** — ไม่มี scope XAUUSD-only • ถ้าแก้กฎที่ไฟล์หนึ่ง อีกไฟล์จะเพี้ยนไปเรื่อยๆ
  2. **ตัวกัน risk-edit ของเราอยู่ใน `.claude/settings.json` (permission `ask`) ซึ่ง Codex ไม่อ่าน** → Codex แก้ RiskManager.mqh / Config/ ได้โดยไม่มีใครถาม
  3. มี MT5 terminal เดียว + junction ชี้ repo โฟลเดอร์เดียว → 2 agents compile/backtest พร้อมกัน = EA ผิดเวอร์ชัน, git ชน (เคยอธิบายไว้ตอนถาม T-034/T-038)
- ข้อดีที่ได้: Codex ใช้โควตาแยก (โควตาสัปดาห์ของ Claude เคยเต็มกลางงาน) และเป็น **reviewer อิสระ** ได้ (คนละโมเดล ไม่ตรวจงานตัวเอง)

## Proposal
### M1 — กฎชุดเดียว
- `CLAUDE.md` = แหล่งกฎหลักเพียงแห่งเดียว
- `AGENTS.md` เหลือแค่: "อ่านและทำตาม `CLAUDE.md` ทั้งหมด (คำว่า Claude Code/Code ให้หมายถึงตัวคุณ)" + หัวข้อ **Codex lane** (ด้านล่าง) — ห้ามคัดลอกกฎซ้ำ
- `.codex/agents/*.toml` ให้ชี้ไปที่ `.claude/agents/*.md` เป็นต้นฉบับ (หรือสร้างใหม่ด้วย script sync เมื่อ agent ฝั่ง Claude เปลี่ยน)

### M2 — แยกพื้นที่ทำงาน (git worktree + branch)
- Codex ทำงานใน **`D:\Claude Projects\MT5-codex`** (`git worktree add ../MT5-codex`) บน branch `codex/T-NNN` เท่านั้น — **ไม่ push `main`**
- ส่งงานเป็น PR (`gh pr create`) → Claude Code ตรวจด้วย qa-reviewer (+ risk-guardian ถ้าแตะ Trade/Expert) → merge → อัปเดต queue
- Codex **ไม่แก้ `docs/queue.md`** (กัน conflict) — รายงานผลใน PR description แทน

### M3 — แบ่ง lane ตามทรัพยากร
| Lane | ใคร | งาน |
|---|---|---|
| **MT5 lane** | Claude (runner / Code) | MQL5, compile, backtest, ทุกอย่างที่ต้องใช้ terminal, merge main |
| **Python/Data lane** | Codex | `dashboard.py`, `report_stats.py`, unit tests, ตรวจ/เติม holidays & news calendar, วิเคราะห์ report ที่มีอยู่แล้ว |
| **Review lane** | Codex | second-opinion review ของ diff MQL5 จาก Claude (อ่านอย่างเดียว) ก่อน gate ของแต่ละ Phase |
- queue.md เพิ่ม field `agent: claude | codex | any` — `/run-task` ของ Claude ข้าม `agent: codex` และกลับกัน
- (ทีหลัง ถ้าจำเป็น) ติดตั้ง MT5 ตัวที่ 2 แบบ portable ให้ worktree ของ Codex → compile/backtest ขนานได้จริง — ยังไม่ทำ เพราะ CPU tester แย่งกันและซับซ้อน

### M4 — ตัวกัน risk ที่ไม่ขึ้นกับ agent (git pre-commit hook)
- `scripts/hooks/pre-commit` + `git config core.hooksPath scripts/hooks` (ใช้ทั้ง main repo และ worktree)
- **บล็อก commit ที่แตะ `src/Include/Core/RiskManager.mqh` หรือ `src/Include/Config/**`** เว้นแต่ Owner ตั้ง `SMARTEA_RISK_EDIT=1` ใน shell ของ commit นั้นเอง
- บล็อก commit ลง `main` จาก worktree ของ Codex
- ทำให้กฎเหล็กข้อ 6 ไม่ขึ้นกับว่าเป็น agent ตัวไหน หรือ config ของใครอ่านไม่อ่าน

## Owner ตัดสิน
| # | เรื่อง | ข้อเสนอ |
|---|---|---|
| M1 | AGENTS.md ชี้ไป CLAUDE.md แทนการคัดลอก | ✅ |
| M2 | Codex ใช้ worktree + branch + PR ไม่ push main | ✅ |
| M3 | Codex = Python/Data lane + Review lane (ไม่ใช้ MT5) | ✅ |
| M4 | pre-commit hook กันไฟล์ risk สำหรับทุก agent | ✅ (ทำก่อนให้ Codex เริ่มงานจริง) |

## Implementation notes (Cowork 2026-10-19)
- `AGENTS.md` เขียนใหม่ (ชี้ไป CLAUDE.md + Codex lane) • สำเนาเก่า `.codex/AGENTS.migrated-backup.md`
- `scripts/hooks/pre-commit` เขียนแล้ว — **ยังไม่ทำงานจนกว่าจะรัน `git config core.hooksPath scripts/hooks`** (T-039)
- Claude settings: `SMARTEA_RISK_EDIT=1 git commit` = ask (Owner ต้องกดอนุญาตเอง, headless ถูกปฏิเสธ) • deny `--no-verify` / `-n` / แก้ hooksPath
- ข้อจำกัดที่ต้องรู้: hook เป็น "ราวกั้น" ไม่ใช่การล็อกถาวร — คนหรือ agent ที่ตั้งใจเลี่ยงได้ (`--no-verify`, ตั้ง env เอง) • การป้องกันชั้นจริงสำหรับ Codex คือ **ทำงานบน branch + PR + Claude risk-guardian review ก่อน merge**
