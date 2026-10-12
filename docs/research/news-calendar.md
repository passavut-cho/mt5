# News calendar 2023–2024 — ผลตรวจ (T-023, 2026-10-12)

ตรวจทั้ง 64 แถวของ `data/files/news.csv` กับแหล่งทางการ → **ถูกต้องทุกแถว ไม่มีการแก้วันที่**

| ชุด | แถว | แหล่ง |
|---|---|---|
| NFP (Employment Situation) 24 | verified=`bls` | https://www.bls.gov/schedule/2023/home.htm , https://www.bls.gov/schedule/2024/home.htm |
| CPI 24 | verified=`bls` | แหล่งเดียวกัน (release 08:30 ET ทุกครั้ง = 15:30 server) |
| FOMC 16 (วันออก statement) | verified=`fed` | https://www.federalreserve.gov/monetarypolicy/fomccalendars.htm |

- FOMC 2024-11-07 (พฤหัส) และ 2024-06-12 (CPI + FOMC วันเดียวกัน) ยืนยันแล้วว่าถูก
- เวลา 14:00 ET ของ FOMC ไม่ได้อยู่ในหน้าที่ตรวจ (ตรวจเฉพาะวัน) — เป็นเวลามาตรฐานของ statement
- ปี 2025+ ยังไม่อยู่ใน covered_years (fail closed) ต้องเติมก่อนใช้ validation/OOS
