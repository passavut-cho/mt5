//+------------------------------------------------------------------+
//|                                                      Logger.mqh  |
//|  Logger กลาง — ที่เดียวในโปรเจกต์ที่เรียก Print ได้               |
//|  prefix: [tag|magic|symbol]                                      |
//+------------------------------------------------------------------+
#ifndef SMARTEA_CORE_LOGGER_MQH
#define SMARTEA_CORE_LOGGER_MQH

enum ENUM_LOG_LEVEL
  {
   LOG_DEBUG = 0,
   LOG_INFO  = 1,
   LOG_WARN  = 2,
   LOG_ERROR = 3
  };

class CLogger
  {
private:
   ENUM_LOG_LEVEL    m_min_level;
   string            m_prefix;

   void              Write(const ENUM_LOG_LEVEL level, const string msg) const
     {
      if(level < m_min_level)
         return;
      string label = (level == LOG_DEBUG) ? "DEBUG" :
                     (level == LOG_INFO)  ? "INFO"  :
                     (level == LOG_WARN)  ? "WARN"  : "ERROR";
      Print(m_prefix, label, " ", msg);
     }

public:
                     CLogger() : m_min_level(LOG_INFO), m_prefix("[SmartEA] ") {}

   //--- mute_debug_in_tester: ใน Strategy Tester ลด DEBUG ทิ้งเพื่อไม่ให้ journal บวม
   void              Init(const string tag, const ulong magic, const ENUM_LOG_LEVEL min_level,
                          const bool mute_debug_in_tester = true)
     {
      m_min_level = min_level;
      if(mute_debug_in_tester && MQLInfoInteger(MQL_TESTER) != 0 && m_min_level < LOG_INFO)
         m_min_level = LOG_INFO;
      m_prefix = StringFormat("[%s|%I64u|%s] ", tag, magic, _Symbol);
     }

   void              Debug(const string msg) const { Write(LOG_DEBUG, msg); }
   void              Info(const string msg)  const { Write(LOG_INFO,  msg); }
   void              Warn(const string msg)  const { Write(LOG_WARN,  msg); }
   void              Error(const string msg) const { Write(LOG_ERROR, msg); }

   //--- เข้า/ออก/ปฏิเสธไม้ — INFO เสมอ (action เช่น OPEN, CLOSE, REJECT)
   void              Trade(const string action, const string details) const
     {
      Write(LOG_INFO, StringFormat("TRADE %s | %s", action, details));
     }
  };

#endif
