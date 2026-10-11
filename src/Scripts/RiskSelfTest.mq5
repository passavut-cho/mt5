//+------------------------------------------------------------------+
//|                                                RiskSelfTest.mq5  |
//|  ตรวจสูตร lot ของ CRiskManager (read-only, ไม่เทรด)               |
//|  A) ตัวเลขตายตัว (XAUUSD / EURUSD / SL แคบ-กว้าง / ต่ำกว่า VOLUME_MIN) |
//|  B) ตลาดจริงของ broker ผ่าน OrderCalcProfit ตาม InpSymbols          |
//|  ผลสรุปบรรทัดสุดท้าย: SELFTEST: PASS|FAIL                          |
//+------------------------------------------------------------------+
#property copyright   "Phas"
#property version     "1.00"
#property description "Self-test for CRiskManager lot calculation (no trading)"
#property script_show_inputs

#include <SmartEA/Core/Logger.mqh>
#include <SmartEA/Core/RiskManager.mqh>

input string InpSymbols         = "XAUUSD,EURUSD";  // symbol สำหรับชุด B (คั่นด้วย ,)
input double InpRiskPct         = 1.0;              // ต้องตรงกับ EA
input double InpDailyLossPct    = 3.0;
input double InpCommissionPerLot = 7.0;

CLogger      g_log;
CRiskManager g_risk;
int          g_pass = 0;
int          g_fail = 0;
int          g_skip = 0;

//+------------------------------------------------------------------+
void Check(const bool ok, const string name)
  {
   if(ok)
     {
      g_pass++;
      g_log.Info("PASS  " + name);
     }
   else
     {
      g_fail++;
      g_log.Error("FAIL  " + name);
     }
  }

//--- คาดว่าได้ lot = expected
void ExpectLot(const string name, const double risk_money, const double loss_per_lot, const double comm,
               const double vmin, const double vmax, const double vstep, const double expected)
  {
   double lot;
   string why;
   bool   ok = g_risk.ComputeLot(risk_money, loss_per_lot, comm, vmin, vmax, vstep, lot, why);
   Check(ok && MathAbs(lot - expected) < 1e-9, StringFormat("%s -> lot %.2f (คาด %.2f) %s", name, lot, expected, why));
   //--- risk จริงต้องไม่เกินที่ตั้ง (ปัดลงเสมอ)
   if(ok)
      Check(lot * (loss_per_lot + comm) <= risk_money + 1e-9,
            StringFormat("%s : risk จริง %.2f <= %.2f", name, lot * (loss_per_lot + comm), risk_money));
  }

//--- คาดว่าต้องข้ามไม้
void ExpectSkip(const string name, const double risk_money, const double loss_per_lot, const double comm,
                const double vmin, const double vmax, const double vstep)
  {
   double lot;
   string why;
   bool   ok = g_risk.ComputeLot(risk_money, loss_per_lot, comm, vmin, vmax, vstep, lot, why);
   Check(!ok && lot == 0.0, StringFormat("%s -> ข้ามไม้ (%s)", name, why));
  }

//+------------------------------------------------------------------+
//| ชุด A: ตัวเลขตายตัว — คำนวณมือได้                                   |
//+------------------------------------------------------------------+
void RunFixedCases()
  {
   //--- XAUUSD: 100 oz/lot, equity 10,000 -> risk 100, SL $5 -> ขาดทุน 500/lot, comm 7
   ExpectLot("XAUUSD SL 5.00",   100.0, 500.0,  7.0, 0.01, 100.0, 0.01, 0.19);   // 100/507 = 0.197
   //--- EURUSD: 100,000/lot, SL 20 pips (0.0020) -> 200/lot
   ExpectLot("EURUSD SL 20pip",  100.0, 200.0,  7.0, 0.01, 100.0, 0.01, 0.48);   // 100/207 = 0.483
   //--- SL แคบ: XAUUSD SL $0.50 -> 50/lot
   ExpectLot("XAUUSD SL แคบ",    100.0,  50.0,  7.0, 0.01, 100.0, 0.01, 1.75);   // 100/57 = 1.754
   //--- SL กว้าง: XAUUSD SL $50 -> 5000/lot -> 0.01996 -> floor = 0.01 (>= min)
   ExpectLot("XAUUSD SL กว้าง",  100.0, 5000.0, 7.0, 0.01, 100.0, 0.01, 0.01);
   //--- ไม่ปัดขึ้น: 0.0199 ต้องได้ 0.01 ไม่ใช่ 0.02
   ExpectLot("ไม่ปัดขึ้น",       199.0, 9993.0, 7.0, 0.01, 100.0, 0.01, 0.01);
   //--- ต่ำกว่า VOLUME_MIN: equity 500 -> risk 5, 5/507 = 0.0098 -> ข้ามไม้
   ExpectSkip("ต่ำกว่า VOLUME_MIN", 5.0, 500.0, 7.0, 0.01, 100.0, 0.01);
   //--- ชน VOLUME_MAX
   ExpectLot("ชน VOLUME_MAX",   100000.0, 10.0, 0.0, 0.01, 50.0, 0.01, 50.0);
   //--- step 0.1 (lot ใหญ่): 0.283 -> 0.2
   ExpectLot("step 0.1",         100.0, 354.0,  0.0, 0.1, 100.0, 0.1, 0.2);      // 100/354 = 0.282
   //--- commission ทำให้ lot ลดลง
   ExpectLot("commission 0",     100.0, 500.0,  0.0, 0.01, 100.0, 0.01, 0.20);   // 100/500
   //--- input ผิด
   ExpectSkip("loss_per_lot = 0", 100.0, 0.0, 7.0, 0.01, 100.0, 0.01);
   ExpectSkip("risk_money = 0",   0.0, 500.0, 7.0, 0.01, 100.0, 0.01);
   ExpectSkip("step = 0",         100.0, 500.0, 7.0, 0.01, 100.0, 0.0);
  }

