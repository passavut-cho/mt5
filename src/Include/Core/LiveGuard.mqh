//+------------------------------------------------------------------+
//|                                                    LiveGuard.mqh |
//|  Live guard (กฎเหล็กข้อ 1) — ย้ายมาจาก SmartEA.mq5 โดยไม่เปลี่ยน logic |
//|  - Tester / Optimization : ผ่านเสมอ                                |
//|  - Demo / Contest        : ผ่าน                                    |
//|  - Real                  : ผ่านเฉพาะเมื่อ allow_live = true         |
//+------------------------------------------------------------------+
#ifndef SMARTEA_CORE_LIVEGUARD_MQH
#define SMARTEA_CORE_LIVEGUARD_MQH

#include "Logger.mqh"

bool CheckLiveGuard(const bool allow_live, const CLogger &log)
  {
   if(MQLInfoInteger(MQL_TESTER) != 0 || MQLInfoInteger(MQL_OPTIMIZATION) != 0)
     {
      log.Info("live guard: OK (TESTER)");
      return(true);
     }

   ENUM_ACCOUNT_TRADE_MODE mode = (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);

   if(mode == ACCOUNT_TRADE_MODE_REAL && !allow_live)
     {
      log.Error("live guard: BLOCKED - real account and InpAllowLive=false");
      return(false);
     }

   string name = (mode == ACCOUNT_TRADE_MODE_DEMO)    ? "DEMO" :
                 (mode == ACCOUNT_TRADE_MODE_CONTEST) ? "CONTEST" : "REAL (InpAllowLive=true)";
   log.Info(StringFormat("live guard: OK (%s)", name));
   return(true);
  }

#endif
