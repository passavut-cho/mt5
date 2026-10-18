//+------------------------------------------------------------------+
//|                                                   Telemetry.mqh  |
//|  เขียนข้อมูลให้ dashboard (docs/specs/dashboard-v1.md)             |
//|  fills.csv / trades.csv / equity_snap.csv / spread_snap.csv /      |
//|  status.json ลง MQL5\Files\SmartEA\telemetry\                       |
//|                                                                  |
//|  หลักการ: read-only, ห้ามกระทบการเทรด                               |
//|  - เขียนไฟล์ล้มเหลว = Warn ครั้งเดียวแล้วทำงานต่อ (ไม่ fail closed)     |
//|  - ปิดตัวเองอัตโนมัติใน Strategy Tester / Optimization              |
//|  - ไม่คำนวณ risk ใดๆ: day_start / limit ส่งเข้ามาจาก EA (getter เดิม) |
//+------------------------------------------------------------------+
#ifndef SMARTEA_CORE_TELEMETRY_MQH
#define SMARTEA_CORE_TELEMETRY_MQH

#include "Logger.mqh"

//--- ข้อมูลที่ EA ป้อนให้ status.json (ส่วนที่ Telemetry หาเองไม่ได้ เพราะอยู่ชั้น Risk/Signals)
struct STelemetryExtra
  {
   string   version;                 // เวอร์ชัน EA
   string   strategy;                // ชื่อ signal
   bool     halted;                  // breaker ทำงานอยู่
   double   day_start_balance;       // balance ต้นวัน (RiskManager.DayStartBalance)
   double   breaker_limit;           // equity ที่ breaker ทำงาน
   int      spread_max;              // InpMaxSpreadPoints
   double   commission_per_lot;      // InpCommissionPerLot (ใช้คำนวณ risk ที่ SL ของไม้ที่เปิดอยู่)
   bool     session_open;            // อยู่ในช่วงเปิดไม้ใหม่ตาม S1/S7
   bool     holiday_today;           // วันนี้อยู่ใน holidays.csv
   int      holidays_covered_until;  // ปีสุดท้ายใน covered_years (0 = ไม่ทราบ)
   bool     news_known;              // มี event ข่าวถัดไป
   string   news_event;
   datetime news_time;
   bool     news_window_active;
   int      news_covered_until;

   void Reset()
     {
      version = "";
      strategy = "";
      halted = false;
      day_start_balance = 0.0;
      breaker_limit = 0.0;
      spread_max = 0;
      commission_per_lot = 0.0;
      session_open = false;
      holiday_today = false;
      holidays_covered_until = 0;
      news_known = false;
      news_event = "";
      news_time = 0;
      news_window_active = false;
      news_covered_until = 0;
     }
  };

//--- ข้อมูลที่ต้องจำข้ามจาก "ตอนเปิด/ปิด" ไปถึง "ตอนปิดไม้" ต่อ position id
struct SPosNote
  {
   ulong  pid;
   double risk_planned;
   double risk_actual;
   string close_reason;
  };

