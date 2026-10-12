//+------------------------------------------------------------------+
//|                                                      Types.mqh   |
//|  ชนิดข้อมูลที่ใช้ร่วมกันระหว่างชั้น Signals -> Risk -> Execution    |
//+------------------------------------------------------------------+
#ifndef SMARTEA_CORE_TYPES_MQH
#define SMARTEA_CORE_TYPES_MQH

//--- ทิศทางของสัญญาณ
enum ENUM_SIGNAL_DIR
  {
   SIGNAL_SELL = -1,
   SIGNAL_NONE = 0,
   SIGNAL_BUY  = 1
  };

//--- ผลลัพธ์ของ Signal: Signal ไม่รู้เรื่อง lot / เงิน — บอกแค่ทิศทางกับระยะ SL/TP
struct SSignalIntent
  {
   ENUM_SIGNAL_DIR dir;
   double          sl_distance;   // ระยะ SL เป็น "ราคา" (เช่น 5.00 สำหรับทอง) ต้อง > 0 เมื่อ dir != NONE
   double          tp_distance;   // 0 = ไม่มี TP
   string          reason;        // เหตุผลสั้นๆ สำหรับ log / comment (<= 20 ตัวอักษร)

   void Reset()
     {
      dir         = SIGNAL_NONE;
      sl_distance = 0.0;
      tp_distance = 0.0;
      reason      = "";
     }
  };

//--- ปัดราคา SL ลง tick grid แบบ "เข้าหา entry" เสมอ (BUY ปัดขึ้น, SELL ปัดลง)
//--- เพื่อไม่ให้ SL จริงอยู่ไกลกว่าที่ใช้คำนวณ lot (risk ไม่เกิน %) — ใช้ร่วมกันทั้ง Risk และ Execution
//--- tick <= 0 -> ใช้ grid ตาม digits (10^-digits); 1e-9 กัน floating noise ไม่ใช่การปัดเพิ่ม
double NormalizeSlToTick(const double price, const double tick_in, const int digits, const bool buy)
  {
   const double tick = (tick_in > 0.0) ? tick_in : MathPow(10.0, -digits);
   double n = price / tick;
   const double eps = 1e-9 * MathMax(1.0, MathAbs(n));   // relative: ราคา/tick สูงๆ (BTC, index) noise โตตาม
   n = buy ? MathCeil(n - eps) : MathFloor(n + eps);
   return(NormalizeDouble(n * tick, digits));
  }

double NormalizeSlPrice(const string symbol, const ENUM_SIGNAL_DIR dir, const double price)
  {
   return(NormalizeSlToTick(price, SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE),
                            (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS), dir == SIGNAL_BUY));
  }

#endif
//+------------------------------------------------------------------+
