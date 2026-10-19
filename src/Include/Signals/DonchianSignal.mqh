//+------------------------------------------------------------------+
//|                                              DonchianSignal.mqh  |
//|  Donchian Breakout H4 (S-B): แท่งปิดทะลุ high/low ของ N แท่งก่อนหน้า |
//|  spec: docs/strategy/spec-donchian-h4.md                          |
//|  Signal ไม่แตะ lot / order / risk — ส่งแค่ทิศทางกับระยะ SL/TP        |
//|  การจัดการหลังเข้าไม้ (trailing / partial / weekend) อยู่ที่ ExitManager |
//+------------------------------------------------------------------+
#ifndef SMARTEA_SIGNALS_DONCHIANSIGNAL_MQH
#define SMARTEA_SIGNALS_DONCHIANSIGNAL_MQH

#include "../Core/SignalBase.mqh"

class CDonchianSignal : public CSignalBase
  {
private:
   CLogger        *m_log;
   string          m_symbol;
   ENUM_TIMEFRAMES m_tf;

   //--- พารามิเตอร์ (ตั้งผ่าน Configure ก่อน Init)
   int             m_entry_bars;          // เข้าเมื่อปิดทะลุ high/low ของกี่แท่งก่อนหน้า (spec = 20)
   int             m_exit_bars;           // trailing ตามขอบของกี่แท่งที่ปิดแล้ว (spec = 10)
   int             m_atr_period;
   double          m_sl_atr_mult;         // SL เริ่มต้น = ATR x ค่านี้ (spec = 2) = 1R
   double          m_tp_r_mult;           // > 0 = ตั้ง TP ที่ R x ค่านี้ตอนส่ง order (B4) • 0 = ไม่มี TP
   int             m_friday_cutoff_hour;  // ศุกร์: ไม่เปิดไม้ใหม่เมื่อเวลาเข้า >= ชั่วโมงนี้
   bool            m_configured;

   int             m_h_atr;

public:
                   CDonchianSignal();
                  ~CDonchianSignal() { Deinit(); }

   bool            Configure(const int entry_bars, const int exit_bars, const int atr_period, const double sl_atr_mult,
                             const double tp_r_mult, const int friday_cutoff_hour);

   virtual bool    Init(const string symbol, const ENUM_TIMEFRAMES tf, CLogger *log);
   virtual void    Deinit();
   virtual bool    Evaluate(SSignalIntent &out);
   virtual string  Name() const { return("DonchianH4"); }

   //--- ขอบ trailing จากแท่งที่ปิดแล้ว (shift 1..exit_bars) — lo ใช้กับ BUY, hi ใช้กับ SELL
   bool            TrailLevels(double &lo, double &hi) const;
   //--- ATR ของแท่งที่ปิดแล้ว (shift 1)
   bool            Atr(double &value) const;
  };

//+------------------------------------------------------------------+
CDonchianSignal::CDonchianSignal()
   : m_log(NULL), m_symbol(""), m_tf(PERIOD_CURRENT), m_entry_bars(0), m_exit_bars(0), m_atr_period(0),
     m_sl_atr_mult(0), m_tp_r_mult(0), m_friday_cutoff_hour(0), m_configured(false), m_h_atr(INVALID_HANDLE)
  {
  }

//+------------------------------------------------------------------+
bool CDonchianSignal::Configure(const int entry_bars, const int exit_bars, const int atr_period, const double sl_atr_mult,
                                const double tp_r_mult, const int friday_cutoff_hour)
  {
   m_configured = false;
   if(entry_bars < 2 || exit_bars < 2 || atr_period < 1 || sl_atr_mult <= 0.0 || tp_r_mult < 0.0 ||
      friday_cutoff_hour < 0 || friday_cutoff_hour > 24)
      return(false);

   m_entry_bars         = entry_bars;
   m_exit_bars          = exit_bars;
   m_atr_period         = atr_period;
   m_sl_atr_mult        = sl_atr_mult;
   m_tp_r_mult          = tp_r_mult;
   m_friday_cutoff_hour = friday_cutoff_hour;
   m_configured         = true;
   return(true);
  }

