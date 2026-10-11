//+------------------------------------------------------------------+
//|                                                 TradeManager.mqh |
//|  ชั้น Execution — ห่อ CTrade                                      |
//|  - SL ส่งพร้อม order เสมอ และตรวจก่อนส่ง (ไม่ผ่าน = ไม่ส่ง)         |
//|  - retry เฉพาะ REQUOTE / PRICE_CHANGED / PRICE_OFF สูงสุด 2 ครั้ง   |
//|  - นับ/ปิดเฉพาะ magic + symbol นี้                                |
//+------------------------------------------------------------------+
#ifndef SMARTEA_CORE_TRADEMANAGER_MQH
#define SMARTEA_CORE_TRADEMANAGER_MQH

#include <Trade/Trade.mqh>
#include "Types.mqh"
#include "Logger.mqh"

#define TRADE_MAX_RETRIES  2

class CTradeManager
  {
private:
   CTrade            m_trade;
   string            m_symbol;
   ulong             m_magic;
   CLogger          *m_log;
   int               m_digits;
   double            m_point;
   bool              m_ready;

   static bool       IsRetryable(const uint retcode)
     {
      return(retcode == TRADE_RETCODE_REQUOTE ||
             retcode == TRADE_RETCODE_PRICE_CHANGED ||
             retcode == TRADE_RETCODE_PRICE_OFF);
     }

   //--- lot ต้องอยู่ใน MIN/MAX และเป็นจำนวนเท่าของ STEP
   bool              ValidateLot(const double lot, string &why) const
     {
      double vmin  = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      double vmax  = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
      double vstep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
      if(lot < vmin || lot > vmax)
        {
         why = StringFormat("lot %.4f outside [%.2f, %.2f]", lot, vmin, vmax);
         return(false);
        }
      if(vstep > 0.0)
        {
         double k = lot / vstep;
         if(MathAbs(k - MathRound(k)) > 1e-6)
           {
            why = StringFormat("lot %.4f not a multiple of step %.4f", lot, vstep);
            return(false);
           }
        }
      return(true);
     }

   //--- SL ต้อง != 0, อยู่ฝั่งถูก, ห่างราคาปัจจุบัน >= STOPS_LEVEL ; TP (ถ้ามี) เช่นเดียวกัน
   bool              ValidateStops(const ENUM_SIGNAL_DIR dir, const double sl, const double tp, string &why) const
     {
      MqlTick tick;
      if(!SymbolInfoTick(m_symbol, tick) || tick.bid <= 0.0 || tick.ask <= 0.0)
        {
         why = "no valid tick";
         return(false);
        }
      if(sl <= 0.0)
        {
         why = "SL is zero/negative";
         return(false);
        }
      double stops = (double)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL) * m_point;
      double eps   = m_point * 0.5;   // กัน floating error ตอนเทียบระยะ

      if(dir == SIGNAL_BUY)
        {
         if(tick.bid - sl < stops - eps || sl >= tick.bid)
           {
            why = StringFormat("BUY SL %s invalid vs bid %s (stops level %s)", DoubleToString(sl, m_digits), DoubleToString(tick.bid, m_digits), DoubleToString(stops, m_digits));
            return(false);
           }
         if(tp > 0.0 && (tp - tick.bid < stops - eps || tp <= tick.bid))
           {
            why = StringFormat("BUY TP %s invalid vs bid %s (stops level %s)", DoubleToString(tp, m_digits), DoubleToString(tick.bid, m_digits), DoubleToString(stops, m_digits));
            return(false);
           }
        }
      else
        {
         if(sl - tick.ask < stops - eps || sl <= tick.ask)
           {
            why = StringFormat("SELL SL %s invalid vs ask %s (stops level %s)", DoubleToString(sl, m_digits), DoubleToString(tick.ask, m_digits), DoubleToString(stops, m_digits));
            return(false);
           }
         if(tp > 0.0 && (tick.ask - tp < stops - eps || tp >= tick.ask))
           {
            why = StringFormat("SELL TP %s invalid vs ask %s (stops level %s)", DoubleToString(tp, m_digits), DoubleToString(tick.ask, m_digits), DoubleToString(stops, m_digits));
            return(false);
           }
        }
      return(true);
     }

   bool              Reject(const string dir_text, const double lot, const string why) const
     {
      m_log.Trade("REJECT", StringFormat("%s lot=%.2f | %s", dir_text, lot, why));
      return(false);
     }

