//+------------------------------------------------------------------+
//|                                                     SmartEA.mq5  |
//|  Core framework: Signals -> Risk -> Execution                    |
//|  Phase 2 — Signal = EMA cross + ADX filter (spec-ema-adx v1)     |
//+------------------------------------------------------------------+
#property copyright "Phas"
#property version   "1.00"   // รูปแบบ x.yy; ใช้ git tag บอก phase แทน
#property description "SmartEA — Signal เลือกได้: EMA cross + ADX / Session Breakout"
#property tester_file "SmartEA\\holidays.csv"   // ให้ Strategy Tester คัดลอกไฟล์วันหยุดไปด้วย (S9)
#property tester_file "SmartEA\\news.csv"   // ข่าว NFP/CPI/FOMC สำหรับ V2b
#property tester_indicator "SmartEA\\SmartEA_EMAPair.ex5"   // แสดงสี EMA ใน visual mode (display only)

#include <SmartEA/Core/Types.mqh>
#include <SmartEA/Core/Logger.mqh>
#include <SmartEA/Core/BarClock.mqh>
#include <SmartEA/Core/SignalBase.mqh>
#include <SmartEA/Core/RiskManager.mqh>
#include <SmartEA/Core/TradeManager.mqh>
#include <SmartEA/Core/Telemetry.mqh>
#include <SmartEA/Signals/EMACrossSignal.mqh>
#include <SmartEA/Signals/SessionBreakoutSignal.mqh>
#include <SmartEA/Signals/HolidayFilter.mqh>
#include <SmartEA/Signals/NewsFilter.mqh>

//--- เลือก Signal (ค่า default = EMA_ADX = พฤติกรรมเดิมทั้งหมด)
enum ENUM_STRATEGY
  {
   STRATEGY_EMA_ADX           = 0,   // EMA cross + ADX (spec-ema-adx v1/v2)
   STRATEGY_SESSION_BREAKOUT  = 1,   // ทะลุกรอบเอเชีย (spec-session-breakout)
   STRATEGY_DONCHIAN          = 2    // Donchian H4 (ยังไม่ implement — init ล้มเหลว)
  };

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
input ENUM_STRATEGY  InpStrategy          = STRATEGY_EMA_ADX;  // เลือก Signal

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

//--- Strategy v2 feature flags (docs/strategy/spec-ema-adx-v2.md) — default = พฤติกรรม v1 เป๊ะ
input bool            InpUseHTFFilter     = false;     // V2a: BUY/SELL ตามแท่ง HTF ที่ปิดแล้วเทียบ EMA(HTF)
input ENUM_TIMEFRAMES InpHTFTimeframe     = PERIOD_H4; // V2a: timeframe ของ HTF
input int             InpHTFEMA           = 50;        // V2a: period EMA ของ HTF
input bool            InpUseNewsFilter    = false;     // V2b: ไม่เปิดไม้ใหม่ช่วงข่าว (news.csv)
input string          InpNewsFile         = "SmartEA\\news.csv";  // path ใต้ MQL5\Files
input int             InpNewsWindowMin    = 30;        // V2b: ±นาทีรอบเวลาข่าว (server time)
input bool            InpNoReverse        = false;     // V2c: cross สวน = ปิดอย่างเดียว ไม่กลับฝั่ง + พักเข้าไม้
input int             InpReentryBars      = 4;         // V2c: ห้ามเปิดไม้ใหม่จนผ่านกี่แท่งหลังปิดด้วย cross สวน
input bool            InpUseOppositeExit  = true;      // V2d: false = ไม่ปิดเมื่อ cross สวน (ปิดด้วย SL/TP/time exit)

//--- Strategy: Session Breakout (docs/strategy/spec-session-breakout.md) — ใช้เมื่อ InpStrategy = SESSION_BREAKOUT
//--- (InpTPRMult / InpTimeExitHHMM / InpFridayCutoffHour ใช้ร่วมกับ EMA)
input int              InpAsiaStartHour   = 1;          // กรอบเอเชีย เริ่ม (server hour, รวมแท่งที่เปิดชั่วโมงนี้)
input int              InpAsiaEndHour     = 10;         // กรอบเอเชีย จบ (ก่อนชั่วโมงนี้) = เริ่มหา breakout
input int              InpEntryEndHour    = 21;         // เข้าไม้ได้ก่อนชั่วโมงนี้ (เวลาที่ส่ง order)
input double           InpMaxRangeATR     = 1.5;        // ข้ามวันที่กรอบกว้างกว่า ค่านี้ x ATR(รายวัน)[1]
input ENUM_TIMEFRAMES  InpRangeATRTF      = PERIOD_D1;  // timeframe ของ ATR กรองกรอบ
input int              InpRangeATRPeriod  = 14;         // period ของ ATR กรองกรอบ
input ENUM_SBO_SL_MODE InpSLMode          = SBO_SL_OPPOSITE;  // SL: OPPOSITE = ขอบตรงข้ามกรอบ, MID = กลางกรอบ
input bool             InpUseTP           = false;      // ตั้ง TP = SL x InpTPRMult (false = ถือถึง time exit)

