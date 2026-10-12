//+------------------------------------------------------------------+
//|                                                  RiskManager.mqh |
//|  ชั้น Risk: คำนวณ lot จาก %risk + ระยะ SL, daily loss breaker,     |
//|  max positions, spread filter  (ADR 0002)                        |
//+------------------------------------------------------------------+
#ifndef SMARTEA_CORE_RISKMANAGER_MQH
#define SMARTEA_CORE_RISKMANAGER_MQH

#include "Types.mqh"
#include "Logger.mqh"

//--- เพดานที่ CLAUDE.md กำหนด — Init จะปฏิเสธค่าที่เกิน (กฎเหล็กข้อ 2)
#define SMARTEA_MAX_RISK_PCT        1.0
#define SMARTEA_MAX_DAILY_LOSS_PCT  3.0
#define SMARTEA_MAX_POSITIONS       1     // ADR 0002: หนึ่ง position ต่อ magic+symbol (กัน pyramiding/averaging)

class CRiskManager
  {
private:
   string    m_symbol;
   ulong     m_magic;
   CLogger  *m_log;
   double    m_risk_pct;
   double    m_daily_loss_pct;
   int       m_max_positions;
   double    m_commission;        // round turn ต่อ 1 lot สกุลเงินบัญชี
   int       m_max_spread;
   bool      m_ready;

   datetime  m_day_start;         // 00:00 ของวัน server ปัจจุบัน
   double    m_day_balance;       // balance ต้นวัน (คำนวณย้อนจาก deal history)
   bool      m_halted;            // breaker ทำงานแล้ว — latch ไว้จนถึงวันถัดไป (D2)
   bool      m_balance_ok;        // false = อ่าน history ไม่ได้ -> fail closed (ไม่เปิดไม้)

   datetime  ServerDayStart() const;
   bool      CalcDayStartBalance(const datetime day_start, double &balance_out) const;
   int       CountPositions() const;
   int       CountSymbolPositions() const;   // ทุก magic (ใช้กับบัญชี netting - D6)
   bool      IsNettingAccount() const;
   int       StepDigits(const double step) const;

public:
             CRiskManager() : m_symbol(""), m_magic(0), m_log(NULL), m_risk_pct(0), m_daily_loss_pct(0),
                              m_max_positions(1), m_commission(0), m_max_spread(0), m_ready(false),
                              m_day_start(0), m_day_balance(0), m_halted(false), m_balance_ok(false) {}

   bool      Init(const string symbol, const ulong magic, CLogger *log,
                  const double risk_pct, const double daily_loss_pct, const int max_positions,
                  const double commission_per_lot, const int max_spread_points);

   //--- daily breaker + max positions + spread  (false -> why บอกเหตุผล)
   bool      CanOpen(string &why);

   //--- lot จากความเสี่ยงจริง ณ ราคา SL (OrderCalcProfit) + commission
   bool      CalcLot(const SSignalIntent &intent, const double entry, double &lot, string &why);

   //--- สูตรล้วน (ไม่แตะตลาด) แยกไว้ให้ RiskSelfTest ตรวจ
   //--- lot = floor_to_step( risk_money / (loss_per_lot + commission) ); ต่ำกว่า vmin = ข้ามไม้ ไม่ปัดขึ้น
   bool      ComputeLot(const double risk_money, const double loss_per_lot, const double commission,
                        const double vmin, const double vmax, const double vstep,
                        double &lot, string &why) const;

   //--- D4: สูตรล้วน — ไม่เปิดไม้ถ้าโดน SL แล้ว equity จะ <= limit รายวัน
   //--- worst_loss = (loss_per_lot + commission) * lot ; limit = day_balance * (1 - daily_loss_pct/100)
   bool      PreTradeOk(const double equity, const double worst_loss, const double day_balance,
                        const double daily_loss_pct, string &why) const;

   //--- D5: risk จริงหลัง fill = -OrderCalcProfit(fill, sl) * volume + commission * volume
   bool      ActualRisk(const ENUM_SIGNAL_DIR dir, const double volume, const double fill_price,
                        const double sl, double &risk_money, double &risk_pct_equity) const;

   //--- จับ balance ต้นวันใหม่ + ปลด breaker
   void      OnNewDay();

   bool      IsHalted() const { return(m_halted); }
   double    DayStartBalance() const { return(m_day_balance); }
  };

