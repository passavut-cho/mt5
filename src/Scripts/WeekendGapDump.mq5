//+------------------------------------------------------------------+
//|                                             WeekendGapDump.mq5   |
//|  T-042: วัด weekend gap ของ symbol บน H4 (อ่านอย่างเดียว ไม่เทรด)  |
//|  ทุกสัปดาห์: close ของแท่ง H4 สุดท้ายวันศุกร์ → open ของแท่งแรก    |
//|  หลังจากนั้น (server time) + ATR(14,H4) ณ แท่งศุกร์สุดท้าย        |
//|  ผลลัพธ์: MQL5\Files\SmartEA\<InpOutFile> (junction → data\files)  |
//+------------------------------------------------------------------+
#property copyright   "Phas"
#property version     "1.00"
#property description "Weekend gap measurement (read-only, no trading)"
#property script_show_inputs

input string   InpFrom      = "2018.01.01";   // วันเริ่ม (server date)
input string   InpTo        = "2022.12.31";   // วันสิ้นสุด (server date)
input int      InpAtrPeriod = 14;             // ช่วง ATR (SMA ของ true range เหมือน iATR)
input string   InpOutFile   = "SmartEA\\weekend_gaps_raw.csv";

//--- ATR ณ แท่ง index i (SMA ของ TR ย้อนหลัง period แท่งที่รวมแท่ง i)
double AtrAt(const MqlRates &r[], const int i, const int period)
  {
   if(i < period)
      return(0.0);
   double sum = 0.0;
   for(int k = i - period + 1; k <= i; k++)
     {
      double tr = MathMax(r[k].high, r[k - 1].close) - MathMin(r[k].low, r[k - 1].close);
      sum += tr;
     }
   return(sum / period);
  }

int DayOfWeekOf(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return(dt.day_of_week);
  }

void OnStart()
  {
   datetime from = StringToTime(InpFrom);
   datetime to   = StringToTime(InpTo) + 86400 - 1;
   if(from <= 0 || to <= from || InpAtrPeriod < 1)
     {
      Print("WEEKENDGAP ERROR input ไม่ถูกต้อง");
      return;
     }
   //--- เผื่อแท่งก่อนหน้าสำหรับ ATR และแท่งหลังวันสุดท้ายเพื่อหา Monday open ของสัปดาห์สุดท้าย
   datetime pre  = from - 30 * 86400;
   datetime post = to + 7 * 86400;
   MqlRates r[];
   ResetLastError();
   int n = CopyRates(_Symbol, PERIOD_H4, pre, post, r);
   if(n <= 0)
     {
      PrintFormat("WEEKENDGAP ERROR CopyRates n=%d err=%d", n, GetLastError());
      return;
     }
   PrintFormat("WEEKENDGAP bars=%d first=%s last=%s", n, TimeToString(r[0].time), TimeToString(r[n - 1].time));

   int h = FileOpen(InpOutFile, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(h == INVALID_HANDLE)
     {
      PrintFormat("WEEKENDGAP ERROR FileOpen err=%d", GetLastError());
      return;
     }
   FileWriteString(h, "fri_bar_time,fri_close,mon_bar_time,mon_open,gap,atr_h4\r\n");

   int rows = 0;
   for(int i = 0; i < n - 1; i++)
     {
      if(r[i].time < from || r[i].time > to)
         continue;
      if(DayOfWeekOf(r[i].time) != 5)
         continue;
      //--- แท่งศุกร์สุดท้าย = แท่งถัดไปไม่ใช่วันศุกร์
      if(DayOfWeekOf(r[i + 1].time) == 5)
         continue;
      double atr = AtrAt(r, i, InpAtrPeriod);
      if(atr <= 0.0)
         continue;
      double gap = r[i + 1].open - r[i].close;
      FileWriteString(h, StringFormat("%s,%.2f,%s,%.2f,%.2f,%.4f\r\n",
                                      TimeToString(r[i].time, TIME_DATE | TIME_MINUTES), r[i].close,
                                      TimeToString(r[i + 1].time, TIME_DATE | TIME_MINUTES), r[i + 1].open,
                                      gap, atr));
      rows++;
     }
   FileClose(h);
   PrintFormat("WEEKENDGAP DONE rows=%d file=%s", rows, InpOutFile);
  }
