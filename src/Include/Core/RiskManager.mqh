//+------------------------------------------------------------------+
//|                                                  RiskManager.mqh |
//|  จุดเดียวที่มีตัวเลข risk (ADR 0002)                               |
//|  - Lot จาก %risk ของ equity + ระยะ SL + commission (D3)           |
//|  - Daily loss breaker ทั้งบัญชี หยุดเปิดไม้ใหม่ถึงวันถัดไป (D1/D2)   |
//|  - Max positions (นับเฉพาะ magic + symbol รวมไม้ค้างจาก session ก่อน) |
//+------------------------------------------------------------------+
#ifndef SMARTEA_CORE_RISKMANAGER_MQH
#define SMARTEA_CORE_RISKMANAGER_MQH

#include "Types.mqh"
#include "Logger.mqh"

//--- เพดานที่ตกลงไว้ — เกินนี้ Init ปฏิเสธ (INIT_PARAMETERS_INCORRECT ที่ EA)
#define RISK_MAX_RISK_PCT        1.0
#define RISK_MAX_DAILY_LOSS_PCT  3.0

class CRiskManager
  {
private:
   string            m_symbol;
   ulong             m_magic;
   CLogger          *m_log;
   double            m_risk_pct;
   double            m_daily_loss_pct;
   int               m_max_positions;
   double            m_commission_per_lot;
   int               m_max_spread_points;
   int               m_digits;
   double            m_point;
   bool              m_ready;

   datetime          m_day_start;        // 00:00 server time ของวันที่กำลังติดตาม
   double            m_day_balance;      // balance ต้นวัน
   bool              m_halted;           // breaker ทำงานแล้ว — ค้างจนข้ามวัน

   //--- 00:00 ของวันตาม server time
   datetime          ServerDayStart() const
     {
      MqlDateTime dt;
      TimeToStruct(TimeTradeServer(), dt);
      dt.hour = 0;
      dt.min  = 0;
      dt.sec  = 0;
      return(StructToTime(dt));
     }

   //--- balance ต้นวัน = balance ตอนนี้ − Σ(profit+swap+commission+fee) ของ deal วันนี้
   //--- ข้าม deal ประเภทฝาก/ถอน/credit/bonus (ไม่ใช่ผลการเทรด) — เงินฝากกลางวันจึงทำให้ breaker เข้มขึ้น (ฝั่งปลอดภัย)
   double            ComputeDayStartBalance(const datetime day_start) const
     {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      if(!HistorySelect(day_start, TimeTradeServer() + 60))
        {
         if(m_log != NULL)
            m_log.Warn(StringFormat("HistorySelect failed err=%d — using current balance as day start", GetLastError()));
         return(balance);
        }
      double pnl   = 0.0;
      int    total = HistoryDealsTotal();
      for(int i = 0; i < total; i++)
        {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket == 0)
            continue;
         long type = HistoryDealGetInteger(ticket, DEAL_TYPE);
         if(type == DEAL_TYPE_BALANCE || type == DEAL_TYPE_CREDIT || type == DEAL_TYPE_BONUS)
            continue;
         pnl += HistoryDealGetDouble(ticket, DEAL_PROFIT)
                + HistoryDealGetDouble(ticket, DEAL_SWAP)
                + HistoryDealGetDouble(ticket, DEAL_COMMISSION)
                + HistoryDealGetDouble(ticket, DEAL_FEE);
        }
      double start = balance - pnl;
      if(start <= 0.0)
        {
         if(m_log != NULL)
            m_log.Warn(StringFormat("computed day-start balance %.2f invalid — using current balance %.2f", start, balance));
         return(balance);
        }
      return(start);
     }

   //--- นับไม้ของ magic + symbol นี้ (รวมไม้ที่ค้างจาก session ก่อน)
   int               CountOwnPositions() const
     {
      int n = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if(PositionGetString(POSITION_SYMBOL) == m_symbol &&
            (ulong)PositionGetInteger(POSITION_MAGIC) == m_magic)
            n++;
        }
      return(n);
     }

   //--- จำนวนทศนิยมของ volume step (0.01 -> 2)
   static int        StepDigits(const double step)
     {
      int d = 0;
      while(d < 8 && MathAbs(step * MathPow(10.0, d) - MathRound(step * MathPow(10.0, d))) > 1e-9)
         d++;
      return(d);
     }

