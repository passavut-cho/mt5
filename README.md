# SmartEA — MT5 Expert Advisor Framework

EA สำหรับ MetaTrader 5 ที่เน้น risk management เข้มงวด พัฒนาด้วย Claude Code แบบทีละ Phase (ดู `docs/runbook.md`)

## เริ่มครั้งแรก (Windows, ไม่ต้องใช้ Admin)
```powershell
cd "D:\Claude Projects\MT5"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/setup.ps1     # หา MT5 + สร้าง junction
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/compile.ps1   # ต้องได้ PASS
git init; git add .; git commit -m "[P0] bootstrap"
claude
```

## เปิด session ใน Claude Code
```
/status
```
แล้วสั่งต่อ เช่น "ทำงานต่อตาม Phase ปัจจุบัน" — Claude จะเรียก subagent ที่เหมาะสมเอง จบ Phase ด้วย `/gate`

## โครงสร้าง
| Path | หน้าที่ |
|---|---|
| `CLAUDE.md` | กฎของโปรเจกต์ — Claude อ่านทุก session |
| `docs/STATUS.md` | Phase ปัจจุบัน + งานค้าง |
| `docs/runbook.md` | ลำดับ Phase และ exit gate |
| `docs/decisions/` | ADR |
| `docs/strategy/` | spec ของกลยุทธ์ (ต้องอนุมัติก่อน implement) |
| `.claude/agents/` | subagents 5 ตัว |
| `.claude/commands/` | `/status` `/gate` `/compile` `/backtest` |
| `src/` | MQL5 source (junction เข้า terminal) |
| `tests/` | `.ini` tester, `.set`, python วิเคราะห์ |
| `scripts/` | setup / compile / backtest |

⚠️ ถ้าจะลบ junction ใน MT5 ให้ใช้ `cmd /c rmdir "<path>"` — อย่าลบไฟล์ข้างใน เพราะจะลบ source ใน repo ไปด้วย
