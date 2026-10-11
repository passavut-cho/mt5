//+------------------------------------------------------------------+
//|                                                RiskSelfTest.mq5  |
//|  ทดสอบ CRiskManager ด้วย spec จริงของ broker (ไม่เทรด ไม่ส่ง order)  |
//|  วิธีใช้: ลากลง chart แล้วอ่านแท็บ Experts — ต้องจบด้วย "ALL PASS"   |
//|  เทียบสูตร OrderCalcProfit (ที่ RiskManager ใช้) กับสูตร tick value  |
//+------------------------------------------------------------------+
#property copyright   "Phas"
#property version     "1.00"
#property description "Self-test for CRiskManager lot sizing and daily breaker (read-only)"
#property script_show_inputs

#include <SmartEA/Core/Types.mqh>
#include <SmartEA/Core/Logger.mqh>
#include <SmartEA/Core/RiskManager.mqh>

input string InpSymbols       = "";    // ว่าง = symbol ของ chart, หลายตัวคั่นด้วย , เช่น XAUUSD,EURUSD
input double InpCommission    = 7.0;   // commission ต่อ lot ที่ใช้ทดสอบ (ควรเท่ากับค่าของ EA)
input ulong  InpMagic         = 260101;
input double InpTolerancePct  = 2.0;   // ความคลาดเคลื่อนที่ยอมรับได้ระหว่างสูตร OrderCalcProfit กับ tick value

CLogger g_log;
int     g_pass = 0;
int     g_fail = 0;

//--- บันทึกผลหนึ่งข้อ
void Check(const bool ok, const string name, const string detail = "")
  {
   if(ok)
     {
      g_pass++;
      g_log.Info("PASS  " + name + (detail == "" ? "" : "  [" + detail + "]"));
     }
   else
     {
      g_fail++;
      g_log.Error("FAIL  " + name + (detail == "" ? "" : "  [" + detail + "]"));
     }
  }

//+------------------------------------------------------------------+
//| 1) logic ของ breaker (pure function)                              |
//+------------------------------------------------------------------+
void TestBreaker()
  {
   Check(CRiskManager::IsDailyLossBreached(9700.00, 10000.0, 3.0),  "breaker: equity exactly at -3% trips");
   Check(!CRiskManager::IsDailyLossBreached(9700.01, 10000.0, 3.0), "breaker: just above -3% does not trip");
   Check(CRiskManager::IsDailyLossBreached(9000.00, 10000.0, 3.0),  "breaker: -10% trips");
   Check(!CRiskManager::IsDailyLossBreached(10500.0, 10000.0, 3.0), "breaker: profit does not trip");
   Check(!CRiskManager::IsDailyLossBreached(0.0, 0.0, 3.0),         "breaker: invalid day balance never trips");
  }

//+------------------------------------------------------------------+
//| 2) Init ต้องปฏิเสธค่าเกินเพดาน (error log ที่เห็นคือสิ่งที่คาดไว้)   |
//+------------------------------------------------------------------+
void TestInitValidation(const string sym)
  {
   g_log.Info("expect 5 ERROR lines below (rejection of invalid parameters):");
   CRiskManager rm;
   Check(!rm.Init(sym, InpMagic, GetPointer(g_log), 1.5, 3.0, 1, InpCommission, 0), "init: risk 1.5% rejected");
   Check(!rm.Init(sym, InpMagic, GetPointer(g_log), 0.0, 3.0, 1, InpCommission, 0), "init: risk 0% rejected");
   Check(!rm.Init(sym, InpMagic, GetPointer(g_log), 1.0, 3.5, 1, InpCommission, 0), "init: daily loss 3.5% rejected");
   Check(!rm.Init(sym, InpMagic, GetPointer(g_log), 1.0, 3.0, 0, InpCommission, 0), "init: max positions 0 rejected");
   Check(!rm.Init(sym, InpMagic, GetPointer(g_log), 1.0, 3.0, 1, -1.0, 0),          "init: negative commission rejected");
   Check(rm.Init(sym, InpMagic, GetPointer(g_log), 1.0, 3.0, 1, InpCommission, 0),  "init: valid parameters accepted");
  }

//+------------------------------------------------------------------+
//| 3) Lot sizing หนึ่งกรณี — ตรวจด้วยสูตร tick value อิสระจาก RiskManager |
//+------------------------------------------------------------------+
void TestLotCase(CRiskManager &rm, const string sym, const ENUM_SIGNAL_DIR dir,
                 const double entry, const double sl_dist, const double equity)
  {
   string label = StringFormat("%s %s sl=%s equity=%.0f", sym, dir == SIGNAL_BUY ? "BUY" : "SELL",
                               DoubleToString(sl_dist, (int)SymbolInfoInteger(sym, SYMBOL_DIGITS)), equity);

   double tick_size  = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   double tick_value = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
   double vmin       = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   double vmax       = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
   double vstep      = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
   if(tick_size <= 0.0 || tick_value <= 0.0)
     {
      Check(false, label, "tick size/value unavailable");
      return;
     }

   SSignalIntent intent;
   intent.Reset();
   intent.dir         = dir;
   intent.sl_distance = sl_dist;
   intent.reason      = "selftest";

   double loss_tick  = sl_dist / tick_size * tick_value;           // ขาดทุนต่อ 1 lot (สูตรอิสระ)
   double risk_money = equity * 1.0 / 100.0;
   double expected   = risk_money / (loss_tick + InpCommission);   // lot ก่อนปัดลง
   double tol        = 1.0 + InpTolerancePct / 100.0;

   double lot = 0.0;
   string why = "";
   bool   ok  = rm.CalcLotForEquity(intent, entry, equity, lot, why);

   if(!ok)
     {
      // ปฏิเสธได้เฉพาะเมื่อ lot ที่ควรได้ต่ำกว่า VOLUME_MIN (ภายใต้ tolerance)
      Check(expected < vmin * tol, label + " -> skipped", StringFormat("expected raw lot %.4f vs min %.2f | %s", expected, vmin, why));
      return;
     }

   bool in_range   = (lot >= vmin && lot <= vmax);
   double k        = lot / vstep;
   bool on_step    = MathAbs(k - MathRound(k)) < 1e-6;
   double real_risk = lot * (loss_tick + InpCommission);
   bool within     = real_risk <= risk_money * tol;                 // ห้ามเกิน 1% (ใน tolerance ของสูตร)
   bool maximal    = (lot >= vmax) || ((lot + vstep) * (loss_tick + InpCommission) > risk_money / tol);   // ไม่ปัดลงเกินจำเป็น
   Check(in_range && on_step && within && maximal, label,
         StringFormat("lot=%.2f expected_raw=%.4f risk=%.2f/%.2f (%.3f%%)", lot, expected, real_risk, risk_money, real_risk / equity * 100.0));
  }

