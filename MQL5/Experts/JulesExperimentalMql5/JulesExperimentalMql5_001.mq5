//+------------------------------------------------------------------+
//|                                     JulesExperimentalMql5.mq5 |
//|                      Copyright 2024, Your Name (Jules)           |
//|                                      https://www.example.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Your Name (Jules)"
#property link      "https://www.example.com"
#property version   "2.00"
#property description "An experimental EA for gold trading, using multi-timeframe trend analysis and robust, fractal-based RSI divergence."

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
input string InpDayFilter     = "Mon,Tue,Wed,Thu,Fri"; // Trading days filter (not yet implemented)
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
bool            isTimeframeOk = false;
string          gEaName = "JulesExperimentalMql5";
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
int  GetOverallTrend();
bool CheckBullishDivergence();
bool CheckBearishDivergence();
void ExecuteTrade(int trend_direction);
void ClosePositionsOnNewBar();
double CalculateLotSize(double sl_distance_points);

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
      // Update display first to ensure the error message is visible on the chart
      UpdateDisplay();
      Print(gEaName, ": Initialization failed. The symbol '", _Symbol, "' is not a valid gold pair. Please use on a chart like XAUUSD or GOLD.");
      return(INIT_FAILED);
     }

   isTimeframeOk = CheckTimeframe();
   if(!isTimeframeOk)
     {
      // Update display first to ensure the error message is visible on the chart
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
   IndicatorRelease(fractals_handle);
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
   //--- We only check for trades if we have a clear trend and no open positions
   if(PositionsTotal() == 0)
     {
      //--- In a confirmed uptrend, look for a bullish divergence to enter long
      if(gOverallTrend == 1)
        {
         if(CheckBullishDivergence())
           {
            ExecuteTrade(gOverallTrend);
           }
        }
      //--- In a confirmed downtrend, look for a bearish divergence to enter short
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
//| Update the on-screen display                                     |
//+------------------------------------------------------------------+
void UpdateDisplay()
  {
   string displayString = "EA Name: " + gEaName + "\n";

   //--- Display Symbol Info
   if(isSymbolOk)
      displayString += "Pair: " + _Symbol + "\n";
   else
      displayString += "Error: Gold Pair Only (e.g., XAUUSD, GOLD)\n";

   //--- Display Timeframe Info
   if(isTimeframeOk)
      displayString += "ChartTimeFrame: " + EnumToString(_Period) + " (" + EnumToString(g_tf2) + ", " + EnumToString(g_tf3) + ")\n";
   else
      displayString += "Error: TimeFrames M15, M30, H1 only\n";

   //--- Display Trend Info
   string trend_status = "Calculating...";
   if(gOverallTrend == 1) trend_status = "UP";
   else if(gOverallTrend == -1) trend_status = "DOWN";
   else trend_status = "NO CONSENSUS";
   displayString += "Overall Trend: " + trend_status + "\n";

   //--- Display Target Info
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

   //--- Check spread filter
   double spread = (latest_tick.ask - latest_tick.bid) / _Point;
   if(spread > InpMaxSpread)
     {
      Print("Spread is too high (", spread, "). Trade aborted.");
      return;
     }

   //--- Determine TP/SL distances in price points
   double tp_distance_points = InpAdaptParameters ? gAdaptedTakeProfit : InpTakeProfit * _Point;
   double sl_distance_points = tp_distance_points * InpStopLossRatio;

   //--- Calculate Lot Size
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

   //--- Determine trade type and prices
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

   //--- Execute trade
   string comment = gEaName + " " + TimeToString(TimeCurrent());
   trade.PositionOpen(_Symbol, trade_type, lot_size, entry_price, sl_price, tp_price, comment);
   if(trade.ResultRetcode() != TRADE_RETCODE_DONE)
     {
      Print("Trade execution failed. Error: ", trade.ResultRetcode(), " - ", trade.ResultComment());
     }
   else
     {
      Print("Trade executed successfully. Order #", trade.ResultOrder(), " Lot Size: ", lot_size);
     }
  }
//+------------------------------------------------------------------+
//| Calculate Lot Size based on risk percentage and SL distance      |
//+------------------------------------------------------------------+
double CalculateLotSize(double sl_distance_points)
  {
   if(sl_distance_points <= 0)
     {
      Print("Cannot calculate lot size: Stop Loss distance is zero or negative.");
      return 0.0;
     }

   //--- Account and symbol info
   double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   if(tick_value <= 0)
     {
      Print("Cannot calculate lot size: Tick value is zero or negative.");
      return 0.0;
     }

   //--- Risk calculation
   double risk_amount = account_balance * (InpRiskPercent / 100.0);
   double sl_value_per_lot = (sl_distance_points / tick_size) * tick_value;

   if(sl_value_per_lot <= 0)
     {
      Print("Cannot calculate lot size: Stop loss value per lot is zero or negative.");
      return 0.0;
     }

   double lot_size = risk_amount / sl_value_per_lot;

   //--- Normalize and validate lot size
   lot_size = floor(lot_size / lot_step) * lot_step;

   if(lot_size < min_lot)
      lot_size = min_lot;
   if(lot_size > max_lot)
      lot_size = max_lot;

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
//--- Timeframe 1 handles
   ema50_handle_tf1 = iMA(_Symbol, g_tf1, 50, 0, MODE_EMA, PRICE_CLOSE);
   ema200_handle_tf1 = iMA(_Symbol, g_tf1, 200, 0, MODE_EMA, PRICE_CLOSE);
   if(ema50_handle_tf1 == INVALID_HANDLE || ema200_handle_tf1 == INVALID_HANDLE) return false;
//--- Timeframe 2 handles
   ema50_handle_tf2 = iMA(_Symbol, g_tf2, 50, 0, MODE_EMA, PRICE_CLOSE);
   ema200_handle_tf2 = iMA(_Symbol, g_tf2, 200, 0, MODE_EMA, PRICE_CLOSE);
   if(ema50_handle_tf2 == INVALID_HANDLE || ema200_handle_tf2 == INVALID_HANDLE) return false;
//--- Timeframe 3 handles
   ema50_handle_tf3 = iMA(_Symbol, g_tf3, 50, 0, MODE_EMA, PRICE_CLOSE);
   ema200_handle_tf3 = iMA(_Symbol, g_tf3, 200, 0, MODE_EMA, PRICE_CLOSE);
   if(ema50_handle_tf3 == INVALID_HANDLE || ema200_handle_tf3 == INVALID_HANDLE) return false;

//--- RSI handle for base timeframe
   rsi_handle = iRSI(_Symbol, g_tf1, InpRsiPeriod, PRICE_CLOSE);
   if(rsi_handle == INVALID_HANDLE) return false;

//--- ATR handle for parameter adaptation
   atr_handle = iATR(_Symbol, PERIOD_D1, InpAtrPeriod);
   if(atr_handle == INVALID_HANDLE) return false;

//--- Fractals handle for divergence detection
   fractals_handle = iFractals(_Symbol, g_tf1);
   if(fractals_handle == INVALID_HANDLE) return false;

   Print("Indicator handles created successfully.");
   return true;
  }
//+------------------------------------------------------------------+
//| Adapts TP based on recent average volatility (ATR)               |
//+------------------------------------------------------------------+
void AdaptParameters()
  {
   gAdaptedTakeProfit = InpTakeProfit * _Point; // Default value in currency points

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

   //--- Let's set the TP to be 150% of the average daily ATR
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

//--- Copy data from indicators
   if(CopyBuffer(ema50_handle_tf1, 0, 0, 1, ema50_tf1) <= 0 || CopyBuffer(ema200_handle_tf1, 0, 0, 1, ema200_tf1) <= 0) return 0;
   if(CopyBuffer(ema50_handle_tf2, 0, 0, 1, ema50_tf2) <= 0 || CopyBuffer(ema200_handle_tf2, 0, 0, 1, ema200_tf2) <= 0) return 0;
   if(CopyBuffer(ema50_handle_tf3, 0, 0, 1, ema50_tf3) <= 0 || CopyBuffer(ema200_handle_tf3, 0, 0, 1, ema200_tf3) <= 0) return 0;

//--- Check trend condition on each timeframe
   bool trend1_up = ema50_tf1[0] > ema200_tf1[0];
   bool trend2_up = ema50_tf2[0] > ema200_tf2[0];
   bool trend3_up = ema50_tf3[0] > ema200_tf3[0];

   bool trend1_down = ema50_tf1[0] < ema200_tf1[0];
   bool trend2_down = ema50_tf2[0] < ema200_tf2[0];
   bool trend3_down = ema50_tf3[0] < ema200_tf3[0];

//--- Check for trend consensus
   if(trend1_up && trend2_up && trend3_up) return 1; // Uptrend
   if(trend1_down && trend2_down && trend3_down) return -1; // Downtrend

   return 0; // No consensus or mixed signals
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
//--- Do nothing if the feature is disabled
   if(!InpCloseOnBarEnd)
      return;

//--- Check for a new bar
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime > g_lastBarTime)
     {
      //--- If a new bar is detected, store its time
      g_lastBarTime = currentBarTime;

      //--- Close all positions for this EA instance
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
//| Check for bullish RSI divergence using Fractals                      |
//+------------------------------------------------------------------+
bool CheckBullishDivergence()
  {
   //--- Buffers for indicator data
   double rsi_buffer[];
   double fractal_buffer[];
   double low_buffer[];

   //--- Copy data
   int bars_to_copy = InpDivergenceLookback;
   if(CopyBuffer(rsi_handle, 0, 0, bars_to_copy, rsi_buffer) < bars_to_copy) return false;
   if(CopyBuffer(fractals_handle, 1, 0, bars_to_copy, fractal_buffer) < bars_to_copy) return false; // Lower fractals
   if(CopyLow(_Symbol, g_tf1, 0, bars_to_copy, low_buffer) < bars_to_copy) return false;

   //--- Find the two most recent lower fractals
   int low2_idx = -1, low1_idx = -1;

   //--- Find the most recent fractal (low 2), starting from bar 3 to avoid current forming fractal
   for(int i = 3; i < bars_to_copy; i++)
     {
      if(fractal_buffer[i] != 0)
        {
         low2_idx = i;
         break;
        }
     }
   if(low2_idx == -1) return false; // No recent fractal found

   //--- Find the fractal before that (low 1)
   for(int i = low2_idx + 1; i < bars_to_copy; i++)
     {
      if(fractal_buffer[i] != 0)
        {
         low1_idx = i;
         break;
        }
     }
   if(low1_idx == -1) return false; // Only one fractal found in lookback period

   //--- Now check the conditions for bullish divergence
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
   //--- Buffers for indicator data
   double rsi_buffer[];
   double fractal_buffer[];
   double high_buffer[];

   //--- Copy data
   int bars_to_copy = InpDivergenceLookback;
   if(CopyBuffer(rsi_handle, 0, 0, bars_to_copy, rsi_buffer) < bars_to_copy) return false;
   if(CopyBuffer(fractals_handle, 0, 0, bars_to_copy, fractal_buffer) < bars_to_copy) return false; // Upper fractals
   if(CopyHigh(_Symbol, g_tf1, 0, bars_to_copy, high_buffer) < bars_to_copy) return false;

   //--- Find the two most recent upper fractals
   int high2_idx = -1, high1_idx = -1;

   //--- Find the most recent fractal (high 2)
   for(int i = 3; i < bars_to_copy; i++)
     {
      if(fractal_buffer[i] != 0)
        {
         high2_idx = i;
         break;
        }
     }
   if(high2_idx == -1) return false;

   //--- Find the fractal before that (high 1)
   for(int i = high2_idx + 1; i < bars_to_copy; i++)
     {
      if(fractal_buffer[i] != 0)
        {
         high1_idx = i;
         break;
        }
     }
   if(high1_idx == -1) return false;

   //--- Now check the conditions for bearish divergence
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
   if(tf == PERIOD_M15 || tf == PERIOD_M30 || tf == PERIOD_H1)
      return true;

   return false;
  }
//+------------------------------------------------------------------+
