//+------------------------------------------------------------------+
//|                                                     SmartEA.mq5  |
//|  Core framework: Signals -> Risk -> Execution                    |
//|  Phase 2 — Signal = EMA cross + ADX filter (spec-ema-adx v1)     |
//+------------------------------------------------------------------+
#property copyright "Phas"
#property version   "1.00"   // รูปแบบ x.yy; ใช้ git tag บอก phase แทน
#property description "SmartEA — EMA 9/21 cross + ADX filter (spec v1)"
#property tester_file "SmartEA\\holidays.csv"   // ให้ Strategy Tester คัดลอกไฟล์วันหยุดไปด้วย (S9)
#property tester_indicator "SmartEA\\SmartEA_EMAPair.ex5"   // แสดงสี EMA ใน visual mode (display only)

#include <SmartEA/Core/Types.mqh>
#include <SmartEA/Core/Logger.mqh>
#include <SmartEA/Core/BarClock.mqh>
#include <SmartEA/Core/SignalBase.mqh>
#include <SmartEA/Core/RiskManager.mqh>
#include <SmartEA/Core/TradeManager.mqh>
#include <SmartEA/Signals/EMACrossSignal.mqh>
#include <SmartEA/Signals/HolidayFilter.mqh>

//--- inputs
input bool           InpAllowLive         = false;     // อนุญาตบัญชีจริง — ผู้ใช้เท่านั้นที่เปิดได้
input ulong          InpMagic             = 260101;    // Magic number ของ EA นี้
input double         InpRiskPct           = 1.0;       // % equity เสี่ยงต่อไม้ (เพดาน 1.0)
input double         InpDailyLossPct      = 3.0;       // % ขาดทุนรายวันทั้งบัญชี (เพดาน 3.0)
input int            InpMaxPositions      = 1;         // จำนวน position สูงสุดต่อ magic+symbol
input double         InpCommissionPerLot  = 7.0;       // commission round turn ต่อ lot (สกุลเงินบัญชี) IC Raw
input int            InpMaxSpreadPoints   = 20;        // spread สูงสุด (points) 0 = ไม่จำกัด • default 20 = XAUUSD (ADR 0002 D7) symbol อื่นตั้งใน .set
input uint           InpDeviationPoints   = 20;        // slippage ที่ยอมรับ (points)
input ENUM_LOG_LEVEL InpLogLevel          = LOG_INFO;  // ระดับ log (DEBUG ถูกปิดอัตโนมัติใน tester)

//--- Strategy: EMA cross + ADX (docs/strategy/spec-ema-adx.md)
input int            InpFastEMA           = 9;         // EMA เร็ว
input int            InpSlowEMA           = 21;        // EMA ช้า
input int            InpADXPeriod         = 14;        // ADX period
input double         InpADXMin            = 25.0;      // ADX ขั้นต่ำ (S2)
input int            InpATRPeriod         = 14;        // ATR period สำหรับ SL
input double         InpSLATRMult         = 1.5;       // SL = ATR x ค่านี้ (S4)
input double         InpTPRMult           = 2.0;       // TP = SL x ค่านี้ (S5)
input int            InpSessionStartHour  = 10;        // เปิดไม้ได้ตั้งแต่ชั่วโมงนี้ (server time) (S1)
input int            InpSessionEndHour    = 23;        // ... ก่อนชั่วโมงนี้ (hour < end)
input int            InpTimeExitHHMM      = 2330;      // ปิดทุก position เมื่อ server time >= HHMM (S6)
input int            InpFridayCutoffHour  = 20;        // ศุกร์ไม่เปิดไม้ใหม่ตั้งแต่ชั่วโมงนี้ (S7)
input bool           InpUseHolidayFilter  = true;      // ไม่เปิดไม้ใหม่ในวันที่อยู่ใน holiday file (S9)
input string         InpHolidayFile       = "SmartEA\\holidays.csv";  // path ใต้ MQL5\Files

