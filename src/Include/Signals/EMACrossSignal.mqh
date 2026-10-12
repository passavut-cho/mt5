//+------------------------------------------------------------------+
//|                                               EMACrossSignal.mqh |
//|  EMA fast/slow cross + ADX/DI filter + ATR SL  (spec-ema-adx v1)  |
//|  Signal ไม่แตะ lot / order / risk — ส่งแค่ทิศทางกับระยะ SL/TP      |
//+------------------------------------------------------------------+
#ifndef SMARTEA_SIGNALS_EMACROSSSIGNAL_MQH
#define SMARTEA_SIGNALS_EMACROSSSIGNAL_MQH

#include "../Core/SignalBase.mqh"

class CEMACrossSignal : public CSignalBase
  {
private:
   CLogger        *m_log;
   string          m_symbol;
   ENUM_TIMEFRAMES m_tf;

   //--- พารามิเตอร์ (ตั้งผ่าน Configure ก่อน Init)
   int             m_fast_period;
   int             m_slow_period;
   int             m_adx_period;
   double          m_adx_min;
   int             m_atr_period;
   double          m_sl_atr_mult;
   double          m_tp_r_mult;
   int             m_session_start_hour;   // เปิดไม้ได้ถ้า start <= hour < end (server time)
   int             m_session_end_hour;
   int             m_time_exit_hhmm;       // ปิดทุก position เมื่อ server time >= HHMM นี้
   int             m_friday_cutoff_hour;   // ศุกร์: ไม่เปิดไม้ใหม่เมื่อ hour >= ค่านี้
   bool            m_configured;

   int             m_h_fast;
   int             m_h_slow;
   int             m_h_adx;
   int             m_h_atr;

   ENUM_SIGNAL_DIR m_raw_cross;            // cross ล่าสุดที่ Evaluate เจอ (ก่อนผ่าน filter) ใช้เป็น exit S3

   bool            Read(const int handle, const int buf, const int count, double &out[]) const;
   bool            InSession(string &why) const;

public:
                   CEMACrossSignal();
                  ~CEMACrossSignal() { Deinit(); }

   bool            Configure(const int fast, const int slow, const int adx_period, const double adx_min,
                             const int atr_period, const double sl_atr_mult, const double tp_r_mult,
                             const int session_start_hour, const int session_end_hour,
                             const int time_exit_hhmm, const int friday_cutoff_hour);

   virtual bool    Init(const string symbol, const ENUM_TIMEFRAMES tf, CLogger *log);
   virtual void    Deinit();
   virtual bool    Evaluate(SSignalIntent &out);
   virtual string  Name() const { return("EMACross+ADX"); }

   //--- cross ดิบของแท่งที่ Evaluate ล่าสุด (ไม่ผ่าน ADX/session) — ใช้ปิด position สวนทาง (S3)
   ENUM_SIGNAL_DIR RawCross() const { return(m_raw_cross); }
   //--- S6: ถึงเวลาปิดทุก position แล้วหรือยัง (server time)
   bool            TimeExitDue() const;
  };

//+------------------------------------------------------------------+
CEMACrossSignal::CEMACrossSignal()
   : m_log(NULL), m_symbol(""), m_tf(PERIOD_CURRENT),
     m_fast_period(0), m_slow_period(0), m_adx_period(0), m_adx_min(0), m_atr_period(0),
     m_sl_atr_mult(0), m_tp_r_mult(0), m_session_start_hour(0), m_session_end_hour(0),
     m_time_exit_hhmm(0), m_friday_cutoff_hour(0), m_configured(false),
     m_h_fast(INVALID_HANDLE), m_h_slow(INVALID_HANDLE), m_h_adx(INVALID_HANDLE), m_h_atr(INVALID_HANDLE),
     m_raw_cross(SIGNAL_NONE)
  {
  }

