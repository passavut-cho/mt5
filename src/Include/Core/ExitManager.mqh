//+------------------------------------------------------------------+
//|                                                 ExitManager.mqh  |
//|  ชั้น Execution: จัดการ position ที่เปิดอยู่ของ S-B (Donchian H4)    |
//|   • partial close 50% + เลื่อน SL มา breakeven (B2/B3)             |
//|   • trailing SL ตามขอบ Donchian (เลื่อนได้ทางเดียว)                  |
//|   • weekend rule: ศุกร์หลัง cutoff ถือเฉพาะไม้ที่ SL ล็อกกำไรแล้ว      |
//|  ทุกอย่าง "ลด risk เท่านั้น" — ไม่เพิ่ม lot ไม่เปิดไม้ (ไม่ใช่ averaging) |
//|  ทุก modify/partial/close ส่งผ่าน CTradeManager (พร้อม magic)        |
//+------------------------------------------------------------------+
#ifndef SMARTEA_CORE_EXITMANAGER_MQH
#define SMARTEA_CORE_EXITMANAGER_MQH

#include "Types.mqh"
#include "Logger.mqh"
#include "TradeManager.mqh"

//--- Exit variant ของ S-B (docs/strategy/spec-donchian-h4.md)
enum ENUM_SBB_EXIT_MODE
  {
   SBB_EXIT_B1 = 0,   // trailing อย่างเดียว ไม่มี TP
   SBB_EXIT_B2 = 1,   // ปิด 50% ที่ +1R แล้ว SL -> breakeven, ที่เหลือ trailing
   SBB_EXIT_B3 = 2,   // ปิด 50% ที่ +2R แล้ว SL -> breakeven, ที่เหลือ trailing
   SBB_EXIT_B4 = 3    // TP เต็มจำนวนที่ +3R (trailing ยังทำงานก่อนถึง TP)
  };

//--- ข้อมูลที่ EA ป้อนให้ทุก tick (ExitManager ไม่อ่าน indicator เอง)
struct SExitContext
  {
   bool   new_bar;      // เพิ่งเกิดแท่งใหม่ (trailing ขยับเฉพาะตอนนี้ เพราะใช้แท่งที่ปิดแล้ว)
   bool   trail_ok;     // trail_lo/trail_hi ใช้ได้
   double trail_lo;     // lowest low ของ N แท่งที่ปิดแล้ว (ใช้กับ BUY)
   double trail_hi;     // highest high ของ N แท่งที่ปิดแล้ว (ใช้กับ SELL)
   bool   atr_ok;
   double atr;          // ATR ของแท่งที่ปิดแล้ว (ใช้กับ weekend lock)

   void Reset()
     {
      new_bar  = false;
      trail_ok = false;
      trail_lo = 0.0;
      trail_hi = 0.0;
      atr_ok   = false;
      atr      = 0.0;
     }
  };

//--- state ต่อ position (key = POSITION_IDENTIFIER)
struct SExitState
  {
   ulong    pid;
   double   r_dist;          // 1R = |ราคาเข้า - SL ตอนส่ง order| (กู้จาก history ได้ถ้า EA restart)
   bool     partial_done;    // ทำ/ตัดสินใจเรื่อง partial แล้ว (สำเร็จ หรือข้ามเพราะ volume_min)
   bool     be_needed;       // partial สำเร็จแล้วแต่ SL ยังไม่ถึง breakeven
   datetime retry_after;     // partial / breakeven ล้มเหลว (broker ปฏิเสธ) -> รอก่อนลองใหม่
   datetime wk_retry;        // weekend close ล้มเหลว -> รอก่อนลองใหม่ (กัน log ท่วมทุก tick)
   int      weekend_day;     // day-of-year ที่ตัดสิน weekend ไปแล้ว (กัน log/ตัดสินซ้ำ)
  };