CLogger        g_log;
CBarClock      g_clock;
CRiskManager   g_risk;
CTradeManager  g_trade;
CSignalBase   *g_signal = NULL;
CHolidayFilter g_holiday;
CEMACrossSignal *g_ema  = NULL;     // ตัวเดียวกับ g_signal (ไว้เรียก RawCross / TimeExitDue)

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

   g_ema = new CEMACrossSignal();
   if(g_ema == NULL)
      return(INIT_FAILED);
   g_signal = g_ema;
   if(!g_ema.Configure(InpFastEMA, InpSlowEMA, InpADXPeriod, InpADXMin, InpATRPeriod, InpSLATRMult, InpTPRMult,
                       InpSessionStartHour, InpSessionEndHour, InpTimeExitHHMM, InpFridayCutoffHour))
     {
      g_log.Error("strategy input ไม่ถูกต้อง");
      delete g_ema;
      g_ema = NULL;
      g_signal = NULL;
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(!g_signal.Init(_Symbol, _Period, &g_log))
     {
      g_log.Error("signal init ล้มเหลว");
      delete g_ema;
      g_ema = NULL;
      g_signal = NULL;
      return(INIT_FAILED);
     }

   if(!g_holiday.Init(&g_log, InpHolidayFile, InpUseHolidayFilter))
     {
      g_signal.Deinit();
      delete g_ema;
      g_ema = NULL;
      g_signal = NULL;
      return(INIT_PARAMETERS_INCORRECT);
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
      g_ema = NULL;
     }
   g_log.Info(StringFormat("deinit reason=%d", reason));
  }

//+------------------------------------------------------------------+
//| OnTester: net profit หลังหัก commission (เกณฑ์ optimize Phase 4) |
//| Tester ของ IC Raw ไม่หัก commission (DEAL_COMMISSION = 0 ทั้ง run)|
//| → ถ้าทั้ง run ไม่มี commission บันทึกเลย จึงหัก                   |
//|   InpCommissionPerLot x volume ต่อไม้ขาออก (ตัดสินระดับ run กันหักซ้ำ)|
//+------------------------------------------------------------------+
double OnTester()
  {
   if(!HistorySelect(0, TimeCurrent() + 1))
     {
      g_log.Error(StringFormat("OnTester: HistorySelect ล้มเหลว err=%d", GetLastError()));
      return -1.0e9;   // ค่าลบมาก = pass นี้ถูกคัดทิ้งตอน optimize
     }
   double net = 0.0, recorded_comm = 0.0, out_volume = 0.0;
   int    out_deals = 0;
   const int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
     {
      const ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol ||
         (ulong)HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagic)
         continue;
      const long type = HistoryDealGetInteger(ticket, DEAL_TYPE);
      if(type != DEAL_TYPE_BUY && type != DEAL_TYPE_SELL)
         continue;
      const double comm = HistoryDealGetDouble(ticket, DEAL_COMMISSION) + HistoryDealGetDouble(ticket, DEAL_FEE);
      recorded_comm += MathAbs(comm);
      net += HistoryDealGetDouble(ticket, DEAL_PROFIT) + HistoryDealGetDouble(ticket, DEAL_SWAP) + comm;
      const long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT || entry == DEAL_ENTRY_OUT_BY)
        {
         out_volume += HistoryDealGetDouble(ticket, DEAL_VOLUME);
         out_deals++;
        }
     }
   double extra_comm = 0.0;
   if(recorded_comm == 0.0)
      extra_comm = InpCommissionPerLot * out_volume;
   net -= extra_comm;
   g_log.Info(StringFormat("OnTester: net=%.2f (หัก commission เพิ่ม %.2f จาก %d ไม้ %.2f lot)",
                           net, extra_comm, out_deals, out_volume));
   return net;
  }

void OpenWithRetry(const SSignalIntent &intent);

