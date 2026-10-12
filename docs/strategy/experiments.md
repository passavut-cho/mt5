# Experiments log — ทุก run ที่ใช้ตัดสินกลยุทธ์ (รวมที่แพ้)

> กติกา: เขียน hypothesis **ก่อน** รัน • ห้ามลบแถว • ช่วงข้อมูลระบุทุกแถว • ตัวเลขหลังหัก commission 7.0 (report_stats.py)
> in-sample = 2023-01-01→2024-12-31 • validation (2025) ต้องบวก validation_looks ใน STATUS.md

| ID | วันที่ | Variant / flags | Hypothesis (เขียนก่อนรัน) | Data / Model | Trades | PF | Net | MaxDD | ผล |
|---|---|---|---|---|---|---|---|---|---|
| E0 | 2026-10-12 | v1 (ema_v1.set) | baseline | in-sample / M1 OHLC | 426 | 0.82 | −3,777.38 | 42.3% | ไม่มี edge (T-014) |
| E1 | 2026-10-12 | v1 | Model=4 จะให้ผลใกล้ E0 (±10% PF) | in-sample / **every-tick สังเคราะห์** (ไม่มี real ticks 2023–24) | 426 | 0.81 | −3,815.91 | 42.5% | ≈ E0 (±1%) — real ticks ใช้ไม่ได้ช่วงนี้ (T-021) |
| E2 | 2026-10-12 | V2a HTF filter | ตัด short ที่สวนเทรนด์ H4 → PF ↑, DD ↓ | in-sample / M1 OHLC (+stress 20) | 183 | 0.81 (stress 0.73) | −1,795.64 (stress −2,711.84) | 26.5% (stress 33.7%) | PF ไม่ดีขึ้น (0.82→0.81); trades −57%, DD ↓ จากจำนวนไม้ที่ลด; short ยังแพ้ PF 0.70 → hypothesis ไม่ยืนยัน |
| E3 | 2026-10-12 | V2b news ±30m | ตัดไม้เวลาข่าว → variance ↓, PF ไม่แย่ลง | in-sample / M1 OHLC (+stress 20) | 419 | 0.82 (stress 0.74) | −3,611.47 (stress −5,511.07) | 40.2% (stress 57.1%) | เกือบเท่า E0 (ตัดแค่ 7 ไม้); long PF 1.11 / short 0.61 → ไม่ช่วย edge |
| E4 | 2026-10-12 | V2c no-reverse 4 bars | ลด whipsaw → trades ↓, PF ↑ | in-sample / M1 OHLC (+stress 20) | 416 | 0.83 (stress 0.75) | −3,524.32 (stress −5,432.92) | 40.2% (stress 56.8%) | ดีขึ้นเล็กน้อยมาก (PF +0.01) ไม่มีนัยสำคัญ |
| E5 | 2026-10-12 | V2d no opposite exit | ปล่อย winner ไปถึง TP → payoff ↑ แต่ DD อาจ ↑ | in-sample / M1 OHLC (+stress 20) | 415 | 0.83 (stress 0.75) | −3,542.41 (stress −5,458.41) | 40.1% (stress 56.9%) | long PF 1.17 ดีขึ้น แต่ short 0.60; DD ไม่ลด → payoff ↑ เล็กน้อย |
| E6 | | v2 = รวม flag ที่ช่วยจริงจาก E2–E5 | ผ่าน bar PF ≥ 1.1, trades ≥ 100, DD ≤ 25% | in-sample / M1 OHLC (+stress 20) | | | | | |