//+------------------------------------------------------------------+
//| ชุด B: ตลาดจริง — เทียบกับ OrderCalcProfit ของ broker               |
//+------------------------------------------------------------------+
void RunLiveSymbol(const string sym)
  {
   if(!SymbolSelect(sym, true))
     {
      g_skip++;
      g_log.Warn("SKIP  " + sym + " : ไม่พบ symbol บน server นี้");
      return;
     }
   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   if(ask <= 0.0)
     {
      g_skip++;
      g_log.Warn("SKIP  " + sym + " : ยังไม่มีราคา (ตลาดปิด?)");
      return;
     }

   CRiskManager rm;
   if(!rm.Init(sym, 1, &g_log, InpRiskPct, InpDailyLossPct, 1, InpCommissionPerLot, 0))
     {
      Check(false, sym + " : RiskManager.Init");
      return;
     }

   //--- SL แคบ / กลาง / กว้าง เป็น % ของราคา (ไม่ผูกกับ symbol)
   double pct[3] = {0.10, 0.50, 2.00};
   for(int i = 0; i < 3; i++)
     {
      SSignalIntent in;
      in.Reset();
      in.dir         = SIGNAL_BUY;
      in.sl_distance = NormalizeDouble(ask * pct[i] / 100.0, (int)SymbolInfoInteger(sym, SYMBOL_DIGITS));
      in.reason      = "selftest";

      double lot = 0.0;
      string why;
      bool   ok  = rm.CalcLot(in, ask, lot, why);

      if(!ok)
        {
         //--- ข้ามไม้ถูกต้อง (ต่ำกว่า min / margin ไม่พอ) ต้องได้ lot = 0 และมีเหตุผล
         Check(lot == 0.0 && why != "", StringFormat("%s SL %.2f%% : ข้ามไม้ (%s)", sym, pct[i], why));
         continue;
        }

      double pl = 0.0;
      double sl = NormalizeDouble(ask - in.sl_distance, (int)SymbolInfoInteger(sym, SYMBOL_DIGITS));
      bool   calc = OrderCalcProfit(ORDER_TYPE_BUY, sym, lot, ask, sl, pl);
      double risk_actual = -pl + lot * InpCommissionPerLot;
      double risk_limit  = AccountInfoDouble(ACCOUNT_EQUITY) * InpRiskPct / 100.0;
      double vmin  = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
      double vstep = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
      double steps = (lot - vmin) / vstep;

      Check(calc && risk_actual <= risk_limit + 1e-6,
            StringFormat("%s SL %.2f%% : lot=%.2f risk จริง %.2f <= %.2f", sym, pct[i], lot, risk_actual, risk_limit));
      Check(MathAbs(steps - MathRound(steps)) < 1e-6 && lot >= vmin - 1e-12 &&
            lot <= SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX) + 1e-12,
            StringFormat("%s SL %.2f%% : lot %.2f อยู่ใน min/max/step", sym, pct[i], lot));
     }
  }

//+------------------------------------------------------------------+
void OnStart()
  {
   g_log.Init("RiskSelfTest", 0, LOG_INFO);
   g_log.Info("== ชุด A: ตัวเลขตายตัว ==");
   RunFixedCases();

   g_log.Info("== ชุด B: ตลาดจริงของ broker ==");
   string list[];
   int n = StringSplit(InpSymbols, ',', list);
   for(int i = 0; i < n; i++)
     {
      string sym = list[i];
      StringTrimLeft(sym);
      StringTrimRight(sym);
      if(sym != "")
         RunLiveSymbol(sym);
     }

   g_log.Info(StringFormat("pass=%d fail=%d skip=%d", g_pass, g_fail, g_skip));
   g_log.Info(g_fail == 0 ? "SELFTEST: PASS" : "SELFTEST: FAIL");
  }
//+------------------------------------------------------------------+
