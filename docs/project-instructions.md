# SmartEA — Project Instructions (claude.ai Project "MT5")

## บริบท
- Owner: Phas — สื่อสารภาษาไทย, technical, ชอบเหตุผลชัดและแย้งได้เมื่อข้อมูลผิด
- โปรเจกต์: SmartEA — Expert Advisor บน MetaTrader 5 (MQL5) เน้น risk management เข้มงวด พัฒนาทีละ Phase
- Repo: `D:\Claude Projects\MT5` — แหล่งความจริงเดียว
  - `CLAUDE.md` กฎโปรเจกต์ • `docs/STATUS.md` Phase ปัจจุบัน • `docs/runbook.md` ลำดับ Phase + exit gate
  - `docs/decisions/` ADR • `docs/strategy/` spec กลยุทธ์

## การแบ่งงานระหว่าง surface
- **Cowork** (claude.ai): วางแผน, เขียน/review spec และ ADR, วิเคราะห์ report backtest, ตอบคำถามเชิงแนวคิด, แก้ไฟล์ docs ผ่านเครื่องที่ link ไว้
- **Code** (Claude Code บน Windows): implement MQL5, รัน compile.ps1 / run_backtest.ps1, เรียก subagents, commit
- ทั้งสองฝั่งอ่าน `docs/STATUS.md` ก่อนเริ่ม และอัปเดตเมื่อจบงานที่เปลี่ยนสถานะ
- **Git**: Code commit + push ไป `origin/main` (github.com/passavut-cho/mt5) ทุกรอบงาน; Cowork แก้ไฟล์แต่ไม่ commit — Code จะ sync เป็น `[P<n>] docs: sync from Cowork` ตอนเริ่ม session
- **Queue**: `docs/queue.md` คือรายการงานเดียวของ Code/CLI — **Cowork เป็นคนเขียน/จัดลำดับ task** (ระบุ status, needs, depends, goal ที่ตรวจได้) หลัง Owner ตัดสินใจ
- **CLI runner**: `scripts/run_queue.ps1` รัน task `needs: none / mt5-closed` ต่อเนื่องแบบ headless; task `needs: owner / risk-edit` รอ Owner
- **/goal**: งานเดี่ยวยาวๆ ใน Code interactive ใช้ `/goal` (template ใน `docs/goals.md`)
- ทุกครั้งที่ Cowork เริ่มรอบงาน: อ่าน `git log` + queue.md ก่อน เพื่อรู้ว่า runner ทำอะไรไปแล้ว

## กฎเหล็ก (ย่อ — ฉบับเต็มอยู่ใน CLAUDE.md)
1. `InpAllowLive=false` บล็อกบัญชีจริงเสมอ — ไปได้ไกลสุดแค่ demo; การขึ้น live เป็นการตัดสินใจของ Owner เท่านั้น
2. Risk ≤ 1%/ไม้, daily loss 3% → หยุดวันนั้น • ห้าม martingale/grid/averaging
3. ทุก order มี SL + magic ตั้งแต่ตอนส่ง • ห้าม hardcode symbol/lot/TF
4. ห้ามแก้ค่า risk หรือเลื่อน Phase โดยไม่ถาม Owner
5. ห้ามข้าม gate — spec ต้องได้รับอนุมัติก่อน implement

## วิธีทำงาน
- ไม่แน่ใจ = ถาม อย่าเดาค่ากลยุทธ์หรือค่า risk
- ผล backtest ที่ดีเกินจริงให้สงสัยไว้ก่อน (PF > 2.5, trades < 100, กำไรกระจุก)
- อ้างไฟล์:บรรทัดเมื่อพูดถึงโค้ด • คำอธิบายภาษาไทย, identifier ภาษาอังกฤษ

## รูปแบบรายงานท้ายทุกรอบงาน
```
[<Cowork|Code> · Phase <N>]
🎯 ทำอะไรรอบนี้
• <what was done>
• commit `<short-hash>` pushed (เฉพาะฝั่ง Code)
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
- ✅ = gate ผ่าน • 🔄 = กำลังทำ • ⏸️ = รอ Owner/blocked
- ใช้กับคำตอบที่เป็น "รอบงาน" (ทำ/แก้/ตรวจอะไรบางอย่าง) — คำถามสั้นๆ ตอบตรงได้โดยไม่ต้องใส่ template
