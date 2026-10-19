//+------------------------------------------------------------------+
//|                                         SessionBreakoutSignal.mqh |
//|  Session Breakout (S-A): ทะลุกรอบเอเชียครั้งแรกของวัน             |
//|  spec: docs/strategy/spec-session-breakout.md                     |
//|  Signal ไม่แตะ lot / order / risk — ส่งแค่ทิศทางกับระยะ SL/TP      |
//+------------------------------------------------------------------+
#ifndef SMARTEA_SIGNALS_SESSIONBREAKOUTSIGNAL_MQH
#define SMARTEA_SIGNALS_SESSIONBREAKOUTSIGNAL_MQH

#include "../Core/SignalBase.mqh"

//--- ตำแหน่ง SL ของ breakout
enum ENUM_SBO_SL_MODE
  {
   SBO_SL_OPPOSITE = 0,   // ขอบตรงข้ามของกรอบ
   SBO_SL_MID      = 1    // กลางกรอบ (½ ความกว้าง)
  };

class CSessionBreakoutSignal : public CSignalBase
  {
private:
   CLogger        *m_log;
   string          m_symbol;
   ENUM_TIMEFRAMES m_tf;

   //--- พารามิเตอร์ (ตั้งผ่าน Configure ก่อน Init)
   int              m_asia_start_hour;     // กรอบเอเชีย = แท่งที่เปิด start <= hour < end (server time)
   int              m_asia_end_hour;
   int              m_entry_end_hour;      // เข้าไม้ได้ตั้งแต่ asia_end จนก่อน hour นี้ (เวลาที่ส่ง order)
   double           m_max_range_atr;       // ข้ามวันที่กรอบกว้างกว่า mult x ATR(รายวัน)[1]
   ENUM_TIMEFRAMES  m_atr_tf;
   int              m_atr_period;
   ENUM_SBO_SL_MODE m_sl_mode;
   bool             m_use_tp;
   double           m_tp_r_mult;
   int              m_friday_cutoff_hour;  // ศุกร์: ไม่เปิดไม้ใหม่เมื่อ hour >= ค่านี้
   bool             m_configured;

   int              m_h_atr;               // ATR รายวัน (handle ของ m_atr_tf)

   //--- state ต่อวัน (key = 00:00 server ของวันที่แท่งสัญญาณเปิด)
   datetime         m_done_day;            // วันที่ใช้สิทธิ์ breakout แรกไปแล้ว/ข้ามวันนี้ (ไม่หาสัญญาณอีก)
   datetime         m_range_day;           // วันที่ที่ cache กรอบไว้
   double           m_range_hi;
   double           m_range_lo;

   bool            BuildRange(const datetime day, bool &skip_day);

public:
                   CSessionBreakoutSignal();
                  ~CSessionBreakoutSignal() { Deinit(); }

   bool            Configure(const int asia_start_hour, const int asia_end_hour, const int entry_end_hour,
                             const double max_range_atr, const ENUM_TIMEFRAMES atr_tf, const int atr_period,
                             const ENUM_SBO_SL_MODE sl_mode, const bool use_tp, const double tp_r_mult,
                             const int friday_cutoff_hour);

   virtual bool    Init(const string symbol, const ENUM_TIMEFRAMES tf, CLogger *log);
   virtual void    Deinit();
   virtual bool    Evaluate(SSignalIntent &out);
   virtual string  Name() const { return("SessionBreakout"); }
  };

//+------------------------------------------------------------------+
CSessionBreakoutSignal::CSessionBreakoutSignal()
   : m_log(NULL), m_symbol(""), m_tf(PERIOD_CURRENT),
     m_asia_start_hour(0), m_asia_end_hour(0), m_entry_end_hour(0), m_max_range_atr(0),
     m_atr_tf(PERIOD_D1), m_atr_period(0), m_sl_mode(SBO_SL_OPPOSITE), m_use_tp(false), m_tp_r_mult(0),
     m_friday_cutoff_hour(0), m_configured(false), m_h_atr(INVALID_HANDLE),
     m_done_day(0), m_range_day(0), m_range_hi(0), m_range_lo(0)
  {
  }

//+------------------------------------------------------------------+
bool CSessionBreakoutSignal::Configure(const int asia_start_hour, const int asia_end_hour, const int entry_end_hour,
                                       const double max_range_atr, const ENUM_TIMEFRAMES atr_tf, const int atr_period,
                                       const ENUM_SBO_SL_MODE sl_mode, const bool use_tp, const double tp_r_mult,
                                       const int friday_cutoff_hour)
  {
   m_configured = false;
   if(asia_start_hour < 0 || asia_end_hour > 23 || asia_start_hour >= asia_end_hour ||
      entry_end_hour <= asia_end_hour || entry_end_hour > 24 ||
      max_range_atr <= 0.0 || atr_tf == PERIOD_CURRENT || atr_period < 1 ||
      (sl_mode != SBO_SL_OPPOSITE && sl_mode != SBO_SL_MID) ||
      (use_tp && tp_r_mult <= 0.0) ||
      friday_cutoff_hour < 0 || friday_cutoff_hour > 24)
      return(false);

   m_asia_start_hour    = asia_start_hour;
   m_asia_end_hour      = asia_end_hour;
   m_entry_end_hour     = entry_end_hour;
   m_max_range_atr      = max_range_atr;
   m_atr_tf             = atr_tf;
   m_atr_period         = atr_period;
   m_sl_mode            = sl_mode;
   m_use_tp             = use_tp;
   m_tp_r_mult          = tp_r_mult;
   m_friday_cutoff_hour = friday_cutoff_hour;
   m_configured         = true;
   return(true);
  }