class CTelemetry
  {
private:
   CLogger        *m_log;
   bool            m_enabled;
   bool            m_warned;            // Warn เขียนไฟล์ล้มเหลวแล้ว
   datetime        m_warn_time;
   string          m_symbol;
   ulong           m_magic;
   string          m_dir;               // "SmartEA\\telemetry\\"
   int             m_digits;
   double          m_point;
   ENUM_TIMEFRAMES m_tf_fast;           // timeframe ATR "ระยะสั้น" ของ panel ทอง
   ENUM_TIMEFRAMES m_tf_slow;           // timeframe ATR "รายวัน"
   int             m_h_atr_fast;
   int             m_h_atr_slow;
   int             m_asian_start;       // ชั่วโมง server time
   int             m_asian_end;
   datetime        m_last_snap;
   ulong           m_last_deal;         // กันเขียน trades.csv ซ้ำ
   SPosNote        m_notes[];

   static string   FmtTime(const datetime t);
   static string   Clean(const string s);
   static string   JStr(const string s);
   string          Px(const double v) const { return(DoubleToString(v, m_digits)); }
   static string   JNum(const double v, const int digits, const bool ok);

   bool            AppendLine(const string file, const string header, const string line);
   bool            WriteWhole(const string file, const string text);
   void            WarnOnce(const string what);

   int             FindNote(const ulong pid, const bool create);
   void            DropNote(const int idx);
   bool            ReadAtr(const int handle, double &out) const;
   bool            AsianRange(double &hi, double &lo) const;
   string          PositionsJson(const double commission_per_lot) const;
   string          AccountModeName() const;
   void            WriteFill(const string action, const string side, const double lot, const double requested,
                             const double fill, const double spread_pts, const double latency_ms,
                             const uint retcode, const string reason);
   void            WriteStatus(const STelemetryExtra &x);
   void            WriteSnapshots(const STelemetryExtra &x, const datetime now);

public:
                   CTelemetry() : m_log(NULL), m_enabled(false), m_warned(false), m_warn_time(0), m_symbol(""), m_magic(0),
                                  m_dir("SmartEA\\telemetry\\"), m_digits(2), m_point(0.01),
                                  m_tf_fast(PERIOD_M15), m_tf_slow(PERIOD_D1),
                                  m_h_atr_fast(INVALID_HANDLE), m_h_atr_slow(INVALID_HANDLE),
                                  m_asian_start(1), m_asian_end(10), m_last_snap(0), m_last_deal(0) {}

   //--- enabled=false หรืออยู่ใน tester -> ไม่ทำอะไรเลย (คืน true เสมอ — telemetry ไม่เคยทำให้ EA init ล้ม)
   bool            Init(CLogger *log, const string symbol, const ulong magic, const bool enabled,
                        const ENUM_TIMEFRAMES tf_fast, const ENUM_TIMEFRAMES tf_slow, const int atr_period,
                        const int asian_start_hour, const int asian_end_hour);
   void            Deinit();
   bool            Enabled() const { return(m_enabled); }

   //--- hook จาก TradeManager: ทุก OrderSend (สำเร็จหรือไม่) • fill=0 เมื่อไม่ได้ fill
   void            OnOrder(const string action, const ENUM_ORDER_TYPE type, const double lot, const double requested,
                           const double fill, const double spread_pts, const double latency_ms,
                           const uint retcode, const string reason);
   //--- จำ risk ของไม้ที่เพิ่งเปิด (ผูกกับ position id ของ deal) ไว้เขียนลง trades.csv ตอนปิด
   void            NoteOpen(const ulong deal_ticket, const double risk_planned, const double risk_actual);
   //--- จำเหตุผลที่ EA สั่งปิด (ผูกกับ position id) ไว้เป็น exit_reason
   void            NoteClose(const ulong pid, const string reason);
   //--- เรียกจาก OnTradeTransaction (DEAL_ADD) -> เขียน trades.csv เมื่อไม้ปิดครบ
   void            OnDealAdded(const ulong deal_ticket);
   //--- เรียกจาก OnTimer (30 วินาที)
   void            OnTimer(const STelemetryExtra &x);
  };

//+------------------------------------------------------------------+
string CTelemetry::FmtTime(const datetime t)
  {
   string s = TimeToString(t, TIME_DATE | TIME_SECONDS);   // 2026.10.19 12:34:56
   StringReplace(s, ".", "-");
   return(s);
  }

//--- ค่าใน CSV ห้ามมี , หรือขึ้นบรรทัดใหม่
string CTelemetry::Clean(const string s_in)
  {
   string s = s_in;
   StringReplace(s, ",", ";");
   StringReplace(s, "\r", " ");
   StringReplace(s, "\n", " ");
   return(s);
  }

string CTelemetry::JStr(const string s_in)
  {
   string s = s_in;
   StringReplace(s, "\\", "\\\\");
   StringReplace(s, "\"", "\\\"");
   StringReplace(s, "\r", " ");
   StringReplace(s, "\n", " ");
   return("\"" + s + "\"");
  }