class CExitManager
  {
private:
   CLogger      *m_log;
   CTradeManager *m_trade;
   string        m_symbol;
   ulong         m_magic;
   bool          m_ready;

   double        m_partial_r;         // 0 = ไม่ partial (B1/B4)
   double        m_partial_pct;       // % ของ volume ที่ปิด (spec = 50)
   double        m_weekend_lock_atr;  // 0 = ถือข้ามสุดสัปดาห์เมื่อ SL >= breakeven; >0 = SL ต้องล็อก >= ค่านี้ x ATR
   int           m_weekend_hour;      // ศุกร์ตั้งแต่ชั่วโมงนี้ (server) ตรวจ weekend rule

   SExitState    m_state[];

   //--- สถิติสำหรับ report (log ตอน Deinit)
   int           m_partial_ok;
   int           m_partial_skipped;   // ข้ามเพราะติด volume_min
   int           m_trail_moves;
   int           m_trail_exits;       // ราคาทะลุขอบ trailing ไปแล้ว -> ปิดตลาด
   int           m_weekend_hold;
   int           m_weekend_close;

   string        RKey(const ulong pid) const { return(StringFormat("SmartEA.R.%I64u.%I64u", m_magic, pid)); }
   int           FindState(const ulong pid) const;
   int           AddState(const ulong pid, const double open_price, const double cur_sl);
   void          Prune();
   void          DoPartial(const int idx, const ulong ticket);
   void          TryBreakeven(const int idx, const ulong ticket);
   void          TryTrail(const ulong ticket, const SExitContext &ctx);
   void          CheckWeekend(const int idx, const ulong ticket, const SExitContext &ctx);

public:
                 CExitManager() : m_log(NULL), m_trade(NULL), m_symbol(""), m_magic(0), m_ready(false),
                                  m_partial_r(0), m_partial_pct(50), m_weekend_lock_atr(0), m_weekend_hour(20),
                                  m_partial_ok(0), m_partial_skipped(0), m_trail_moves(0), m_trail_exits(0),
                                  m_weekend_hold(0), m_weekend_close(0) {}

   bool          Init(const string symbol, const ulong magic, CLogger *log, CTradeManager *trade,
                      const double partial_r, const double partial_pct, const double weekend_lock_atr,
                      const int weekend_hour);
   //--- EA แจ้งหลังเปิดไม้สำเร็จ: 1R = |fill - SL ที่ส่ง| (เก็บใน GlobalVariable ด้วย เพื่อให้รอด restart)
   void          NoteOpen(const ulong deal_ticket, const double r_dist);
   void          Manage(const SExitContext &ctx);   // เรียกทุก tick (ถูกมาก ถ้าไม่มี position)
   void          LogSummary() const;
  };

//+------------------------------------------------------------------+
bool CExitManager::Init(const string symbol, const ulong magic, CLogger *log, CTradeManager *trade,
                        const double partial_r, const double partial_pct, const double weekend_lock_atr,
                        const int weekend_hour)
  {
   m_ready = false;
   if(log == NULL || trade == NULL)
      return(false);
   m_log = log;
   if(partial_r < 0.0 || partial_pct <= 0.0 || partial_pct >= 100.0 || weekend_lock_atr < 0.0 ||
      weekend_hour < 0 || weekend_hour > 23)
     {
      m_log.Error("CExitManager: พารามิเตอร์ไม่ถูกต้อง");
      return(false);
     }
   m_trade            = trade;
   m_symbol           = symbol;
   m_magic            = magic;
   m_partial_r        = partial_r;
   m_partial_pct      = partial_pct;
   m_weekend_lock_atr = weekend_lock_atr;
   m_weekend_hour     = weekend_hour;
   ArrayResize(m_state, 0);
   m_ready = true;
   m_log.Info(StringFormat("CExitManager init: partial=%s weekend lock=%.2fxATR (ศุกร์ >= %02d:00)",
                           (m_partial_r > 0.0 ? StringFormat("%.0f%% ที่ +%.1fR", m_partial_pct, m_partial_r) : "off"),
                           m_weekend_lock_atr, m_weekend_hour));
   return(true);
  }

//+------------------------------------------------------------------+
int CExitManager::FindState(const ulong pid) const
  {
   for(int i = ArraySize(m_state) - 1; i >= 0; i--)
      if(m_state[i].pid == pid)
         return(i);
   return(-1);
  }

