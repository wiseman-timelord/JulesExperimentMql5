//+------------------------------------------------------------------+
//|                                     JulesExperimentalMql5.mq5 |
//|                      Copyright 2024, Your Name (Jules)           |
//|                                      https://www.example.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Your Name (Jules)"
#property link      "https://www.example.com"
#property version   "1.10"
#property description "An experimental EA for gold trading. v1.1 has improved init logging and Close on Bar End feature."

#include <Trade/Trade.mqh>

//--- EA Input Parameters
input ulong  InpMagicNumber = 1337;      // Magic Number
input double InpLotSize     = 0.01;       // Fixed Lot Size
input int    InpMaxSpread   = 50;         // Maximum allowed spread in points
input int    InpTakeProfit  = 1000;       // Take Profit in points
input double InpStopLossRatio = 2.0;      // Stop Loss ratio to Take Profit
input bool   InpCloseOnBarEnd = false;    // Close any open trade at the end of the bar
//--- Indicator Settings
input int    InpRsiPeriod   = 14;         // RSI Period
input int    InpDivergenceLookback = 50;  // Lookback bars for divergence
//--- Parameter Adaptation Settings
input bool   InpAdaptParameters    = true;       // Adapt TP/SL to volatility?
input int    InpAtrPeriod          = 14;         // ATR Period for adaptation
input int    InpAtrHistoryDays     = 30;         // Days of history for ATR analysis


//--- Global variables
CTrade          trade;
bool            isSymbolOk = false;
bool            isTimeframeOk = false;
string          gEaName = "JulesExperimentalMql5";
int             gOverallTrend = 0; // 1 for UP, -1 for DOWN, 0 for NONE

//--- Indicator Handles
int    ema50_handle_tf1, ema200_handle_tf1;
int    ema50_handle_tf2, ema200_handle_tf2;
int    ema50_handle_tf3, ema200_handle_tf3;
int    rsi_handle;
int    atr_handle;

//--- Adapted Parameters
double gAdaptedTakeProfit = 0;

//--- Time-based variables
datetime g_lastBarTime = 0;

//--- Multi-Timeframe settings
ENUM_TIMEFRAMES g_tf1, g_tf2, g_tf3;

//--- Forward declarations
void UpdateDisplay();
bool CheckSymbol();
bool CheckTimeframe();
bool SetTimeframes();
bool CreateIndicatorHandles();
void AdaptParameters();
int  GetOverallTrend();
bool CheckDivergence(int trend_direction);
void ExecuteTrade(int trend_direction);
void ClosePositionsOnNewBar();

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Initialize the trade object
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10); // Slippage
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   trade.SetAsyncMode(false);

//--- Print initialization message
   Print(gEaName, " Initializing...");

//--- Perform validation checks
   isSymbolOk = CheckSymbol();
   if(!isSymbolOk)
     {
      UpdateDisplay();
      Print(gEaName, ": Initialization failed. The symbol '", _Symbol, "' is not a valid gold pair. Please use on a chart like XAUUSD or GOLD.");
      return(INIT_FAILED);
     }

   isTimeframeOk = CheckTimeframe();
   if(!isTimeframeOk)
     {
      UpdateDisplay();
      Print(gEaName, ": Initialization failed. The timeframe '", EnumToString(_Period), "' is not supported. Please use M15, M30, or H1.");
      return(INIT_FAILED);
     }

//--- Set up multi-timeframe analysis
   if(!SetTimeframes())
     {
      Print("Failed to set multi-timeframes.");
      return(INIT_FAILED);
     }
   if(!CreateIndicatorHandles())
     {
      Print("Failed to create indicator handles.");
      return(INIT_FAILED);
     }

//--- Adapt parameters based on volatility
   AdaptParameters();

   UpdateDisplay();
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Print deinitialization message
   Print(gEaName, " Deinitialized. Reason: ", reason);
//--- Clean up the chart display
   Comment("");
//--- Release indicator handles
   IndicatorRelease(ema50_handle_tf1);
   IndicatorRelease(ema200_handle_tf1);
   IndicatorRelease(ema50_handle_tf2);
   IndicatorRelease(ema200_handle_tf2);
   IndicatorRelease(ema50_handle_tf3);
   IndicatorRelease(ema200_handle_tf3);
   IndicatorRelease(rsi_handle);
   IndicatorRelease(atr_handle);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- Handle per-bar logic first
   ClosePositionsOnNewBar();

//--- Get the latest overall trend
   gOverallTrend = GetOverallTrend();

//--- Update the display on each tick
   UpdateDisplay();