//+------------------------------------------------------------------+
//| 4) เทียบ OrderCalcProfit กับ tick value                           |
//+------------------------------------------------------------------+
void TestProfitFormulas(const string sym, const double ask, const double sl_dist)
  {
   double tick_size  = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   double tick_value = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
   double profit     = 0.0;
   if(!OrderCalcProfit(ORDER_TYPE_BUY, sym, 1.0, ask, ask - sl_dist, profit) || tick_size <= 0.0)
     {
      Check(false, sym + " OrderCalcProfit vs tick value", "OrderCalcProfit failed");
      return;
     }
   double by_tick = sl_dist / tick_size * tick_value;
   double diff    = MathAbs(-profit - by_tick) / by_tick * 100.0;
   Check(-profit > 0.0 && diff <= InpTolerancePct, sym + " OrderCalcProfit vs tick value",
         StringFormat("calc=%.2f tick=%.2f diff=%.3f%%", -profit, by_tick, diff));
  }

//+------------------------------------------------------------------+
void TestSymbol(const string sym)
  {
   g_log.Info("---- symbol " + sym + " ----");
   if(!SymbolSelect(sym, true))
     {
      Check(false, sym + " available", "SymbolSelect failed");
      return;
     }
   MqlTick tick;
   if(!SymbolInfoTick(sym, tick) || tick.ask <= 0.0 || tick.bid <= 0.0)
     {
      Check(false, sym + " has quotes", "no tick (market closed / not loaded?) — open the symbol chart and retry");
      return;
     }

   CRiskManager rm;
   if(!rm.Init(sym, InpMagic, GetPointer(g_log), 1.0, 3.0, 1, InpCommission, 0))
     {
      Check(false, sym + " risk init");
      return;
     }

   double mid = (tick.ask + tick.bid) / 2.0;
   double sl_pcts[] = {0.05, 0.3, 2.0};            // SL แคบ / ปกติ / กว้าง (% ของราคา — ไม่ผูกกับ symbol ใดๆ)
   double equities[];
   ArrayResize(equities, 3);
   equities[0] = AccountInfoDouble(ACCOUNT_EQUITY);
   equities[1] = 10000.0;
   equities[2] = 50.0;                              // เล็กจนต้องต่ำกว่า VOLUME_MIN

   TestProfitFormulas(sym, tick.ask, mid * sl_pcts[1] / 100.0);

   for(int e = 0; e < ArraySize(equities); e++)
      for(int s = 0; s < ArraySize(sl_pcts); s++)
        {
         double sl_dist = NormalizeDouble(mid * sl_pcts[s] / 100.0, (int)SymbolInfoInteger(sym, SYMBOL_DIGITS));
         TestLotCase(rm, sym, SIGNAL_BUY,  tick.ask, sl_dist, equities[e]);
         TestLotCase(rm, sym, SIGNAL_SELL, tick.bid, sl_dist, equities[e]);
        }

   //--- intent ไม่ถูกต้องต้องถูกปฏิเสธ
   SSignalIntent bad;
   bad.Reset();
   double lot = 0.0;
   string why = "";
   Check(!rm.CalcLotForEquity(bad, tick.ask, 10000.0, lot, why), sym + " intent NONE rejected");
   bad.dir = SIGNAL_BUY;
   bad.sl_distance = 0.0;
   Check(!rm.CalcLotForEquity(bad, tick.ask, 10000.0, lot, why), sym + " zero SL distance rejected");
  }

//+------------------------------------------------------------------+
void OnStart()
  {
   g_log.Init("RiskSelfTest", InpMagic, LOG_INFO, false);
   g_log.Info(StringFormat("account trade_mode=%s currency=%s commission=%.2f",
                           EnumToString((ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE)),
                           AccountInfoString(ACCOUNT_CURRENCY), InpCommission));

   TestBreaker();
   string src = (InpSymbols == "") ? _Symbol : InpSymbols;
   string list[];
   int n = StringSplit(src, ',', list);
   bool first = true;
   for(int i = 0; i < n; i++)
     {
      string sym = list[i];
      StringTrimLeft(sym);
      StringTrimRight(sym);
      if(sym == "")
         continue;
      if(first)
        {
         TestInitValidation(sym);
         first = false;
        }
      TestSymbol(sym);
     }

   g_log.Info(StringFormat("SUMMARY: %d passed, %d failed", g_pass, g_fail));
   if(g_fail == 0)
      g_log.Info("ALL PASS");
   else
      g_log.Error("SOME CHECKS FAILED");
  }
//+------------------------------------------------------------------+
