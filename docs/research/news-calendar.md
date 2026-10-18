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

---

# ขยายย้อนหลัง 2010–2022 (T-029, 2026-10-19)

`covered_years` ของ `news.csv` และ `holidays.csv` ตอนนี้ครอบคลุม 2010–2024 / 2010–2026 ตามลำดับ (ไม่ได้ใส่ 2027 — ดู T-018)

## news.csv (+417 แถว 2010–2022: NFP 156, CPI 156, FOMC 105 = 103 นัดปกติ + 2 นัดพิเศษ 2020)
| ชุด | verified | แหล่ง / วิธี |
|---|---|---|
| NFP (Employment Situation) | `bls` | https://www.bls.gov/schedule/{ปี}/home.htm ทุกปี 2010–2022 (08:30 ET = 15:30 server) |
| CPI | `bls` | แหล่งเดียวกัน (08:30 ET = 15:30 server) |
| FOMC | `fed` | **วัน** = วันจบการประชุมใน https://www.federalreserve.gov/monetarypolicy/fomchistorical{ปี}.htm (2021–2022 จาก fomccalendars.htm) • **เวลา** = ข้อความ "to be released at / for release at H:MM p.m." ใน FOMC minutes ของแต่ละนัด `fomcminutes{YYYYMMDD}.htm` (ดึง HTML ตรงด้วย curl + grep ครบ 103 นัด ไม่ผ่านตัวสรุป) แล้ว +7 ชม. |

เวลา FOMC ที่พบ (ET): 2010 ทุกนัด 14:15 • 2011: 14:15 ยกเว้น 04-27, 06-22, 11-02 = 12:30 • 2012: 12:30 ที่ 01-25, 04-25, 06-20, 09-13, 12-12, นอกนั้น 14:15 • 2013-01-30 14:15 • **2013-03-20 เป็นต้นไป 14:00 ทุกนัด** (ไม่มี 12:30 อีก)
นัดพิเศษ 2020 (จาก minutes ของ 03-15): 2020-03-03 10:00 ET (=17:00 server) และ **2020-03-15 17:00 ET (=00:00 server ของ 2020-03-16)**

### ไม่ได้ใส่ (ตั้งใจ)
- ประชุมทางโทรศัพท์/notation vote ที่ไม่มี statement นโยบายประกาศตลาด: 2010-05-09 (swap lines), 2010-10-15, 2011-08-01, 2011-11-28, 2013-10-16, 2014-03-04, 2019-10-04, 2020-03-19/23/31, 2020-08-27 — ยังไม่ได้ตรวจเวลา/ผลต่อราคาทอง จึงไม่เดาใส่
- วันที่ BLS เลื่อนจาก shutdown ปี 2013 ใช้วันที่จริงตาม archive (NFP 2013-10-22, CPI 2013-10-30)

## holidays.csv (+152 แถว 2010–2022)
- คำนวณตามกฎวันหยุดสหรัฐ (5 U.S.C. §6103 / ปฏิทิน federal) + Good Friday จากวัน Easter: ใช้ tag `fed` เหมือนแถว 2023–2025 เดิม (dates ตกเสาร์→เลื่อนศุกร์, ตกอาทิตย์→เลื่อนจันทร์)
- แถว early_close (วันหลัง Thanksgiving, 3 ก.ค., 24 ธ.ค., 31 ธ.ค.) tag `probable` ตามแนวเดิม
- **ยังไม่ได้เทียบกับประกาศ holiday trading hours ของ CME/IC รายปีย้อนหลัง** — แถวอาจเกิน (เช่น 2021-12-31, 2010-12-31 ที่ federal ถือเป็น observed แต่ CME อาจเปิด) ซึ่งเอนไปทาง "ไม่เปิดไม้" (ปลอดภัย) และอาจขาดวัน ad-hoc (เช่น 2018-12-05 Bush day of mourning, 2012-10-29/30 Sandy) ถ้า backtest พบไม้ที่ข้าม 23:30 ในวันนอกไฟล์ → เติมวันนั้น (กติกา backtest-analyst)
- Juneteenth เริ่มใส่ตั้งแต่ 2021 (federal holiday ตั้งแต่ปี 2021)