//+------------------------------------------------------------------+
bool CSessionBreakoutSignal::Init(const string symbol, const ENUM_TIMEFRAMES tf, CLogger *log)
  {
   if(log == NULL)
      return(false);
   m_log = log;
   if(!m_configured)
     {
      m_log.Error("CSessionBreakoutSignal: พารามิเตอร์ไม่ถูกต้อง/ยังไม่ Configure");
      return(false);
     }
   if(PeriodSeconds(tf) <= 0 || PeriodSeconds(tf) > 3600)
     {
      m_log.Error("CSessionBreakoutSignal: timeframe ของ chart ต้องไม่เกิน H1 (ใช้นับแท่งในกรอบเอเชีย)");
      return(false);
     }

   m_symbol = symbol;
   m_tf     = tf;
   Deinit();   // กัน handle รั่วถ้า Init ซ้ำ

   m_h_atr = iATR(symbol, m_atr_tf, m_atr_period);
   if(m_h_atr == INVALID_HANDLE)
     {
      m_log.Error(StringFormat("สร้าง ATR(%s) handle ล้มเหลว err=%d", EnumToString(m_atr_tf), GetLastError()));
      return(false);
     }

   m_done_day  = 0;
   m_range_day = 0;
   m_log.Info(StringFormat("CSessionBreakoutSignal init %s %s asia %02d-%02d entry <%02d range<=%.2fxATR(%s,%d) sl=%s tp=%s friCut %02d",
                           symbol, EnumToString(tf), m_asia_start_hour, m_asia_end_hour, m_entry_end_hour,
                           m_max_range_atr, EnumToString(m_atr_tf), m_atr_period,
                           (m_sl_mode == SBO_SL_OPPOSITE ? "OPPOSITE" : "MID"),
                           (m_use_tp ? StringFormat("%.1fR", m_tp_r_mult) : "off"), m_friday_cutoff_hour));
   return(true);
  }

//+------------------------------------------------------------------+
void CSessionBreakoutSignal::Deinit()
  {
   if(m_h_atr != INVALID_HANDLE) { IndicatorRelease(m_h_atr); m_h_atr = INVALID_HANDLE; }
  }

//+------------------------------------------------------------------+
//| สร้างกรอบเอเชียของวัน (key = 00:00 server)                          |
//| คืน false = ข้อมูลไม่พร้อม (ลองใหม่แท่งหน้า)                          |
//| skip_day = true เมื่อวันนี้ไม่เทรด (แท่งไม่พอ / กรอบกว้างเกิน ATR)      |
//+------------------------------------------------------------------+
bool CSessionBreakoutSignal::BuildRange(const datetime day, bool &skip_day)
  {
   skip_day = false;

   const datetime from = day + (datetime)m_asia_start_hour * 3600;
   const datetime to   = day + (datetime)m_asia_end_hour * 3600 - 1;
   MqlRates rates[];
   const int n = CopyRates(m_symbol, m_tf, from, to, rates);
   if(n < 0)
      return(false);

   //--- ต้องมีแท่งอย่างน้อย 5/6 ของที่ควรมี (M15 กรอบ 9 ชม. = 36 แท่ง -> 30)
   const int expected = (m_asia_end_hour - m_asia_start_hour) * 3600 / PeriodSeconds(m_tf);
   const int min_bars = (int)MathCeil(expected * 5.0 / 6.0);
   if(n < min_bars)
     {
      m_log.Info(StringFormat("SBO ข้ามวัน %s: แท่งในกรอบเอเชียมี %d < %d", TimeToString(day, TIME_DATE), n, min_bars));
      skip_day = true;
      return(true);
     }

   double hi = rates[0].high, lo = rates[0].low;
   for(int i = 1; i < n; i++)
     {
      hi = MathMax(hi, rates[i].high);
      lo = MathMin(lo, rates[i].low);
     }
   const double width = hi - lo;

   //--- ATR รายวันของวันก่อนหน้า (shift 1 = แท่งที่ปิดแล้ว)
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(m_h_atr, 0, 1, 1, atr) != 1)
      return(false);
   if(atr[0] <= 0.0)
     {
      m_log.Warn(StringFormat("SBO ข้ามวัน %s: ATR ไม่ถูกต้อง (%.5f)", TimeToString(day, TIME_DATE), atr[0]));
      skip_day = true;
      return(true);
     }
   if(width <= 0.0 || width > m_max_range_atr * atr[0])
     {
      m_log.Info(StringFormat("SBO ข้ามวัน %s: กรอบ %.2f (hi %.2f lo %.2f) ไม่อยู่ใน 0..%.2fxATR %.2f",
                              TimeToString(day, TIME_DATE), width, hi, lo, m_max_range_atr, atr[0]));
      skip_day = true;
      return(true);
     }

   m_range_day = day;
   m_range_hi  = hi;
   m_range_lo  = lo;
   m_log.Info(StringFormat("SBO กรอบเอเชีย %s: hi %.2f lo %.2f กว้าง %.2f (%d แท่ง, ATR %.2f)",
                           TimeToString(day, TIME_DATE), hi, lo, width, n, atr[0]));
   return(true);
  }

