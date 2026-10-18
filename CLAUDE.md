# Project: SmartEA — MT5 Expert Advisor Framework

## Mission
พัฒนา EA บน MQL5 **สำหรับ XAUUSD (ทอง) เท่านั้น** ที่มี risk management เข้มงวด ทดสอบครบทุกขั้น และไปได้ไกลสุดแค่ **demo account** — การขึ้น live เป็นการตัดสินใจของผู้ใช้เท่านั้น

**Scope: XAUUSD only (Owner 2026-10-19)** — กลยุทธ์ การวิจัย ค่า default (spread 20 pts, session, holiday/news ของ US) และ dashboard ออกแบบสำหรับทองทั้งหมด • ห้ามเสนอ/ทดสอบ symbol อื่นโดยไม่ถาม Owner • EA ต้องปฏิเสธการรันบน symbol ที่ไม่ใช่ทอง (T-037)

## บริบท
- Platform: MetaTrader 5 / MQL5 (OOP, syntax คล้าย C++)
- ผู้ใช้: Phas — กำลังเรียนรู้ algorithmic trading ต้องการโค้ดที่อ่านง่าย มีเหตุผลรองรับ
- ภาษา: อธิบายและ comment เป็นไทย, identifier เป็นอังกฤษ
- OS: Windows — scripts เป็น PowerShell เรียกผ่าน `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/<name>.ps1`

## เริ่มทุก session
1. อ่าน `docs/STATUS.md` → รู้ว่าอยู่ Phase ไหน, งานค้างอะไร
2. อ่านส่วนของ Phase นั้นใน `docs/runbook.md`
3. ทำงานเฉพาะใน Phase ปัจจุบัน ห้ามข้าม gate
4. จบ session → อัปเดต `docs/STATUS.md` (ทำอะไรไป, เหลืออะไร, blocker)

## ⛔ กฎเหล็ก (ห้ามฝ่าฝืนเด็ดขาด)
1. **Live guard**: ทุก EA ต้องมี `input bool InpAllowLive = false;` — ใน `OnInit` ถ้า `ACCOUNT_TRADE_MODE == ACCOUNT_TRADE_MODE_REAL` และ `InpAllowLive == false` → `return INIT_FAILED` (Strategy Tester และ demo ทำงานได้ปกติ) ห้ามเขียนทางเลี่ยง guard นี้ในรูปแบบใดๆ
2. **Risk ต่อไม้ ≤ 1% ของ equity รวม commission** (`InpCommissionPerLot` round turn) • **Max daily loss 3% ทั้งบัญชี**: equity (รวม floating) ≤ balance ต้นวัน (server time) × 97% → หยุดเปิดไม้ใหม่จนถึงวันถัดไป ไม้ที่เปิดอยู่ปล่อยให้ SL/TP ทำงาน • ห้ามเปิดไม้ที่ถ้าโดน SL แล้วจะทะลุ 3% (pre-trade check) (ADR 0002 D1–D4)
3. **ห้าม martingale / grid / averaging down** — ห้ามเพิ่ม lot ตามผลไม้ก่อนหน้า ห้ามเปิดไม้เพิ่มทิศเดียวกันเพื่อเฉลี่ยราคา
4. **ทุก order ต้องมี Stop Loss และ magic number** ตั้งแต่ตอนส่ง order (ไม่ใช่ modify ตามทีหลัง)
5. **ห้าม hardcode** symbol, lot, timeframe, magic — ต้องเป็น input หรือมาจาก `_Symbol` / `_Period`
6. **ห้ามแก้ค่า risk ใดๆ** (ค่า default ใน `src/Include/Config/`, logic ใน `RiskManager.mqh`) โดยไม่ถามผู้ใช้ก่อน — settings.json ตั้งให้ถามอยู่แล้ว ห้ามหาทางอ้อม

