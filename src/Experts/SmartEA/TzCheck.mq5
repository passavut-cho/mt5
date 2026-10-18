//+------------------------------------------------------------------+
//|                                                      TzCheck.mq5 |
//|  T-030: ตรวจ timezone ของ history M15 — หาแท่งที่ range ใหญ่สุด    |
//|  ของวัน NFP แต่ละวัน (server date) ควรเริ่ม 15:30 server          |
//|  อ่านอย่างเดียว ไม่เทรด — รันใน Strategy Tester แล้วอ่าน journal    |
//+------------------------------------------------------------------+
#property copyright "Phas"
#property version   "1.00"
#property description "History timezone check (read-only, no trading)"

input string InpDates      = "2011.08.05,2014.03.07,2016.07.08,2019.02.01,2021.04.02"; // วัน NFP (server date) คั่นด้วย ,
input int    InpExpectHHMM = 1530;  // เวลาเริ่มแท่งที่คาดไว้ (server)

datetime g_top[3];

//--- ตรวจ 1 วัน: พิมพ์แท่งที่ range ใหญ่สุด + ผลเทียบกับที่คาด
void CheckDay(const string day, int &ok, int &bad)
  {
   datetime from = StringToTime(day);
   if(from <= 0)
     {
      PrintFormat("TZCHECK %s | ERROR วันที่ไม่ถูกต้อง", day);
      bad++;
      return;
     }
   MqlRates rates[];
   int n = CopyRates(_Symbol, PERIOD_M15, from, from + 86400 - 1, rates);
   if(n <= 0)
     {
      PrintFormat("TZCHECK %s | ERROR CopyRates n=%d err=%d", day, n, GetLastError());
      bad++;
      return;
     }
   int best = 0;
   for(int i = 1; i < n; i++)
      if(rates[i].high - rates[i].low > rates[best].high - rates[best].low)
         best = i;
   MqlDateTime dt;
   TimeToStruct(rates[best].time, dt);
   int hhmm = dt.hour * 100 + dt.min;
   double range = rates[best].high - rates[best].low;
   PrintFormat("TZCHECK %s | bars=%d first=%s | maxrange=%.2f at %s (hhmm=%04d) expect=%04d offset_min=%d",
               day, n, TimeToString(rates[0].time, TIME_MINUTES), range,
               TimeToString(rates[best].time, TIME_MINUTES), hhmm, InpExpectHHMM,
               (dt.hour * 60 + dt.min) - (InpExpectHHMM / 100 * 60 + InpExpectHHMM % 100));
   //--- แท่งที่ range ใหญ่สุด 3 อันดับ + แท่งที่คาดไว้ (ใช้ประกอบการตัดสินเมื่อข้อมูลบาง)
   for(int k = 0; k < 3; k++)
     {
      int bi = -1;
      double br = -1;
      for(int i = 0; i < n; i++)
        {
         double r = rates[i].high - rates[i].low;
         bool used = false;
         for(int u = 0; u < k; u++)
            if(rates[i].time == g_top[u])
               used = true;
         if(!used && r > br)
           {
            br = r;
            bi = i;
           }
        }
      if(bi < 0)
         break;
      g_top[k] = rates[bi].time;
      PrintFormat("TZCHECK %s |   top%d %s range=%.2f ticks=%d", day, k + 1, TimeToString(rates[bi].time, TIME_MINUTES), br, (int)rates[bi].tick_volume);
     }
   for(int i = 0; i < n; i++)
     {
      MqlDateTime d2;
      TimeToStruct(rates[i].time, d2);
      if(d2.hour * 100 + d2.min == InpExpectHHMM)
         PrintFormat("TZCHECK %s |   expected-bar %s range=%.2f ticks=%d", day, TimeToString(rates[i].time, TIME_MINUTES), rates[i].high - rates[i].low, (int)rates[i].tick_volume);
     }
   if(hhmm == InpExpectHHMM)
      ok++;
   else
      bad++;
  }

//--- CopyRates ย้อนหลังก่อนเริ่มเทสไม่ได้ (err 4401) → รอให้เวลาจำลองผ่านสิ้นวันก่อนค่อยอ่าน
//    ใช้ ini ทีละวัน: FromDate = วันนั้น, ToDate = วันถัดไป+1
string g_days[];
int    g_next = 0;
int    g_ok = 0, g_bad = 0;

int OnInit()
  {
   int cnt = StringSplit(InpDates, ',', g_days);
   for(int i = 0; i < cnt; i++)
     {
      StringTrimLeft(g_days[i]);
      StringTrimRight(g_days[i]);
     }
   return cnt > 0 ? INIT_SUCCEEDED : INIT_PARAMETERS_INCORRECT;
  }

void OnTick()
  {
   int cnt = ArraySize(g_days);
   while(g_next < cnt && TimeCurrent() >= StringToTime(g_days[g_next]) + 86400)
     {
      CheckDay(g_days[g_next], g_ok, g_bad);
      g_next++;
     }
   if(g_next >= cnt)
     {
      PrintFormat("TZCHECK SUMMARY | symbol=%s ok=%d bad=%d total=%d", _Symbol, g_ok, g_bad, cnt);
      ExpertRemove();
     }
  }

//--- วันศุกร์ (NFP) ไม่มี tick หลังสิ้นวัน → เช็คส่วนที่เหลือตอนจบเทส
void OnDeinit(const int reason)
  {
   int cnt = ArraySize(g_days);
   if(g_next >= cnt)
      return;
   while(g_next < cnt)
     {
      CheckDay(g_days[g_next], g_ok, g_bad);
      g_next++;
     }
   PrintFormat("TZCHECK SUMMARY | symbol=%s ok=%d bad=%d total=%d", _Symbol, g_ok, g_bad, cnt);
  }