public:
                     CRiskManager() : m_symbol(""), m_magic(0), m_log(NULL), m_risk_pct(0.0),
                     m_daily_loss_pct(0.0), m_max_positions(1), m_commission_per_lot(0.0),
                     m_max_spread_points(0), m_digits(0), m_point(0.0), m_ready(false),
                     m_day_start(0), m_day_balance(0.0), m_halted(false) {}

   //--- false = พารามิเตอร์เกินเพดาน/ไม่ถูกต้อง (EA คืน INIT_PARAMETERS_INCORRECT)
   bool              Init(const string symbol, const ulong magic, CLogger *log,
                          const double risk_pct,
                          const double daily_loss_pct,
                          const int    max_positions,
                          const double commission_per_lot,
                          const int    max_spread_points)
     {
      m_ready = false;
      if(log == NULL)
         return(false);
      m_log = log;

      if(risk_pct <= 0.0 || risk_pct > RISK_MAX_RISK_PCT)
        {
         m_log.Error(StringFormat("InpRiskPct=%.2f invalid (must be >0 and <=%.1f)", risk_pct, RISK_MAX_RISK_PCT));
         return(false);
        }
      if(daily_loss_pct <= 0.0 || daily_loss_pct > RISK_MAX_DAILY_LOSS_PCT)
        {
         m_log.Error(StringFormat("InpDailyLossPct=%.2f invalid (must be >0 and <=%.1f)", daily_loss_pct, RISK_MAX_DAILY_LOSS_PCT));
         return(false);
        }
      if(max_positions < 1)
        {
         m_log.Error(StringFormat("InpMaxPositions=%d invalid (must be >=1)", max_positions));
         return(false);
        }
      if(commission_per_lot < 0.0)
        {
         m_log.Error(StringFormat("InpCommissionPerLot=%.2f invalid (must be >=0)", commission_per_lot));
         return(false);
        }
      if(max_spread_points < 0)
        {
         m_log.Error(StringFormat("InpMaxSpreadPoints=%d invalid (must be >=0)", max_spread_points));
         return(false);
        }
      if(!SymbolSelect(symbol, true))
        {
         m_log.Error(StringFormat("symbol '%s' not available", symbol));
         return(false);
        }

      m_symbol             = symbol;
      m_magic              = magic;
      m_risk_pct           = risk_pct;
      m_daily_loss_pct     = daily_loss_pct;
      m_max_positions      = max_positions;
      m_commission_per_lot = commission_per_lot;
      m_max_spread_points  = max_spread_points;
      m_digits             = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      m_point              = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(m_point <= 0.0)
        {
         m_log.Error("SYMBOL_POINT invalid");
         return(false);
        }
      m_ready = true;
      OnNewDay();
      m_log.Info(StringFormat("risk init: risk=%.2f%% dailyLoss=%.2f%% maxPos=%d commission/lot=%.2f maxSpread=%d",
                              m_risk_pct, m_daily_loss_pct, m_max_positions, m_commission_per_lot, m_max_spread_points));
      return(true);
     }

   //--- logic ล้วน (ไม่แตะ state) — แยกไว้ให้ RiskSelfTest ทดสอบ
   static bool       IsDailyLossBreached(const double equity, const double day_start_balance, const double daily_loss_pct)
     {
      if(day_start_balance <= 0.0)
         return(false);
      return(equity <= day_start_balance * (1.0 - daily_loss_pct / 100.0));
     }

   //--- จับ balance ต้นวันใหม่ + ปลด breaker (CanOpen เรียกเองเมื่อข้ามวัน จึงลืมเรียกไม่ได้)
   void              OnNewDay()
     {
      m_day_start   = ServerDayStart();
      m_day_balance = ComputeDayStartBalance(m_day_start);
      m_halted      = false;
      if(m_log != NULL)
         m_log.Info(StringFormat("new trading day %s | day-start balance=%.2f | breaker limit equity<=%.2f",
                                 TimeToString(m_day_start, TIME_DATE), m_day_balance,
                                 m_day_balance * (1.0 - m_daily_loss_pct / 100.0)));
     }

   //--- daily breaker + max positions + spread
   bool              CanOpen(string &why)
     {
      why = "";
      if(!m_ready)
        {
         why = "risk manager not initialised";
         return(false);
        }

      if(ServerDayStart() != m_day_start)
         OnNewDay();

      if(!m_halted)
        {
         double equity = AccountInfoDouble(ACCOUNT_EQUITY);
         if(IsDailyLossBreached(equity, m_day_balance, m_daily_loss_pct))
           {
            m_halted = true;
            m_log.Warn(StringFormat("DAILY LOSS BREAKER: equity %.2f <= limit %.2f (day-start balance %.2f, %.2f%%) — no new trades until next server day",
                                    equity, m_day_balance * (1.0 - m_daily_loss_pct / 100.0),
                                    m_day_balance, m_daily_loss_pct));
           }
        }
      if(m_halted)
        {
         why = "daily loss breaker active";
         return(false);
        }

      int open_n = CountOwnPositions();
      if(open_n >= m_max_positions)
        {
         why = StringFormat("max positions reached (%d/%d)", open_n, m_max_positions);
         return(false);
        }

      if(m_max_spread_points > 0)
        {
         long spread = SymbolInfoInteger(m_symbol, SYMBOL_SPREAD);
         if(spread > m_max_spread_points)
           {
            why = StringFormat("spread %d > max %d points", (int)spread, m_max_spread_points);
            return(false);
           }
        }
      return(true);
     }

   //--- ราคา SL/TP จากระยะ — Expert ใช้ตัวนี้เพื่อให้ตรงกับที่ CalcLot ใช้คำนวณ
   double            SlPrice(const ENUM_SIGNAL_DIR dir, const double entry, const double distance) const
     {
      return(NormalizeDouble(dir == SIGNAL_BUY ? entry - distance : entry + distance, m_digits));
     }

   double            TpPrice(const ENUM_SIGNAL_DIR dir, const double entry, const double distance) const
     {
      if(distance <= 0.0)
         return(0.0);
      return(NormalizeDouble(dir == SIGNAL_BUY ? entry + distance : entry - distance, m_digits));
     }

   //--- คำนวณ lot จาก equity ที่ระบุ (แยกไว้ให้ทดสอบด้วยตัวเลขสมมติ)
   //--- lot = floor_to_step( equity*risk% / (loss_per_lot_at_SL + commission_per_lot) )  ต่ำกว่า VOLUME_MIN = ข้ามไม้
   bool              CalcLotForEquity(const SSignalIntent &intent, const double entry, const double equity,
                                      double &lot, string &why) const
     {
      lot = 0.0;
      why = "";
      if(!m_ready)
        {
         why = "risk manager not initialised";
         return(false);
        }
      if(intent.dir == SIGNAL_NONE || intent.sl_distance <= 0.0)
        {
         why = "intent has no direction or SL distance";
         return(false);
        }
      if(entry <= 0.0 || equity <= 0.0)
        {
         why = "invalid entry price or equity";
         return(false);
        }

      double sl = SlPrice(intent.dir, entry, intent.sl_distance);
      if(sl <= 0.0 || MathAbs(entry - sl) < m_point)
        {
         why = "SL price invalid after normalisation";
         return(false);
        }

      ENUM_ORDER_TYPE otype = (intent.dir == SIGNAL_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      double profit = 0.0;
      if(!OrderCalcProfit(otype, m_symbol, 1.0, entry, sl, profit))
        {
         why = StringFormat("OrderCalcProfit failed err=%d", GetLastError());
         return(false);
        }
      double loss_per_lot = -profit;
      if(loss_per_lot <= 0.0)
        {
         why = StringFormat("loss per lot at SL is not positive (%.2f)", loss_per_lot);
         return(false);
        }

      double vol_min  = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      double vol_max  = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
      double vol_step = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
      if(vol_min <= 0.0 || vol_max < vol_min || vol_step <= 0.0)
        {
         why = "symbol volume limits invalid";
         return(false);
        }

      double risk_money = equity * m_risk_pct / 100.0;
      double cost_lot   = loss_per_lot + m_commission_per_lot;
      double raw        = risk_money / cost_lot;
      double stepped    = NormalizeDouble(MathFloor(raw / vol_step) * vol_step, StepDigits(vol_step));
      if(stepped < vol_min)
        {
         why = StringFormat("lot %.4f below VOLUME_MIN %.2f (risk %.2f, loss/lot+comm %.2f) — skip trade",
                            raw, vol_min, risk_money, cost_lot);
         return(false);
        }
      if(stepped > vol_max)
         stepped = vol_max;

      lot = stepped;
      return(true);
     }

   //--- lot สำหรับ equity จริงของบัญชี + ตรวจ margin อิสระพอ
   bool              CalcLot(const SSignalIntent &intent, const double entry, double &lot, string &why) const
     {
      if(!CalcLotForEquity(intent, entry, AccountInfoDouble(ACCOUNT_EQUITY), lot, why))
         return(false);

      ENUM_ORDER_TYPE otype = (intent.dir == SIGNAL_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      double margin = 0.0;
      if(!OrderCalcMargin(otype, m_symbol, lot, entry, margin))
        {
         why = StringFormat("OrderCalcMargin failed err=%d", GetLastError());
         lot = 0.0;
         return(false);
        }
      double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      if(margin > free_margin)
        {
         why = StringFormat("margin %.2f > free margin %.2f for lot %.2f", margin, free_margin, lot);
         lot = 0.0;
         return(false);
        }
      return(true);
     }
  };

#endif