//+------------------------------------------------------------------+
bool CDonchianSignal::Init(const string symbol, const ENUM_TIMEFRAMES tf, CLogger *log)
  {
   if(log == NULL)
      return(false);
   m_log = log;
   if(!m_configured)
     {
      m_log.Error("CDonchianSignal: พารามิเตอร์ไม่ถูกต้อง/ยังไม่ Configure");
      return(false);
     }
   if(PeriodSeconds(tf) < 3600)
     {
      m_log.Error("CDonchianSignal: timeframe ของ chart ต้อง >= H1 (spec ใช้ H4 — กำหนดที่ tester ini / chart)");
      return(false);
     }

   m_symbol = symbol;
   m_tf     = tf;
   Deinit();   // กัน handle รั่วถ้า Init ซ้ำ

   m_h_atr = iATR(symbol, tf, m_atr_period);
   if(m_h_atr == INVALID_HANDLE)
     {
      m_log.Error(StringFormat("สร้าง ATR handle ล้มเหลว err=%d", GetLastError()));
      return(false);
     }

   m_log.Info(StringFormat("CDonchianSignal init %s %s entry %d trail %d SL %.1fxATR(%d) TP=%s friCut %02d",
                           symbol, EnumToString(tf), m_entry_bars, m_exit_bars, m_sl_atr_mult, m_atr_period,
                           (m_tp_r_mult > 0.0 ? StringFormat("%.1fR", m_tp_r_mult) : "off"), m_friday_cutoff_hour));
   return(true);
  }

//+------------------------------------------------------------------+
void CDonchianSignal::Deinit()
  {
   if(m_h_atr != INVALID_HANDLE) { IndicatorRelease(m_h_atr); m_h_atr = INVALID_HANDLE; }
  }

//+------------------------------------------------------------------+
bool CDonchianSignal::Atr(double &value) const
  {
   value = 0.0;
   if(m_h_atr == INVALID_HANDLE)
      return(false);
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(m_h_atr, 0, 1, 1, atr) != 1 || atr[0] <= 0.0)
      return(false);
   value = atr[0];
   return(true);
  }

//+------------------------------------------------------------------+
bool CDonchianSignal::TrailLevels(double &lo, double &hi) const
  {
   lo = 0.0;
   hi = 0.0;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(m_symbol, m_tf, 1, m_exit_bars, r) != m_exit_bars)
      return(false);
   lo = r[0].low;
   hi = r[0].high;
   for(int i = 1; i < m_exit_bars; i++)
     {
      lo = MathMin(lo, r[i].low);
      hi = MathMax(hi, r[i].high);
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| เรียกตอนเกิดแท่งใหม่: แท่งสัญญาณ = shift 1 (ปิดแล้ว)                  |
//| เทียบกับ high/low ของ entry_bars แท่งก่อนหน้านั้น (shift 2..N+1)       |
//+------------------------------------------------------------------+
bool CDonchianSignal::Evaluate(SSignalIntent &out)
  {
   out.Reset();
   if(m_h_atr == INVALID_HANDLE)
      return(false);

   MqlRates r[];
   ArraySetAsSeries(r, true);
   const int need = m_entry_bars + 1;            // [0] = แท่งสัญญาณ, [1..N] = N แท่งก่อนหน้า
   if(CopyRates(m_symbol, m_tf, 1, need, r) != need)
      return(false);

   //--- เวลาเข้าไม้ = เวลาปิดแท่งสัญญาณ; ศุกร์หลัง cutoff ไม่เปิดไม้ใหม่ (weekend rule)
   const datetime entry_time = r[0].time + (datetime)PeriodSeconds(m_tf);
   MqlDateTime et;
   TimeToStruct(entry_time, et);
   //--- แท่งศุกร์ >= cutoff ปิดเป็นเสาร์ 00:00 (dow 6) -> ก็ห้ามเข้า ไม่งั้นไปเปิดตอนตลาดเปิดวันจันทร์ (ช่วง gap)
   if((et.day_of_week == 5 && et.hour >= m_friday_cutoff_hour) || et.day_of_week == 6 || et.day_of_week == 0)
      return(true);

   double hh = r[1].high, ll = r[1].low;
   for(int i = 2; i <= m_entry_bars; i++)
     {
      hh = MathMax(hh, r[i].high);
      ll = MathMin(ll, r[i].low);
     }

   ENUM_SIGNAL_DIR dir = SIGNAL_NONE;
   if(r[0].close > hh)
      dir = SIGNAL_BUY;
   else if(r[0].close < ll)
      dir = SIGNAL_SELL;
   else
      return(true);   // ยังอยู่ในช่อง = ไม่มีสัญญาณ

   double atr = 0.0;
   if(!Atr(atr))
      return(false);

   out.dir         = dir;
   out.sl_distance = atr * m_sl_atr_mult;
   out.tp_distance = (m_tp_r_mult > 0.0) ? out.sl_distance * m_tp_r_mult : 0.0;
   out.reason      = (dir == SIGNAL_BUY) ? "SBB_BUY" : "SBB_SELL";
   m_log.Info(StringFormat("signal %s: close %.2f ทะลุช่อง %d แท่ง [%.2f, %.2f] ATR %.2f sl_dist %.5f tp_dist %.5f",
                           (dir == SIGNAL_BUY) ? "BUY" : "SELL", r[0].close, m_entry_bars, ll, hh, atr,
                           out.sl_distance, out.tp_distance));
   return(true);
  }

#endif
//+------------------------------------------------------------------+
