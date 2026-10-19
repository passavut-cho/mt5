//+------------------------------------------------------------------+
//|                                            ScreenerExportEA.mq5  |
//|  T-048: export แท่ง M15 ผ่าน Strategy Tester (อ่านอย่างเดียว       |
//|  ไม่มี order) — terminal ไม่เก็บ history M15 ย้อนหลังไว้ใน chart     |
//|  แต่ tester ดึง M1 จาก broker เองจึงได้ครบช่วง                     |
//|  ทุกแท่งใหม่เขียนแท่งที่ "ปิดแล้ว" (shift 1): bid OHLC, tick_volume,   |
//|  spread (points) เป็น server time → Common\Files\<InpOutFile>      |
//|  กันมองข้อมูล validation: ไม่เขียนแท่งหลัง 2022.12.31 23:59        |
//+------------------------------------------------------------------+
#property copyright   "Phas"
#property version     "1.00"
#property description "Screener data export EA (tester only, no trading)"

input string InpOutFile   = "SmartEA_xauusd_m15_export.csv";   // ใน Common\Files
input bool   InpAllowLive = false;   // live guard (กฎเหล็กข้อ 1)

//--- เพดานข้อมูลที่อนุญาต (research set) — ไม่ใช่ค่า risk
const datetime SCREENER_LIMIT = D'2022.12.31 23:59:59';

int      g_handle   = INVALID_HANDLE;
datetime g_last_bar = 0;
int      g_rows     = 0;
datetime g_first    = 0;
datetime g_written  = 0;

int OnInit()
  {
   //--- live guard: บัญชีจริงต้องเปิด InpAllowLive (EA นี้ไม่เทรด แต่ใช้กฎเดียวกันทุก EA)
   if(AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_REAL && !InpAllowLive)
     {
      Print("SCREENEXPORT ERROR live guard: บัญชีจริงและ InpAllowLive=false");
      return(INIT_FAILED);
     }
   //--- ใช้ได้เฉพาะใน tester: ไม่ให้ไปรันบน chart จริงโดยไม่ตั้งใจ
   if(!MQLInfoInteger(MQL_TESTER))
     {
      Print("SCREENEXPORT ERROR รันได้เฉพาะใน Strategy Tester");
      return(INIT_FAILED);
     }
   ResetLastError();
   g_handle = FileOpen(InpOutFile, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(g_handle == INVALID_HANDLE)
     {
      PrintFormat("SCREENEXPORT ERROR FileOpen err=%d", GetLastError());
      return(INIT_FAILED);
     }
   FileWriteString(g_handle, "time,open,high,low,close,tick_volume,spread\r\n");
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   if(g_handle != INVALID_HANDLE)
     {
      FileClose(g_handle);
      g_handle = INVALID_HANDLE;
     }
   PrintFormat("SCREENEXPORT DONE rows=%d first=%s last=%s file=%s",
               g_rows, TimeToString(g_first), TimeToString(g_written), InpOutFile);
  }

void OnTick()
  {
   if(g_handle == INVALID_HANDLE)
      return;
   datetime cur = iTime(_Symbol, PERIOD_M15, 0);
   if(cur == 0 || cur == g_last_bar)
      return;
   g_last_bar = cur;

   MqlRates r[];
   ResetLastError();
   if(CopyRates(_Symbol, PERIOD_M15, 1, 1, r) != 1)
     {
      PrintFormat("SCREENEXPORT WARN CopyRates err=%d at %s", GetLastError(), TimeToString(cur));
      return;
     }
   if(r[0].time > SCREENER_LIMIT)
      return;
   FileWriteString(g_handle, StringFormat("%s,%.2f,%.2f,%.2f,%.2f,%I64d,%d\r\n",
                                          TimeToString(r[0].time, TIME_DATE | TIME_MINUTES),
                                          r[0].open, r[0].high, r[0].low, r[0].close,
                                          r[0].tick_volume, r[0].spread));
   if(g_first == 0)
      g_first = r[0].time;
   g_written = r[0].time;
   g_rows++;
  }