public:
                     CTradeManager() : m_symbol(""), m_magic(0), m_log(NULL), m_digits(0), m_point(0.0), m_ready(false) {}

   bool              Init(const string symbol, const ulong magic, CLogger *log, const uint deviation_points)
     {
      m_ready = false;
      if(log == NULL)
         return(false);
      m_log = log;
      if(!SymbolSelect(symbol, true))
        {
         m_log.Error(StringFormat("symbol '%s' not available", symbol));
         return(false);
        }
      m_symbol = symbol;
      m_magic  = magic;
      m_digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      m_point  = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(m_point <= 0.0)
        {
         m_log.Error("SYMBOL_POINT invalid");
         return(false);
        }
      m_trade.SetExpertMagicNumber(magic);
      m_trade.SetDeviationInPoints(deviation_points);
      m_trade.SetAsyncMode(false);
      if(!m_trade.SetTypeFillingBySymbol(symbol))
        {
         m_log.Error("SetTypeFillingBySymbol failed");
         return(false);
        }
      m_ready = true;
      m_log.Info(StringFormat("trade init: deviation=%u points", deviation_points));
      return(true);
     }

   //--- เปิดไม้ตลาดพร้อม SL/TP + magic ในคำสั่งเดียว
   bool              Open(const ENUM_SIGNAL_DIR dir, const double lot, const double sl, const double tp, const string comment)
     {
      string dir_text = (dir == SIGNAL_BUY) ? "BUY" : (dir == SIGNAL_SELL) ? "SELL" : "NONE";
      if(!m_ready)
         return(false);
      if(dir == SIGNAL_NONE)
         return(Reject(dir_text, lot, "direction is NONE"));

      string why = "";
      if(!ValidateLot(lot, why))
         return(Reject(dir_text, lot, why));

      double nsl = NormalizeDouble(sl, m_digits);
      double ntp = (tp > 0.0) ? NormalizeDouble(tp, m_digits) : 0.0;
      string cmt = StringSubstr(comment, 0, 31);

      for(int attempt = 0; attempt <= TRADE_MAX_RETRIES; attempt++)
        {
         if(!ValidateStops(dir, nsl, ntp, why))
            return(Reject(dir_text, lot, why));

         MqlTick tick;
         if(!SymbolInfoTick(m_symbol, tick))
            return(Reject(dir_text, lot, "no tick"));

         bool sent;
         if(dir == SIGNAL_BUY)
            sent = m_trade.Buy(lot, m_symbol, tick.ask, nsl, ntp, cmt);
         else
            sent = m_trade.Sell(lot, m_symbol, tick.bid, nsl, ntp, cmt);

         uint rc = m_trade.ResultRetcode();
         if(sent && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL))
           {
            m_log.Trade("OPEN", StringFormat("%s lot=%.2f price=%s sl=%s tp=%s deal=%I64u rc=%u | %s",
                                             dir_text, lot, DoubleToString(m_trade.ResultPrice(), m_digits),
                                             DoubleToString(nsl, m_digits), DoubleToString(ntp, m_digits),
                                             m_trade.ResultDeal(), rc, cmt));
            return(true);
           }

         if(IsRetryable(rc) && attempt < TRADE_MAX_RETRIES)
           {
            m_log.Warn(StringFormat("%s retcode %u (%s) — retry %d/%d", dir_text, rc,
                                    m_trade.ResultRetcodeDescription(), attempt + 1, TRADE_MAX_RETRIES));
            Sleep(100);
            continue;
           }
         return(Reject(dir_text, lot, StringFormat("send failed retcode=%u (%s)", rc, m_trade.ResultRetcodeDescription())));
        }
      return(false);
     }

   //--- ปิดทุกไม้ของ magic + symbol นี้ ; true = ปิดครบทุกไม้
   bool              CloseAll(const string why)
     {
      if(!m_ready)
         return(false);
      bool all_ok = true;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != m_symbol ||
            (ulong)PositionGetInteger(POSITION_MAGIC) != m_magic)
            continue;
         bool   ok = m_trade.PositionClose(ticket);
         uint   rc = m_trade.ResultRetcode();
         if(ok && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL))
            m_log.Trade("CLOSE", StringFormat("ticket=%I64u price=%s | %s", ticket, DoubleToString(m_trade.ResultPrice(), m_digits), why));
         else
           {
            all_ok = false;
            m_log.Trade("CLOSE_FAILED", StringFormat("ticket=%I64u retcode=%u (%s) | %s", ticket, rc,
                                                      m_trade.ResultRetcodeDescription(), why));
           }
        }
      return(all_ok);
     }

   int               CountPositions() const
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
  };

#endif
