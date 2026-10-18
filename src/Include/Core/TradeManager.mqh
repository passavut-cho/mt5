//+------------------------------------------------------------------+
//|                                                 TradeManager.mqh |
//|  ชั้น Execution: ห่อ CTrade — ส่ง order พร้อม SL + magic เสมอ       |
//+------------------------------------------------------------------+
#ifndef SMARTEA_CORE_TRADEMANAGER_MQH
#define SMARTEA_CORE_TRADEMANAGER_MQH

#include <Trade/Trade.mqh>
#include "Types.mqh"
#include "Logger.mqh"
#include "Telemetry.mqh"

class CTradeManager
  {
private:
   CTrade    m_trade;
   string    m_symbol;
   ulong     m_magic;
   CLogger  *m_log;
   bool      m_ready;
   double    m_last_fill;     // ราคา fill ของ Open ล่าสุดที่สำเร็จ
   double    m_last_sl;       // SL (normalized) ที่ส่งไปกับ Open ล่าสุด
   ulong     m_last_deal;     // deal ticket ของ Open ล่าสุดที่สำเร็จ
   CTelemetry *m_tel;         // NULL = ไม่เก็บ telemetry (read-only hook ห้ามกระทบการเทรด)

   double    NormPrice(const double price) const;
   bool      ValidateStops(const ENUM_SIGNAL_DIR dir, const double sl, const double tp, string &why) const;
   bool      IsRetryable(const uint retcode) const;
   bool      IsSuccess(const uint retcode) const;

public:
             CTradeManager() : m_symbol(""), m_magic(0), m_log(NULL), m_ready(false), m_last_fill(0), m_last_sl(0), m_last_deal(0), m_tel(NULL) {}

   bool      Init(const string symbol, const ulong magic, CLogger *log, const uint deviation_points);

   //--- ส่ง order ครั้งเดียว (D5: ไม่ retry ในนี้ — ผู้เรียกคำนวณราคา/SL/lot ใหม่ผ่าน RiskManager แล้วเรียกซ้ำ)
   //--- sl ต้อง != 0 และถูกฝั่ง/ห่างพอ ไม่งั้นไม่ส่ง; tp = 0 คือไม่มี TP
   //--- retryable = true เมื่อ retcode เป็น REQUOTE / PRICE_CHANGED / PRICE_OFF
   bool      Open(const ENUM_SIGNAL_DIR dir, const double lot, const double sl, const double tp, const string comment,
                  bool &retryable);
   double    LastFillPrice() const { return(m_last_fill); }
   double    LastSl() const { return(m_last_sl); }
   ulong     LastDeal() const { return(m_last_deal); }
   void      SetTelemetry(CTelemetry *tel) { m_tel = tel; }
   bool      CloseAll(const string why);
   int       CountPositions() const;      // กรอง magic + symbol
  };

//+------------------------------------------------------------------+
bool CTradeManager::Init(const string symbol, const ulong magic, CLogger *log, const uint deviation_points)
  {
   m_ready = false;
   if(log == NULL)
      return(false);
   m_log = log;

   if(!SymbolSelect(symbol, true))
     {
      m_log.Error(StringFormat("SymbolSelect(%s) ล้มเหลว err=%d", symbol, GetLastError()));
      return(false);
     }

   m_symbol = symbol;
   m_magic  = magic;

   m_trade.SetExpertMagicNumber(magic);
   m_trade.SetDeviationInPoints(deviation_points);
   m_trade.SetTypeFillingBySymbol(symbol);
   m_trade.SetAsyncMode(false);

   m_ready = true;
   return(true);
  }

//+------------------------------------------------------------------+
double CTradeManager::NormPrice(const double price) const
  {
   int    digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
   double tick   = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick > 0.0)
      return(NormalizeDouble(MathRound(price / tick) * tick, digits));
   return(NormalizeDouble(price, digits));
  }

