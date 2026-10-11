//+------------------------------------------------------------------+
//|                                              SymbolSpecDump.mq5  |
//|  ดึง spec ของบัญชี + symbol เพื่อเทียบ broker และตรวจสูตรคำนวณ lot |
//|  ผลลัพธ์: แท็บ Experts + MQL5\Files\SmartEA\specs_<server>.tsv     |
//|  (Files\SmartEA เป็น junction เข้า repo: data\files\)              |
//+------------------------------------------------------------------+
#property copyright   "Phas"
#property version     "1.00"
#property description "Dump account + symbol specifications (read-only, no trading)"
#property script_show_inputs

input string InpSymbols    = "";  // ว่าง = symbol ของ chart, หลายตัวคั่นด้วย , เช่น XAUUSD,EURUSD
input int    InpSpreadDays = 7;   // จำนวนวันย้อนหลังสำหรับสถิติ spread (จากแท่ง M1)

int g_file = INVALID_HANDLE;

//--- เขียน 1 แถว ทั้งลง log และไฟล์
void Row(const string scope, const string key, const string value)
  {
   PrintFormat("%-10s | %-26s | %s", scope, key, value);
   if(g_file != INVALID_HANDLE)
      FileWrite(g_file, scope, key, value);
  }

//--- แปลง flag filling mode เป็นข้อความ
string FillingToString(const long flags)
  {
   string s = "";
   if((flags & SYMBOL_FILLING_FOK) != 0)
      s += "FOK ";
   if((flags & SYMBOL_FILLING_IOC) != 0)
      s += "IOC ";
   if((flags & 4) != 0)
      s += "BOC ";
   if(s == "")
      s = "RETURN only";
   return(s);
  }

//--- ตัดอักขระที่ใช้ในชื่อไฟล์ไม่ได้
string SafeName(string s)
  {
   string bad[] = {" ", ":", "/", "\\", "*", "?", "\"", "<", ">", "|"};
   for(int i = 0; i < ArraySize(bad); i++)
      StringReplace(s, bad[i], "_");
   return(s);
  }

//--- ข้อมูลบัญชี (ไม่ดึง login / balance โดยตั้งใจ)
void DumpAccount()
  {
   ENUM_ACCOUNT_TRADE_MODE  tm = (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   ENUM_ACCOUNT_MARGIN_MODE mm = (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   ENUM_ACCOUNT_STOPOUT_MODE sm = (ENUM_ACCOUNT_STOPOUT_MODE)AccountInfoInteger(ACCOUNT_MARGIN_SO_MODE);

   Row("ACCOUNT", "server",         AccountInfoString(ACCOUNT_SERVER));
   Row("ACCOUNT", "company",        AccountInfoString(ACCOUNT_COMPANY));
   Row("ACCOUNT", "trade_mode",     EnumToString(tm));
   Row("ACCOUNT", "margin_mode",    EnumToString(mm));
   Row("ACCOUNT", "currency",       AccountInfoString(ACCOUNT_CURRENCY));
   Row("ACCOUNT", "leverage",       IntegerToString(AccountInfoInteger(ACCOUNT_LEVERAGE)));
   Row("ACCOUNT", "stopout_mode",   EnumToString(sm));
   Row("ACCOUNT", "margin_call",    DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_SO_CALL), 2));
   Row("ACCOUNT", "stop_out",       DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_SO_SO), 2));
   Row("ACCOUNT", "terminal_build", IntegerToString(TerminalInfoInteger(TERMINAL_BUILD)));
  }

//--- สถิติ spread จากแท่ง M1 ย้อนหลัง (หน่วย points)
void DumpSpreadStats(const string sym)
  {
   MqlRates rates[];
   datetime to   = TimeCurrent();
   datetime from = (datetime)((long)to - (long)InpSpreadDays * 86400);
   int n = CopyRates(sym, PERIOD_M1, from, to, rates);
   if(n <= 0)
     {
      Row(sym, "spread_stats", StringFormat("n/a (CopyRates err %d - run again after history loads)", GetLastError()));
      return;
     }

   int  sp[];
   long sum = 0;
   ArrayResize(sp, n);
   for(int i = 0; i < n; i++)
     {
      sp[i] = rates[i].spread;
      sum  += rates[i].spread;
     }
   ArraySort(sp);

   Row(sym, "spread_m1_bars",    IntegerToString(n));
   Row(sym, "spread_avg_pts",    DoubleToString((double)sum / n, 1));
   Row(sym, "spread_median_pts", IntegerToString(sp[n / 2]));
   Row(sym, "spread_p95_pts",    IntegerToString(sp[(int)(n * 0.95)]));
   Row(sym, "spread_max_pts",    IntegerToString(sp[n - 1]));
  }