//--- Core trading logic
   if(gOverallTrend != 0 && PositionsTotal() == 0)
     {
      bool divergence_found = CheckDivergence(gOverallTrend);
      if(divergence_found)
        {
         ExecuteTrade(gOverallTrend);
        }
     }
  }
//+------------------------------------------------------------------+
//| Update the on-screen display                                     |
//+------------------------------------------------------------------+
void UpdateDisplay()
  {
   string displayString = "EA Name: " + gEaName + "\n";

   if(isSymbolOk)
      displayString += "Pair: " + _Symbol + "\n";
   else
      displayString += "Error: Gold Pair Only (e.g., XAUUSD, GOLD)\n";

   if(isTimeframeOk)
      displayString += "ChartTimeFrame: " + EnumToString(_Period) + " (" + EnumToString(g_tf2) + ", " + EnumToString(g_tf3) + ")\n";
   else
      displayString += "Error: TimeFrames M15, M30, H1 only\n";

   string trend_status = "Calculating...";
   if(gOverallTrend == 1) trend_status = "UP";
   else if(gOverallTrend == -1) trend_status = "DOWN";
   else trend_status = "NO CONSENSUS";
   displayString += "Overall Trend: " + trend_status + "\n";

   double tp_dist = InpAdaptParameters ? gAdaptedTakeProfit : InpTakeProfit * _Point;
   double sl_dist = tp_dist * InpStopLossRatio;
   displayString += "Target TP: " + DoubleToString(tp_dist / _Point, 0) + " points\n";
   displayString += "Target SL: " + DoubleToString(sl_dist / _Point, 0) + " points\n";

   Comment(displayString);
  }
//+------------------------------------------------------------------+
//| Execute a trade based on the trend direction                     |
//+------------------------------------------------------------------+
void ExecuteTrade(int trend_direction)
  {
   MqlTick latest_tick;
   if(!SymbolInfoTick(_Symbol, latest_tick))
     {
      Print("Could not get latest tick data. Trade aborted.");
      return;
     }

   double spread = (latest_tick.ask - latest_tick.bid) / _Point;
   if(spread > InpMaxSpread)
     {
      Print("Spread is too high (", spread, "). Trade aborted.");
      return;
     }

   double tp_distance_points = InpAdaptParameters ? gAdaptedTakeProfit : InpTakeProfit * _Point;
   double sl_distance_points = tp_distance_points * InpStopLossRatio;

   ENUM_ORDER_TYPE trade_type;
   double entry_price = 0;
   double tp_price = 0;
   double sl_price = 0;

   if(trend_direction == 1) // Buy
     {
      trade_type = ORDER_TYPE_BUY;
      entry_price = latest_tick.ask;
      tp_price = entry_price + tp_distance_points;
      sl_price = entry_price - sl_distance_points;
     }
   else // Sell
     {
      trade_type = ORDER_TYPE_SELL;
      entry_price = latest_tick.bid;
      tp_price = entry_price - tp_distance_points;
      sl_price = entry_price + sl_distance_points;
     }

   string comment = gEaName + " " + TimeToString(TimeCurrent());
   trade.PositionOpen(_Symbol, trade_type, InpLotSize, entry_price, sl_price, tp_price, comment);
   if(trade.ResultRetcode() != TRADE_RETCODE_DONE)
     {
      Print("Trade execution failed. Error: ", trade.ResultRetcode(), " - ", trade.ResultComment());
     }
   else
     {
      Print("Trade executed successfully. Order #", trade.ResultOrder());
     }
  }
//+------------------------------------------------------------------+
//| Set the higher timeframes based on the chart's period            |
//+------------------------------------------------------------------+
bool SetTimeframes()
  {
   g_tf1 = _Period;
   switch(g_tf1)
     {
      case PERIOD_M15:
         g_tf2 = PERIOD_M30;
         g_tf3 = PERIOD_H1;
         break;
      case PERIOD_M30:
         g_tf2 = PERIOD_H1;
         g_tf3 = PERIOD_H4;
         break;
      case PERIOD_H1:
         g_tf2 = PERIOD_H4;
         g_tf3 = PERIOD_D1;
         break;
      default:
         return false; // Should not happen due to initial check
     }
   Print("Timeframes set: ", EnumToString(g_tf1), ", ", EnumToString(g_tf2), ", ", EnumToString(g_tf3));
   return true;
  }
