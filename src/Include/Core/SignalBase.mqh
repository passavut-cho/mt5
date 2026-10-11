//+------------------------------------------------------------------+
//|                                                   SignalBase.mqh |
//|  Abstract signal — Signal ไม่รู้เรื่อง lot / account / order      |
//+------------------------------------------------------------------+
#ifndef SMARTEA_CORE_SIGNALBASE_MQH
#define SMARTEA_CORE_SIGNALBASE_MQH

#include "Types.mqh"
#include "Logger.mqh"

class CSignalBase
  {
public:
   virtual          ~CSignalBase() {}
   virtual bool      Init(const string symbol, const ENUM_TIMEFRAMES tf, CLogger *log) = 0;
   virtual void      Deinit() = 0;                        // IndicatorRelease ทุก handle
   virtual bool      Evaluate(SSignalIntent &out) = 0;    // false = ข้อมูลไม่พร้อม (ไม่ใช่ "ไม่มีสัญญาณ")
   virtual string    Name() const = 0;
  };

#endif