//+------------------------------------------------------------------+
bool CEMACrossSignal::Configure(const int fast, const int slow, const int adx_period, const double adx_min,
                                const int atr_period, const double sl_atr_mult, const double tp_r_mult,
                                const int session_start_hour, const int session_end_hour,
                                const int time_exit_hhmm, const int friday_cutoff_hour)
  {
   m_configured = false;
   const int exit_h = time_exit_hhmm / 100;
   const int exit_m = time_exit_hhmm % 100;
   if(fast < 1 || slow <= fast || adx_period < 1 || adx_min < 0.0 || atr_period < 1 ||
      sl_atr_mult <= 0.0 || tp_r_mult <= 0.0 ||
      session_start_hour < 0 || session_end_hour > 24 || session_start_hour >= session_end_hour ||
      exit_h < 0 || exit_h > 23 || exit_m < 0 || exit_m > 59 ||
      friday_cutoff_hour < 0 || friday_cutoff_hour > 24)
      return(false);

   m_fast_period        = fast;
   m_slow_period        = slow;
   m_adx_period         = adx_period;
   m_adx_min            = adx_min;
   m_atr_period         = atr_period;
   m_sl_atr_mult        = sl_atr_mult;
   m_tp_r_mult          = tp_r_mult;
   m_session_start_hour = session_start_hour;
   m_session_end_hour   = session_end_hour;
   m_time_exit_hhmm     = time_exit_hhmm;
   m_friday_cutoff_hour = friday_cutoff_hour;
   m_configured         = true;
   return(true);
  }

//+------------------------------------------------------------------+
bool CEMACrossSignal::Init(const string symbol, const ENUM_TIMEFRAMES tf, CLogger *log)
  {
   if(log == NULL)
      return(false);
   m_log = log;
   if(!m_configured)
     {
      m_log.Error("CEMACrossSignal: พารามิเตอร์ไม่ถูกต้อง/ยังไม่ Configure");
      return(false);
     }

   m_symbol = symbol;
   m_tf     = tf;
   Deinit();   // กัน handle รั่วถ้า Init ซ้ำ

   m_h_fast = iMA(symbol, tf, m_fast_period, 0, MODE_EMA, PRICE_CLOSE);
   m_h_slow = iMA(symbol, tf, m_slow_period, 0, MODE_EMA, PRICE_CLOSE);
   m_h_adx  = iADX(symbol, tf, m_adx_period);
   m_h_atr  = iATR(symbol, tf, m_atr_period);
   if(m_h_fast == INVALID_HANDLE || m_h_slow == INVALID_HANDLE ||
      m_h_adx == INVALID_HANDLE || m_h_atr == INVALID_HANDLE)
     {
      m_log.Error(StringFormat("สร้าง indicator handle ล้มเหลว err=%d", GetLastError()));
      Deinit();
      return(false);
     }

   m_log.Info(StringFormat("CEMACrossSignal init %s %s EMA %d/%d ADX(%d)>=%.1f ATR(%d)x%.2f TP %.1fR session %02d-%02d exit %04d friCut %02d",
                           symbol, EnumToString(tf), m_fast_period, m_slow_period, m_adx_period, m_adx_min,
                           m_atr_period, m_sl_atr_mult, m_tp_r_mult, m_session_start_hour, m_session_end_hour,
                           m_time_exit_hhmm, m_friday_cutoff_hour));
   return(true);
  }

//+------------------------------------------------------------------+
void CEMACrossSignal::Deinit()
  {
   if(m_h_fast != INVALID_HANDLE) { IndicatorRelease(m_h_fast); m_h_fast = INVALID_HANDLE; }
   if(m_h_slow != INVALID_HANDLE) { IndicatorRelease(m_h_slow); m_h_slow = INVALID_HANDLE; }
   if(m_h_adx  != INVALID_HANDLE) { IndicatorRelease(m_h_adx);  m_h_adx  = INVALID_HANDLE; }
   if(m_h_atr  != INVALID_HANDLE) { IndicatorRelease(m_h_atr);  m_h_atr  = INVALID_HANDLE; }
  }

//+------------------------------------------------------------------+
//| อ่าน count ค่าเริ่มที่ shift 1 (แท่งปิดล่าสุด): out[0]=shift1, out[1]=shift2 |
//+------------------------------------------------------------------+
bool CEMACrossSignal::Read(const int handle, const int buf, const int count, double &out[]) const
  {
   ArraySetAsSeries(out, true);
   if(CopyBuffer(handle, buf, 1, count, out) != count)
      return(false);
   return(true);
  }

