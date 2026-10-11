//+------------------------------------------------------------------+
//|                                                     SmartEA.mq5  |
//|  Phase 0 — skeleton: ยังไม่เทรด มีแค่ live guard                  |
//+------------------------------------------------------------------+
#property copyright "Phas"
#property version   "1.00"   // รูปแบบ xxx.yyy ตาม MQL5 Market; ใช้ git tag บอก phase แทน
#property description "SmartEA framework — Phase 0 skeleton (no trading)"

//--- inputs
input bool  InpAllowLive = false;   // อนุญาตบัญชีจริง — ผู้ใช้เท่านั้นที่เปิดได้
input ulong InpMagic     = 260101;  // Magic number ของ EA นี้

//+------------------------------------------------------------------+
//| Live guard (กฎเหล็กข้อ 1)                                          |
//| - Tester / Optimization : ผ่านเสมอ                                |
//| - Demo / Contest        : ผ่าน                                    |
//| - Real                  : ผ่านเฉพาะเมื่อ InpAllowLive = true       |
//| TODO(P1): ย้ายไป Core/ และเปลี่ยน Print เป็น CLogger              |
//+------------------------------------------------------------------+
bool CheckLiveGuard()
  {
   if(MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION))
     {
      Print("[SmartEA] live guard: OK (TESTER)");
      return(true);
     }

   ENUM_ACCOUNT_TRADE_MODE mode = (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);

   if(mode == ACCOUNT_TRADE_MODE_REAL && !InpAllowLive)
     {
      Print("[SmartEA] live guard: BLOCKED - real account and InpAllowLive=false");
      return(false);
     }

   string name = (mode == ACCOUNT_TRADE_MODE_DEMO)    ? "DEMO" :
                 (mode == ACCOUNT_TRADE_MODE_CONTEST) ? "CONTEST" : "REAL (InpAllowLive=true)";
   PrintFormat("[SmartEA] live guard: OK (%s) magic=%I64u", name, InpMagic);
   return(true);
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   if(!CheckLiveGuard())
      return(INIT_FAILED);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   // P1: IndicatorRelease() ทุก handle ที่นี่
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   // Phase 0: ไม่เทรด — P1 จะต่อ Signal -> Risk -> Execution ที่นี่
  }
//+------------------------------------------------------------------+