//+------------------------------------------------------------------+
//| เรียกตอนเกิดแท่งใหม่: ดูแท่งที่ปิดแล้ว (shift 1)                     |
//| breakout แรกของวัน (ฝั่งใดก็ได้) ใช้สิทธิ์ของวันนั้นทันที —          |
//| ต่อให้ filter ภายหลัง (S4/news/holiday/risk) ปฏิเสธ ก็ไม่หาใหม่ในวันเดียวกัน|
//+------------------------------------------------------------------+
bool CSessionBreakoutSignal::Evaluate(SSignalIntent &out)
  {
   out.Reset();
   if(m_h_atr == INVALID_HANDLE)
      return(false);

   MqlRates bar[];
   if(CopyRates(m_symbol, m_tf, 1, 1, bar) != 1)
      return(false);

   //--- เวลาเข้าไม้ = เวลาปิดแท่งสัญญาณ (open แท่งถัดไป)
   const datetime entry_time = bar[0].time + (datetime)PeriodSeconds(m_tf);
   MqlDateTime et;
   TimeToStruct(entry_time, et);
   if(et.day_of_week < 1 || et.day_of_week > 5)
      return(true);
   if(et.hour < m_asia_end_hour || et.hour >= m_entry_end_hour)
      return(true);
   if(et.day_of_week == 5 && et.hour >= m_friday_cutoff_hour)
      return(true);   // S7

   const datetime day = bar[0].time - (bar[0].time % 86400);
   if(day != entry_time - (entry_time % 86400))
      return(true);   // แท่งสัญญาณข้ามเที่ยงคืน (ไม่ควรเกิดเมื่อ entry_end <= 24 แต่กันไว้)
   if(day == m_done_day)
      return(true);

   if(m_range_day != day)
     {
      bool skip = false;
      if(!BuildRange(day, skip))
         return(false);
      if(skip)
        {
         m_done_day = day;
         return(true);
        }
     }

   ENUM_SIGNAL_DIR dir = SIGNAL_NONE;
   if(bar[0].close > m_range_hi)
      dir = SIGNAL_BUY;
   else if(bar[0].close < m_range_lo)
      dir = SIGNAL_SELL;
   else
      return(true);    // ยังอยู่ในกรอบ = ไม่มีสัญญาณ

   m_done_day = day;   // breakout แรกของวัน — ใช้สิทธิ์แล้วไม่ว่าจะเข้าได้หรือไม่
   const string side = (dir == SIGNAL_BUY) ? "BUY" : "SELL";

   const double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
     {
      m_log.Warn(StringFormat("SBO breakout %s ไม่เข้า: อ่าน ask/bid ไม่ได้", side));
      return(true);
     }

   //--- SL ตาม variant: OPPOSITE = ขอบตรงข้ามกรอบ, MID = กลางกรอบ
   const double sl_price = (m_sl_mode == SBO_SL_OPPOSITE)
                           ? ((dir == SIGNAL_BUY) ? m_range_lo : m_range_hi)
                           : (m_range_hi + m_range_lo) / 2.0;
   const double sl_dist = (dir == SIGNAL_BUY) ? ask - sl_price : sl_price - bid;
   if(sl_dist <= 0.0)
     {
      m_log.Warn(StringFormat("SBO breakout %s ไม่เข้า: SL %.2f อยู่ผิดฝั่งของราคาเข้า", side, sl_price));
      return(true);
     }

   //--- S4: SL แคบกว่า 2 x spread = ไม่เข้า
   const double spread = ask - bid;
   if(sl_dist < 2.0 * spread)
     {
      m_log.Info(StringFormat("SBO breakout %s ไม่เข้า: SL %.5f < 2 x spread %.5f (S4)", side, sl_dist, spread));
      return(true);
     }

   out.dir         = dir;
   out.sl_distance = sl_dist;
   out.tp_distance = m_use_tp ? sl_dist * m_tp_r_mult : 0.0;
   out.reason      = (dir == SIGNAL_BUY) ? "SBO_BUY" : "SBO_SELL";
   m_log.Info(StringFormat("signal %s: close %.2f กรอบ %.2f-%.2f sl_dist %.5f tp_dist %.5f",
                           side, bar[0].close, m_range_lo, m_range_hi, out.sl_distance, out.tp_distance));
   return(true);
  }

#endif
//+------------------------------------------------------------------+
