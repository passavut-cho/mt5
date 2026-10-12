//+------------------------------------------------------------------+
//|                                              HolidayFilter.mqh   |
//|  Holiday filter (spec S9): ไม่เปิดไม้ใหม่ในวันที่อยู่ใน holidays.csv  |
//|  Fail closed: อ่านไฟล์ไม่ได้ / ปีไม่อยู่ใน covered_years -> ห้ามเปิดไม้ |
//+------------------------------------------------------------------+
#property strict

#include "../Core/Logger.mqh"

//+------------------------------------------------------------------+
//| รูปแบบไฟล์ (วันที่เป็น server date):                                 |
//|   # covered_years: 2023,2024,...   <- บรรทัดบอกปีที่ครอบคลุม          |
//|   # ...                            <- comment อื่น ข้าม              |
//|   date,type,note,verified          <- header ข้าม                   |
//|   2024-11-28,closed,Thanksgiving,fed                              |
//+------------------------------------------------------------------+
class CHolidayFilter
  {
private:
   CLogger          *m_log;
   string            m_file;
   bool              m_enabled;
   bool              m_loaded;          // อ่านไฟล์สำเร็จและมี covered_years
   int               m_dates[];         // yyyymmdd
   string            m_notes[];
   int               m_years[];         // covered_years
   int               m_warn_day;        // yyyymmdd ที่ Warn ล่าสุด (วันละครั้ง)
   int               m_load_day;        // yyyymmdd ที่โหลดไฟล์ล่าสุด

   static int        DayKey(const datetime t);
   static int        ParseDate(const string s);
   bool              Load();
   bool              YearCovered(const int year) const;
   void              WarnOncePerDay(const int day, const string msg);

public:
                     CHolidayFilter() : m_log(NULL), m_enabled(true), m_loaded(false), m_warn_day(0), m_load_day(0) {}
   bool              Init(CLogger *log, const string file, const bool enabled);
   //--- true = ห้ามเปิดไม้ใหม่ ณ เวลา t (why = เหตุผลสำหรับ log)
   bool              BlocksEntry(const datetime t, string &why);
  };

//+------------------------------------------------------------------+
int CHolidayFilter::DayKey(const datetime t)
  {
   MqlDateTime d;
   TimeToStruct(t, d);
   return(d.year * 10000 + d.mon * 100 + d.day);
  }

//+------------------------------------------------------------------+
//| "2024-11-28" -> 20241128 ; รูปแบบผิด -> 0                          |
//+------------------------------------------------------------------+
int CHolidayFilter::ParseDate(const string s)
  {
   string p[];
   if(StringSplit(s, '-', p) != 3)
      return(0);
   const int y = (int)StringToInteger(p[0]);
   const int m = (int)StringToInteger(p[1]);
   const int d = (int)StringToInteger(p[2]);
   if(y < 2000 || y > 2100 || m < 1 || m > 12 || d < 1 || d > 31)
      return(0);
   return(y * 10000 + m * 100 + d);
  }

//+------------------------------------------------------------------+
bool CHolidayFilter::Init(CLogger *log, const string file, const bool enabled)
  {
   m_log     = log;
   if(m_log == NULL)
      return(false);
   m_file    = file;
   m_enabled = enabled;
   if(!m_enabled)
     {
      m_log.Warn("holiday filter ปิดอยู่ (InpUseHolidayFilter=false)");
      return(true);
     }
   if(m_file == "")
     {
      m_log.Error("holiday filter: InpHolidayFile ว่าง");
      return(false);
     }
   m_load_day = DayKey(TimeTradeServer());
   Load();     // โหลดไม่ได้ไม่ทำให้ init ล้ม — BlocksEntry จะ fail closed + Warn เอง
   return(true);
  }

//+------------------------------------------------------------------+
bool CHolidayFilter::Load()
  {
   m_loaded = false;
   ArrayResize(m_dates, 0);
   ArrayResize(m_notes, 0);
   ArrayResize(m_years, 0);

   ResetLastError();
   const int h = FileOpen(m_file, FILE_READ | FILE_TXT | FILE_ANSI);
   if(h == INVALID_HANDLE)
     {
      m_log.Error(StringFormat("holiday filter: เปิด %s ไม่ได้ err=%d", m_file, GetLastError()));
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
      if(nf < 1)
         continue;
      const int day = ParseDate(f[0]);
      if(day == 0)
         continue;                         // header (date,type,...) หรือบรรทัดเสีย
      const int k = ArraySize(m_dates);
      ArrayResize(m_dates, k + 1);
      ArrayResize(m_notes, k + 1);
      m_dates[k] = day;
      m_notes[k] = (nf >= 3) ? f[2] : "";
     }
   FileClose(h);

   if(ArraySize(m_years) == 0)
     {
      m_log.Error(StringFormat("holiday filter: %s ไม่มีบรรทัด '# covered_years:'", m_file));
      return(false);
     }
   m_loaded = true;
   m_log.Info(StringFormat("holiday filter: โหลด %s สำเร็จ %d วัน, covered_years=%d ปี",
                           m_file, ArraySize(m_dates), ArraySize(m_years)));
   return(true);
  }

//+------------------------------------------------------------------+
bool CHolidayFilter::YearCovered(const int year) const
  {
   for(int i = 0; i < ArraySize(m_years); i++)
      if(m_years[i] == year)
         return(true);
   return(false);
  }

//+------------------------------------------------------------------+
void CHolidayFilter::WarnOncePerDay(const int day, const string msg)
  {
   if(m_warn_day == day)
      return;
   m_warn_day = day;
   m_log.Warn(msg);
  }

//+------------------------------------------------------------------+
bool CHolidayFilter::BlocksEntry(const datetime t, string &why)
  {
   if(!m_enabled)
      return(false);

   const int day = DayKey(t);
   // วันใหม่ -> โหลดไฟล์ใหม่ (รับการอัปเดตไฟล์โดยไม่ต้อง restart EA) — เฉพาะ live/demo; tester โหลดครั้งเดียว
   if(day != m_load_day && !MQLInfoInteger(MQL_TESTER))
     {
      m_load_day = day;
      Load();
     }

   if(!m_loaded)
     {
      why = "holiday file อ่านไม่ได้/ไม่มี covered_years (fail closed)";
      WarnOncePerDay(day, "holiday filter: " + why + " -> ไม่เปิดไม้ใหม่");
      return(true);
     }
   if(!YearCovered(day / 10000))
     {
      why = StringFormat("ปี %d ไม่อยู่ใน covered_years (fail closed)", day / 10000);
      WarnOncePerDay(day, "holiday filter: " + why + " -> ไม่เปิดไม้ใหม่ ต้องเติม holidays.csv");
      return(true);
     }
   for(int i = 0; i < ArraySize(m_dates); i++)
     {
      if(m_dates[i] == day)
        {
         why = StringFormat("วันหยุด %d %s", day, m_notes[i]);
         return(true);
        }
     }
   return(false);
  }
//+------------------------------------------------------------------+