//+------------------------------------------------------------------+
//| Create all necessary indicator handles                           |
//+------------------------------------------------------------------+
bool CreateIndicatorHandles()
  {
   ema50_handle_tf1 = iMA(_Symbol, g_tf1, 50, 0, MODE_EMA, PRICE_CLOSE);
   ema200_handle_tf1 = iMA(_Symbol, g_tf1, 200, 0, MODE_EMA, PRICE_CLOSE);
   if(ema50_handle_tf1 == INVALID_HANDLE || ema200_handle_tf1 == INVALID_HANDLE) return false;
   ema50_handle_tf2 = iMA(_Symbol, g_tf2, 50, 0, MODE_EMA, PRICE_CLOSE);
   ema200_handle_tf2 = iMA(_Symbol, g_tf2, 200, 0, MODE_EMA, PRICE_CLOSE);
   if(ema50_handle_tf2 == INVALID_HANDLE || ema200_handle_tf2 == INVALID_HANDLE) return false;
   ema50_handle_tf3 = iMA(_Symbol, g_tf3, 50, 0, MODE_EMA, PRICE_CLOSE);
   ema200_handle_tf3 = iMA(_Symbol, g_tf3, 200, 0, MODE_EMA, PRICE_CLOSE);
   if(ema50_handle_tf3 == INVALID_HANDLE || ema200_handle_tf3 == INVALID_HANDLE) return false;

   rsi_handle = iRSI(_Symbol, g_tf1, InpRsiPeriod, PRICE_CLOSE);
   if(rsi_handle == INVALID_HANDLE) return false;

   atr_handle = iATR(_Symbol, PERIOD_D1, InpAtrPeriod);
   if(atr_handle == INVALID_HANDLE) return false;

   Print("Indicator handles created successfully.");
   return true;
  }
//+------------------------------------------------------------------+
//| Adapts TP based on recent average volatility (ATR)               |
//+------------------------------------------------------------------+
void AdaptParameters()
  {
   gAdaptedTakeProfit = InpTakeProfit * _Point;

   if(!InpAdaptParameters)
     {
      Print("Parameter adaptation is disabled by user.");
      return;
     }

   double atr_buffer[];
   if(CopyBuffer(atr_handle, 0, 1, InpAtrHistoryDays, atr_buffer) < InpAtrHistoryDays)
     {
      Print("Could not copy enough ATR history (", InpAtrHistoryDays, " days). Using default TP.");
      return;
     }

   double sum = 0;
   for(int i = 0; i < InpAtrHistoryDays; i++)
     {
      sum += atr_buffer[i];
     }
   double average_atr = sum / InpAtrHistoryDays;

   gAdaptedTakeProfit = average_atr * 1.5;

   Print("Parameter Adaptation Complete. Average ATR(", InpAtrPeriod, ") over last ", InpAtrHistoryDays, " days: ", NormalizeDouble(average_atr, _Digits));
   Print("Adapted Take Profit set to: ", NormalizeDouble(gAdaptedTakeProfit, _Digits), " (", gAdaptedTakeProfit / _Point, " points)");
  }
//+------------------------------------------------------------------+
//| Determine the overall trend based on 3 timeframes                |
//+------------------------------------------------------------------+
int GetOverallTrend()
  {
   double ema50_tf1[1], ema200_tf1[1];
   double ema50_tf2[1], ema200_tf2[1];
   double ema50_tf3[1], ema200_tf3[1];

   if(CopyBuffer(ema50_handle_tf1, 0, 0, 1, ema50_tf1) <= 0 || CopyBuffer(ema200_handle_tf1, 0, 0, 1, ema200_tf1) <= 0) return 0;
   if(CopyBuffer(ema50_handle_tf2, 0, 0, 1, ema50_tf2) <= 0 || CopyBuffer(ema200_handle_tf2, 0, 0, 1, ema200_tf2) <= 0) return 0;
   if(CopyBuffer(ema50_handle_tf3, 0, 0, 1, ema50_tf3) <= 0 || CopyBuffer(ema200_handle_tf3, 0, 0, 1, ema200_tf3) <= 0) return 0;

   bool trend1_up = ema50_tf1[0] > ema200_tf1[0];
   bool trend2_up = ema50_tf2[0] > ema200_tf2[0];
   bool trend3_up = ema50_tf3[0] > ema200_tf3[0];

   bool trend1_down = ema50_tf1[0] < ema200_tf1[0];
   bool trend2_down = ema50_tf2[0] < ema200_tf2[0];
   bool trend3_down = ema50_tf3[0] < ema200_tf3[0];

   if(trend1_up && trend2_up && trend3_up) return 1;
   if(trend1_down && trend2_down && trend3_down) return -1;

   return 0;
  }