//+------------------------------------------------------------------+
bool CRiskManager::Init(const string symbol, const ulong magic, CLogger *log,
                        const double risk_pct, const double daily_loss_pct, const int max_positions,
                        const double commission_per_lot, const int max_spread_points)
  {
   m_ready = false;
   if(log == NULL)
      return(false);
   m_log = log;

   if(risk_pct <= 0.0 || risk_pct > SMARTEA_MAX_RISK_PCT)
     {
      m_log.Error(StringFormat("InpRiskPct=%.2f ไม่ถูกต้อง (ต้อง 0 < x <= %.1f)", risk_pct, SMARTEA_MAX_RISK_PCT));
      return(false);
     }
   if(daily_loss_pct <= 0.0 || daily_loss_pct > SMARTEA_MAX_DAILY_LOSS_PCT)
     {
      m_log.Error(StringFormat("InpDailyLossPct=%.2f ไม่ถูกต้อง (ต้อง 0 < x <= %.1f)", daily_loss_pct, SMARTEA_MAX_DAILY_LOSS_PCT));
      return(false);
     }
   if(max_positions < 1 || max_positions > SMARTEA_MAX_POSITIONS || commission_per_lot < 0.0 || max_spread_points < 0)
     {
      m_log.Error("max_positions/commission/max_spread ไม่ถูกต้อง (max_positions ต้องเป็น 1)");
      return(false);
     }
   if(!SymbolSelect(symbol, true))
     {
      m_log.Error(StringFormat("SymbolSelect(%s) ล้มเหลว err=%d", symbol, GetLastError()));
      return(false);
     }

   m_symbol         = symbol;
   m_magic          = magic;
   m_risk_pct       = risk_pct;
   m_daily_loss_pct = daily_loss_pct;
   m_max_positions  = max_positions;
   m_commission     = commission_per_lot;
   m_max_spread     = max_spread_points;
   m_ready          = true;

   OnNewDay();
   m_log.Info(StringFormat("Risk init: risk=%.2f%% dailyLoss=%.2f%% maxPos=%d commission=%.2f/lot maxSpread=%d",
                           m_risk_pct, m_daily_loss_pct, m_max_positions, m_commission, m_max_spread));
   //--- D6: netting รวม position ต่าง magic เป็นตัวเดียว -> fail closed (ดู CanOpen)
   if(IsNettingAccount())
      m_log.Warn("บัญชีเป็น NETTING: ถ้ามี position ของ symbol นี้อยู่แล้ว (ทุก magic) จะไม่เปิดไม้ — ใช้บัญชี hedging เป็นหลัก");
   return(true);
  }

//+------------------------------------------------------------------+
datetime CRiskManager::ServerDayStart() const
  {
   long t = (long)TimeTradeServer();
   return((datetime)(t - (t % 86400)));
  }