//--- spec ของ symbol
bool DumpSymbol(const string sym)
  {
   if(!SymbolSelect(sym, true))
     {
      Row(sym, "error", "symbol not found on this server");
      return(false);
     }

   int    digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   double point  = SymbolInfoDouble(sym, SYMBOL_POINT);

   Row(sym, "description",      SymbolInfoString(sym, SYMBOL_DESCRIPTION));
   Row(sym, "calc_mode",        EnumToString((ENUM_SYMBOL_CALC_MODE)SymbolInfoInteger(sym, SYMBOL_TRADE_CALC_MODE)));
   Row(sym, "exec_mode",        EnumToString((ENUM_SYMBOL_TRADE_EXECUTION)SymbolInfoInteger(sym, SYMBOL_TRADE_EXEMODE)));
   Row(sym, "filling",          FillingToString(SymbolInfoInteger(sym, SYMBOL_FILLING_MODE)));
   Row(sym, "digits",           IntegerToString(digits));
   Row(sym, "point",            DoubleToString(point, digits));
   Row(sym, "contract_size",    DoubleToString(SymbolInfoDouble(sym, SYMBOL_TRADE_CONTRACT_SIZE), 2));
   Row(sym, "tick_size",        DoubleToString(SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE), digits));
   Row(sym, "tick_value",       DoubleToString(SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE), 5));
   Row(sym, "volume_min",       DoubleToString(SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN), 2));
   Row(sym, "volume_max",       DoubleToString(SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX), 2));
   Row(sym, "volume_step",      DoubleToString(SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP), 2));
   Row(sym, "stops_level_pts",  IntegerToString(SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL)));
   Row(sym, "freeze_level_pts", IntegerToString(SymbolInfoInteger(sym, SYMBOL_TRADE_FREEZE_LEVEL)));
   Row(sym, "spread_float",     SymbolInfoInteger(sym, SYMBOL_SPREAD_FLOAT) != 0 ? "true" : "false");
   Row(sym, "spread_now_pts",   IntegerToString(SymbolInfoInteger(sym, SYMBOL_SPREAD)));
   Row(sym, "swap_mode",        EnumToString((ENUM_SYMBOL_SWAP_MODE)SymbolInfoInteger(sym, SYMBOL_SWAP_MODE)));
   Row(sym, "swap_long",        DoubleToString(SymbolInfoDouble(sym, SYMBOL_SWAP_LONG), 2));
   Row(sym, "swap_short",       DoubleToString(SymbolInfoDouble(sym, SYMBOL_SWAP_SHORT), 2));
   Row(sym, "currency_profit",  SymbolInfoString(sym, SYMBOL_CURRENCY_PROFIT));
   Row(sym, "currency_margin",  SymbolInfoString(sym, SYMBOL_CURRENCY_MARGIN));

   //--- ขาดทุนต่อ 1 lot เมื่อราคาวิ่งสวน 1.00 — ใช้ตรวจสูตรคำนวณ lot ของ RiskManager
   double ask    = SymbolInfoDouble(sym, SYMBOL_ASK);
   double pl     = 0.0;
   double margin = 0.0;
   if(ask > 0.0 && OrderCalcProfit(ORDER_TYPE_BUY, sym, 1.0, ask, ask - 1.0, pl))
      Row(sym, "pl_per_lot_per_1.00_move", DoubleToString(pl, 2));
   else
      Row(sym, "pl_per_lot_per_1.00_move", "n/a (market closed?)");
   if(ask > 0.0 && OrderCalcMargin(ORDER_TYPE_BUY, sym, 1.0, ask, margin))
      Row(sym, "margin_per_lot", DoubleToString(margin, 2));
   else
      Row(sym, "margin_per_lot", "n/a (market closed?)");

   //--- ความลึกของ history บน server (สำคัญกับ Phase 3)
   long first_m1 = SeriesInfoInteger(sym, PERIOD_M1, SERIES_SERVER_FIRSTDATE);
   Row(sym, "server_first_m1_bar", first_m1 > 0 ? TimeToString((datetime)first_m1, TIME_DATE) : "n/a");

   DumpSpreadStats(sym);
   return(true);
  }

//+------------------------------------------------------------------+
void OnStart()
  {
   string fname = "SmartEA\\specs_" + SafeName(AccountInfoString(ACCOUNT_SERVER)) + ".tsv";
   g_file = FileOpen(fname, FILE_WRITE | FILE_CSV | FILE_ANSI, '\t');
   if(g_file == INVALID_HANDLE)
      PrintFormat("FileOpen(%s) failed, err=%d - log only", fname, GetLastError());
   else
      FileWrite(g_file, "scope", "key", "value");

   Row("META", "generated_local", TimeToString(TimeLocal(), TIME_DATE | TIME_SECONDS));
   DumpAccount();

   string src = (InpSymbols == "") ? _Symbol : InpSymbols;
   string list[];
   int n = StringSplit(src, ',', list);
   for(int i = 0; i < n; i++)
     {
      string sym = list[i];
      StringTrimLeft(sym);
      StringTrimRight(sym);
      if(sym != "")
         DumpSymbol(sym);
     }

   if(g_file != INVALID_HANDLE)
     {
      FileClose(g_file);
      PrintFormat("Saved: MQL5\\Files\\%s", fname);
     }
  }
//+------------------------------------------------------------------+
