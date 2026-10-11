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

#endif
//+------------------------------------------------------------------+