string CTelemetry::JNum(const double v, const int digits, const bool ok)
  {
   if(!ok || !MathIsValidNumber(v))
      return("null");
   return(DoubleToString(v, digits));
  }

//+------------------------------------------------------------------+
bool CTelemetry::Init(CLogger *log, const string symbol, const ulong magic, const bool enabled,
                      const ENUM_TIMEFRAMES tf_fast, const ENUM_TIMEFRAMES tf_slow, const int atr_period,
                      const int asian_start_hour, const int asian_end_hour)
  {
   m_log     = log;
   m_enabled = false;
   if(m_log == NULL)
      return(true);
   if(!enabled)
     {
      m_log.Info("telemetry: ปิด (InpTelemetry=false)");
      return(true);
     }
   if(MQLInfoInteger(MQL_TESTER) != 0 || MQLInfoInteger(MQL_OPTIMIZATION) != 0)
     {
      m_log.Info("telemetry: ปิดอัตโนมัติใน Strategy Tester/Optimization");
      return(true);
     }

   m_symbol      = symbol;
   m_magic       = magic;
   m_digits      = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   m_point       = SymbolInfoDouble(symbol, SYMBOL_POINT);
   m_tf_fast     = tf_fast;
   m_tf_slow     = tf_slow;
   m_asian_start = asian_start_hour;
   m_asian_end   = asian_end_hour;
   if(m_point <= 0.0)
      m_point = 0.01;

   ResetLastError();
   if(!FolderCreate("SmartEA\\telemetry") && GetLastError() != 5019)   // 5019 = มีอยู่แล้ว
      WarnOnce(StringFormat("FolderCreate err=%d", GetLastError()));

   //--- ATR เป็นข้อมูลแสดงผลอย่างเดียว — handle สร้างไม่ได้ก็แค่ได้ null ใน status.json
   m_h_atr_fast = iATR(symbol, m_tf_fast, atr_period);
   m_h_atr_slow = iATR(symbol, m_tf_slow, atr_period);
   if(m_h_atr_fast == INVALID_HANDLE || m_h_atr_slow == INVALID_HANDLE)
      m_log.Warn("telemetry: สร้าง handle ATR ไม่ได้ — status.json จะไม่มีค่า ATR");

   m_enabled = true;
   m_log.Info(StringFormat("telemetry: เปิด -> MQL5\\Files\\%s (ATR %s/%s period %d, เอเชีย %02d-%02d)",
                           m_dir, EnumToString(m_tf_fast), EnumToString(m_tf_slow), atr_period,
                           m_asian_start, m_asian_end));
   return(true);
  }

void CTelemetry::Deinit()
  {
   if(m_h_atr_fast != INVALID_HANDLE) { IndicatorRelease(m_h_atr_fast); m_h_atr_fast = INVALID_HANDLE; }
   if(m_h_atr_slow != INVALID_HANDLE) { IndicatorRelease(m_h_atr_slow); m_h_atr_slow = INVALID_HANDLE; }
   m_enabled = false;
  }

//+------------------------------------------------------------------+
void CTelemetry::WarnOnce(const string what)
  {
   if(m_log == NULL || (m_warned && TimeLocal() - m_warn_time < 600))
      return;                       // Warn ไม่เกินทุก 10 นาที (ไม่ท่วม journal)
   m_warned = true;
   m_warn_time = TimeLocal();
   m_log.Warn("telemetry: เขียนไฟล์ไม่สำเร็จ (" + what + ") — เทรดต่อตามปกติ (แจ้งซ้ำไม่เกินทุก 10 นาที)");
  }

