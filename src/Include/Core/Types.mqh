//+------------------------------------------------------------------+
//|                                                       Types.mqh  |
//|  ชนิดข้อมูลกลางที่ใช้ข้ามชั้น Signals -> Risk -> Execution         |
//+------------------------------------------------------------------+
#ifndef SMARTEA_CORE_TYPES_MQH
#define SMARTEA_CORE_TYPES_MQH

//--- ทิศทางสัญญาณ
enum ENUM_SIGNAL_DIR
  {
   SIGNAL_NONE =  0,
   SIGNAL_BUY  =  1,
   SIGNAL_SELL = -1
  };

//--- เจตนาของ Signal: บอกแค่ "ทิศ + ระยะ SL/TP" — ไม่รู้เรื่อง lot
struct SSignalIntent
  {
   ENUM_SIGNAL_DIR dir;
   double          sl_distance;   // ระยะ SL เป็น "ราคา" (เช่น 5.00 สำหรับทอง) > 0 เสมอเมื่อ dir != NONE
   double          tp_distance;   // 0 = ไม่มี TP
   string          reason;        // เหตุผลสั้นๆ สำหรับ log / comment (≤ 20 ตัวอักษร)

   void Reset()
     {
      dir         = SIGNAL_NONE;
      sl_distance = 0.0;
      tp_distance = 0.0;
      reason      = "";
     }
  };

#endif