//+------------------------------------------------------------------+
//| ทิศของ position ที่ EA นี้ถืออยู่ (magic+symbol) — NONE = ไม่มี      |
//+------------------------------------------------------------------+
ENUM_SIGNAL_DIR HeldDirection()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(PositionGetSymbol(i) != _Symbol)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      return(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? SIGNAL_BUY : SIGNAL_SELL);
     }
   return(SIGNAL_NONE);
  }

//+------------------------------------------------------------------+
//| มี position ของ EA ที่เปิดก่อน 00:00 server ของวันนี้หรือไม่          |
//| (ข้ามคืนทั้งที่ S6 ควรปิดแล้ว เช่น วันตลาดปิดเร็วไม่มี tick หลัง 23:30)  |
//+------------------------------------------------------------------+
bool HeldFromBeforeToday()
  {
   MqlDateTime t;
   TimeToStruct(TimeTradeServer(), t);
   t.hour = 0;
   t.min  = 0;
   t.sec  = 0;
   const datetime day_start = StructToTime(t);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(PositionGetSymbol(i) != _Symbol)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      if((datetime)PositionGetInteger(POSITION_TIME) < day_start)
         return(true);
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| S6: ปิดทุก position เมื่อถึงเวลา หรือเมื่อถือข้ามวันมา               |
//| (ตรวจทุก tick เพราะมีเวลาตายตัว)                                    |
//| ถ้าปิดไม่สำเร็จ ลองใหม่ได้ไม่เกินทุก 5 วินาที กัน log ท่วม            |
//+------------------------------------------------------------------+
void CheckTimeExit()
  {
   static datetime last_try = 0;
   if(HeldDirection() == SIGNAL_NONE)
      return;
   const bool due   = g_ema.TimeExitDue();
   const bool stale = !due && HeldFromBeforeToday();
   if(!due && !stale)
      return;
   const datetime now = TimeCurrent();
   if(now - last_try < 5)
      return;
   last_try = now;
   g_trade.CloseAll(due ? StringFormat("time exit %04d (S6)", InpTimeExitHHMM)
                        : "time exit: ถือข้ามวัน (S6)");
  }

//+------------------------------------------------------------------+
//| Flow ต่อแท่งใหม่: Signal -> (exit S3) -> Risk.CanOpen -> CalcLot -> Trade |
//+------------------------------------------------------------------+
void OnTick()
  {
   CheckTimeExit();

   if(!g_clock.IsNewBar())
      return;

   string why;
   bool can_open = g_risk.CanOpen(why);   // เรียกทุกแท่งเพื่อให้ breaker / day rollover ทำงานและ log ตามปกติ

   SSignalIntent intent;
   intent.Reset();
   if(!g_signal.Evaluate(intent))
     {
      g_log.Warn("signal ข้อมูลไม่พร้อม");
      return;
     }

   //--- S3: cross ฝั่งตรงข้ามกับ position ที่ถืออยู่ -> ปิด แล้วค่อยพิจารณาเข้าฝั่งใหม่ (ผ่าน filter + risk ปกติ)
   const ENUM_SIGNAL_DIR held = HeldDirection();
   if(held != SIGNAL_NONE && g_ema.RawCross() == (ENUM_SIGNAL_DIR)(-(int)held))
     {
      if(!g_trade.CloseAll("opposite cross (S3)"))
         return;                            // ปิดไม่สำเร็จ -> ไม่เปิดไม้ใหม่ (รอบหน้าลองใหม่)
      can_open = g_risk.CanOpen(why);
     }

   if(intent.dir == SIGNAL_NONE)
      return;

   string hol_why;
   if(g_holiday.BlocksEntry(TimeTradeServer(), hol_why))
     {
      g_log.Trade("SKIP", StringFormat("%s : %s", intent.reason, hol_why));   // S9
      return;
     }

   if(!can_open)
     {
      g_log.Debug("SKIP: " + why);   // DEBUG กัน journal บวมตอน position เปิดอยู่/breaker ทำงาน
      return;
     }

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
