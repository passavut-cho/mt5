//+------------------------------------------------------------------+
//|                                              SmartEA_EMAPair.mq5 |
//|  แสดง EMA fast/slow บน chart คนละสี — display only              |
//|  EA ห้ามใช้ค่าจาก indicator นี้ตัดสินใจเทรด (ใช้ iMA ของ signal)   |
//+------------------------------------------------------------------+
#property copyright "Phas"
#property version   "1.00"
#property description "EMA fast (น้ำเงิน) / EMA slow (ส้ม) สำหรับ visual tester"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

#property indicator_label1  "EMA fast"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#property indicator_label2  "EMA slow"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrange
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

input int InpFastPeriod = 9;    // EMA fast period
input int InpSlowPeriod = 21;   // EMA slow period

double g_fast[];
double g_slow[];

//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpFastPeriod < 1 || InpSlowPeriod <= InpFastPeriod)
      return(INIT_PARAMETERS_INCORRECT);
   SetIndexBuffer(0, g_fast, INDICATOR_DATA);
   SetIndexBuffer(1, g_slow, INDICATOR_DATA);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| EMA ของ close: ค่าแรก = close[0] แล้ว ema = prev + k*(close-prev)   |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[], const double &high[],
                const double &low[], const double &close[], const long &tick_volume[],
                const long &volume[], const int &spread[])
  {
   if(rates_total < 1)
      return(0);

   const double k_fast = 2.0 / (InpFastPeriod + 1.0);
   const double k_slow = 2.0 / (InpSlowPeriod + 1.0);

   int start = prev_calculated - 1;
   if(start < 1)
     {
      g_fast[0] = close[0];
      g_slow[0] = close[0];
      start = 1;
     }
   for(int i = start; i < rates_total; i++)
     {
      g_fast[i] = g_fast[i - 1] + k_fast * (close[i] - g_fast[i - 1]);
      g_slow[i] = g_slow[i - 1] + k_slow * (close[i] - g_slow[i - 1]);
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
