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
- in-sample 2023-01-01 → 2024-12-31, **Model=1** (R1) + cost stress +20 points/round turn, commission 7.0, ใช้ report_stats.py
- 1 flag ต่อ run (E2–E5) → รวมเฉพาะ flag ที่ "ช่วยจริง" (PF ดีขึ้น **และ** DD ไม่แย่ลง เทียบ E1) เป็น E6 = v2
- **Pre-validation bar (E6):** base PF ≥ 1.1 **และ** stress PF ≥ 1.0, trades ≥ 100, MaxDD ≤ 25% (หลังหัก commission)
- ไม่ผ่าน → หยุด รายงาน Owner (V3) — ห้ามเพิ่ม variant / ห้ามปรับพารามิเตอร์

## Data limitation (T-021, 2026-10-12) — **Owner อนุมัติ R1–R3 ตามที่เสนอ (2026-10-12)**
**ข้อเท็จจริง:** IC demo มี real ticks XAUUSD เฉพาะ 2026-04 → 2026-10 • ปี 2023–2024 tester ตกไปใช้ "every tick" สังเคราะห์จากแท่ง M1 (History Quality 0% real) ได้ผลเท่า Model=1 ±1% (426/426 ไม้ตรงกัน, exit type ตรงกันทุกไม้)
**ผลที่ตามมา:** Model=4 ในช่วง in-sample/validation ไม่ได้ให้ข้อมูลเพิ่ม — แต่ช่วง **OOS (2026-01→09) มี real ticks ตั้งแต่ เม.ย.** = ใช้ตรวจ execution จริงได้ตอนท้าย

| # | คำถาม | ข้อเสนอ Cowork | เหตุผล |
|---|---|---|---|
| R1 | Phase 3 research ใช้ข้อมูลแบบไหน | **Model=1 + cost stress +20 points/round turn** (≈ p95 spread ทองของ IC) • variant ต้องผ่าน bar ทั้ง base (PF ≥ 1.1) และ stress (PF ≥ 1.0) | เปรียบเทียบ variant ต่อกันได้ยุติธรรม; stress แทนความเสี่ยง spread/slippage ที่ M1 มองไม่เห็น |
| R2 | real ticks อยู่ตรงไหนในแผน | ย้ายไปเป็น **เงื่อนไข Phase 4: OOS 2026-04→09 ด้วย real ticks (รันครั้งเดียว)** + Phase 5 demo forward | ข้อมูลจริงที่มีอยู่ตรงกับช่วง holdout พอดี — ไม่ต้องลงแรงหา data ภายนอกก่อนรู้ว่ามีกลยุทธ์ที่คุ้มค่า |
| R3 | นำเข้า tick data ภายนอก (Dukascopy ฯลฯ) เป็น custom symbol | **ยังไม่ทำ** — ทำเฉพาะถ้า v2 ผ่าน validation แล้วต้องการความมั่นใจเพิ่ม | งานใหญ่ + spread/commission ของแหล่งอื่นไม่ใช่ของ IC ต้องปรับอีกชั้น |