//+------------------------------------------------------------------+
//| S1 + S7: ช่วงเวลาเปิดไม้ใหม่ (server time)                          |
//+------------------------------------------------------------------+
bool CEMACrossSignal::InSession(string &why) const
  {
   MqlDateTime t;
   TimeToStruct(TimeTradeServer(), t);
   if(t.hour < m_session_start_hour || t.hour >= m_session_end_hour)
     {
      why = StringFormat("นอก session (server %02d:%02d, เปิดได้ %02d-%02d)", t.hour, t.min,
                         m_session_start_hour, m_session_end_hour);
      return(false);
     }
   if(t.day_of_week == 5 && t.hour >= m_friday_cutoff_hour)
     {
      why = StringFormat("ศุกร์หลัง %02d:00 server ไม่เปิดไม้ใหม่ (S7)", m_friday_cutoff_hour);
      return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
bool CEMACrossSignal::TimeExitDue() const
  {
   MqlDateTime t;
   TimeToStruct(TimeTradeServer(), t);
   return(t.hour * 100 + t.min >= m_time_exit_hhmm);
  }

//+------------------------------------------------------------------+
bool CEMACrossSignal::Evaluate(SSignalIntent &out)
  {
   out.Reset();
   m_raw_cross = SIGNAL_NONE;
   if(m_h_fast == INVALID_HANDLE || m_h_slow == INVALID_HANDLE ||
      m_h_adx == INVALID_HANDLE || m_h_atr == INVALID_HANDLE)
      return(false);

   double fast[], slow[], adx[], pdi[], mdi[], atr[];
   if(!Read(m_h_fast, 0, 2, fast) || !Read(m_h_slow, 0, 2, slow) ||
      !Read(m_h_adx, 0, 1, adx) || !Read(m_h_adx, 1, 1, pdi) || !Read(m_h_adx, 2, 1, mdi) ||
      !Read(m_h_atr, 0, 1, atr))
      return(false);   // ข้อมูล/indicator ยังไม่พร้อม (แท่งไม่พอ ฯลฯ)

   //--- cross ที่แท่งปิดแล้ว: [0]=shift1, [1]=shift2
   if(fast[1] <= slow[1] && fast[0] > slow[0])
      m_raw_cross = SIGNAL_BUY;
   else if(fast[1] >= slow[1] && fast[0] < slow[0])
      m_raw_cross = SIGNAL_SELL;
   else
      return(true);    // ไม่มี cross = ไม่มีสัญญาณ

   const string side = (m_raw_cross == SIGNAL_BUY) ? "BUY" : "SELL";

   //--- S2: ADX + ทิศ DI
   if(adx[0] < m_adx_min)
     {
      m_log.Info(StringFormat("cross %s ไม่เข้า: ADX %.1f < %.1f", side, adx[0], m_adx_min));
      return(true);
     }
   const bool di_ok = (m_raw_cross == SIGNAL_BUY) ? (pdi[0] > mdi[0]) : (mdi[0] > pdi[0]);
   if(!di_ok)
     {
      m_log.Info(StringFormat("cross %s ไม่เข้า: DI สวนทาง (+DI %.1f / -DI %.1f)", side, pdi[0], mdi[0]));
      return(true);
     }

   //--- S1 + S7: session
   string why;
   if(!InSession(why))
     {
      m_log.Info(StringFormat("cross %s ไม่เข้า: %s", side, why));
      return(true);
     }

   //--- S4: SL = ATR x mult ; แคบกว่า 2 x spread = ไม่เข้า
   if(atr[0] <= 0.0)
     {
      m_log.Warn(StringFormat("cross %s ไม่เข้า: ATR ไม่ถูกต้อง (%.5f)", side, atr[0]));
      return(true);   // คืน true เพื่อให้ S3 (ปิดสวนทาง) ยังทำงาน
     }
   const double sl_dist = atr[0] * m_sl_atr_mult;
   const double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
     {
      m_log.Warn(StringFormat("cross %s ไม่เข้า: อ่าน ask/bid ไม่ได้", side));
      return(true);
     }
   const double spread = ask - bid;
   if(sl_dist < 2.0 * spread)
     {
      m_log.Info(StringFormat("cross %s ไม่เข้า: SL %.5f < 2 x spread %.5f (S4)", side, sl_dist, spread));
      return(true);
     }

   out.dir         = m_raw_cross;
   out.sl_distance = sl_dist;
   out.tp_distance = sl_dist * m_tp_r_mult;   // S5: 2R
   out.reason      = (m_raw_cross == SIGNAL_BUY) ? "EMAX_ADX_BUY" : "EMAX_ADX_SELL";
   m_log.Info(StringFormat("signal %s: ADX %.1f +DI %.1f -DI %.1f ATR %.5f sl_dist %.5f tp_dist %.5f",
                           side, adx[0], pdi[0], mdi[0], atr[0], out.sl_distance, out.tp_distance));
   return(true);
  }

#endif
//+------------------------------------------------------------------+
