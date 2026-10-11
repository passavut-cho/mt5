//+------------------------------------------------------------------+
//|                                                     SmartEA.mq5  |
//|  Phase 1 — Core framework: Signal -> Risk -> Execution           |
//|  (signal ตอนนี้ = CSignalNone จึงยังไม่เปิดไม้ — ใช้ smoke test)     |
//+------------------------------------------------------------------+
#property copyright "Phas"
#property version   "1.00"   // รูปแบบ xxx.yyy ตาม MQL5 Market; ใช้ git tag บอก phase แทน
#property description "SmartEA framework — Phase 1 core (CSignalNone: no entries)"

#include <SmartEA/Core/Types.mqh>
#include <SmartEA/Core/Logger.mqh>
#include <SmartEA/Core/LiveGuard.mqh>
#include <SmartEA/Core/BarClock.mqh>
#include <SmartEA/Core/SignalBase.mqh>
#include <SmartEA/Core/RiskManager.mqh>
#include <SmartEA/Core/TradeManager.mqh>
#include <SmartEA/Signals/SignalNone.mqh>

//--- inputs
input bool           InpAllowLive         = false;     // อนุญาตบัญชีจริง — ผู้ใช้เท่านั้นที่เปิดได้
input ulong          InpMagic             = 260101;    // Magic number ของ EA นี้
input double         InpRiskPct           = 1.0;       // Risk ต่อไม้ % ของ equity (เพดาน 1.0)
input double         InpDailyLossPct      = 3.0;       // Daily loss ทั้งบัญชี % (เพดาน 3.0)
input int            InpMaxPositions      = 1;         // จำนวนไม้เปิดพร้อมกันสูงสุด (magic+symbol)
input double         InpCommissionPerLot  = 7.0;       // Commission round turn ต่อ 1 lot (สกุลเงินบัญชี)
input int            InpMaxSpreadPoints   = 0;         // spread สูงสุดที่เปิดไม้ได้ (points), 0 = ไม่จำกัด
input uint           InpDeviationPoints   = 20;        // slippage สูงสุด (points)
input ENUM_LOG_LEVEL InpLogLevel          = LOG_INFO;  // ระดับ log (DEBUG ถูกปิดใน tester)

//--- objects (symbol/timeframe มาจาก _Symbol/_Period)
CLogger      g_log;
CBarClock    g_clock;
CRiskManager g_risk;
CTradeManager g_trade;
CSignalBase *g_signal = NULL;

//+------------------------------------------------------------------+
void ReleaseSignal()
  {
   if(g_signal != NULL)
     {
      g_signal.Deinit();     // IndicatorRelease ทุก handle
      delete g_signal;
      g_signal = NULL;
     }
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   g_log.Init("SmartEA", InpMagic, InpLogLevel);

   if(!CheckLiveGuard(InpAllowLive, g_log))
      return(INIT_FAILED);

   if(!g_risk.Init(_Symbol, InpMagic, GetPointer(g_log), InpRiskPct, InpDailyLossPct,
                   InpMaxPositions, InpCommissionPerLot, InpMaxSpreadPoints))
      return(INIT_PARAMETERS_INCORRECT);

   if(!g_trade.Init(_Symbol, InpMagic, GetPointer(g_log), InpDeviationPoints))
      return(INIT_FAILED);

   g_signal = new CSignalNone();
   if(g_signal == NULL || !g_signal.Init(_Symbol, _Period, GetPointer(g_log)))
     {
      g_log.Error("signal init failed");
      ReleaseSignal();
      return(INIT_FAILED);
     }

   g_clock.Init(_Symbol, _Period);
   g_log.Info(StringFormat("ready: signal=%s symbol=%s tf=%s", g_signal.Name(), _Symbol, EnumToString(_Period)));
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ReleaseSignal();
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   if(!g_clock.IsNewBar())
      return;

   //--- 1) Risk gate: daily breaker, max positions, spread
   string why = "";
   if(!g_risk.CanOpen(why))
     {
      g_log.Debug("skip bar: " + why);
      return;
     }

   //--- 2) Signal (คำนวณบนแท่งที่ปิดแล้วภายใน Signal เอง)
   SSignalIntent intent;
   intent.Reset();
   if(!g_signal.Evaluate(intent))
     {
      g_log.Warn("signal data not ready: " + g_signal.Name());
      return;
     }
   if(intent.dir == SIGNAL_NONE)
      return;

   //--- 3) Risk sizing
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
     {
      g_log.Trade("REJECT", "no tick for entry price");
      return;
     }
   double entry = (intent.dir == SIGNAL_BUY) ? tick.ask : tick.bid;
   double lot   = 0.0;
   if(!g_risk.CalcLot(intent, entry, lot, why))
     {
      g_log.Trade("REJECT", StringFormat("%s | %s", intent.reason, why));
      return;
     }

   //--- 4) Execution (SL/magic ส่งพร้อม order)
   double sl = g_risk.SlPrice(intent.dir, entry, intent.sl_distance);
   double tp = g_risk.TpPrice(intent.dir, entry, intent.tp_distance);
   g_trade.Open(intent.dir, lot, sl, tp, intent.reason);
  }
//+------------------------------------------------------------------+