//--- append ท้ายไฟล์ (เปิด-ปิดทุกครั้ง + flush เพื่อให้ dashboard อ่านได้ทันที) • header เขียนเมื่อไฟล์ว่าง
bool CTelemetry::AppendLine(const string file, const string header, const string line)
  {
   ResetLastError();
   const int h = FileOpen(m_dir + file, FILE_READ | FILE_WRITE | FILE_BIN | FILE_SHARE_READ);
   if(h == INVALID_HANDLE)
     {
      WarnOnce(StringFormat("เปิด %s err=%d", file, GetLastError()));
      return(false);
     }
   const bool empty = (FileSize(h) == 0);
   FileSeek(h, 0, SEEK_END);

   uchar  bytes[];
   const string text = (empty ? header + "\n" : "") + line + "\n";
   const int n = StringToCharArray(text, bytes, 0, -1, CP_UTF8) - 1;   // ตัด null ท้ายสตริง
   bool ok = (n > 0 && FileWriteArray(h, bytes, 0, n) == (uint)n);
   FileFlush(h);
   FileClose(h);
   if(!ok)
      WarnOnce(StringFormat("เขียน %s err=%d", file, GetLastError()));
   return(ok);
  }

//--- เขียนทับทั้งไฟล์ (status.json): เขียนไฟล์ชั่วคราวแล้ว FileMove ทับ เพื่อไม่ให้ dashboard เห็นไฟล์ครึ่งเดียว
bool CTelemetry::WriteWhole(const string file, const string text)
  {
   uchar bytes[];
   const int n = StringToCharArray(text, bytes, 0, -1, CP_UTF8) - 1;
   if(n <= 0)
      return(false);

   const string tmp = m_dir + file + ".tmp";
   ResetLastError();
   int h = FileOpen(tmp, FILE_WRITE | FILE_BIN | FILE_SHARE_READ);
   if(h == INVALID_HANDLE)
     {
      WarnOnce(StringFormat("เปิด %s err=%d", tmp, GetLastError()));
      return(false);
     }
   bool ok = (FileWriteArray(h, bytes, 0, n) == (uint)n);
   FileFlush(h);
   FileClose(h);
   if(!ok)
     {
      WarnOnce(StringFormat("เขียน %s err=%d", tmp, GetLastError()));
      return(false);
     }
   if(FileMove(tmp, 0, m_dir + file, FILE_REWRITE))
      return(true);

   //--- FileMove ไม่ได้ (เช่น dashboard กำลังเปิดไฟล์ปลายทาง) -> เขียนทับตรงๆ
   h = FileOpen(m_dir + file, FILE_WRITE | FILE_BIN | FILE_SHARE_READ);
   if(h == INVALID_HANDLE)
     {
      WarnOnce(StringFormat("เปิด %s err=%d", file, GetLastError()));
      return(false);
     }
   ok = (FileWriteArray(h, bytes, 0, n) == (uint)n);
   FileFlush(h);
   FileClose(h);
   FileDelete(tmp);
   if(!ok)
      WarnOnce(StringFormat("เขียน %s err=%d", file, GetLastError()));
   return(ok);
  }

//+------------------------------------------------------------------+
int CTelemetry::FindNote(const ulong pid, const bool create)
  {
   const int n = ArraySize(m_notes);
   for(int i = 0; i < n; i++)
      if(m_notes[i].pid == pid)
         return(i);
   if(!create)
      return(-1);
   if(n >= 64)
      DropNote(0);                  // กัน memory โต: ทิ้งอันเก่าสุด
   const int k = ArraySize(m_notes);
   ArrayResize(m_notes, k + 1);
   m_notes[k].pid          = pid;
   m_notes[k].risk_planned = 0.0;
   m_notes[k].risk_actual  = 0.0;
   m_notes[k].close_reason = "";
   return(k);
  }

void CTelemetry::DropNote(const int idx)
  {
   const int n = ArraySize(m_notes);
   for(int i = idx; i < n - 1; i++)
      m_notes[i] = m_notes[i + 1];
   if(n > 0)
      ArrayResize(m_notes, n - 1);
  }