## Coding Standard
- แยกชั้น: **Signals → Risk → Execution**, Logging ข้ามชั้นได้ ห้ามปน logic
- Input ขึ้นต้น `Inp`, member ของ class ขึ้นต้น `m_`, class ขึ้นต้น `C`
- ทุก indicator handle: ตรวจ `INVALID_HANDLE` ใน init และ `IndicatorRelease()` ใน `OnDeinit`
- ตรวจ return ของ `CopyBuffer` / `CopyRates` / `OrderSend` / `CTrade` ทุกครั้ง (รวม `ResultRetcode()`)
- คำนวณ signal บน **แท่งที่ปิดแล้ว** (shift 1) และทำงานเฉพาะเมื่อเกิดแท่งใหม่ ยกเว้น spec ระบุเป็นอย่างอื่น
- Lot ต้อง normalize ตาม `SYMBOL_VOLUME_MIN/MAX/STEP`; ราคา SL/TP ต้อง normalize และเคารพ `SYMBOL_TRADE_STOPS_LEVEL`
- Log การเข้า/ออก/ปฏิเสธไม้ทุกครั้งผ่าน `CLogger` — ห้าม `Print` กระจัดกระจาย
- Include ภายนอกโปรเจกต์ใช้ `#include <SmartEA/...>`; ภายใน `src/Include` ใช้ relative `#include "..."`
- ไฟล์ `.mq5` / `.mqh` บันทึกเป็น **UTF-8 with BOM** (ไม่งั้น MetaEditor อ่านภาษาไทยเพี้ยน)
- `#property version` ต้องอยู่ในรูป `x.yy` เช่น `"1.00"` (MetaEditor เตือน warning 68 ถ้าใช้ `"0.01"`) — บอก phase ด้วย git tag แทน

## Definition of Done (ทุก feature)
- [ ] `scripts/compile.ps1` ผ่าน: **0 errors, 0 warnings**
- [ ] Backtest ผ่าน Strategy Tester ได้ report จริงใน `data/reports/`
- [ ] `risk-guardian` → PASS และ `qa-reviewer` → ไม่มี issue ระดับ blocker
- [ ] มี `.set` ใน `tests/setfiles/` และ `.ini` ใน `tests/tester-ini/`
- [ ] อัปเดต `docs/STATUS.md` แล้ว commit + push (ดูหัวข้อ Git)