//+------------------------------------------------------------------+
//| Check if the symbol is a valid gold pair                         |
//+------------------------------------------------------------------+
bool CheckSymbol()
  {
   string symbol = _Symbol;
   StringToUpper(symbol);

   if(StringFind(symbol, "XAU") != -1 || StringFind(symbol, "GOLD") != -1)
      return true;

   return false;
  }
//+------------------------------------------------------------------+
//| Checks for a new bar and closes positions if the setting is on   |
//+------------------------------------------------------------------+
void ClosePositionsOnNewBar()
  {
   if(!InpCloseOnBarEnd)
      return;

   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime > g_lastBarTime)
     {
      g_lastBarTime = currentBarTime;

      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
           {
            if(!trade.PositionClose(ticket))
              {
               Print("Failed to close position #", ticket, ". Error: ", trade.ResultRetcode());
              }
            else
              {
               Print("Position #", ticket, " closed on new bar.");
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
//| Check for RSI divergence in the direction of the trend           |
//+------------------------------------------------------------------+
bool CheckDivergence(int trend_direction)
  {
   double rsi_buffer[];
   double high_buffer[];
   double low_buffer[];

   int bars_to_copy = InpDivergenceLookback + 5;
   if(CopyBuffer(rsi_handle, 0, 0, bars_to_copy, rsi_buffer) < bars_to_copy) return false;
   if(CopyHigh(_Symbol, g_tf1, 0, bars_to_copy, high_buffer) < bars_to_copy) return false;
   if(CopyLow(_Symbol, g_tf1, 0, bars_to_copy, low_buffer) < bars_to_copy) return false;

   ArraySetAsSeries(rsi_buffer, true);
   ArraySetAsSeries(high_buffer, true);
   ArraySetAsSeries(low_buffer, true);

   if(trend_direction == 1)
     {
      int low2_idx = -1;
      double low2_price = 999999;
      for(int i = 1; i < 10; i++)
        {
         if(low_buffer[i] < low2_price)
           {
            low2_price = low_buffer[i];
            low2_idx = i;
           }
        }
      if(low2_idx == -1) return false;

      int low1_idx = -1;
      double low1_price = 999999;
      for(int i = low2_idx + 3; i < InpDivergenceLookback; i++)
        {
         if(low_buffer[i] < low1_price)
           {
            low1_price = low_buffer[i];
            low1_idx = i;
           }
        }
      if(low1_idx == -1) return false;

      bool price_lower_low = low2_price < low1_price;
      bool rsi_higher_low = rsi_buffer[low2_idx] > rsi_buffer[low1_idx];

      if(price_lower_low && rsi_higher_low)
        {
         Print("Bullish Divergence Detected: Price Lows at bar ", low1_idx, "(",low1_price,") and bar ",low2_idx,"(",low2_price,"). RSI Lows: ", rsi_buffer[low1_idx], " and ", rsi_buffer[low2_idx]);
         return true;
        }
     }
   else if(trend_direction == -1)
     {
      int high2_idx = -1;
      double high2_price = 0;
      for(int i = 1; i < 10; i++)
        {
         if(high_buffer[i] > high2_price)
           {
            high2_price = high_buffer[i];
            high2_idx = i;
           }
        }
      if(high2_idx == -1) return false;

      int high1_idx = -1;
      double high1_price = 0;
      for(int i = high2_idx + 3; i < InpDivergenceLookback; i++)
        {
         if(high_buffer[i] > high1_price)
           {
            high1_price = high_buffer[i];
            high1_idx = i;
           }
        }
      if(high1_idx == -1) return false;

      bool price_higher_high = high2_price > high1_price;
      bool rsi_lower_high = rsi_buffer[high2_idx] < rsi_buffer[high1_idx];

      if(price_higher_high && rsi_lower_high)
        {
         Print("Bearish Divergence Detected: Price Highs at bar ", high1_idx, "(",high1_price,") and bar ",high2_idx,"(",high2_price,"). RSI Highs: ", rsi_buffer[high1_idx], " and ", rsi_buffer[high2_idx]);
         return true;
        }
     }

   return false;
  }
//+------------------------------------------------------------------+
//| Check if the timeframe is one of the allowed ones                |
//+------------------------------------------------------------------+
bool CheckTimeframe()
  {
   ENUM_TIMEFRAMES tf = _Period;
   return (tf == PERIOD_M15 || tf == PERIOD_M30 || tf == PERIOD_H1);
  }
//+------------------------------------------------------------------+