//+------------------------------------------------------------------+
void CTelemetry::WriteFill(const string action, const string side, const double lot, const double requested,
                           const double fill, const double spread_pts, const double latency_ms,
                           const uint retcode, const string reason)
  {
   //--- slip บวก = แย่สำหรับเรา: buy จ่ายแพงกว่าที่ขอ / sell ได้ถูกกว่าที่ขอ
   double slip = 0.0;
   if(fill > 0.0 && requested > 0.0)
      slip = (fill - requested) / m_point * (side == "buy" ? 1.0 : -1.0);

   const string line = StringFormat("%s,%I64u,%I64u,%s,%s,%s,%.2f,%s,%s,%.1f,%.1f,%.0f,%u,%s",
                                    FmtTime(TimeTradeServer()), m_magic, m_magic, m_symbol, action, side, lot,
                                    Px(requested), Px(fill), slip, latency_ms, spread_pts, retcode, Clean(reason));
   AppendLine("fills.csv",
              "time,magic,leg,symbol,action,side,lot,requested,fill,slip_points,latency_ms,spread_points,retcode,reason",
              line);
  }

void CTelemetry::OnOrder(const string action, const ENUM_ORDER_TYPE type, const double lot, const double requested,
                         const double fill, const double spread_pts, const double latency_ms,
                         const uint retcode, const string reason)
  {
   if(!m_enabled)
      return;
   const bool is_buy = (type == ORDER_TYPE_BUY || type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_BUY_STOP);
   WriteFill(action, is_buy ? "buy" : "sell", lot, requested, fill, spread_pts, latency_ms, retcode, reason);
  }

void CTelemetry::NoteOpen(const ulong deal_ticket, const double risk_planned, const double risk_actual)
  {
   if(!m_enabled || deal_ticket == 0)
      return;
   if(!HistoryDealSelect(deal_ticket))
      return;
   const ulong pid = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
   const int i = FindNote(pid, true);
   m_notes[i].risk_planned = risk_planned;
   m_notes[i].risk_actual  = risk_actual;
  }

void CTelemetry::NoteClose(const ulong pid, const string reason)
  {
   if(!m_enabled || pid == 0)
      return;
   const int i = FindNote(pid, true);
   m_notes[i].close_reason = reason;
  }