//+------------------------------------------------------------------+
//| balance ต้นวัน = balance ตอนนี้ − Σ(profit+swap+commission+fee ของ deal วันนี้) |
//| คำนวณย้อนจาก history เพื่อให้ถูกแม้ EA restart กลางวัน (ADR 0002)   |
//+------------------------------------------------------------------+
bool CRiskManager::CalcDayStartBalance(const datetime day_start, double &balance_out) const
  {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   balance_out = balance;

   if(!HistorySelect(day_start, TimeTradeServer() + 60))
     {
      m_log.Warn(StringFormat("HistorySelect ล้มเหลว err=%d — fail closed ไม่เปิดไม้จนกว่าจะอ่าน history ได้", GetLastError()));
      return(false);
     }

   double today = 0.0;
   int    total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;
      //--- นับเฉพาะ deal เทรด; ไม่นับ deposit/withdraw/credit (DEAL_TYPE_BALANCE ฯลฯ)
      //--- ไม่งั้นเงินฝากวันนี้ (หรือ initial deposit ใน tester) จะทำให้ balance ต้นวัน ~ 0
      ENUM_DEAL_TYPE dt = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);
      if(dt != DEAL_TYPE_BUY && dt != DEAL_TYPE_SELL)
         continue;
      today += HistoryDealGetDouble(ticket, DEAL_PROFIT)
               + HistoryDealGetDouble(ticket, DEAL_SWAP)
               + HistoryDealGetDouble(ticket, DEAL_COMMISSION)
               + HistoryDealGetDouble(ticket, DEAL_FEE);
     }
   balance_out = balance - today;
   if(balance_out <= 0.0)
     {
      m_log.Warn(StringFormat("balance ต้นวันคำนวณได้ %.2f (<=0) ผิดปกติ — fail closed", balance_out));
      return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
void CRiskManager::OnNewDay()
  {
   if(m_log == NULL)
      return;
   m_day_start   = ServerDayStart();
   m_halted      = false;
   m_balance_ok  = CalcDayStartBalance(m_day_start, m_day_balance);
   if(!m_balance_ok)
      return;
   m_log.Info(StringFormat("New day %s: balance ต้นวัน=%.2f  breaker ที่ equity<=%.2f",
                           TimeToString(m_day_start, TIME_DATE), m_day_balance,
                           m_day_balance * (1.0 - m_daily_loss_pct / 100.0)));
  }

//+------------------------------------------------------------------+
int CRiskManager::CountPositions() const
  {
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(PositionGetSymbol(i) != m_symbol)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != m_magic)
         continue;
      n++;
     }
   return(n);
  }

//+------------------------------------------------------------------+
int CRiskManager::CountSymbolPositions() const
  {
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(PositionGetSymbol(i) == m_symbol)
         n++;
     }
   return(n);
  }