//+------------------------------------------------------------------+
//| สร้าง state ของ position ที่เพิ่งเห็น: 1R จาก order SL ตอนเข้า       |
//| และ partial_done = มี deal ขาออกแล้ว (กู้ state หลัง EA restart)       |
//+------------------------------------------------------------------+
int CExitManager::AddState(const ulong pid, const double open_price, const double cur_sl)
  {
   SExitState st;
   st.pid          = pid;
   st.r_dist       = 0.0;
   st.partial_done = false;
   st.be_needed    = false;
   st.retry_after  = 0;
   st.wk_retry     = 0;
   st.weekend_day  = -1;

   //--- 1R: GlobalVariable ที่ NoteOpen เก็บไว้ (หลัก) -> DEAL_SL ของ deal เข้า -> ORDER_SL ของ order เข้า
   if(GlobalVariableCheck(RKey(pid)))
      st.r_dist = GlobalVariableGet(RKey(pid));

   if(HistorySelectByPosition(pid))
     {
      const int n = HistoryDealsTotal();
      bool found_in = false;
      for(int i = 0; i < n; i++)
        {
         const ulong deal = HistoryDealGetTicket(i);
         if(deal == 0)
            continue;
         const long entry = HistoryDealGetInteger(deal, DEAL_ENTRY);
         if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)
            st.partial_done = true;
         else if(entry == DEAL_ENTRY_IN && !found_in)
           {
            found_in = true;
            if(st.r_dist <= 0.0)
              {
               const ulong order = (ulong)HistoryDealGetInteger(deal, DEAL_ORDER);
               double sl0 = HistoryDealGetDouble(deal, DEAL_SL);
               if(sl0 <= 0.0)
                  sl0 = HistoryOrderGetDouble(order, ORDER_SL);
               if(sl0 > 0.0)
                  st.r_dist = MathAbs(HistoryDealGetDouble(deal, DEAL_PRICE) - sl0);
              }
           }
        }
     }
   else
      m_log.Warn(StringFormat("CExitManager: HistorySelectByPosition(%I64u) ล้มเหลว err=%d", pid, GetLastError()));

   //--- restart หลัง partial สำเร็จแต่ SL ยังไม่ถึง breakeven -> บังคับ breakeven ต่อ (TryBreakeven ตรวจ SL จริงเอง)
   if(st.partial_done && st.r_dist > 0.0 && m_partial_r > 0.0)
      st.be_needed = true;

   if(st.r_dist <= 0.0)
     {
      //--- กู้ไม่ได้ -> ไม่ partial ไม้นี้ (trailing/weekend ยังทำงาน) แทนที่จะเดา 1R จาก SL ปัจจุบันที่อาจเลื่อนแล้ว
      st.partial_done = true;
      m_log.Warn(StringFormat("CExitManager: หา 1R ของ position %I64u ไม่ได้ (open %.2f sl %.2f) — ข้าม partial ไม้นี้",
                              pid, open_price, cur_sl));
     }
   else
      m_log.Info(StringFormat("CExitManager: ติดตาม position %I64u 1R=%.2f partial_done=%s", pid, st.r_dist,
                              st.partial_done ? "yes" : "no"));

   const int idx = ArraySize(m_state);
   ArrayResize(m_state, idx + 1);
   m_state[idx] = st;
   return(idx);
  }

//+------------------------------------------------------------------+
void CExitManager::NoteOpen(const ulong deal_ticket, const double r_dist)
  {
   if(!m_ready || deal_ticket == 0 || r_dist <= 0.0)
      return;
   if(!HistoryDealSelect(deal_ticket))
     {
      m_log.Warn(StringFormat("CExitManager: HistoryDealSelect(%I64u) ล้มเหลว err=%d — ไม่ได้เก็บ 1R", deal_ticket, GetLastError()));
      return;
     }
   const ulong pid = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
   if(pid == 0)
      return;
   GlobalVariableSet(RKey(pid), r_dist);
  }

//+------------------------------------------------------------------+
//| ลบ state ของ position ที่ปิดไปแล้ว                                  |
//+------------------------------------------------------------------+
void CExitManager::Prune()
  {
   for(int i = ArraySize(m_state) - 1; i >= 0; i--)
     {
      bool alive = false;
      for(int j = PositionsTotal() - 1; j >= 0 && !alive; j--)
        {
         if(PositionGetSymbol(j) != m_symbol || (ulong)PositionGetInteger(POSITION_MAGIC) != m_magic)
            continue;
         alive = ((ulong)PositionGetInteger(POSITION_IDENTIFIER) == m_state[i].pid);
        }
      if(!alive)
        {
         const int last = ArraySize(m_state) - 1;
         GlobalVariableDel(RKey(m_state[i].pid));
         if(i != last)
            m_state[i] = m_state[last];
         ArrayResize(m_state, last);
        }
     }
  }

