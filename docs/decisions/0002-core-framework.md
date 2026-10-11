# ADR 0002 — Core Framework (Phase 1)

**Status:** Accepted — D1–D3 ตัดสินโดย Owner 2026-10-12 • **Date:** 2026-10-12

## Context
Phase 1 ต้องมี Logger / RiskManager / TradeManager / SignalBase ที่แยกชั้นกันจริง เปลี่ยนกลยุทธ์โดยไม่แตะ Risk ได้
Broker เป้าหมายตอนนี้: IC Markets Raw (XAUUSD 100 oz/lot, commission $7/lot round turn) — ดู `docs/research/broker-icmarkets.md`

## Flow ต่อ 1 tick
```
OnTick
  └─ CBarClock.IsNewBar()? ── no ──► return
        │ yes
        ▼
  CRiskManager.CanOpen(why) ── false ──► log why, return       (daily breaker, max positions, spread, live guard)
        │ true
        ▼
  CSignalBase.Evaluate(intent)  ── intent.dir == 0 ──► return  (Signal ไม่รู้เรื่อง lot)
        │
        ▼
  CRiskManager.CalcLot(intent, entry, sl, lot, why) ── false ──► log, return
        │
        ▼
  CTradeManager.Open(intent.dir, lot, sl, tp, intent.reason)  (validate SL ก่อนส่งเสมอ)
        │
        ▼
  CLogger  ◄── ทุกชั้นเขียน log ผ่านตัวนี้
```

## Interface stubs (ไม่ใช่โค้ดเต็ม — strategy-dev / Claude Code เป็นคน implement)

```mql5
// Core/Types.mqh
enum ENUM_SIGNAL_DIR { SIGNAL_NONE = 0, SIGNAL_BUY = 1, SIGNAL_SELL = -1 };
struct SSignalIntent
  {
   ENUM_SIGNAL_DIR dir;
   double          sl_distance;   // ระยะ SL เป็น "ราคา" (เช่น 5.00 สำหรับทอง) > 0 เสมอเมื่อ dir != NONE
   double          tp_distance;   // 0 = ไม่มี TP
   string          reason;        // เหตุผลสั้นๆ สำหรับ log / comment (≤ 20 ตัวอักษร)
  };

// Core/Logger.mqh
enum ENUM_LOG_LEVEL { LOG_DEBUG, LOG_INFO, LOG_WARN, LOG_ERROR };
class CLogger
  {
public:
   void Init(const string tag, const ulong magic, const ENUM_LOG_LEVEL min_level);
   void Debug(const string msg); void Info(const string msg);
   void Warn(const string msg);  void Error(const string msg);
   void Trade(const string action, const string details);   // เข้า/ออก/ปฏิเสธไม้ — level INFO เสมอ
  };

// Core/BarClock.mqh
class CBarClock
  {
public:
   void Init(const string symbol, const ENUM_TIMEFRAMES tf);
   bool IsNewBar();               // true ครั้งเดียวต่อแท่ง
  };

// Core/SignalBase.mqh
class CSignalBase
  {
public:
   virtual bool   Init(const string symbol, const ENUM_TIMEFRAMES tf, CLogger *log) = 0;
   virtual void   Deinit() = 0;   // IndicatorRelease ทุก handle
   virtual bool   Evaluate(SSignalIntent &out) = 0;   // false = ข้อมูลไม่พร้อม (ไม่ใช่ "ไม่มีสัญญาณ")
   virtual string Name() const = 0;
  };
// Signals/SignalNone.mqh — คืน SIGNAL_NONE เสมอ (ใช้ smoke test)

// Core/RiskManager.mqh
class CRiskManager
  {
public:
   bool Init(const string symbol, const ulong magic, CLogger *log,
             const double risk_pct,            // ≤ 1.0 — ถ้าเกิน: INIT_PARAMETERS_INCORRECT
             const double daily_loss_pct,      // ≤ 3.0
             const int    max_positions,       // default 1
             const double commission_per_lot,  // round turn, สกุลเงินบัญชี (D3)
             const int    max_spread_points);  // 0 = ไม่จำกัด
   bool CanOpen(string &why);                  // daily breaker + max positions + spread
   bool CalcLot(const SSignalIntent &intent, const double entry, double &lot, string &why);
   void OnNewDay();                            // จับ balance ต้นวันใหม่
  };

// Core/TradeManager.mqh  (ห่อ CTrade)
class CTradeManager
  {
public:
   bool Init(const string symbol, const ulong magic, CLogger *log, const uint deviation_points);
   bool Open(const ENUM_SIGNAL_DIR dir, const double lot, const double sl, const double tp, const string comment);
   bool CloseAll(const string why);
   int  CountPositions();                       // กรอง magic + symbol
  };
```

