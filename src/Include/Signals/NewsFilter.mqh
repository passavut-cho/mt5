//+------------------------------------------------------------------+
//|                                                  NewsFilter.mqh  |
//|  News filter (spec v2 V2b): ไม่เปิดไม้ใหม่ในช่วง ±N นาทีของข่าว       |
//|  Fail closed: อ่านไฟล์ไม่ได้ / ปีไม่อยู่ใน covered_years -> ห้ามเปิดไม้ |
//+------------------------------------------------------------------+
#property strict

#include "../Core/Logger.mqh"

//+------------------------------------------------------------------+
//| รูปแบบไฟล์ (เวลาเป็น SERVER time):                                   |
//|   # covered_years: 2023,2024                                      |
//|   date,time,event,verified        <- header ข้าม                   |
//|   2024-06-12,15:30,CPI,bls                                        |
//+------------------------------------------------------------------+
class CNewsFilter
  {
private:
   CLogger          *m_log;
   string            m_file;
   bool              m_enabled;
   bool              m_loaded;
   int               m_window_sec;
   datetime          m_times[];
   string            m_events[];
   int               m_years[];
   int               m_warn_day;
   int               m_load_day;

   static int        DayKey(const datetime t);
   static datetime   ParseDateTime(const string d, const string hhmm);
   bool              Load();
   bool              YearCovered(const int year) const;
   void              WarnOncePerDay(const int day, const string msg);

public:
                     CNewsFilter() : m_log(NULL), m_enabled(false), m_loaded(false), m_window_sec(0), m_warn_day(0), m_load_day(0) {}
   bool              Init(CLogger *log, const string file, const bool enabled, const int window_min);
   //--- true = ห้ามเปิดไม้ใหม่ ณ เวลา t (why = เหตุผลสำหรับ log)
   bool              BlocksEntry(const datetime t, string &why);
   //--- อ่านอย่างเดียวสำหรับ telemetry (ไม่ reload ไม่ Warn ไม่กระทบการตัดสิน)
   int               CoveredUntilYear() const;   // 0 = ยังไม่โหลด/ปิด flag
   bool              InWindow(const datetime t) const;
   bool              NextEvent(const datetime t, string &name, datetime &when) const;   // event แรกที่ยังไม่ผ่านพ้น t
  };

//+------------------------------------------------------------------+
int CNewsFilter::DayKey(const datetime t)
  {
   MqlDateTime d;
   TimeToStruct(t, d);
   return(d.year * 10000 + d.mon * 100 + d.day);
  }

//+------------------------------------------------------------------+
//| "2024-06-12","15:30" -> datetime ; รูปแบบผิด -> 0                   |
//+------------------------------------------------------------------+
datetime CNewsFilter::ParseDateTime(const string d, const string hhmm)
  {
   string p[], q[];
   if(StringSplit(d, '-', p) != 3 || StringSplit(hhmm, ':', q) != 2)
      return(0);
   MqlDateTime t;
   t.year = (int)StringToInteger(p[0]);
   t.mon  = (int)StringToInteger(p[1]);
   t.day  = (int)StringToInteger(p[2]);
   t.hour = (int)StringToInteger(q[0]);
   t.min  = (int)StringToInteger(q[1]);
   t.sec  = 0;
   if(t.year < 2000 || t.year > 2100 || t.mon < 1 || t.mon > 12 || t.day < 1 || t.day > 31 ||
      t.hour < 0 || t.hour > 23 || t.min < 0 || t.min > 59)
      return(0);
   return(StructToTime(t));
  }

//+------------------------------------------------------------------+
bool CNewsFilter::Init(CLogger *log, const string file, const bool enabled, const int window_min)
  {
   m_log = log;
   if(m_log == NULL)
      return(false);
   m_file    = file;
   m_enabled = enabled;
   if(!m_enabled)
      return(true);                 // flag ปิด = พฤติกรรม v1 ไม่แตะไฟล์
   if(m_file == "" || window_min < 0 || window_min > 24 * 60)
     {
      m_log.Error("news filter: InpNewsFile ว่าง หรือ InpNewsWindowMin ไม่ถูกต้อง");
      return(false);
     }
   m_window_sec = window_min * 60;
   m_load_day   = DayKey(TimeTradeServer());
   Load();     // โหลดไม่ได้ไม่ทำให้ init ล้ม — BlocksEntry จะ fail closed + Warn เอง
   return(true);
  }