//+------------------------------------------------------------------+
//| partial 50%: floor ตาม volume_step; ติด volume_min -> ไม่ partial + log |
//+------------------------------------------------------------------+
void CExitManager::DoPartial(const int idx, const ulong ticket)
  {
   if(!PositionSelectByTicket(ticket))
      return;
   const double vol  = PositionGetDouble(POSITION_VOLUME);
   const double step = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
   const double vmin = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
   if(step <= 0.0 || vmin <= 0.0)
     {
      m_log.Error("CExitManager: อ่าน volume_step/min ไม่ได้ — ข้าม partial");
      m_state[idx].retry_after = TimeCurrent() + 3600;
      return;
     }
   const double part = NormalizeDouble(MathFloor(vol * m_partial_pct / 100.0 / step + 1e-9) * step, 8);
   const double eps  = 1e-9;
   if(part < vmin - eps || vol - part < vmin - eps)
     {
      m_state[idx].partial_done = true;
      m_partial_skipped++;
      m_log.Trade("SKIP", StringFormat("PARTIAL ticket=%I64u vol=%.2f : ส่วนปิด %.2f / ส่วนเหลือ %.2f ต่ำกว่า volume_min %.2f — ถือทั้งไม้ต่อด้วย trailing",
                                       ticket, vol, part, vol - part, vmin));
      return;
     }
   if(m_trade.ClosePartial(ticket, part, StringFormat("partial +%.1fR", m_partial_r)))
     {
      m_state[idx].partial_done = true;
      m_state[idx].be_needed    = true;
      m_partial_ok++;
      TryBreakeven(idx, ticket);
     }
   else
      m_state[idx].retry_after = TimeCurrent() + 30;   // ไม่ลองทุก tick
  }

//+------------------------------------------------------------------+
//| SL -> breakeven (= ราคาเข้า) ถ้ายังแย่กว่า; trailing ที่ดีกว่าอยู่แล้วคงไว้ |
//+------------------------------------------------------------------+
void CExitManager::TryBreakeven(const int idx, const ulong ticket)
  {
   if(!PositionSelectByTicket(ticket))
      return;
   const bool   buy  = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
   const double open = PositionGetDouble(POSITION_PRICE_OPEN);
   const double sl   = PositionGetDouble(POSITION_SL);
   const bool   done = (sl > 0.0) && (buy ? sl >= open : sl <= open);
   if(done)
     {
      m_state[idx].be_needed = false;
      return;
     }
   if(m_trade.ModifySl(ticket, open, "breakeven หลัง partial"))
      m_state[idx].be_needed = false;
   else
      m_state[idx].retry_after = TimeCurrent() + 30;   // ไม่สำเร็จ -> ลองใหม่ใน tick ถัดไปหลัง 30 วินาที
  }

//+------------------------------------------------------------------+
//| trailing: SL ตามขอบ Donchian เลื่อนได้ทางเดียว                       |
//| ถ้าราคาทะลุขอบไปแล้ว (SL จะถูกชนทันที) -> ปิดตลาด เทียบเท่าโดน stop     |
//+------------------------------------------------------------------+
void CExitManager::TryTrail(const ulong ticket, const SExitContext &ctx)
  {
   if(!ctx.trail_ok || !PositionSelectByTicket(ticket))
      return;
   const bool   buy   = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
   const double sl    = PositionGetDouble(POSITION_SL);
   const double level = buy ? ctx.trail_lo : ctx.trail_hi;
   if(level <= 0.0)
      return;
   if(sl > 0.0 && (buy ? level <= sl : level >= sl))
      return;   // ขอบยังไม่ดีกว่า SL ปัจจุบัน

   MqlTick tk;
   if(!SymbolInfoTick(m_symbol, tk) || tk.bid <= 0.0 || tk.ask <= 0.0)
      return;
   const double px = buy ? tk.bid : tk.ask;
   if(buy ? px <= level : px >= level)
     {
      if(m_trade.CloseTicket(ticket, StringFormat("donchian exit: ราคา %.2f ทะลุขอบ %.2f", px, level)))
         m_trail_exits++;
      return;
     }
   if(m_trade.ModifySl(ticket, level, "trailing donchian"))
      m_trail_moves++;
  }

