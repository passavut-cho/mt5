//+------------------------------------------------------------------+
//|                                                     SmartEA.mq5  |
//|  Phase 1 — Core framework: Signals -> Risk -> Execution          |
//|  Signal ตอนนี้เป็น CSignalNone (ไม่เทรด) ไว้ smoke test           |
//+------------------------------------------------------------------+
#property copyright "Phas"
#property version   "1.00"   // รูปแบบ x.yy; ใช้ git tag บอก phase แทน
#property description "SmartEA framework — Phase 1 core (CSignalNone: no signals)"

#include <SmartEA/Core/Types.mqh>
#include <SmartEA/Core/Logger.mqh>
#include <SmartEA/Core/BarClock.mqh>
#include <SmartEA/Core/SignalBase.mqh>
#include <SmartEA/Core/RiskManager.mqh>
#include <SmartEA/Core/TradeManager.mqh>
#include <SmartEA/Signals/SignalNone.mqh>

//--- inputs
input bool           InpAllowLive         = false;     // อนุญาตบัญชีจริง — ผู้ใช้เท่านั้นที่เปิดได้
input ulong          InpMagic             = 260101;    // Magic number ของ EA นี้
input double         InpRiskPct           = 1.0;       // % equity เสี่ยงต่อไม้ (เพดาน 1.0)
input double         InpDailyLossPct      = 3.0;       // % ขาดทุนรายวันทั้งบัญชี (เพดาน 3.0)
input int            InpMaxPositions      = 1;         // จำนวน position สูงสุดต่อ magic+symbol
input double         InpCommissionPerLot  = 7.0;       // commission round turn ต่อ lot (สกุลเงินบัญชี) IC Raw
input int            InpMaxSpreadPoints   = 0;         // spread สูงสุด (points) 0 = ไม่จำกัด
input uint           InpDeviationPoints   = 20;        // slippage ที่ยอมรับ (points)
input ENUM_LOG_LEVEL InpLogLevel          = LOG_INFO;  // ระดับ log (DEBUG ถูกปิดอัตโนมัติใน tester)

CLogger        g_log;
CBarClock      g_clock;
CRiskManager   g_risk;
CTradeManager  g_trade;
CSignalBase   *g_signal = NULL;

//+------------------------------------------------------------------+
//| Live guard (กฎเหล็กข้อ 1)                                          |
//| - Tester / Optimization : ผ่านเสมอ                                |
//| - Demo / Contest        : ผ่าน                                    |
//| - Real                  : ผ่านเฉพาะเมื่อ InpAllowLive = true       |
//+------------------------------------------------------------------+
bool CheckLiveGuard()
  {
   if(MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION))
     {
      g_log.Info("live guard: OK (TESTER)");
      return(true);
     }

   ENUM_ACCOUNT_TRADE_MODE mode = (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);

   if(mode == ACCOUNT_TRADE_MODE_REAL && !InpAllowLive)
     {
      g_log.Error("live guard: BLOCKED - real account and InpAllowLive=false");
      return(false);
     }

   string name = (mode == ACCOUNT_TRADE_MODE_DEMO)    ? "DEMO" :
                 (mode == ACCOUNT_TRADE_MODE_CONTEST) ? "CONTEST" : "REAL (InpAllowLive=true)";
   g_log.Info(StringFormat("live guard: OK (%s)", name));
   return(true);
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   g_log.Init("SmartEA", InpMagic, InpLogLevel);

   if(!CheckLiveGuard())
      return(INIT_FAILED);

   if(!g_risk.Init(_Symbol, InpMagic, &g_log, InpRiskPct, InpDailyLossPct, InpMaxPositions,
                   InpCommissionPerLot, InpMaxSpreadPoints))
      return(INIT_PARAMETERS_INCORRECT);

   if(!g_trade.Init(_Symbol, InpMagic, &g_log, InpDeviationPoints))
      return(INIT_FAILED);

   g_signal = new CSignalNone();
   if(g_signal == NULL || !g_signal.Init(_Symbol, _Period, &g_log))
     {
      g_log.Error("signal init ล้มเหลว");
      if(g_signal != NULL)
        {
         delete g_signal;
         g_signal = NULL;
        }
      return(INIT_FAILED);
     }

   g_clock.Init(_Symbol, _Period);
   g_log.Info(StringFormat("init OK: signal=%s tf=%s", g_signal.Name(), EnumToString(_Period)));
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_signal != NULL)
     {
      g_signal.Deinit();      // Signal ที่มี indicator ต้อง IndicatorRelease ใน Deinit
      delete g_signal;
      g_signal = NULL;
     }
   g_log.Info(StringFormat("deinit reason=%d", reason));
  }

