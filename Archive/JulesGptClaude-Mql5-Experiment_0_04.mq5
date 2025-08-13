//+------------------------------------------------------------------+
//|                                     JulesExperimentalMql5_002.mq5 |
//|                      Copyright 2024, Your Name (Jules)           |
//|                                      https://www.example.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Your Name (Jules)"
#property link      "https://www.example.com"
#property version   "2.10"
#property description "An experimental EA for gold trading. v2.1 includes a day filter and on-bar calculation optimizations."

#include <Trade/Trade.mqh>

//--- EA Input Parameters
input ulong  InpMagicNumber = 1337;      // Magic Number
input double InpLotSize     = 0.01;       // Fixed Lot Size (if not using % risk)
input int    InpMaxSpread   = 50;         // Maximum allowed spread in points (20-100)
input int    InpTakeProfit  = 1000;       // Take Profit in points (if adaptation is off) (500-5000)
input double InpStopLossRatio = 1.5;      // Stop Loss ratio to Take Profit (1.0-3.0)
input bool   InpCloseOnBarEnd = false;    // Close any open trade at the end of the bar
//--- Risk Management
input bool   InpUseRiskPercent = true;    // Use % of balance for lot size?
input double InpRiskPercent    = 1.0;     // Percent of balance to risk per trade (0.5-5.0)
//--- Day Filter
enum Custom_Dayfilter_Config
  {
   FULL_WEEK,     // Monday to Friday
   MON_TUE,       // Monday, Tuesday
   TUE_THUR,      // Tuesday, Wednesday, Thursday
   MON_FRI,       // Monday, Friday
   THU_FRI,       // Thursday, Friday
   TUE_THU_FRI,   // Tuesday, Thursday, Friday
   MON_TUE_WED,   // Monday, Tuesday, Wednesday
   WED_THU_FRI,   // Wednesday, Thursday, Friday
   NOT_MON,       // Not Monday (Tue-Fri)
   NOT_WED,       // Not Wednesday (Mon,Tue,Thu,Fri)
   NOT_FRI        // Not Friday (Mon-Thu)
  };
input Custom_Dayfilter_Config InpDayFilter = FULL_WEEK; // Day filter configuration
//--- Indicator Settings
input int    InpRsiPeriod   = 14;         // RSI Period (7-25)
input int    InpDivergenceLookback = 50;  // Lookback bars for divergence (30-100)
input int    InpRsiOverbought = 70;       // RSI level for bearish divergence
input int    InpRsiOversold   = 30;       // RSI level for bullish divergence
//--- Parameter Adaptation Settings
input bool   InpAdaptParameters    = true;       // Adapt TP/SL to volatility?
input int    InpAtrPeriod          = 14;         // ATR Period for adaptation (7-28)
input int    InpAtrHistoryDays     = 30;         // Days of history for ATR analysis (20-60)


//--- Global variables
CTrade          trade;
bool            isSymbolOk = false;
//bool            isTimeframeOk = false; // This is now validated directly in OnInit
string          gEaName = "JulesExperimentalMql5_v3";
int             gOverallTrend = 0; // 1 for UP, -1 for DOWN, 0 for NONE

//--- Indicator Handles
int    ema50_handle_tf1, ema200_handle_tf1;
int    ema50_handle_tf2, ema200_handle_tf2;
int    ema50_handle_tf3, ema200_handle_tf3;
int    rsi_handle;
int    atr_handle;
int    fractals_handle;

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
void OnNewBar();
int  GetOverallTrend();
bool CheckBullishDivergence();
bool CheckBearishDivergence();
void ExecuteTrade(int trend_direction);
double CalculateLotSize(double sl_distance_points);
bool IsTradingDayAllowed();

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

   if(!CheckTimeframe()) // Validation is now direct
     {
      Print(gEaName, ": Initialization failed. The selected timeframe '", EnumToString(_Period), "' is not supported by this EA's logic.");
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
   Print(gEaName, " Deinitialized. Reason: ", reason);
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
   IndicatorRelease(fractals_handle);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- Check for a new bar and run maintenance
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime > g_lastBarTime)
     {
      g_lastBarTime = currentBarTime;
      OnNewBar();
     }