//+------------------------------------------------------------------+
//| deal ปิดไม้ (OUT) -> สรุปทั้ง position ลง trades.csv               |
//| ไม้ที่ปิดด้วย SL/TP ฝั่ง server ไม่ผ่าน OrderSend ของ EA จึงเขียนแถว    |
//| fills.csv (action=close, requested = SL/TP) ที่นี่เพื่อวัด slip ขาออก  |
//+------------------------------------------------------------------+
void CTelemetry::OnDealAdded(const ulong deal_ticket)
  {
   if(!m_enabled || deal_ticket == 0 || deal_ticket == m_last_deal)
      return;
   if(!HistoryDealSelect(deal_ticket))
      return;
   if(HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != m_symbol)
      return;                       // magic ตรวจที่ deal ขาเข้าของ position (ปิดมือ/stopout deal อาจ magic = 0)
   const long type = HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
   if(type != DEAL_TYPE_BUY && type != DEAL_TYPE_SELL)
      return;
   const long entry = HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT && entry != DEAL_ENTRY_OUT_BY)
      return;
   m_last_deal = deal_ticket;

   const ulong      pid        = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
   const datetime   close_time = (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
   const double     close_px   = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
   const long       reason     = HistoryDealGetInteger(deal_ticket, DEAL_REASON);

   //--- รวมทุก deal ของ position นี้
   if(!HistorySelectByPosition(pid))
     {
      WarnOnce(StringFormat("HistorySelectByPosition(%I64u) err=%d", pid, GetLastError()));
      return;
     }
   double   vol_in = 0.0, vol_out = 0.0, profit = 0.0, comm = 0.0, swap = 0.0, open_px = 0.0;
   datetime open_time = 0;
   long     open_type = -1;
   ulong    open_order = 0;
   ulong    open_magic = 0;
   const int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
     {
      const ulong d = HistoryDealGetTicket(i);
      if(d == 0)
         continue;
      const long dtype = HistoryDealGetInteger(d, DEAL_TYPE);
      if(dtype != DEAL_TYPE_BUY && dtype != DEAL_TYPE_SELL)
         continue;
      profit += HistoryDealGetDouble(d, DEAL_PROFIT);
      comm   += HistoryDealGetDouble(d, DEAL_COMMISSION) + HistoryDealGetDouble(d, DEAL_FEE);
      swap   += HistoryDealGetDouble(d, DEAL_SWAP);
      const long de = HistoryDealGetInteger(d, DEAL_ENTRY);
      if(de == DEAL_ENTRY_IN)
        {
         vol_in    += HistoryDealGetDouble(d, DEAL_VOLUME);
         open_time  = (datetime)HistoryDealGetInteger(d, DEAL_TIME);
         open_px    = HistoryDealGetDouble(d, DEAL_PRICE);
         open_type  = dtype;
         open_order = (ulong)HistoryDealGetInteger(d, DEAL_ORDER);
         open_magic = (ulong)HistoryDealGetInteger(d, DEAL_MAGIC);
        }
      else
         vol_out += HistoryDealGetDouble(d, DEAL_VOLUME);
     }
   if(open_type < 0 || vol_out < vol_in - 1e-8 || open_magic != m_magic)
      return;                       // ยังไม่รู้ขาเข้า (EA เริ่มทีหลัง) หรือปิดบางส่วน — ยังไม่สรุป

   double sl = 0.0, tp = 0.0;
   if(open_order != 0 && HistoryOrderSelect(open_order))
     {
      sl = HistoryOrderGetDouble(open_order, ORDER_SL);
      tp = HistoryOrderGetDouble(open_order, ORDER_TP);
     }

   //--- exit_reason + แถว slip ของ SL/TP
   const int ni = FindNote(pid, false);
   string exit_reason;
   if(reason == DEAL_REASON_SL)
      exit_reason = "sl";
   else if(reason == DEAL_REASON_TP)
      exit_reason = "tp";
   else if(reason == DEAL_REASON_SO)
      exit_reason = "stopout";
   else if(reason == DEAL_REASON_EXPERT)
      exit_reason = (ni >= 0 && m_notes[ni].close_reason != "") ? m_notes[ni].close_reason : "expert";
   else
      exit_reason = "manual";

   if(reason == DEAL_REASON_SL || reason == DEAL_REASON_TP)
     {
      const double req  = (reason == DEAL_REASON_SL) ? sl : tp;
      const bool   sell = (type == DEAL_TYPE_SELL);          // ปิด long = ขาย
      const double spr  = (double)SymbolInfoInteger(m_symbol, SYMBOL_SPREAD);
      if(req > 0.0)
         WriteFill("close", sell ? "sell" : "buy", vol_out, req, close_px, spr, 0.0, 0, exit_reason);
     }

   const double planned = (ni >= 0) ? m_notes[ni].risk_planned : 0.0;
   const double actual  = (ni >= 0) ? m_notes[ni].risk_actual : 0.0;
   if(ni >= 0)
      DropNote(ni);

   const string line = StringFormat("%I64u,%I64u,%I64u,%s,%s,%.2f,%s,%s,%s,%s,%s,%s,%.2f,%.2f,%.2f,%s,%.2f,%.2f",
                                    pid, m_magic, m_magic, m_symbol, (open_type == DEAL_TYPE_BUY) ? "buy" : "sell",
                                    vol_in, FmtTime(open_time), Px(open_px), FmtTime(close_time), Px(close_px),
                                    Px(sl), Px(tp), profit, comm, swap, Clean(exit_reason), planned, actual);
   AppendLine("trades.csv",
              "ticket,magic,leg,symbol,side,lot,open_time,open_price,close_time,close_price,sl,tp,profit,commission,swap,exit_reason,risk_planned,risk_actual",
              line);
  }

//+------------------------------------------------------------------+
bool CTelemetry::ReadAtr(const int handle, double &out) const
  {
   if(handle == INVALID_HANDLE)
      return(false);
   double buf[];
   if(CopyBuffer(handle, 0, 1, 1, buf) != 1)       // แท่งที่ปิดแล้ว
      return(false);
   out = buf[0];
   return(out > 0.0);
  }