//--- Telemetry สำหรับ dashboard (docs/specs/dashboard-v1.md) — read-only, ปิดเองใน tester
input bool            InpTelemetry        = true;      // เขียนไฟล์ให้ dashboard ที่ MQL5/Files/SmartEA/telemetry (ปิดเองใน tester)
input ENUM_TIMEFRAMES InpTelFastTF        = PERIOD_M15; // ATR "ระยะสั้น" + แท่งที่ใช้หากรอบเอเชีย
input ENUM_TIMEFRAMES InpTelSlowTF        = PERIOD_D1; // ATR รายวัน
input int             InpTelAsianStartH   = 1;         // กรอบเอเชีย เริ่ม (server hour)
input int             InpTelAsianEndH     = 10;        // กรอบเอเชีย จบ (server hour)

#define EA_VERSION "1.00"   // ต้องตรงกับ #property version

CLogger        g_log;
CBarClock      g_clock;
CRiskManager   g_risk;
CTradeManager  g_trade;
CSignalBase   *g_signal = NULL;
CHolidayFilter g_holiday;
CNewsFilter    g_news;
CTelemetry     g_tel;
datetime       g_noreverse_bar = 0;   // V2c: เวลาเปิดแท่งที่ปิดไม้ด้วย cross สวน (0 = ไม่มีการพัก)
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
//| Scope guard (T-037): EA นี้ออกแบบสำหรับทอง (XAU/USD) เท่านั้น        |
//| ตรวจจากสกุลเงินของ symbol ไม่ใช่ชื่อ → รองรับ suffix เช่น XAUUSD.m    |
//+------------------------------------------------------------------+
bool CheckSymbolScope()
  {
   const string base   = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_BASE);
   const string profit = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_PROFIT);
   if(base != "XAU" || profit != "USD")
     {
      g_log.Error(StringFormat("scope guard: BLOCKED - %s (base=%s profit=%s) ไม่ใช่ทอง XAU/USD; EA นี้รันได้เฉพาะ XAUUSD",
                               _Symbol, base, profit));
      return(false);
     }
   g_log.Info(StringFormat("scope guard: OK (%s = %s/%s)", _Symbol, base, profit));
   return(true);
  }

//+------------------------------------------------------------------+
//| ปล่อย signal (ใช้ตอน init ล้มเหลวและตอน deinit)                      |
//+------------------------------------------------------------------+
void ReleaseSignal()
  {
   if(g_signal != NULL)
     {
      g_signal.Deinit();      // Signal ที่มี indicator ต้อง IndicatorRelease ใน Deinit
      delete g_signal;
     }
   g_signal = NULL;
   g_ema    = NULL;
  }