//--- Core per-tick trading logic
   if(IsTradingDayAllowed() && PositionsTotal() == 0)
     {
      if(gOverallTrend == 1)
        {
         if(CheckBullishDivergence())
           {
            ExecuteTrade(gOverallTrend);
           }
        }
      else if(gOverallTrend == -1)
        {
         if(CheckBearishDivergence())
           {
            ExecuteTrade(gOverallTrend);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Performs all calculations that only need to run once per bar     |
//+------------------------------------------------------------------+
void OnNewBar()
  {
//--- Close positions if "Close on Bar End" is enabled
   if(InpCloseOnBarEnd)
     {
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

//--- Recalculate the overall trend
   gOverallTrend = GetOverallTrend();

//--- Update the display
   UpdateDisplay();
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

   double lot_size = InpLotSize;
   if(InpUseRiskPercent)
     {
      lot_size = CalculateLotSize(sl_distance_points);
     }
   if(lot_size <= 0)
     {
      Print("Lot size calculation failed. Lot size is zero or negative. Trade aborted.");
      return;
     }

   ENUM_ORDER_TYPE trade_type;
   double entry_price, tp_price, sl_price;

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
   if(trade.PositionOpen(_Symbol, trade_type, lot_size, entry_price, sl_price, tp_price, comment))
     {
      Print("Trade Executed: ", (trend_direction == 1 ? "BUY" : "SELL"),
            " Lot:", lot_size, " Entry:", entry_price, " TP:", tp_price, " SL:", sl_price);
     }
   else
     {
      Print("Trade Failed. Error: ", trade.ResultRetcode(), " - ", trade.ResultComment());
     }
  }

//+------------------------------------------------------------------+
//| Calculate Lot Size based on risk percentage and SL distance      |
//+------------------------------------------------------------------+
double CalculateLotSize(double sl_distance_points)
  {
   if(sl_distance_points <= 0) return 0.0;

   double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   if(tick_value <= 0 || tick_size <= 0) return 0.0;

   double risk_amount = account_balance * (InpRiskPercent / 100.0);
   double sl_value_per_lot = (sl_distance_points / tick_size) * tick_value;

   if(sl_value_per_lot <= 0) return 0.0;

   double lot_size = risk_amount / sl_value_per_lot;

   lot_size = floor(lot_size / lot_step) * lot_step;

   if(lot_size < min_lot) lot_size = min_lot;
   if(lot_size > max_lot) lot_size = max_lot;

   return lot_size;
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
         return false;
     }
   Print("Timeframes: ", EnumToString(g_tf1), ", ", EnumToString(g_tf2), ", ", EnumToString(g_tf3));
   return true;
  }

//+------------------------------------------------------------------+
//| Create all necessary indicator handles                           |
//+------------------------------------------------------------------+
bool CreateIndicatorHandles()
  {
   ema50_handle_tf1 = iMA(_Symbol, g_tf1, 50, 0, MODE_EMA, PRICE_CLOSE);
   ema200_handle_tf1 = iMA(_Symbol, g_tf1, 200, 0, MODE_EMA, PRICE_CLOSE);
   ema50_handle_tf2 = iMA(_Symbol, g_tf2, 50, 0, MODE_EMA, PRICE_CLOSE);
   ema200_handle_tf2 = iMA(_Symbol, g_tf2, 200, 0, MODE_EMA, PRICE_CLOSE);
   ema50_handle_tf3 = iMA(_Symbol, g_tf3, 50, 0, MODE_EMA, PRICE_CLOSE);
   ema200_handle_tf3 = iMA(_Symbol, g_tf3, 200, 0, MODE_EMA, PRICE_CLOSE);

   if(ema50_handle_tf1 == INVALID_HANDLE || ema200_handle_tf1 == INVALID_HANDLE ||
      ema50_handle_tf2 == INVALID_HANDLE || ema200_handle_tf2 == INVALID_HANDLE ||
      ema50_handle_tf3 == INVALID_HANDLE || ema200_handle_tf3 == INVALID_HANDLE)
      return false;

   rsi_handle = iRSI(_Symbol, g_tf1, InpRsiPeriod, PRICE_CLOSE);
   atr_handle = iATR(_Symbol, PERIOD_D1, InpAtrPeriod);
   fractals_handle = iFractals(_Symbol, g_tf1);

   if(rsi_handle == INVALID_HANDLE || atr_handle == INVALID_HANDLE || fractals_handle == INVALID_HANDLE)
      return false;

   Print("All indicator handles created successfully.");
   return true;
  }

//+------------------------------------------------------------------+
//| Adapts TP based on recent average volatility (ATR)               |
//+------------------------------------------------------------------+
void AdaptParameters()
  {
   gAdaptedTakeProfit = InpTakeProfit * _Point;

   if(!InpAdaptParameters || atr_handle == INVALID_HANDLE)
     {
      return;
     }

   double atr_buffer[];
   if(CopyBuffer(atr_handle, 0, 1, InpAtrHistoryDays, atr_buffer) < InpAtrHistoryDays)
     {
      Print("Insufficient ATR history. Using default TP.");
      return;
     }

   double sum = 0;
   for(int i = 0; i < InpAtrHistoryDays; i++)
     {
      sum += atr_buffer[i];
     }
   double average_atr = sum / InpAtrHistoryDays;

   double timeframe_multiplier = 1.0;
   switch(_Period)
     {
      case PERIOD_M15: timeframe_multiplier = 0.3; break;
      case PERIOD_M30: timeframe_multiplier = 0.5; break;
      case PERIOD_H1:  timeframe_multiplier = 1.0; break;
      default: timeframe_multiplier = 1.0; break;
     }

   gAdaptedTakeProfit = average_atr * 1.5 * timeframe_multiplier;

   Print("ATR Adaptation: Avg ATR=", NormalizeDouble(average_atr, _Digits),
         " Adapted TP=", NormalizeDouble(gAdaptedTakeProfit, _Digits),
         " (", NormalizeDouble(gAdaptedTakeProfit/_Point, 0), " points)");
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

   return (StringFind(symbol, "XAU") != -1 || StringFind(symbol, "GOLD") != -1);
  }

//+------------------------------------------------------------------+
//| Checks if trading is allowed on the current day of the week      |
//+------------------------------------------------------------------+
bool IsTradingDayAllowed()
  {
   MqlDateTime current_time;
   TimeCurrent(current_time);
   int day_of_week = current_time.day_of_week;

   switch(InpDayFilter)
     {
      case FULL_WEEK:      return (day_of_week >= 1 && day_of_week <= 5);
      case MON_TUE:        return (day_of_week == 1 || day_of_week == 2);
      case TUE_THUR:       return (day_of_week >= 2 && day_of_week <= 4);
      case MON_FRI:        return (day_of_week == 1 || day_of_week == 5);
      case THU_FRI:        return (day_of_week == 4 || day_of_week == 5);
      case TUE_THU_FRI:    return (day_of_week == 2 || day_of_week == 4 || day_of_week == 5);
      case MON_TUE_WED:    return (day_of_week >= 1 && day_of_week <= 3);
      case WED_THU_FRI:    return (day_of_week >= 3 && day_of_week <= 5);
      case NOT_MON:        return (day_of_week != 1 && day_of_week >= 2 && day_of_week <= 5);
      case NOT_WED:        return (day_of_week != 3 && day_of_week >= 1 && day_of_week <= 5);
      case NOT_FRI:        return (day_of_week != 5 && day_of_week >= 1 && day_of_week <= 4);
      default:             return true;
     }
  }

//+------------------------------------------------------------------+
//| Check for bullish RSI divergence using Fractals                      |
//+------------------------------------------------------------------+
bool CheckBullishDivergence()
  {
   double rsi_buffer[];
   double fractal_buffer[];
   double low_buffer[];

   int bars_to_copy = InpDivergenceLookback;
   if(CopyBuffer(rsi_handle, 0, 0, bars_to_copy, rsi_buffer) < bars_to_copy) return false;
   if(CopyBuffer(fractals_handle, 1, 0, bars_to_copy, fractal_buffer) < bars_to_copy) return false;
   if(CopyLow(_Symbol, g_tf1, 0, bars_to_copy, low_buffer) < bars_to_copy) return false;

   int low2_idx = -1, low1_idx = -1;

   for(int i = 3; i < bars_to_copy; i++)
     {
      if(fractal_buffer[i] != 0)
        {
         low2_idx = i;
         break;
        }
     }
   if(low2_idx == -1) return false;

   for(int i = low2_idx + 1; i < bars_to_copy; i++)
     {
      if(fractal_buffer[i] != 0)
        {
         low1_idx = i;
         break;
        }
     }
   if(low1_idx == -1) return false;

   bool price_lower_low = low_buffer[low2_idx] < low_buffer[low1_idx];
   bool rsi_higher_low = rsi_buffer[low2_idx] > rsi_buffer[low1_idx];
   bool rsi_is_oversold = rsi_buffer[low2_idx] < InpRsiOversold || rsi_buffer[low1_idx] < InpRsiOversold;

   if(price_lower_low && rsi_higher_low && rsi_is_oversold)
     {
      Print("Bullish Divergence Confirmed: Price(", DoubleToString(low_buffer[low1_idx]), " -> ", DoubleToString(low_buffer[low2_idx]), "), RSI(", DoubleToString(rsi_buffer[low1_idx]), " -> ", DoubleToString(rsi_buffer[low2_idx]), ")");
      return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//| Check for bearish RSI divergence using Fractals                     |
//+------------------------------------------------------------------+
bool CheckBearishDivergence()
  {
   double rsi_buffer[];
   double fractal_buffer[];
   double high_buffer[];

   int bars_to_copy = InpDivergenceLookback;
   if(CopyBuffer(rsi_handle, 0, 0, bars_to_copy, rsi_buffer) < bars_to_copy) return false;
   if(CopyBuffer(fractals_handle, 0, 0, bars_to_copy, fractal_buffer) < bars_to_copy) return false;
   if(CopyHigh(_Symbol, g_tf1, 0, bars_to_copy, high_buffer) < bars_to_copy) return false;

   int high2_idx = -1, high1_idx = -1;

   for(int i = 3; i < bars_to_copy; i++)
     {
      if(fractal_buffer[i] != 0)
        {
         high2_idx = i;
         break;
        }
     }
   if(high2_idx == -1) return false;

   for(int i = high2_idx + 1; i < bars_to_copy; i++)
     {
      if(fractal_buffer[i] != 0)
        {
         high1_idx = i;
         break;
        }
     }
   if(high1_idx == -1) return false;

   bool price_higher_high = high_buffer[high2_idx] > high_buffer[high1_idx];
   bool rsi_lower_high = rsi_buffer[high2_idx] < rsi_buffer[high1_idx];
   bool rsi_is_overbought = rsi_buffer[high2_idx] > InpRsiOverbought || rsi_buffer[high1_idx] > InpRsiOverbought;

   if(price_higher_high && rsi_lower_high && rsi_is_overbought)
     {
      Print("Bearish Divergence Confirmed: Price(", DoubleToString(high_buffer[high1_idx]), " -> ", DoubleToString(high_buffer[high2_idx]), "), RSI(", DoubleToString(rsi_buffer[high1_idx]), " -> ", DoubleToString(rsi_buffer[high2_idx]), ")");
      return true;
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
