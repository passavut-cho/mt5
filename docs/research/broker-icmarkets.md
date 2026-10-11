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

## ยังต้องเก็บ (รัน SymbolSpecDump)
- [ ] spread จริง (avg / median / p95) ของ XAUUSD บน IC Raw demo
- [ ] margin mode ของบัญชี
- [ ] วันที่ของแท่ง M1 แรกบน server (ความลึก history สำหรับ Phase 3)