//+------------------------------------------------------------------+
//| สร้าง + ตั้งค่า + Init signal ตาม InpStrategy                       |
//| คืน INIT_SUCCEEDED หรือรหัสล้มเหลว (เคลียร์ signal ให้แล้ว)          |
//+------------------------------------------------------------------+
int CreateSignal()
  {
   if(InpStrategy == STRATEGY_EMA_ADX)
     {
      g_ema = new CEMACrossSignal();
      if(g_ema == NULL)
         return(INIT_FAILED);
      g_signal = g_ema;
      if(!g_ema.Configure(InpFastEMA, InpSlowEMA, InpADXPeriod, InpADXMin, InpATRPeriod, InpSLATRMult, InpTPRMult,
                          InpSessionStartHour, InpSessionEndHour, InpTimeExitHHMM, InpFridayCutoffHour))
        {
         g_log.Error("strategy input ไม่ถูกต้อง");
         ReleaseSignal();
         return(INIT_PARAMETERS_INCORRECT);
        }
      if(!g_ema.ConfigureHTF(InpUseHTFFilter, InpHTFTimeframe, InpHTFEMA))
        {
         g_log.Error("HTF input ไม่ถูกต้อง");
         ReleaseSignal();
         return(INIT_PARAMETERS_INCORRECT);
        }
      if(InpReentryBars < 0)
        {
         g_log.Error("InpReentryBars ต้อง >= 0");
         ReleaseSignal();
         return(INIT_PARAMETERS_INCORRECT);
        }
     }
   else if(InpStrategy == STRATEGY_SESSION_BREAKOUT)
     {
      CSessionBreakoutSignal *sbo = new CSessionBreakoutSignal();
      if(sbo == NULL)
         return(INIT_FAILED);
      g_signal = sbo;
      if(InpTimeExitHHMM < 0 || InpTimeExitHHMM / 100 > 23 || InpTimeExitHHMM % 100 > 59 ||
         !sbo.Configure(InpAsiaStartHour, InpAsiaEndHour, InpEntryEndHour, InpMaxRangeATR, InpRangeATRTF,
                        InpRangeATRPeriod, InpSLMode, InpUseTP, InpTPRMult, InpFridayCutoffHour))
        {
         g_log.Error("session breakout input ไม่ถูกต้อง");
         ReleaseSignal();
         return(INIT_PARAMETERS_INCORRECT);
        }
     }
   else
     {
      g_log.Error(StringFormat("InpStrategy=%s ยังไม่ implement", EnumToString(InpStrategy)));
      return(INIT_PARAMETERS_INCORRECT);
     }

   if(!g_signal.Init(_Symbol, _Period, &g_log))
     {
      g_log.Error("signal init ล้มเหลว");
      ReleaseSignal();
      return(INIT_FAILED);
     }
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   g_log.Init("SmartEA", InpMagic, InpLogLevel);

   if(!CheckLiveGuard())
      return(INIT_FAILED);

   if(!CheckSymbolScope())
      return(INIT_FAILED);

   if(!g_risk.Init(_Symbol, InpMagic, &g_log, InpRiskPct, InpDailyLossPct, InpMaxPositions,
                   InpCommissionPerLot, InpMaxSpreadPoints))
      return(INIT_PARAMETERS_INCORRECT);

   if(!g_trade.Init(_Symbol, InpMagic, &g_log, InpDeviationPoints))
      return(INIT_FAILED);

   const int sig_rc = CreateSignal();
   if(sig_rc != INIT_SUCCEEDED)
      return(sig_rc);

   if(!g_holiday.Init(&g_log, InpHolidayFile, InpUseHolidayFilter))
     {
      ReleaseSignal();
      return(INIT_PARAMETERS_INCORRECT);
     }

   if(!g_news.Init(&g_log, InpNewsFile, InpUseNewsFilter, InpNewsWindowMin))
     {
      ReleaseSignal();
      return(INIT_PARAMETERS_INCORRECT);
     }

   g_log.Info(StringFormat("v2 flags: HTF=%s news=%s noReverse=%s(reentry %d) oppositeExit=%s",
                           InpUseHTFFilter ? "ON" : "off", InpUseNewsFilter ? "ON" : "off",
                           InpNoReverse ? "ON" : "off", InpReentryBars, InpUseOppositeExit ? "on" : "OFF"));
   g_clock.Init(_Symbol, _Period);

   //--- telemetry ไม่เคยทำให้ init ล้ม (Init คืน true เสมอ) — ปิดอัตโนมัติใน tester
   g_tel.Init(&g_log, _Symbol, InpMagic, InpTelemetry, InpTelFastTF, InpTelSlowTF, InpATRPeriod,
              InpTelAsianStartH, InpTelAsianEndH);
   g_trade.SetTelemetry(&g_tel);
   if(g_tel.Enabled())
     {
      EventSetTimer(30);
      OnTimer();                  // เขียน status.json ทันที ไม่ต้องรอ 30 วินาทีแรก
     }

   g_log.Info(StringFormat("init OK: signal=%s tf=%s", g_signal.Name(), EnumToString(_Period)));
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   g_tel.Deinit();
   ReleaseSignal();
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
//| Telemetry (dashboard) — ทุกอย่างอ่านอย่างเดียว                      |
//+------------------------------------------------------------------+
//--- S1/S7: ตอนนี้เปิดไม้ใหม่ได้ตามช่วงเวลาหรือไม่ (ไม่รวม holiday/news/risk)
bool SessionOpenNow()
  {
   MqlDateTime t;
   TimeToStruct(TimeTradeServer(), t);
   const int start_h = (InpStrategy == STRATEGY_SESSION_BREAKOUT) ? InpAsiaEndHour : InpSessionStartHour;
   const int end_h   = (InpStrategy == STRATEGY_SESSION_BREAKOUT) ? InpEntryEndHour : InpSessionEndHour;
   if(t.hour < start_h || t.hour >= end_h)
      return(false);
   if(t.day_of_week == 5 && t.hour >= InpFridayCutoffHour)
      return(false);
   return(t.day_of_week >= 1 && t.day_of_week <= 5);
  }

void OnTimer()
  {
   STelemetryExtra x;
   x.Reset();
   const datetime now = TimeTradeServer();
   x.version                = EA_VERSION;
   x.strategy               = (g_signal != NULL) ? g_signal.Name() : "";
   x.halted                 = g_risk.IsHalted();
   x.day_start_balance      = g_risk.DayStartBalance();
   x.breaker_limit          = x.day_start_balance * (1.0 - InpDailyLossPct / 100.0);   // สูตรเดียวกับ RiskManager (อ่านอย่างเดียว)
   x.spread_max             = InpMaxSpreadPoints;
   x.commission_per_lot     = InpCommissionPerLot;
   x.session_open           = SessionOpenNow();
   x.holiday_today          = g_holiday.IsHoliday(now);
   x.holidays_covered_until = g_holiday.CoveredUntilYear();
   x.news_known             = g_news.NextEvent(now, x.news_event, x.news_time);
   x.news_window_active     = g_news.InWindow(now);
   x.news_covered_until     = g_news.CoveredUntilYear();
   g_tel.OnTimer(x);
  }

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
      g_tel.OnDealAdded(trans.deal);
  }

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
//| S6: ถึงเวลาปิดทุก position แล้วหรือยัง (server time) — ใช้ร่วมทุก strategy |
//+------------------------------------------------------------------+
bool TimeExitDue()
  {
   MqlDateTime t;
   TimeToStruct(TimeTradeServer(), t);
   return(t.hour * 100 + t.min >= InpTimeExitHHMM);
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
   const bool due   = TimeExitDue();
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
   //--- V2d: InpUseOppositeExit=false -> ข้ามทั้งก้อน • V2c: InpNoReverse -> ปิดอย่างเดียว + พักเข้าไม้ InpReentryBars แท่ง
   const ENUM_SIGNAL_DIR held = HeldDirection();
   if(g_ema != NULL && InpUseOppositeExit && held != SIGNAL_NONE && g_ema.RawCross() == (ENUM_SIGNAL_DIR)(-(int)held))
     {
      if(!g_trade.CloseAll("opposite cross (S3)"))
         return;                            // ปิดไม่สำเร็จ -> ไม่เปิดไม้ใหม่ (รอบหน้าลองใหม่)
      can_open = g_risk.CanOpen(why);
      if(InpNoReverse)
        {
         g_noreverse_bar = iTime(_Symbol, _Period, 0);
         g_log.Trade("SKIP", StringFormat("%s : V2c no-reverse ปิดอย่างเดียว พัก %d แท่ง", intent.reason, InpReentryBars));
         return;
        }
     }

   if(intent.dir == SIGNAL_NONE)
      return;

   //--- V2c: ยังอยู่ในช่วงพักหลังปิดด้วย cross สวน (ห้ามเปิดทุกทิศ)
   if(g_ema != NULL && InpNoReverse && g_noreverse_bar > 0)
     {
      const int bars_since = iBarShift(_Symbol, _Period, g_noreverse_bar, false);
      if(bars_since >= 0 && bars_since < InpReentryBars)
        {
         g_log.Trade("SKIP", StringFormat("%s : V2c re-entry พัก (ผ่านมา %d/%d แท่ง)", intent.reason, bars_since, InpReentryBars));
         return;
        }
     }

   string news_why;
   if(g_news.BlocksEntry(TimeTradeServer(), news_why))
     {
      g_log.Trade("SKIP", StringFormat("%s : %s", intent.reason, news_why));   // V2b
      return;
     }

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
           {
            g_log.Trade("RISK", StringFormat("actual_risk=%.2f (%.3f%% ของ equity) lot=%.2f fill=%.5f sl=%.5f",
                                             risk_money, risk_pct, lot, g_trade.LastFillPrice(), g_trade.LastSl()));
            g_tel.NoteOpen(g_trade.LastDeal(), AccountInfoDouble(ACCOUNT_EQUITY) * InpRiskPct / 100.0, risk_money);
           }
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
