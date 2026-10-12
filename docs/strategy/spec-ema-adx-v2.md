# Strategy Spec — EMA+ADX v2 (research variants)

**Status:** APPROVED for research (Owner 2026-10-12: V1/V2/V3 ตามที่เสนอใน v2-options.md) • ใช้ได้กับ **in-sample 2023–2024 เท่านั้น** จนกว่าจะผ่าน pre-validation bar
**ฐาน:** spec v1 (`spec-ema-adx.md`) ทุกข้อคงเดิม — v2 เพิ่ม **feature flag** 4 ตัว ค่า default = ปิดทั้งหมด = พฤติกรรม v1 เป๊ะ

## Feature flags
| Flag (input) | Default | เมื่อเปิด | พารามิเตอร์ (fixed — ห้าม optimize ใน Phase 3) |
|---|---|---|---|
| `InpUseHTFFilter` (V2a) | false | BUY ได้เฉพาะเมื่อ `close(H4)[1] > EMA50(H4)[1]`, SELL เฉพาะเมื่อ `<` — ใช้แท่ง H4 **ที่ปิดแล้ว** เท่านั้น (กัน look-ahead) | `InpHTFTimeframe = PERIOD_H4`, `InpHTFEMA = 50` |
| `InpUseNewsFilter` (V2b) | false | ไม่เปิดไม้ใหม่ถ้า server time อยู่ในช่วง ±`InpNewsWindowMin` นาทีของเหตุการณ์ใน `data/files/news.csv` • ไม้ที่ถืออยู่ไม่ถูกปิด (SL คุมแล้ว) • fail closed ถ้าปีไม่อยู่ใน covered_years หรืออ่านไฟล์ไม่ได้ (เหมือน holidays) • `#property tester_file "SmartEA\\news.csv"` | `InpNewsWindowMin = 30` |
| `InpNoReverse` (V2c) | false | cross สวน = ปิดอย่างเดียว และห้ามเปิดไม้ใหม่ (ทุกทิศ) จนกว่าจะผ่าน `InpReentryBars` แท่งหลังปิด | `InpReentryBars = 4` |
| `InpUseOppositeExit` (V2d) | **true** | false = ไม่ปิดเมื่อ cross สวน (ปิดด้วย SL/TP/time exit เท่านั้น); cross สวนขณะถือไม้ = ไม่ทำอะไร | — |

- Flags ทั้งหมดอยู่ในชั้น Signal/Expert — **ห้ามแตะ RiskManager / Config**
- Log ทุกครั้งที่ flag ปฏิเสธสัญญาณ: `TRADE SKIP | <reason>` (เช่น `HTF filter: close 2010.5 < EMA50 2015.2`, `news CPI 15:30 ±30m`)

## Regression (ต้องผ่านก่อนรัน variant ใดๆ)
flags ทั้งหมดเป็นค่า default + Model=1 + ema_v1.set → **426 ไม้, net หลังหัก commission −3,777.38** เท่ากับ T-014 ทุกตัว

## Experiments (บันทึกใน `docs/strategy/experiments.md`)
- in-sample 2023-01-01 → 2024-12-31, **Model=4**, commission 7.0, ใช้ report_stats.py
- 1 flag ต่อ run (E2–E5) → รวมเฉพาะ flag ที่ "ช่วยจริง" (PF ดีขึ้น **และ** DD ไม่แย่ลง เทียบ E1) เป็น E6 = v2
- **Pre-validation bar (E6):** PF ≥ 1.1, trades ≥ 100, MaxDD ≤ 25% (หลังหัก commission)
- ไม่ผ่าน → หยุด รายงาน Owner (V3) — ห้ามเพิ่ม variant / ห้ามปรับพารามิเตอร์
