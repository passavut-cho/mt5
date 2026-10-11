//+------------------------------------------------------------------+
//|                                                    BarClock.mqh  |
//|  ตรวจแท่งใหม่ — คืน true ครั้งเดียวต่อแท่ง                          |
//+------------------------------------------------------------------+
#ifndef SMARTEA_CORE_BARCLOCK_MQH
#define SMARTEA_CORE_BARCLOCK_MQH

class CBarClock
  {
private:
   string          m_symbol;
   ENUM_TIMEFRAMES m_tf;
   datetime        m_last_bar;

public:
                   CBarClock() : m_symbol(""), m_tf(PERIOD_CURRENT), m_last_bar(0) {}

   void            Init(const string symbol, const ENUM_TIMEFRAMES tf)
     {
      m_symbol   = symbol;
      m_tf       = tf;
      m_last_bar = 0;
     }

   //--- เรียกครั้งแรกหลัง Init จะจำแท่งปัจจุบันไว้แล้วคืน false
   //--- (ไม่ลงมือกลางแท่งที่ EA เพิ่งเริ่ม) — แท่งถัดไปจึงคืน true
   bool            IsNewBar()
     {
      datetime t = iTime(m_symbol, m_tf, 0);
      if(t == 0)
         return(false);          // ข้อมูลยังไม่พร้อม
      if(m_last_bar == 0)
        {
         m_last_bar = t;
         return(false);
        }
      if(t == m_last_bar)
         return(false);
      m_last_bar = t;
      return(true);
     }
  };

#endif
//+------------------------------------------------------------------+
