//+------------------------------------------------------------------+
//|                                                   SignalNone.mqh |
//|  คืน SIGNAL_NONE เสมอ — ใช้ smoke test ว่ากรอบงานรันครบวงจร        |
//+------------------------------------------------------------------+
#ifndef SMARTEA_SIGNALS_SIGNALNONE_MQH
#define SMARTEA_SIGNALS_SIGNALNONE_MQH

#include "../Core/SignalBase.mqh"

class CSignalNone : public CSignalBase
  {
private:
   CLogger          *m_log;

public:
                     CSignalNone() : m_log(NULL) {}

   virtual bool      Init(const string symbol, const ENUM_TIMEFRAMES tf, CLogger *log)
     {
      m_log = log;
      if(m_log != NULL)
         m_log.Info(StringFormat("signal '%s' init on %s %s", Name(), symbol, EnumToString(tf)));
      return(true);
     }

   virtual void      Deinit() {}    // ไม่มี indicator handle

   virtual bool      Evaluate(SSignalIntent &out)
     {
      out.Reset();
      return(true);
     }

   virtual string    Name() const { return("None"); }
  };

#endif