//+------------------------------------------------------------------+
bool CRiskManager::IsNettingAccount() const
  {
   ENUM_ACCOUNT_MARGIN_MODE mm = (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   return(mm != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
  }

//+------------------------------------------------------------------+
bool CRiskManager::PreTradeOk(const double equity, const double worst_loss, const double day_balance,
                              const double daily_loss_pct, string &why) const
  {
   why = "";
   double limit = day_balance * (1.0 - daily_loss_pct / 100.0);
   if(equity - worst_loss <= limit)
     {
      why = StringFormat("D4 pre-trade: ถ้าโดน SL equity %.2f - %.2f = %.2f <= limit รายวัน %.2f (balance ต้นวัน %.2f, %.2f%%)",
                         equity, worst_loss, equity - worst_loss, limit, day_balance, daily_loss_pct);
      return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
bool CRiskManager::ActualRisk(const ENUM_SIGNAL_DIR dir, const double volume, const double fill_price,
                              const double sl, double &risk_money, double &risk_pct_equity) const
  {
   risk_money      = 0.0;
   risk_pct_equity = 0.0;
   if(!m_ready || volume <= 0.0 || fill_price <= 0.0 || sl <= 0.0 || dir == SIGNAL_NONE)
      return(false);

   double pl = 0.0;
   if(!OrderCalcProfit((dir == SIGNAL_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, m_symbol, volume, fill_price, sl, pl))
      return(false);

   risk_money = -pl + m_commission * volume;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   risk_pct_equity = (equity > 0.0) ? risk_money / equity * 100.0 : 0.0;
   return(true);
  }

//+------------------------------------------------------------------+
bool CRiskManager::CanOpen(string &why)
  {
   why = "";
   if(!m_ready)
     {
      why = "RiskManager ยังไม่ Init";
      return(false);
     }

   //--- terminal หลุดจาก server -> ราคา/ข้อมูลบัญชีอาจเก่า (นอก tester เท่านั้น)
   if(!MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_OPTIMIZATION) &&
      !TerminalInfoInteger(TERMINAL_CONNECTED))
     {
      why = "terminal ไม่ได้เชื่อมต่อ server (fail closed)";
      return(false);
     }

   if(ServerDayStart() != m_day_start)
      OnNewDay();

   //--- อ่าน history ไม่ได้ตอนเริ่มวัน -> ลองใหม่ทุกครั้ง; ยังไม่ได้ = ไม่เปิดไม้ (fail closed)
   if(!m_balance_ok)
     {
      m_balance_ok = CalcDayStartBalance(m_day_start, m_day_balance);
      if(m_balance_ok)
         m_log.Info(StringFormat("อ่าน history ได้แล้ว: balance ต้นวัน=%.2f", m_day_balance));
      else
        {
         why = "อ่าน deal history ไม่ได้ — ไม่รู้ balance ต้นวัน (fail closed)";
         return(false);
        }
     }

   if(m_halted)
     {
      why = "daily loss breaker ทำงานอยู่ (รอวันใหม่ตาม server time)";
      return(false);
     }

   //--- D1: ทั้งบัญชี — equity (รวม floating) เทียบ balance ต้นวัน
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double limit  = m_day_balance * (1.0 - m_daily_loss_pct / 100.0);
   if(equity <= limit)
     {
      m_halted = true;
      why = StringFormat("daily loss breaker: equity %.2f <= %.2f (balance ต้นวัน %.2f, %.2f%%)",
                         equity, limit, m_day_balance, m_daily_loss_pct);
      m_log.Warn(why);     // latch ครั้งเดียวต่อวัน — ให้เห็นใน journal ของ tester (Debug ถูกปิด)
      return(false);
     }

   int pos = CountPositions();
   if(pos >= m_max_positions)
     {
      why = StringFormat("มี position ครบ %d/%d แล้ว", pos, m_max_positions);
      return(false);
     }

   //--- D6: netting — position ของ symbol นี้ทุก magic รวมเป็นตัวเดียว ห้ามเปิดทับ
   if(IsNettingAccount())
     {
      int sym_pos = CountSymbolPositions();
      if(sym_pos > 0)
        {
         why = StringFormat("netting: มี position ของ %s อยู่แล้ว %d (ทุก magic) — ไม่เปิด", m_symbol, sym_pos);
         return(false);
        }
     }

   if(m_max_spread > 0)
     {
      long spread = SymbolInfoInteger(m_symbol, SYMBOL_SPREAD);
      if(spread > m_max_spread)
        {
         why = StringFormat("spread %d > จำกัด %d points", (int)spread, m_max_spread);
         return(false);
        }
     }
   return(true);
  }

//+------------------------------------------------------------------+
int CRiskManager::StepDigits(const double step) const
  {
   int d = 0;
   while(d < 8 && MathAbs(step * MathPow(10.0, d) - MathRound(step * MathPow(10.0, d))) > 1e-9)
      d++;
   return(d);
  }

//+------------------------------------------------------------------+
bool CRiskManager::ComputeLot(const double risk_money, const double loss_per_lot, const double commission,
                              const double vmin, const double vmax, const double vstep,
                              double &lot, string &why) const
  {
   lot = 0.0;
   why = "";

   if(risk_money <= 0.0 || loss_per_lot <= 0.0 || commission < 0.0)
     {
      why = StringFormat("input ไม่ถูกต้อง risk_money=%.2f loss_per_lot=%.2f commission=%.2f",
                         risk_money, loss_per_lot, commission);
      return(false);
     }
   if(vmin <= 0.0 || vmax < vmin || vstep <= 0.0)
     {
      why = StringFormat("volume spec ไม่ถูกต้อง min=%.4f max=%.4f step=%.4f", vmin, vmax, vstep);
      return(false);
     }

   double raw   = risk_money / (loss_per_lot + commission);
   //--- ปัดลงเสมอ; 1e-9 กัน floating noise (เช่น 0.3/0.1 = 2.9999999) ไม่ใช่การปัดขึ้น
   double steps = MathFloor(raw / vstep + 1e-9);
   double v     = steps * vstep;

   if(v < vmin - 1e-12)
     {
      why = StringFormat("lot %.4f ต่ำกว่า volume_min %.2f — ข้ามไม้ (ไม่ปัดขึ้น)", raw, vmin);
      return(false);
     }

   v   = MathMin(v, vmax);
   lot = NormalizeDouble(v, StepDigits(vstep));
   return(true);
  }

//+------------------------------------------------------------------+
bool CRiskManager::CalcLot(const SSignalIntent &intent, const double entry, double &lot, string &why)
  {
   lot = 0.0;
   why = "";
   if(!m_ready)
     {
      why = "RiskManager ยังไม่ Init";
      return(false);
     }
   if(intent.dir == SIGNAL_NONE || intent.sl_distance <= 0.0 || entry <= 0.0)
     {
      why = "intent ไม่ถูกต้อง (ต้องมีทิศทางและ sl_distance > 0)";
      return(false);
     }

   bool   buy    = (intent.dir == SIGNAL_BUY);
   //--- helper เดียวกับ CTradeManager::Open: SL ปัดเข้าหา entry บน tick grid -> lot คำนวณจาก SL ที่จะถูกส่งจริง
   double sl     = NormalizeSlPrice(m_symbol, intent.dir, buy ? entry - intent.sl_distance : entry + intent.sl_distance);

   //--- ขาดทุนจริงต่อ 1 lot ที่ราคา SL ในสกุลเงินบัญชี
   double pl = 0.0;
   if(!OrderCalcProfit(buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, m_symbol, 1.0, entry, sl, pl))
     {
      why = StringFormat("OrderCalcProfit ล้มเหลว err=%d", GetLastError());
      return(false);
     }
   double loss_per_lot = -pl;

   double equity     = AccountInfoDouble(ACCOUNT_EQUITY);
   double risk_money = equity * m_risk_pct / 100.0;
   double vmin       = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
   double vmax       = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
   double vstep      = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);

   if(!ComputeLot(risk_money, loss_per_lot, m_commission, vmin, vmax, vstep, lot, why))
      return(false);

   //--- D4: ถ้าโดน SL (รวม commission) แล้วทะลุ daily limit -> ปฏิเสธ ไม่ลด lot
   if(!m_balance_ok)
     {
      lot = 0.0;
      why = "ไม่รู้ balance ต้นวัน (fail closed)";
      return(false);
     }
   double worst_loss = (loss_per_lot + m_commission) * lot;
   if(!PreTradeOk(equity, worst_loss, m_day_balance, m_daily_loss_pct, why))
     {
      lot = 0.0;
      return(false);
     }

   //--- margin พอไหม
   double margin = 0.0;
   if(!OrderCalcMargin(buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, m_symbol, lot, entry, margin))
     {
      lot = 0.0;
      why = StringFormat("OrderCalcMargin ล้มเหลว err=%d", GetLastError());
      return(false);
     }
   double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(margin > free_margin)
     {
      why = StringFormat("margin ไม่พอ ต้องการ %.2f เหลือ %.2f (lot %.2f)", margin, free_margin, lot);
      lot = 0.0;
      return(false);
     }

   m_log.Debug(StringFormat("CalcLot: equity=%.2f risk=%.2f loss/lot=%.2f comm=%.2f -> lot=%.2f",
                            equity, risk_money, loss_per_lot, m_commission, lot));
   return(true);
  }

#endif
//+------------------------------------------------------------------+