//+------------------------------------------------------------------+
//| SL ต้อง != 0, ถูกฝั่ง, ห่างราคา >= STOPS_LEVEL; TP (ถ้ามี) ก็เช่นกัน |
//+------------------------------------------------------------------+
bool CTradeManager::ValidateStops(const ENUM_SIGNAL_DIR dir, const double sl, const double tp, string &why) const
  {
   why = "";
   if(sl <= 0.0)
     {
      why = "ไม่มี SL";
      return(false);
     }

   MqlTick tick;
   if(!SymbolInfoTick(m_symbol, tick) || tick.ask <= 0.0 || tick.bid <= 0.0)
     {
      why = StringFormat("อ่านราคาไม่ได้ err=%d", GetLastError());
      return(false);
     }

   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   double level = (double)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;

   if(dir == SIGNAL_BUY)
     {
      if(sl > tick.bid - level)
        {
         why = StringFormat("SL %.5f ต้อง <= bid-stops_level (%.5f)", sl, tick.bid - level);
         return(false);
        }
      if(tp > 0.0 && tp < tick.bid + level)
        {
         why = StringFormat("TP %.5f ต้อง >= bid+stops_level (%.5f)", tp, tick.bid + level);
         return(false);
        }
     }
   else if(dir == SIGNAL_SELL)
     {
      if(sl < tick.ask + level)
        {
         why = StringFormat("SL %.5f ต้อง >= ask+stops_level (%.5f)", sl, tick.ask + level);
         return(false);
        }
      if(tp > 0.0 && tp > tick.ask - level)
        {
         why = StringFormat("TP %.5f ต้อง <= ask-stops_level (%.5f)", tp, tick.ask - level);
         return(false);
        }
     }
   else
     {
      why = "ทิศทางไม่ถูกต้อง";
      return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
bool CTradeManager::IsRetryable(const uint retcode) const
  {
   return(retcode == TRADE_RETCODE_REQUOTE ||
          retcode == TRADE_RETCODE_PRICE_CHANGED ||
          retcode == TRADE_RETCODE_PRICE_OFF);
  }

bool CTradeManager::IsSuccess(const uint retcode) const
  {
   return(retcode == TRADE_RETCODE_DONE || retcode == TRADE_RETCODE_DONE_PARTIAL);
  }

//+------------------------------------------------------------------+
bool CTradeManager::Open(const ENUM_SIGNAL_DIR dir, const double lot, const double sl_in, const double tp_in,
                         const string comment, bool &retryable)
  {
   retryable   = false;
   m_last_fill = 0.0;
   m_last_sl   = 0.0;
   m_last_deal = 0;
   if(!m_ready || m_log == NULL)
      return(false);
   if(lot <= 0.0)
     {
      m_log.Trade("REJECT", StringFormat("lot=%.2f ไม่ถูกต้อง", lot));
      return(false);
     }

   const double sl   = NormalizeSlPrice(m_symbol, dir, sl_in);   // helper เดียวกับ CalcLot (ปัดเข้าหา entry)
   const double tp   = (tp_in > 0.0) ? NormPrice(tp_in) : 0.0;
   const string side = (dir == SIGNAL_BUY) ? "BUY" : "SELL";

   string why;
   if(!ValidateStops(dir, sl, tp, why))
     {
      m_log.Trade("REJECT", StringFormat("%s lot=%.2f sl=%.5f tp=%.5f : %s", side, lot, sl, tp, why));
      return(false);
     }

   //--- SL + magic ไปพร้อม order ตั้งแต่ครั้งแรก (price = 0 -> ราคาตลาดปัจจุบัน)
   //--- telemetry: จดราคาที่ "ขอ" (ask/bid ก่อนส่ง) และเวลา round trip — อ่านอย่างเดียว ไม่กระทบ order
   MqlTick pre;
   const bool pre_ok = (m_tel != NULL && m_tel.Enabled() && SymbolInfoTick(m_symbol, pre));
   const ulong t0 = GetMicrosecondCount();
   bool sent = (dir == SIGNAL_BUY) ? m_trade.Buy(lot, m_symbol, 0.0, sl, tp, comment)
                                   : m_trade.Sell(lot, m_symbol, 0.0, sl, tp, comment);
   const double latency_ms = (double)(GetMicrosecondCount() - t0) / 1000.0;
   uint rc = m_trade.ResultRetcode();
   if(pre_ok)
     {
      const double req = (dir == SIGNAL_BUY) ? pre.ask : pre.bid;
      m_tel.OnOrder("open", (dir == SIGNAL_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, lot, req,
                    (sent && IsSuccess(rc)) ? m_trade.ResultPrice() : 0.0,
                    MathRound((pre.ask - pre.bid) / SymbolInfoDouble(m_symbol, SYMBOL_POINT)), latency_ms, rc, comment);
     }

   if(sent && IsSuccess(rc))
     {
      m_last_fill = m_trade.ResultPrice();
      m_last_sl   = sl;
      m_last_deal = m_trade.ResultDeal();
      m_log.Trade("OPEN", StringFormat("%s lot=%.2f price=%.5f sl=%.5f tp=%.5f deal=%I64u [%s]",
                                       side, lot, m_last_fill, sl, tp, m_trade.ResultDeal(), comment));
      return(true);
     }

   retryable = IsRetryable(rc);
   if(retryable)
     {
      m_log.Warn(StringFormat("%s retcode=%u (%s) — ขอคำนวณราคา/SL/lot ใหม่", side, rc, m_trade.ResultRetcodeDescription()));
      return(false);
     }

   m_log.Trade("REJECT", StringFormat("%s lot=%.2f sl=%.5f : send=%s retcode=%u (%s)",
                                      side, lot, sl, sent ? "true" : "false", rc,
                                      m_trade.ResultRetcodeDescription()));
   return(false);
  }

//+------------------------------------------------------------------+
int CTradeManager::CountPositions() const
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
bool CTradeManager::CloseAll(const string why)
  {
   if(!m_ready)
      return(false);

   bool all_ok = true;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != m_symbol || (ulong)PositionGetInteger(POSITION_MAGIC) != m_magic)
         continue;

      //--- telemetry: ราคาที่ "ขอ" ตอนปิด long = bid, short = ask (ต้องอ่านก่อนปิด)
      const ulong pid = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      const bool  was_buy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      const double vol = PositionGetDouble(POSITION_VOLUME);
      MqlTick pre;
      const bool pre_ok = (m_tel != NULL && m_tel.Enabled() && SymbolInfoTick(m_symbol, pre));
      if(m_tel != NULL)
         m_tel.NoteClose(pid, why);
      const ulong t0 = GetMicrosecondCount();
      bool ok = m_trade.PositionClose(ticket);
      const double latency_ms = (double)(GetMicrosecondCount() - t0) / 1000.0;
      uint rc = m_trade.ResultRetcode();
      if(pre_ok)
         m_tel.OnOrder("close", was_buy ? ORDER_TYPE_SELL : ORDER_TYPE_BUY, vol, was_buy ? pre.bid : pre.ask,
                       (ok && IsSuccess(rc)) ? m_trade.ResultPrice() : 0.0,
                       MathRound((pre.ask - pre.bid) / SymbolInfoDouble(m_symbol, SYMBOL_POINT)), latency_ms, rc, why);
      if(ok && IsSuccess(rc))
         m_log.Trade("CLOSE", StringFormat("ticket=%I64u price=%.5f : %s", ticket, m_trade.ResultPrice(), why));
      else
        {
         all_ok = false;
         m_log.Error(StringFormat("CLOSE ticket=%I64u ล้มเหลว retcode=%u (%s)", ticket, rc,
                                  m_trade.ResultRetcodeDescription()));
        }
     }
   return(all_ok);
  }

#endif
//+------------------------------------------------------------------+
