# Spec — SmartEA Monitor Dashboard v1

**Status:** PROPOSED (Cowork 2026-10-19 จากภาพ reference ของ Owner) — ค่า default ด้านล่างใช้ได้ทันที เว้นแต่ Owner แก้ DB1–DB3
**Scope:** XAUUSD only (Owner 2026-10-19) — ทุก panel ออกแบบสำหรับทอง
**เป้าหมาย:** ดูสุขภาพ EA แบบ real-time บน demo (Phase 5) และวัด **execution quality จริง** ซึ่งเป็นเกณฑ์ผ่าน Phase 5 — ไม่ใช่เครื่องมือเทรด

## หลักการ
1. **Read-only 100%** — dashboard ไม่มีปุ่มสั่งเทรด/ปิดไม้/แก้ค่า (DB2) • EA ไม่อ่านอะไรจาก dashboard
2. **ข้อมูลไม่ออกจากเครื่อง** — HTML ไฟล์เดียวสร้างบนเครื่อง Owner (DB1) • ไม่ upload เลข account / balance
3. **ทุกตัวเลขหลังหัก commission** และแยก "ที่เกิดจริง" กับ "ถ้าไม่มี slippage (ประมาณ)"
4. **Telemetry ห้ามกระทบการเทรด** — เขียนไฟล์ไม่สำเร็จ = log WARN แล้วเทรดต่อตามปกติ (ไม่ fail closed เพราะไม่ใช่ risk)

## สถาปัตยกรรม
```
SmartEA (demo chart)                       Owner's PC
 ├─ CTelemetry (Core/Telemetry.mqh) ──► MQL5\Files\SmartEA\telemetry\*.csv|json  (junction → repo data/files/telemetry/)
 │    hook ใน TradeManager: requested/fill/latency
 │    OnTimer 30s: status.json + equity_snap.csv
 └─ (เทรดตามปกติ)
                                        scripts/dashboard.py  ──► data/dashboard/index.html (meta refresh 30s)
                                        scripts/run_dashboard.ps1 (loop ทุก 30s + เปิด browser)
Backtest mode: dashboard.py --report data/reports/<x>.htm  (ไม่มี slippage จริง → ช่อง execution แสดง "N/A ใน tester")
```

## Data contract (UTF-8, header บรรทัดแรก, เวลาเป็น server time `YYYY-MM-DD HH:MM:SS`)
**fills.csv** (append ทุก OrderSend ที่ได้ fill) — `time,magic,leg,symbol,action(open|close),side(buy|sell),lot,requested,fill,slip_points,latency_ms,spread_points,retcode,reason`
- `slip_points` = (fill − requested)/point × (+1 ถ้า buy / −1 ถ้า sell) → **ค่าบวก = แย่สำหรับเรา** • `latency_ms` = `GetMicrosecondCount()` รอบ OrderSend / 1000

**trades.csv** (append ตอนปิดไม้) — `ticket,magic,leg,symbol,side,lot,open_time,open_price,close_time,close_price,sl,tp,profit,commission,swap,exit_reason,risk_planned,risk_actual`

**equity_snap.csv** (ทุก 5 นาที) — `time,balance,equity,floating,day_start_balance,breaker_limit`

**status.json** (เขียนทับทุก 30 วินาที) — `heartbeat, ea_version, strategy, symbol, tf, server, account_mode(DEMO|CONTEST|REAL), live_guard(OK|BLOCKED), connected, balance, equity, day_start_balance, breaker_limit, halted, spread_now, spread_max, session_open, holiday_today, next_news{event,time,minutes}, news_window_active, holidays_covered_until, news_covered_until, open_positions[{ticket,side,lot,entry,sl,tp,age_min,pl}]`

### เพิ่มจาก implement จริง (T-034, c655103)
- **status.json** มี field เพิ่ม: `heartbeat_utc`, `bid`, `ask`, `atr_m15`, `atr_d1` ($), `asian{high,low,width}`, `risk_at_sl` ต่อ position
- **spread_snap.csv** (ใหม่) — snapshot spread สำหรับ panel "Gold spread by hour" (ไม่บันทึกตอนตลาดปิด)
- **fills.csv มีแถวที่ไม่ได้ fill (`fill = 0`, เช่น requote/reject)** → dashboard ต้อง **กรอง `fill > 0` ก่อนคำนวณ slip** และแสดงจำนวน reject แยก
- slip ขาออกของไม้ที่ปิดด้วย SL/TP มาจาก OnTradeTransaction (requested = ระดับ SL/TP)
- ข้อจำกัด v1: เขียนไฟล์ล้มเหลวไม่ retry • `risk_planned/actual` = 0 ถ้า EA restart ระหว่างถือไม้ • `breaker_limit` คำนวณซ้ำฝั่ง Telemetry (ดู T-038)