## Decisions ที่ตัดสินแล้ว (technical)
- **Lot จาก `OrderCalcProfit()`** แทนสูตร tick value — ได้ขาดทุนจริงต่อ 1 lot ที่ราคา SL ในสกุลเงินบัญชี รองรับ symbol ข้ามสกุลเงินอัตโนมัติ
  `lot = floor_to_step( risk_money / (loss_per_lot + commission_per_lot) )` → ต่ำกว่า VOLUME_MIN = **ข้ามไม้** ไม่ปัดขึ้น
- **SL ส่งพร้อม order เสมอ**, ตรวจก่อนส่ง: ≠ 0, อยู่ฝั่งถูก, ห่างราคา ≥ `STOPS_LEVEL` — ไม่ผ่าน = ไม่ส่ง
- **Filling mode** ตั้งด้วย `CTrade::SetTypeFillingBySymbol()`
- **Retry** เฉพาะ `REQUOTE` / `PRICE_CHANGED` / `PRICE_OFF` สูงสุด 2 ครั้ง; retcode อื่น = log + ยกเลิก
- **Balance ต้นวันหลัง EA restart**: คำนวณย้อนจาก deal history ของวันนี้ (`balance_now − Σ profit+swap+commission ของ deal วันนี้`) ไม่ใช้ balance ตอน init
- **วัน** = วันตาม server time (`TimeTradeServer()`)
- **หนึ่ง position ต่อ magic+symbol** ไม่ว่าบัญชีจะเป็น hedging หรือ netting

## Owner decisions (2026-10-12)
- **D1 = (a)** daily loss วัดทั้งบัญชี: `equity_now ≤ day_start_balance × (1 − 3%)` (รวม floating ของทุกไม้ในบัญชี)
- **D2 = (a)** ถึง 3% → หยุดเปิดไม้ใหม่จนถึงวันใหม่ (server time) ไม้ที่เปิดอยู่ปล่อย SL/TP ทำงาน
- **D3 = (a)** นับ commission ใน 1% risk: `InpCommissionPerLot` (round turn, สกุลเงินบัญชี) default **7.0**

### ตัวเลือกที่พิจารณา
| # | คำถาม | ตัวเลือก | ข้อเสนอ |
|---|---|---|---|
| D1 | Daily loss 3% วัดจากอะไร | (a) ทั้งบัญชี: equity เทียบ balance ต้นวัน รวม floating • (b) เฉพาะไม้ของ EA นี้ (magic) | **(a)** — ปลอดภัยกว่า ถ้าวันหนึ่งรันหลาย EA หรือเทรดมือด้วยก็ยังหยุดถูก |
| D2 | ถึง 3% แล้วทำอะไร | (a) หยุดเปิดไม้ใหม่ ไม้ที่เปิดอยู่ปล่อยให้ SL/TP ทำงาน • (b) ปิดทุกไม้ทันที | **(a)** ตรงกับ CLAUDE.md อยู่แล้ว และไม้ทุกไม้มี SL จำกัดความเสียหายไว้แล้ว |
| D3 | นับ commission ใน 1% risk ไหม | (a) นับ: input `InpCommissionPerLot` • (b) ไม่นับ | **(a)** — ที่ IC ทอง $7/lot ≈ 7% ของ risk ต่อไม้ที่ SL $5 ไม่นับ = risk จริงเกิน 1% · default ในโค้ด = 7.0 (IC Raw) |

## Consequences
- Signal ใหม่ = ไฟล์ใหม่ใน `Signals/` + 1 บรรทัดใน Expert — ไม่แตะ Core
- RiskManager เป็นจุดเดียวที่มีตัวเลข risk → `settings.json` บังคับให้ถาม Owner ก่อนแก้
- ต้องมี `RiskSelfTest.mq5` ทดสอบ CalcLot กับตัวเลขจริงของ broker (เทียบกับ `pl_per_lot_per_1.00_move` จาก SymbolSpecDump)
