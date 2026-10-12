# Experiments log — ทุก run ที่ใช้ตัดสินกลยุทธ์ (รวมที่แพ้)

> กติกา: เขียน hypothesis **ก่อน** รัน • ห้ามลบแถว • ช่วงข้อมูลระบุทุกแถว • ตัวเลขหลังหัก commission 7.0 (report_stats.py)
> in-sample = 2023-01-01→2024-12-31 • validation (2025) ต้องบวก validation_looks ใน STATUS.md

| ID | วันที่ | Variant / flags | Hypothesis (เขียนก่อนรัน) | Data / Model | Trades | PF | Net | MaxDD | ผล |
|---|---|---|---|---|---|---|---|---|---|
| E0 | 2026-10-12 | v1 (ema_v1.set) | baseline | in-sample / M1 OHLC | 426 | 0.82 | −3,777.38 | 42.3% | ไม่มี edge (T-014) |
| E1 | 2026-10-12 | v1 | Model=4 จะให้ผลใกล้ E0 (±10% PF) | in-sample / **every-tick สังเคราะห์** (ไม่มี real ticks 2023–24) | 426 | 0.81 | −3,815.91 | 42.5% | ≈ E0 (±1%) — real ticks ใช้ไม่ได้ช่วงนี้ (T-021) |
| E2 | | V2a HTF filter | ตัด short ที่สวนเทรนด์ H4 → PF ↑, DD ↓ | in-sample / M1 OHLC (+stress 20) | | | | | |
| E3 | | V2b news ±30m | ตัดไม้เวลาข่าว → variance ↓, PF ไม่แย่ลง | in-sample / M1 OHLC (+stress 20) | | | | | |
| E4 | | V2c no-reverse 4 bars | ลด whipsaw → trades ↓, PF ↑ | in-sample / M1 OHLC (+stress 20) | | | | | |
| E5 | | V2d no opposite exit | ปล่อย winner ไปถึง TP → payoff ↑ แต่ DD อาจ ↑ | in-sample / M1 OHLC (+stress 20) | | | | | |
| E6 | | v2 = รวม flag ที่ช่วยจริงจาก E2–E5 | ผ่าน bar PF ≥ 1.1, trades ≥ 100, DD ≤ 25% | in-sample / M1 OHLC (+stress 20) | | | | | |