//+------------------------------------------------------------------+
bool CNewsFilter::Load()
  {
   m_loaded = false;
   ArrayResize(m_times, 0);
   ArrayResize(m_events, 0);
   ArrayResize(m_years, 0);

   ResetLastError();
   const int h = FileOpen(m_file, FILE_READ | FILE_TXT | FILE_ANSI);
   if(h == INVALID_HANDLE)
     {
      m_log.Error(StringFormat("news filter: เปิด %s ไม่ได้ err=%d", m_file, GetLastError()));
      return(false);
     }

   while(!FileIsEnding(h))
     {
      string line = FileReadString(h);
      StringTrimLeft(line);
      StringTrimRight(line);
      if(line == "")
         continue;
      if(StringFind(line, "#") >= 0 && StringFind(line, "#") <= 3)   // เผื่อ BOM นำหน้า
        {
         const string key = "covered_years:";
         const int pos = StringFind(line, key);
         if(pos >= 0)
           {
            string ys[];
            const int n = StringSplit(StringSubstr(line, pos + StringLen(key)), ',', ys);
            for(int i = 0; i < n; i++)
              {
               const int y = (int)StringToInteger(ys[i]);
               if(y >= 2000 && y <= 2100)
                 {
                  ArrayResize(m_years, ArraySize(m_years) + 1);
                  m_years[ArraySize(m_years) - 1] = y;
                 }
              }
           }
         continue;
        }
      string f[];
      const int nf = StringSplit(line, ',', f);
      if(nf < 3)
         continue;
      const datetime when = ParseDateTime(f[0], f[1]);
      if(when == 0)
         continue;                         // header หรือบรรทัดเสีย
      const int k = ArraySize(m_times);
      ArrayResize(m_times, k + 1);
      ArrayResize(m_events, k + 1);
      m_times[k]  = when;
      m_events[k] = f[2];
     }
   FileClose(h);

   if(ArraySize(m_years) == 0)
     {
      m_log.Error(StringFormat("news filter: %s ไม่มีบรรทัด '# covered_years:'", m_file));
      return(false);
     }
   m_loaded = true;
   m_log.Info(StringFormat("news filter: โหลด %s สำเร็จ %d เหตุการณ์, covered_years=%d ปี, window ±%d นาที",
                           m_file, ArraySize(m_times), ArraySize(m_years), m_window_sec / 60));
   return(true);
  }

//+------------------------------------------------------------------+
bool CNewsFilter::YearCovered(const int year) const
  {
   for(int i = 0; i < ArraySize(m_years); i++)
      if(m_years[i] == year)
         return(true);
   return(false);
  }

//+------------------------------------------------------------------+
void CNewsFilter::WarnOncePerDay(const int day, const string msg)
  {
   if(m_warn_day == day)
      return;
   m_warn_day = day;
   m_log.Warn(msg);
  }

//+------------------------------------------------------------------+
int CNewsFilter::CoveredUntilYear() const
  {
   int y = 0;
   if(!m_loaded)
      return(0);
   for(int i = 0; i < ArraySize(m_years); i++)
      y = MathMax(y, m_years[i]);
   return(y);
  }

bool CNewsFilter::InWindow(const datetime t) const
  {
   if(!m_loaded)
      return(false);
   for(int i = 0; i < ArraySize(m_times); i++)
      if(MathAbs((long)(t - m_times[i])) <= m_window_sec)
         return(true);
   return(false);
  }

bool CNewsFilter::NextEvent(const datetime t, string &name, datetime &when) const
  {
   bool found = false;
   if(!m_loaded)
      return(false);
   for(int i = 0; i < ArraySize(m_times); i++)
     {
      if(m_times[i] < t)
         continue;
      if(!found || m_times[i] < when)
        {
         found = true;
         when  = m_times[i];
         name  = m_events[i];
        }
     }
   return(found);
  }

//+------------------------------------------------------------------+
bool CNewsFilter::BlocksEntry(const datetime t, string &why)
  {
   if(!m_enabled)
      return(false);

   const int day = DayKey(t);
   if(day != m_load_day && !MQLInfoInteger(MQL_TESTER))   // รับการอัปเดตไฟล์ตอน live/demo; tester โหลดครั้งเดียว
     {
      m_load_day = day;
      Load();
     }

   if(!m_loaded)
     {
      why = "news file อ่านไม่ได้/ไม่มี covered_years (fail closed)";
      WarnOncePerDay(day, "news filter: " + why + " -> ไม่เปิดไม้ใหม่");
      return(true);
     }
   if(!YearCovered(day / 10000))
     {
      why = StringFormat("ปี %d ไม่อยู่ใน covered_years (fail closed)", day / 10000);
      WarnOncePerDay(day, "news filter: " + why + " -> ไม่เปิดไม้ใหม่ ต้องเติม news.csv");
      return(true);
     }
   for(int i = 0; i < ArraySize(m_times); i++)
     {
      if(MathAbs((long)(t - m_times[i])) <= m_window_sec)
        {
         why = StringFormat("news %s %s ±%dm", m_events[i], TimeToString(m_times[i], TIME_DATE | TIME_MINUTES),
                            m_window_sec / 60);
         return(true);
        }
     }
   return(false);
  }
//+------------------------------------------------------------------+