## Holiday calendar (spec S9) — อัปเดตทุกปี
- ไฟล์เดียว: `data/files/holidays.csv` (EA อ่านผ่าน junction `MQL5\Files\SmartEA\`) — วันที่เป็น **server date** • `# covered_years:` บอกปีที่ครอบคลุม
- **ภายใน 15 ธันวาคมของทุกปี** ต้องเพิ่มปีถัดไป: ดึงจาก CME Group holiday calendar (COMEX metals) เป็นหลัก + ประกาศ holiday trading hours ของ IC Markets เป็นตัวยืนยัน → ใส่ `verified` ตามแหล่ง → อัปเดต `covered_years` → commit `[P<n>] data: holidays <ปี>` → Owner รับทราบ
- ประกาศของ CME/IC ออกล่วงหน้าไม่กี่สัปดาห์ → แถว `probable` ต้องถูกยืนยันใหม่ภายใน 2 สัปดาห์ก่อนถึงวันจริง (ตอนรัน demo/live)
- ห้ามลบปีที่ผ่านมา (backtest ต้องใช้) • ถ้า backtest ช่วงที่ไม่อยู่ใน covered_years → EA จะไม่เปิดไม้ (fail closed) ต้องเติมไฟล์ก่อน
- backtest-analyst: ไม้ที่ข้าม 23:30 ในวันที่ไม่อยู่ในไฟล์ = หลักฐานว่าต้องเพิ่มวันนั้น → รายงานใน ⚠️

- **News calendar (`data/files/news.csv`, spec v2 V2b)** ใช้กติกาเดียวกับ holidays: วันเวลาเป็น **server time** (IC = New York + 7 ชม. คงที่ทุกฤดู) • `# covered_years:` fail closed • แหล่งหลัก: BLS release schedule (NFP, CPI) และ Federal Reserve FOMC calendar • ต้องเติมปีถัดไปพร้อม holidays (ภายใน 15 ธ.ค.) และ **ตรวจทุกต้นเดือน** เพราะวันประกาศเลื่อนได้ (เช่น government shutdown) • ก่อนใช้ข้อมูลช่วง validation/OOS ต้องเติมปีนั้นให้ครบก่อน

## โหมดการทำงาน 3 แบบ
| ใคร | เครื่องมือ | ทำอะไร |
|---|---|---|
| **Cowork** (claude.ai) | แก้ไฟล์ผ่านเครื่องที่ link | วางแผน, spec, ADR, review, วิเคราะห์ report, **เขียน/จัดลำดับ `docs/queue.md`** — ไม่ commit |
| **Code interactive** (Owner นั่งอยู่) | `claude` ปกติ หรือ `claude --permission-mode auto` + `/goal` / `/loop` | task `needs: risk-edit`, debug, `/gate`, งานที่ต้องคุยกัน |
| **CLI runner** (ไม่มีคนเฝ้า) | `scripts/run_queue.ps1` (headless `claude -p` + auto mode) | task `needs: none` / `mt5-closed` ต่อกันจนคิวหมดหรือติด |

## Queue runner (ใช้กับ /run-task, /loop, run_queue.ps1)
1. แหล่งงานเดียวคือ `docs/queue.md` — ทำทีละ 1 task, ห้ามทำงานนอกคิว, ห้ามเรียงลำดับ/ลบ task เอง
2. เลือก task แรกที่ `READY` + depends ทุกตัว DONE + needs ทำได้ (ดูนิยาม needs ใน queue.md)
3. headless (`-p`) ข้าม `needs: owner` และ `needs: risk-edit` เสมอ — ไฟล์ risk ตั้ง `ask` ไว้ จะถูกปฏิเสธอัตโนมัติ
4. permission ถูกปฏิเสธ / ต้องการคำตัดสิน / หลักฐานไม่ครบ → `BLOCKED <เหตุผล>` แล้วหยุด — **ห้ามหาทางอ้อม**
5. จบ task: อัปเดต queue.md + STATUS.md → commit + push → พิมพ์ `QUEUE: T-NNN DONE <hash>` หรือ `QUEUE: T-NNN BLOCKED <เหตุผล>`
6. ไม่มีอะไรทำได้ → พิมพ์ `QUEUE: NOTHING RUNNABLE` + สรุปว่ารออะไร แล้วหยุด
7. การเลื่อน Phase (`/gate`) และการเปลี่ยน spec เป็น APPROVED ทำได้เฉพาะ Owner

## Git — commit + push ทุกรอบงาน
Remote: `origin` → github.com/passavut-cho/mt5 (branch `main`)
1. จบทุกหน่วยงานที่เสร็จ (feature step, doc, fix) → `git add` เฉพาะไฟล์ที่เกี่ยวข้อง → commit → `git push origin main` **ทันที** ไม่ต้องรอถาม
2. ก่อน commit ไฟล์ใน `src/`: `compile.ps1` ต้อง PASS (0/0) — ไม่ผ่าน = ห้าม commit โค้ดนั้น แก้ให้ผ่านก่อน
3. แตะ Risk/Trade/Expert → ต้องได้ risk-guardian PASS ก่อน commit
4. Message: `[P<n>] <type>: <สรุปสั้น>` type = feat / fix / docs / test / chore เช่น `[P1] feat: RiskManager daily loss breaker`
5. เริ่ม session: `git status` — ถ้ามีไฟล์ค้างที่ Cowork แก้ไว้ (docs/, CLAUDE.md, .claude/) → commit แยกเป็น `[P<n>] docs: sync from Cowork` ก่อนเริ่มงาน
6. push ไม่ผ่าน → `git pull --rebase` แล้ว push ใหม่ 1 ครั้ง ยังไม่ผ่าน → หยุด รายงานใน ⚠️ — **ห้าม force push, ห้าม reset --hard**
7. ห้าม commit: `*.ex5`, `scripts/config.local.ps1`, log, report ดิบ (มีใน .gitignore แล้ว — ห้าม `git add -f`)
8. ใส่ short hash ที่ push แล้วในรายงานท้ายรอบ (🎯)

## /goal — ทำงานต่อเนื่อง
`/goal` เป็นคำสั่ง built-in ของ Claude Code: หลังจบแต่ละ turn จะมี model อีกตัวตรวจว่า condition ครบหรือยัง ถ้ายัง Claude ทำต่อเอง
- template ของแต่ละ Phase อยู่ใน `docs/goals.md` — ใช้ `/goal-plan` เพื่อให้ Claude ร่าง condition ของงานถัดไปจาก STATUS.md
- evaluator **อ่านได้แค่ transcript** ไม่ได้รันคำสั่งเอง → ทุกหลักฐาน (ผล compile, verdict ของ agent, hash ที่ push) ต้องแสดงออกมาในคำตอบ
- เจอเรื่องที่ต้องให้ Owner ตัดสิน (ค่า risk, spec กำกวม, เลื่อน Phase, การทดสอบที่ต้องเปิด MT5 ด้วยมือ) → หยุด, commit+push งานที่เสร็จแล้ว, รายงานใน ⚠️ ด้วยคำว่า `BLOCKED: ต้องให้ Owner ตัดสินใจ`

## Subagents (`.claude/agents/`)
| Agent | ใช้เมื่อ |
|---|---|
| `mql5-architect` | ก่อน feature/refactor ใหม่ → ADR + interface stub |
| `strategy-dev` | เขียน/แก้ Signals และ Expert หลักตาม spec |
| `risk-guardian` | **ทุกครั้ง** หลังแตะ Risk/Trade/Expert — มีสิทธิ์ REJECT |
| `backtest-analyst` | ตีความ report, ตัดสิน gate ของ Phase 2–5 |
| `qa-reviewer` | gate สุดท้ายก่อน commit feature |

Commands: `/status` `/gate` `/compile` `/backtest <ini>` `/goal-plan` `/run-task [T-NNN]` • built-in: `/goal` `/loop` (ใช้ `.claude/loop.md`)

## รูปแบบรายงานท้ายทุกรอบงาน
ปิดทุกรอบงาน (ไม่ใช่คำถามสั้น) ด้วย block นี้ — header tag ฝั่งนี้คือ `Code`:
```
[Code · Phase <N>]
🎯 ทำอะไรรอบนี้
• <what was done>
• commit `<short-hash>` pushed → origin/main
📊 Progress
• Phase <N> · <gate> · <✅ / 🔄 / ⏸️>
💡 น่าสนใจ / คำแนะนำ     ← only if real
• <insight/proposal>
⚠️ ติด / ต้องตัดสินใจ     ← only if real
• <blocker/decision>
➡️ ถัดไป
• <next step / waiting on Owner>
━━━━━━━━━━━━━━━━━━━━━━━━━
```
Rules: 🎯/📊/➡️ always; 💡/⚠️ only when real (never "none" as filler); header tag always present.
✅ = gate ผ่าน • 🔄 = กำลังทำ • ⏸️ = รอ Owner/blocked • Owner = Phas

## สิ่งที่ Claude ทำเองไม่ได้ (ต้องให้ผู้ใช้ทำ)
- รัน MetaEditor / Strategy Tester ถ้า session ไม่ได้อยู่บน Windows เครื่องที่ติดตั้ง MT5 → บอกผู้ใช้ให้รัน script แล้ววางผลลัพธ์กลับมา
- ตัดสินใจขึ้น live account (Phase 6)