//--- high/low ของช่วงเอเชีย (server time) ของวันนี้เท่าที่เกิดขึ้นแล้ว
bool CTelemetry::AsianRange(double &hi, double &lo) const
  {
   const datetime now       = TimeTradeServer();
   const datetime day_start = (datetime)((long)now - ((long)now % 86400));
   const datetime from      = day_start + m_asian_start * 3600;
   const datetime to_full   = day_start + m_asian_end * 3600;
   if(now <= from)
      return(false);
   const datetime to = (now < to_full) ? now : to_full - 1;

   MqlRates rates[];
   const int n = CopyRates(m_symbol, m_tf_fast, from, to, rates);
   if(n <= 0)
      return(false);
   hi = rates[0].high;
   lo = rates[0].low;
   for(int i = 1; i < n; i++)
     {
      hi = MathMax(hi, rates[i].high);
      lo = MathMin(lo, rates[i].low);
     }
   return(true);
  }

string CTelemetry::AccountModeName() const
  {
   const ENUM_ACCOUNT_TRADE_MODE mode = (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   return((mode == ACCOUNT_TRADE_MODE_DEMO)    ? "DEMO" :
          (mode == ACCOUNT_TRADE_MODE_CONTEST) ? "CONTEST" : "REAL");
  }

//--- ไม้ที่ EA ถืออยู่ พร้อม risk ที่ SL ($) = ขาดทุนถ้าโดน SL + commission
string CTelemetry::PositionsJson(const double commission_per_lot) const
  {
   string out = "[";
   bool first = true;
   const datetime now = TimeTradeServer();
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != m_symbol || (ulong)PositionGetInteger(POSITION_MAGIC) != m_magic)
         continue;

      const bool   buy   = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      const double lot   = PositionGetDouble(POSITION_VOLUME);
      const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl    = PositionGetDouble(POSITION_SL);
      const double tp    = PositionGetDouble(POSITION_TP);
      const double pl    = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      const double age   = (double)(now - (datetime)PositionGetInteger(POSITION_TIME)) / 60.0;

      double risk = 0.0;
      double sl_profit = 0.0;
      const bool risk_ok = (sl > 0.0 &&
                            OrderCalcProfit(buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, m_symbol, lot, entry, sl, sl_profit));
      if(risk_ok)
         risk = -sl_profit + commission_per_lot * lot;

      if(!first)
         out += ",";
      first = false;
      out += StringFormat("{\"ticket\":%I64u,\"side\":\"%s\",\"lot\":%.2f,\"entry\":%s,\"sl\":%s,\"tp\":%s,\"age_min\":%.1f,\"pl\":%.2f,\"risk_at_sl\":%s}",
                          ticket, buy ? "buy" : "sell", lot, Px(entry), Px(sl), Px(tp), age, pl,
                          JNum(risk, 2, risk_ok));
     }
   return(out + "]");
  }

