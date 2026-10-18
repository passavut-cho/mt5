# Broker research — IC Markets (2026-10-12)

> สถานะ: ข้อมูลจากเอกสารสาธารณะ — **ต้องยืนยันด้วย `SymbolSpecDump` บน terminal จริง** (ตัวเลขใน terminal ชนะเอกสารเสมอ)

## Entity ที่ลูกค้าไทยน่าจะอยู่ใต้
- หน้า regulation ภาษาไทยของ IC ระบุนิติบุคคลเดียวคือ **Raw Trading Ltd** (Seychelles, FSA license SD018) ใช้ชื่อการค้า "IC" / "IC Markets Global"
- **ไม่ใช่ ASIC** — ASIC ครอบคลุมเฉพาะ entity ออสเตรเลีย
- ในไทย: ก.ล.ต. ไม่กำกับ Forex และไม่เคยออกใบอนุญาตให้ผู้ให้บริการ Forex ผ่านอินเทอร์เน็ตที่ไม่ใช่ธนาคาร/บล. → ไม่มีการคุ้มครองตามกฎหมายไทย
- แหล่ง: https://www.ic.com/th/company/regulation • https://www.pptvhd36.com/wealth/stock-investment/180854

## XAUUSD (Commodity Specification Sheet)
| รายการ | ค่า |
|---|---|
| Contract size | 100 oz / 1.00 lot |
| Min / Max volume | 0.01 / 100 lot |
| Commission (Raw Spread) | **USD 7 ต่อ lot round turn** (3.5 ต่อข้าง) |
| Margin call / Stop out | 100% / 50% |
| Max leverage (entity SC) | 1:2000 — ไม่เกี่ยวกับ risk ของเรา เพราะ lot คำนวณจาก % risk ไม่ใช่ margin |

แหล่ง: https://cdn.icmarkets.com/uploads/Commodity+Specification+Sheet.pdf

## ผลกระทบต่อการออกแบบ
- 1 lot × ราคาขยับ $1 = $100 → SL 5$ ที่ 1 lot = $500 ต่อไม้; บัญชี $10,000 risk 1% = $100 → ~0.20 lot (ก่อนหัก commission)
- Commission $7/lot round turn ≈ 7% ของ risk ต่อไม้ที่ SL $5 → **ควรนับ commission เข้าไปใน 1% risk** (ADR 0002 · D3)
- ต้องยืนยันจาก terminal: ชื่อ symbol, digits, stops level, filling mode, ประเภทบัญชี (hedging/netting), ความลึกของ history

## ยืนยันจาก terminal (SymbolSpecDump v1.10, 2026-10-12 03:15 เวลาไทย) — `data/files/specs_ICMarketsSC-Demo.tsv`
| รายการ | ค่า | หมายเหตุ |
|---|---|---|
| Server / company | ICMarketsSC-Demo / Raw Trading Ltd | ยืนยัน entity Seychelles |
| Margin mode | **RETAIL_HEDGING** | D6 netting guard เป็นแค่ safety net |
| Leverage | 1:500 | backtest ini ใช้ 1:100 — ไม่กระทบ lot (คำนวณจาก risk) แต่ margin check ต่างกัน |
| XAUUSD digits / point | 2 / 0.01 | 1 point = $0.01 ของราคา |
| Contract / tick value | 100 oz / $1 ต่อ tick ต่อ lot | |
| P/L ต่อ lot ต่อราคาขยับ $1 | −$100.00 | ตรงกับ spec sheet ✅ |
| Volume min / step / max | 0.01 / 0.01 / 100 | |
| Stops / freeze level | 0 / 0 | |
| Filling | IOC only | CTrade.SetTypeFillingBySymbol จัดการแล้ว |
| Swap long / short | −57.03 / +39.77 points ต่อ lot ต่อคืน | ≈ −$57 / +$40 ต่อ lot ต่อคืน (พุธ ×3) — ต้องนับใน spec ถ้าถือข้ามคืน |
| Margin ต่อ lot | ~$839 | ที่ราคาประมาณ 4,195 |
| M1 history แรกบน server | 1998-04-22 | ⚠️ **แค่วันที่แท่งแรก** — M1 เต็มจริงเริ่ม **2017** (2016 รายชั่วโมง, ก่อนนั้นแทบว่าง) • real ticks เริ่ม 2026-04 (T-021, T-030) |
| Spread (แท่ง M1 7 วัน, 6,883 แท่ง) | avg 7.3 • median 6 • p95 11 • max 40 points | = $0.07 / $0.06 / $0.11 / $0.40 |
| Spread ตอนรัน | 50 points | รันช่วงตลาดเพิ่งเปิด/rollover — spread กว้างผิดปกติ |

ยังไม่ได้ยืนยัน: commission $7/lot (spec ไม่บอก commission) → ดูจาก deal แรกบน demo