void OpenWithRetry(const SSignalIntent &intent);

//+------------------------------------------------------------------+
//| Flow ต่อแท่งใหม่: Risk.CanOpen -> Signal -> Risk.CalcLot -> Trade  |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(!g_clock.IsNewBar())
      return;

   string why;
   if(!g_risk.CanOpen(why))
     {
      g_log.Debug("SKIP: " + why);   // DEBUG กัน journal บวมตอน position เปิดอยู่/breaker ทำงาน
      return;
     }

   SSignalIntent intent;
   intent.Reset();
   if(!g_signal.Evaluate(intent))
     {
      g_log.Warn("signal ข้อมูลไม่พร้อม");
      return;
     }
   if(intent.dir == SIGNAL_NONE)
      return;

   OpenWithRetry(intent);
  }

//+------------------------------------------------------------------+
//| D5: ทุก attempt (สูงสุด 1 + 2 retry) refresh ราคา -> CanOpen ->     |
//| CalcLot (SL/lot/D4 ใหม่ผ่าน RiskManager) -> Open แล้ว log risk จริง |
//+------------------------------------------------------------------+
void OpenWithRetry(const SSignalIntent &intent)
  {
   const int max_retry = 2;
   const bool buy = (intent.dir == SIGNAL_BUY);

   for(int attempt = 0; attempt <= max_retry; attempt++)
     {
      string why;
      if(attempt > 0 && !g_risk.CanOpen(why))      // attempt แรกผ่าน CanOpen มาแล้วใน OnTick
        {
         g_log.Trade("REJECT", StringFormat("%s : retry %d : %s", intent.reason, attempt, why));
         return;
        }

      MqlTick tick;
      if(!SymbolInfoTick(_Symbol, tick) || tick.ask <= 0.0 || tick.bid <= 0.0)
        {
         g_log.Error(StringFormat("SymbolInfoTick ล้มเหลว err=%d", GetLastError()));
         return;
        }
      double entry = buy ? tick.ask : tick.bid;

      double lot = 0.0;
      if(!g_risk.CalcLot(intent, entry, lot, why))
        {
         g_log.Trade("REJECT", StringFormat("%s : %s", intent.reason, why));
         return;
        }

      double sl = buy ? entry - intent.sl_distance : entry + intent.sl_distance;
      double tp = 0.0;
      if(intent.tp_distance > 0.0)
         tp = buy ? entry + intent.tp_distance : entry - intent.tp_distance;

      bool retryable = false;
      if(g_trade.Open(intent.dir, lot, sl, tp, intent.reason, retryable))
        {
         double risk_money = 0.0, risk_pct = 0.0;
         if(g_risk.ActualRisk(intent.dir, lot, g_trade.LastFillPrice(), g_trade.LastSl(), risk_money, risk_pct))
            g_log.Trade("RISK", StringFormat("actual_risk=%.2f (%.3f%% ของ equity) lot=%.2f fill=%.5f sl=%.5f",
                                             risk_money, risk_pct, lot, g_trade.LastFillPrice(), g_trade.LastSl()));
         else
            g_log.Warn("คำนวณ actual_risk หลัง fill ไม่ได้");
         return;
        }
      if(!retryable)
         return;
     }
   g_log.Trade("REJECT", StringFormat("%s : retry ครบ %d ครั้งแล้วยังไม่สำเร็จ", intent.reason, max_retry));
  }
//+------------------------------------------------------------------+