//+------------------------------------------------------------------+
//| Weekend rule (O2): ศุกร์ >= cutoff ตรวจแต่ละไม้ครั้งเดียวต่อวัน        |
//|  SL ล็อกกำไรได้ตามเกณฑ์ -> ถือข้ามสุดสัปดาห์ • ไม่งั้นปิด               |
//+------------------------------------------------------------------+
void CExitManager::CheckWeekend(const int idx, const ulong ticket, const SExitContext &ctx)
  {
   MqlDateTime t;
   TimeToStruct(TimeTradeServer(), t);
   if(t.day_of_week != 5 || t.hour < m_weekend_hour || m_state[idx].weekend_day == t.day_of_year + t.year * 400)
      return;
   if(TimeCurrent() < m_state[idx].wk_retry)
      return;
   if(!PositionSelectByTicket(ticket))
      return;

   const bool   buy   = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
   const double open  = PositionGetDouble(POSITION_PRICE_OPEN);
   const double sl    = PositionGetDouble(POSITION_SL);
   const double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);

   bool   locked = false;
   string detail = "";
   if(m_weekend_lock_atr <= 0.0)
     {
      locked = (sl > 0.0) && (buy ? sl >= open - point * 0.5 : sl <= open + point * 0.5);   // breakeven หรือดีกว่า
      detail = StringFormat("SL %.2f เทียบ breakeven %.2f", sl, open);
     }
   else if(ctx.atr_ok)
     {
      const double need = m_weekend_lock_atr * ctx.atr;
      locked = (sl > 0.0) && (buy ? sl >= open + need - point * 0.5 : sl <= open - need + point * 0.5);
      detail = StringFormat("SL %.2f ต้องล็อก >= %.2f (%.2fxATR %.2f) จาก %.2f", sl, need, m_weekend_lock_atr, ctx.atr, open);
     }
   else
      detail = "ไม่มี ATR สำหรับเกณฑ์ lock — ปิดเพื่อความปลอดภัย";

   m_state[idx].weekend_day = t.day_of_year + t.year * 400;
   if(locked)
     {
      m_weekend_hold++;
      m_log.Trade("HOLD", StringFormat("ticket=%I64u weekend: %s — ถือข้ามสุดสัปดาห์", ticket, detail));
      return;
     }
   if(m_trade.CloseTicket(ticket, "weekend: SL ยังไม่ล็อกกำไร (" + detail + ")"))
      m_weekend_close++;
   else
     {
      m_state[idx].weekend_day = -1;                     // ปิดไม่สำเร็จ -> ลองใหม่ (หลัง 30 วินาที)
      m_state[idx].wk_retry    = TimeCurrent() + 30;
     }
  }

//+------------------------------------------------------------------+
void CExitManager::Manage(const SExitContext &ctx)
  {
   if(!m_ready)
      return;
   if(ctx.new_bar)
      Prune();

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != m_symbol || (ulong)PositionGetInteger(POSITION_MAGIC) != m_magic)
         continue;

      const ulong  pid  = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      const bool   buy  = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      const double open = PositionGetDouble(POSITION_PRICE_OPEN);
      int idx = FindState(pid);
      if(idx < 0)
         idx = AddState(pid, open, PositionGetDouble(POSITION_SL));

      //--- 1) partial เมื่อกำไรถึง k x R (ตรวจทุก tick)
      if(m_partial_r > 0.0 && !m_state[idx].partial_done && m_state[idx].r_dist > 0.0 &&
         TimeCurrent() >= m_state[idx].retry_after)
        {
         MqlTick tk;
         if(SymbolInfoTick(m_symbol, tk) && tk.bid > 0.0 && tk.ask > 0.0)
           {
            const double gain = buy ? tk.bid - open : open - tk.ask;
            if(gain >= m_partial_r * m_state[idx].r_dist)
               DoPartial(idx, ticket);
           }
        }

      //--- 2) breakeven ที่ค้าง (partial สำเร็จแต่ modify ไม่ผ่าน / กู้หลัง restart): ลองทุก tick ห่างกัน >= 30 วินาที
      if(m_state[idx].be_needed && TimeCurrent() >= m_state[idx].retry_after)
         TryBreakeven(idx, ticket);

      //--- 3) trailing: เฉพาะแท่งใหม่ (ใช้แท่งที่ปิดแล้ว)
      if(ctx.new_bar)
         TryTrail(ticket, ctx);

      //--- 4) weekend rule (ใช้ SL ล่าสุดหลังขั้นตอนข้างบน)
      if(PositionSelectByTicket(ticket))
         CheckWeekend(idx, ticket, ctx);
     }
  }

//+------------------------------------------------------------------+
void CExitManager::LogSummary() const
  {
   if(m_log == NULL)
      return;
   m_log.Info(StringFormat("EXIT summary: partial_ok=%d partial_skipped_volmin=%d trail_moves=%d trail_exits=%d weekend_hold=%d weekend_close=%d",
                           m_partial_ok, m_partial_skipped, m_trail_moves, m_trail_exits, m_weekend_hold, m_weekend_close));
  }

#endif
//+------------------------------------------------------------------+
