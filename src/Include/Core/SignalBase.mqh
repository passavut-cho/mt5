//+------------------------------------------------------------------+
//|                                                  SignalBase.mqh  |
//|  Abstract class ของ Signal — Signal ไม่แตะ lot / order / risk      |
//+------------------------------------------------------------------+
#ifndef SMARTEA_CORE_SIGNALBASE_MQH
#define SMARTEA_CORE_SIGNALBASE_MQH

#include "Types.mqh"
#include "Logger.mqh"

class CSignalBase
  {
public:
   virtual         ~CSignalBase() {}

   virtual bool    Init(const string symbol, const ENUM_TIMEFRAMES tf, CLogger *log) = 0;
   virtual void    Deinit() = 0;                      // IndicatorRelease ทุก handle
   //--- คำนวณจากแท่งที่ปิดแล้ว (shift 1) เท่านั้น — ห้ามใช้แท่งที่กำลังวิ่ง
   //--- คืน false = ข้อมูลไม่พร้อม (ไม่ใช่ "ไม่มีสัญญาณ" — กรณีนั้นคืน true พร้อม dir = NONE)
   virtual bool    Evaluate(SSignalIntent &out) = 0;
   virtual string  Name() const = 0;
  };

#endif
//+------------------------------------------------------------------+