//+------------------------------------------------------------------+
void CTelemetry::WriteStatus(const STelemetryExtra &x)
  {
   MqlTick tick;
   const bool tick_ok = SymbolInfoTick(m_symbol, tick) && tick.bid > 0.0 && tick.ask > 0.0;
   const double spread_now = (double)SymbolInfoInteger(m_symbol, SYMBOL_SPREAD);

   double atr_fast = 0.0, atr_slow = 0.0, a_hi = 0.0, a_lo = 0.0;
   const bool fast_ok  = ReadAtr(m_h_atr_fast, atr_fast);
   const bool slow_ok  = ReadAtr(m_h_atr_slow, atr_slow);
   const bool asian_ok = AsianRange(a_hi, a_lo);

   string tf = EnumToString(_Period);
   StringReplace(tf, "PERIOD_", "");

   string news = "null";
   if(x.news_known)
     {
      const double mins = (double)(x.news_time - TimeTradeServer()) / 60.0;
      news = StringFormat("{\"event\":%s,\"time\":%s,\"minutes\":%.0f}", JStr(x.news_event),
                          JStr(FmtTime(x.news_time)), mins);
     }

   string j = "{";
   j += StringFormat("\"heartbeat\":%s,\"heartbeat_utc\":%I64d,", JStr(FmtTime(TimeTradeServer())), (long)TimeGMT());
   j += StringFormat("\"ea_version\":%s,\"strategy\":%s,\"symbol\":%s,\"tf\":%s,\"server\":%s,",
                     JStr(x.version), JStr(x.strategy), JStr(m_symbol), JStr(tf),
                     JStr(AccountInfoString(ACCOUNT_SERVER)));
   j += StringFormat("\"account_mode\":%s,\"live_guard\":\"OK\",\"connected\":%s,",
                     JStr(AccountModeName()), TerminalInfoInteger(TERMINAL_CONNECTED) ? "true" : "false");
   j += StringFormat("\"balance\":%.2f,\"equity\":%.2f,\"day_start_balance\":%.2f,\"breaker_limit\":%.2f,\"halted\":%s,",
                     AccountInfoDouble(ACCOUNT_BALANCE), AccountInfoDouble(ACCOUNT_EQUITY),
                     x.day_start_balance, x.breaker_limit, x.halted ? "true" : "false");
   j += StringFormat("\"bid\":%s,\"ask\":%s,\"spread_now\":%.0f,\"spread_max\":%d,",
                     JNum(tick.bid, m_digits, tick_ok), JNum(tick.ask, m_digits, tick_ok), spread_now, x.spread_max);
   j += StringFormat("\"atr_m15\":%s,\"atr_d1\":%s,", JNum(atr_fast, 2, fast_ok), JNum(atr_slow, 2, slow_ok));
   j += StringFormat("\"asian\":{\"valid\":%s,\"high\":%s,\"low\":%s,\"width\":%s},",
                     asian_ok ? "true" : "false", JNum(a_hi, m_digits, asian_ok), JNum(a_lo, m_digits, asian_ok),
                     JNum(a_hi - a_lo, m_digits, asian_ok));
   j += StringFormat("\"session_open\":%s,\"holiday_today\":%s,\"next_news\":%s,\"news_window_active\":%s,",
                     x.session_open ? "true" : "false", x.holiday_today ? "true" : "false", news,
                     x.news_window_active ? "true" : "false");
   j += StringFormat("\"holidays_covered_until\":%s,\"news_covered_until\":%s,",
                     x.holidays_covered_until > 0 ? IntegerToString(x.holidays_covered_until) : "null",
                     x.news_covered_until > 0 ? IntegerToString(x.news_covered_until) : "null");
   j += "\"open_positions\":" + PositionsJson(x.commission_per_lot) + "}";

   WriteWhole("status.json", j);
  }

//--- spread_snap.csv (ทุก timer) ไว้ทำสถิติ spread รายชั่วโมง • equity_snap.csv (ทุก 5 นาที)
void CTelemetry::WriteSnapshots(const STelemetryExtra &x, const datetime now)
  {
   //--- ตลาดปิด/tick เก่า -> ไม่บันทึก spread (กันสถิติรายชั่วโมงเพี้ยน)
   MqlTick tk;
   if(SymbolInfoTick(m_symbol, tk) && TimeCurrent() - tk.time <= 120)
      AppendLine("spread_snap.csv", "time,spread_points",
                 StringFormat("%s,%.0f", FmtTime(now), (double)SymbolInfoInteger(m_symbol, SYMBOL_SPREAD)));

   if(m_last_snap != 0 && now - m_last_snap < 300)
      return;
   m_last_snap = now;
   const double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   const double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   AppendLine("equity_snap.csv", "time,balance,equity,floating,day_start_balance,breaker_limit",
              StringFormat("%s,%.2f,%.2f,%.2f,%.2f,%.2f", FmtTime(now), balance, equity, equity - balance,
                           x.day_start_balance, x.breaker_limit));
  }

void CTelemetry::OnTimer(const STelemetryExtra &x)
  {
   if(!m_enabled)
      return;
   WriteStatus(x);
   WriteSnapshots(x, TimeTradeServer());
  }

#endif
//+------------------------------------------------------------------+