## Panels (ดัดแปลงจากภาพ reference)
| Panel | ที่มาในภาพ | SmartEA v1 |
|---|---|---|
| Header | ชื่อ, RUNNING, regime, server, spread, ping, news, server/NY time | ชื่อ+version+strategy+symbol/TF • **RUNNING/STALE** (heartbeat < 90s) • badge **DEMO / REAL-BLOCKED** • spread now/avg/max • ข่าวถัดไป + นับถอยหลัง • server time + New York time |
| ~~License card~~ | LICENSED / TRIAL / EXPIRES | **ตัดทิ้ง** → แทนด้วย **Safety card**: live guard, breaker headroom, และ **Data coverage**: holidays/news ครอบคลุมถึง 31 ธ.ค. ปี X · เหลือ N วัน (เหลือง ≤ 30 วัน, แดง = หมด → EA หยุดเปิดไม้เอง) |
| KPI tiles | balance, equity, today, week, month, return, DD | เหมือนกัน + DD วัดจาก equity_snap |
| Legs | ผลแยกตาม leg | **leg = magic number** (1 magic ต่อกลยุทธ์/instance) • today, month, trades, win%, PF, per-trade, 20 ไม้ล่าสุด (เขียว/แดง) |
| Execution quality | entry/exit median, p90, worst, latency, slip cost, slip vs edge, broker grade, slip by hour | **เหมือนกันทั้งหมด** — นี่คือแกนหลัก • slip vs edge = slip cost ÷ gross profit ก่อน slip • grade: A ≤ 0.3 pt median & p90 ≤ 1.5, B ≤ 0.6/2.5, C อื่นๆ |
| Open now | positions + trail | ticket, side, lot, entry, SL, TP, อายุ, P/L, **risk ที่ SL ($ และ %)** |
| Guards | regime, news, spread, DD, hours, audit | breaker headroom, D4, spread vs max, news window, holiday, session hours, connected, telemetry heartbeat |
| Daily P/L calendar + Equity | ปฏิทินรายวัน, equity เทียบ "without slippage" | เหมือนกัน (equity จริง vs equity + slip cost สะสม) |

## XAUUSD-specific panels (เพิ่มเพราะ focus ทอง)
| Panel | เนื้อหา |
|---|---|
| **Gold header** | ราคา bid/ask, spread เป็น points **และ $ ต่อ 0.01 lot**, ATR(14) M15/D1 ในหน่วย $, กรอบเอเชียของวันนี้ (high/low/ความกว้าง เทียบ 1.5×ATR D1) |
| **By session** | P/L, จำนวนไม้, slip median แยก เอเชีย (01–10) / London (10–15:30) / NY (15:30–23:30) server time |
| **News days** | ผลและ slip ของไม้ในวัน NFP / CPI / FOMC เทียบวันปกติ + ไม้ที่ถูก news filter ข้าม |
| **Swap** | swap สะสม long/short (ทอง long ≈ −$57/lot/คืน) — สำคัญถ้าเปิด S-B (ถือข้ามคืน) |
| **Gold spread by hour** | spread median/p95 รายชั่วโมงจาก status snapshots — เห็นช่วง rollover / เปิดตลาด |

## Owner decisions (ค่า default ที่ใช้ถ้าไม่แก้)
| # | เรื่อง | Default |
|---|---|---|
| DB1 | รูปแบบ | HTML ไฟล์เดียวบนเครื่อง (Python, ไม่มี dependency นอก stdlib, ไม่โหลดอะไรจากอินเทอร์เน็ต) — **ไม่ใช้ hosted page** เพราะจะต้องส่งข้อมูลบัญชีขึ้น cloud |
| DB2 | ปุ่มควบคุม | ไม่มี (read-only) |
| DB3 | License panel | ตัดทิ้ง → Safety + Data coverage |
