//+------------------------------------------------------------------+
//|                                                     Logger.mqh   |
//|  Log ทางเดียวของโปรเจกต์ — prefix ด้วย tag + magic + symbol         |
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
   string         m_prefix;
   ENUM_LOG_LEVEL m_min_level;

   void           Write(const ENUM_LOG_LEVEL level, const string msg) const;

public:
                  CLogger() : m_prefix("[SmartEA]"), m_min_level(LOG_INFO) {}

   //--- disable_debug_in_tester: ใน Strategy Tester (ไม่ใช่ visual) ปิด DEBUG เพื่อไม่ให้ journal บวม
   void           Init(const string tag, const ulong magic, const ENUM_LOG_LEVEL min_level,
                       const bool disable_debug_in_tester = true);

   void           Debug(const string msg) const { Write(LOG_DEBUG, msg); }
   void           Info(const string msg)  const { Write(LOG_INFO,  msg); }
   void           Warn(const string msg)  const { Write(LOG_WARN,  msg); }
   void           Error(const string msg) const { Write(LOG_ERROR, msg); }

   //--- เข้า/ออก/ปฏิเสธไม้ — level INFO เสมอ (ไม่ถูกกรองด้วย min_level)
   void           Trade(const string action, const string details) const;
  };

//+------------------------------------------------------------------+
void CLogger::Init(const string tag, const ulong magic, const ENUM_LOG_LEVEL min_level,
                   const bool disable_debug_in_tester)
  {
   m_prefix    = StringFormat("[%s magic=%I64u %s]", tag, magic, _Symbol);
   m_min_level = min_level;

   bool in_tester = (MQLInfoInteger(MQL_TESTER) != 0 || MQLInfoInteger(MQL_OPTIMIZATION) != 0);
   bool visual    = (MQLInfoInteger(MQL_VISUAL_MODE) != 0);
   if(disable_debug_in_tester && in_tester && !visual && m_min_level < LOG_INFO)
      m_min_level = LOG_INFO;
  }

//+------------------------------------------------------------------+
void CLogger::Write(const ENUM_LOG_LEVEL level, const string msg) const
  {
   if(level < m_min_level)
      return;

   string lv = (level == LOG_DEBUG) ? "DEBUG" :
               (level == LOG_INFO)  ? "INFO"  :
               (level == LOG_WARN)  ? "WARN"  : "ERROR";
   Print(m_prefix, " ", lv, " ", msg);
  }

//+------------------------------------------------------------------+
void CLogger::Trade(const string action, const string details) const
  {
   Print(m_prefix, " TRADE ", action, " | ", details);
  }

#endif
//+------------------------------------------------------------------+
