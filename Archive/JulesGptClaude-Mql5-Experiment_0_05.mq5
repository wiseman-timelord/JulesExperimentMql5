//+------------------------------------------------------------------+
//|                                     JulesExperimentalMql5_003.mq5 |
//|                      Copyright 2024, Your Name (Jules)           |
//|                                      https://www.example.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Your Name (Jules)"
#property link      "https://www.example.com"
#property version   "3.00"
#property description "Fixed EA for gold trading. v3.0 includes fractal detection fixes, improved divergence logic, and enhanced risk management."

#include <Trade/Trade.mqh>

//--- Day Filter Enum
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

//--- Timeframe Enum
enum ENUM_BASE_TIMEFRAME
  {
   TF_M15 = PERIOD_M15,
   TF_M20 = PERIOD_M20,
   TF_M30 = PERIOD_M30,
   TF_H1  = PERIOD_H1,
   TF_H2  = PERIOD_H2
  };

//--- EA Input Parameters
input ENUM_BASE_TIMEFRAME InpBaseTimeframe = TF_M15; // Base timeframe for trading signals
input ulong  InpMagicNumber = 1337;      // Magic Number (1000-9999)
input double InpLotSize     = 0.01;       // Fixed Lot Size (0.01-1.0)
input int    InpMaxSpread   = 30;         // Max spread in points - Gold typical (10-50)
input int    InpTakeProfit  = 800;        // Take Profit in points - Gold optimized (300-2000)
input double InpStopLossRatio = 1.8;      // Stop Loss ratio to TP - Gold volatility (1.2-2.5)
input bool   InpCloseOnBarEnd = false;    // Close trades at bar end
input Custom_Dayfilter_Config InpDayFilter = FULL_WEEK; // Trading days filter
//--- Risk Management
input bool   InpUseRiskPercent = true;    // Use % of balance for position sizing
input double InpRiskPercent    = 1.5;     // Risk per trade % - Gold suitable (0.5-3.0)
input double InpMaxDailyLoss   = 4.0;     // Max daily loss % - Gold protection (2.0-8.0)
input int    InpMaxTradesPerDay = 4;      // Max trades per day - Gold frequency (1-6)
//--- Indicator Settings
input int    InpRsiPeriod   = 14;         // RSI Period - standard (8-21)
input int    InpDivergenceLookback = 40;  // Divergence lookback bars - Gold optimized (20-80)
input int    InpRsiOverbought = 75;       // RSI overbought level - Gold tuned (70-80)
input int    InpRsiOversold   = 25;       // RSI oversold level - Gold tuned (20-30)
input int    InpMinFractalDistance = 3;   // Min bars between fractals - Gold sensitivity (2-8)
//--- Parameter Adaptation Settings
input bool   InpAdaptParameters    = true;       // Adapt TP/SL to volatility
input int    InpAtrPeriod          = 14;         // ATR Period for volatility (10-21)
input int    InpAtrHistoryDays     = 25;         // ATR history days - Gold analysis (15-45)
input double InpVolatilityMultiplier = 1.2;     // ATR multiplier for TP - Gold calibrated (0.8-2.0)

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
datetime g_lastTradeDay = 0;
int      g_dailyTradeCount = 0;
double   g_dailyStartBalance = 0;

//--- Multi-Timeframe settings
ENUM_TIMEFRAMES g_tf1, g_tf2, g_tf3;

//--- Divergence detection variables
struct FractalPoint
{
   int bar_index;
   double price;
   double rsi_value;
   datetime time;

   // Initialize function to replace constructor
   void Init(int idx = 0, double p = 0.0, double rsi = 0.0, datetime t = 0)
   {
      bar_index = idx;
      price = p;
      rsi_value = rsi;
      time = t;
   }

   // Copy function to replace copy constructor
   void CopyFrom(const FractalPoint &other)
   {
      bar_index = other.bar_index;
      price = other.price;
      rsi_value = other.rsi_value;
      time = other.time;
   }
};

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
bool CheckRiskLimits();
void UpdateDailyStats();
bool FindFractalLows(FractalPoint &fractals[], int &count);
bool FindFractalHighs(FractalPoint &fractals[], int &count);
bool ValidateTrendAlignment(int trend_direction);

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
      Print(gEaName, ": Initialization failed. The selected timeframe '", EnumToString((ENUM_TIMEFRAMES)InpBaseTimeframe), "' is not supported by this EA's logic.");
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

//--- Initialize daily stats
   UpdateDailyStats();

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
   datetime currentBarTime = iTime(_Symbol, (ENUM_TIMEFRAMES)InpBaseTimeframe, 0);
   if(currentBarTime > g_lastBarTime)
     {
      g_lastBarTime = currentBarTime;
      OnNewBar();
     }

//--- Update daily statistics
   UpdateDailyStats();

//--- Core per-tick trading logic
   if(IsTradingDayAllowed() && CheckRiskLimits() && PositionsTotal() == 0)
     {
//--- In a confirmed uptrend, look for a bullish divergence to enter long
      if(gOverallTrend == 1 && ValidateTrendAlignment(1))
        {
         if(CheckBullishDivergence())
           {
            ExecuteTrade(1);
           }
        }
//--- In a confirmed downtrend, look for a bearish divergence to enter short
      else if(gOverallTrend == -1 && ValidateTrendAlignment(-1))
        {
         if(CheckBearishDivergence())
           {
            ExecuteTrade(-1);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Update daily statistics and risk management                      |
//+------------------------------------------------------------------+
void UpdateDailyStats()
  {
   MqlDateTime current_time;
   TimeCurrent(current_time);

   datetime today = iTime(_Symbol, PERIOD_D1, 0);

   if(today != g_lastTradeDay)
     {
      g_lastTradeDay = today;
      g_dailyTradeCount = 0;
      g_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      Print("New trading day started. Balance: ", g_dailyStartBalance);
     }
  }

//+------------------------------------------------------------------+
//| Check risk management limits                                     |
//+------------------------------------------------------------------+
bool CheckRiskLimits()
  {
//--- Check daily trade limit
   if(g_dailyTradeCount >= InpMaxTradesPerDay)
     {
      return false;
     }

//--- Check daily loss limit
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double dailyLoss = (g_dailyStartBalance - currentBalance) / g_dailyStartBalance * 100.0;

   if(dailyLoss > InpMaxDailyLoss)
     {
      Print("Daily loss limit reached: ", NormalizeDouble(dailyLoss, 2), "%");
      return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Validate trend alignment across timeframes                       |
//+------------------------------------------------------------------+
bool ValidateTrendAlignment(int trend_direction)
  {
//--- Get current price relative to key EMAs on base timeframe
   double ema50_tf1[1], ema200_tf1[1];
   double close_price[1];

   if(CopyBuffer(ema50_handle_tf1, 0, 0, 1, ema50_tf1) <= 0) return false;
   if(CopyBuffer(ema200_handle_tf1, 0, 0, 1, ema200_tf1) <= 0) return false;
   if(CopyClose(_Symbol, g_tf1, 0, 1, close_price) <= 0) return false;

//--- For bullish trades, ensure price is above key moving averages
   if(trend_direction == 1)
     {
      return (close_price[0] > ema50_tf1[0] && ema50_tf1[0] > ema200_tf1[0]);
     }
//--- For bearish trades, ensure price is below key moving averages
   else if(trend_direction == -1)
     {
      return (close_price[0] < ema50_tf1[0] && ema50_tf1[0] < ema200_tf1[0]);
     }

   return false;
  }

//+------------------------------------------------------------------+
//| Find fractal lows for bullish divergence detection              |
//+------------------------------------------------------------------+
bool FindFractalLows(FractalPoint &fractals[], int &count)
  {
   count = 0;
   double fractal_buffer[];
   double low_buffer[];
   double rsi_buffer[];

   int bars_to_copy = InpDivergenceLookback;
   if(CopyBuffer(fractals_handle, 1, 0, bars_to_copy, fractal_buffer) < bars_to_copy) return false;
   if(CopyLow(_Symbol, g_tf1, 0, bars_to_copy, low_buffer) < bars_to_copy) return false;
   if(CopyBuffer(rsi_handle, 0, 0, bars_to_copy, rsi_buffer) < bars_to_copy) return false;

//--- Find fractals (remember: index 0 is most recent)
   for(int i = InpMinFractalDistance; i < bars_to_copy - 2 && count < 10; i++)
     {
      if(fractal_buffer[bars_to_copy - 1 - i] != 0) // Convert to historical indexing
        {
         fractals[count].bar_index = i;
         fractals[count].price = low_buffer[i];
         fractals[count].rsi_value = rsi_buffer[i];
         fractals[count].time = iTime(_Symbol, g_tf1, i);
         count++;
        }
     }

   return (count >= 2);
  }

//+------------------------------------------------------------------+
//| Find fractal highs for bearish divergence detection             |
//+------------------------------------------------------------------+
bool FindFractalHighs(FractalPoint &fractals[], int &count)
  {
   count = 0;
   double fractal_buffer[];
   double high_buffer[];
   double rsi_buffer[];

   int bars_to_copy = InpDivergenceLookback;
   if(CopyBuffer(fractals_handle, 0, 0, bars_to_copy, fractal_buffer) < bars_to_copy) return false;
   if(CopyHigh(_Symbol, g_tf1, 0, bars_to_copy, high_buffer) < bars_to_copy) return false;
   if(CopyBuffer(rsi_handle, 0, 0, bars_to_copy, rsi_buffer) < bars_to_copy) return false;

//--- Find fractals
   for(int i = InpMinFractalDistance; i < bars_to_copy - 2 && count < 10; i++)
     {
      if(fractal_buffer[bars_to_copy - 1 - i] != 0)
        {
         fractals[count].bar_index = i;
         fractals[count].price = high_buffer[i];
         fractals[count].rsi_value = rsi_buffer[i];
         fractals[count].time = iTime(_Symbol, g_tf1, i);
         count++;
        }
     }

   return (count >= 2);
  }

//+------------------------------------------------------------------+
//| Check for bullish RSI divergence using improved fractal logic   |
//+------------------------------------------------------------------+
bool CheckBullishDivergence()
  {
   FractalPoint fractals[10];
   int fractal_count = 0;

   if(!FindFractalLows(fractals, fractal_count) || fractal_count < 2)
      return false;

//--- Check the two most recent fractals
   FractalPoint recent, previous;
   recent.CopyFrom(fractals[0]);    // Use copy function
   previous.CopyFrom(fractals[1]);  // Use copy function

//--- Conditions for bullish divergence
   bool price_lower_low = recent.price < previous.price;
   bool rsi_higher_low = recent.rsi_value > previous.rsi_value;
   bool rsi_in_oversold = (recent.rsi_value < InpRsiOversold) || (previous.rsi_value < InpRsiOversold);
   bool sufficient_rsi_difference = (recent.rsi_value - previous.rsi_value) > 2.0; // Minimum 2 points difference

   if(price_lower_low && rsi_higher_low && rsi_in_oversold && sufficient_rsi_difference)
     {
      Print("Bullish Divergence Detected:");
      Print("  Recent Low: Price=", DoubleToString(recent.price, _Digits), " RSI=", DoubleToString(recent.rsi_value, 2), " Time=", TimeToString(recent.time));
      Print("  Previous Low: Price=", DoubleToString(previous.price, _Digits), " RSI=", DoubleToString(previous.rsi_value, 2), " Time=", TimeToString(previous.time));
      return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//| Check for bearish RSI divergence using improved fractal logic   |
//+------------------------------------------------------------------+
bool CheckBearishDivergence()
  {
   FractalPoint fractals[10];
   int fractal_count = 0;

   if(!FindFractalHighs(fractals, fractal_count) || fractal_count < 2)
      return false;

//--- Check the two most recent fractals
   FractalPoint recent, previous;
   recent.CopyFrom(fractals[0]);    // Use copy function
   previous.CopyFrom(fractals[1]);  // Use copy function

//--- Conditions for bearish divergence
   bool price_higher_high = recent.price > previous.price;
   bool rsi_lower_high = recent.rsi_value < previous.rsi_value;
   bool rsi_in_overbought = (recent.rsi_value > InpRsiOverbought) || (previous.rsi_value > InpRsiOverbought);
   bool sufficient_rsi_difference = (previous.rsi_value - recent.rsi_value) > 2.0;

   if(price_higher_high && rsi_lower_high && rsi_in_overbought && sufficient_rsi_difference)
     {
      Print("Bearish Divergence Detected:");
      Print("  Recent High: Price=", DoubleToString(recent.price, _Digits), " RSI=", DoubleToString(recent.rsi_value, 2), " Time=", TimeToString(recent.time));
      Print("  Previous High: Price=", DoubleToString(previous.price, _Digits), " RSI=", DoubleToString(previous.rsi_value, 2), " Time=", TimeToString(previous.time));
      return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//| Update the on-screen display                                     |
//+------------------------------------------------------------------+
void UpdateDisplay()
  {
   string displayString = "EA: " + gEaName + " v3.0\n";

//--- Display Symbol Info
   if(isSymbolOk)
      displayString += "Pair: " + _Symbol + "\n";
   else
      displayString += "Error: Gold Pair Only (e.g., XAUUSD, GOLD)\n";

//--- Display Timeframe Info
   displayString += "Base TF: " + EnumToString((ENUM_TIMEFRAMES)InpBaseTimeframe) + " | Chart TF: " + EnumToString(_Period) + "\n";
   displayString += "Higher TFs: " + EnumToString(g_tf2) + ", " + EnumToString(g_tf3) + "\n";

//--- Display Trend Info
   string trend_status = "Calculating...";
   if(gOverallTrend == 1) trend_status = "BULLISH";
   else if(gOverallTrend == -1) trend_status = "BEARISH";
   else trend_status = "NEUTRAL";
   displayString += "Trend: " + trend_status + "\n";

//--- Display Risk Info
   displayString += "Daily Trades: " + IntegerToString(g_dailyTradeCount) + "/" + IntegerToString(InpMaxTradesPerDay) + "\n";

   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(g_dailyStartBalance > 0)
     {
      double dailyPL = ((currentBalance - g_dailyStartBalance) / g_dailyStartBalance) * 100.0;
      displayString += "Daily P&L: " + DoubleToString(dailyPL, 2) + "%\n";
     }

//--- Display Target Info
   double tp_dist = InpAdaptParameters ? gAdaptedTakeProfit : InpTakeProfit * _Point;
   double sl_dist = tp_dist * InpStopLossRatio;
   displayString += "TP: " + DoubleToString(tp_dist / _Point, 0) + " pts | ";
   displayString += "SL: " + DoubleToString(sl_dist / _Point, 0) + " pts\n";

   displayString += "Positions: " + IntegerToString(PositionsTotal());

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
      Print("Spread too high (", spread, " pts). Trade aborted.");
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
      Print("Invalid lot size calculated. Trade aborted.");
      return;
     }

//--- Determine trade type and prices
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

//--- Execute trade
   string comment = gEaName + "_" + TimeToString(TimeCurrent(), TIME_SECONDS);

   if(trade.PositionOpen(_Symbol, trade_type, lot_size, entry_price, sl_price, tp_price, comment))
     {
      g_dailyTradeCount++;
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

//--- Risk calculation
   double risk_amount = account_balance * (InpRiskPercent / 100.0);
   double sl_value_per_lot = (sl_distance_points / tick_size) * tick_value;

   if(sl_value_per_lot <= 0) return 0.0;

   double lot_size = risk_amount / sl_value_per_lot;

//--- Normalize lot size
   lot_size = NormalizeDouble(lot_size / lot_step, 0) * lot_step;

//--- Apply limits
   if(lot_size < min_lot) lot_size = min_lot;
   if(lot_size > max_lot) lot_size = max_lot;

   return lot_size;
  }

//+------------------------------------------------------------------+
//| Set the higher timeframes based on the chart's period            |
//+------------------------------------------------------------------+
bool SetTimeframes()
  {
   g_tf1 = (ENUM_TIMEFRAMES)InpBaseTimeframe;
   switch(g_tf1)
     {
      case PERIOD_M15:
         g_tf2 = PERIOD_M30;
         g_tf3 = PERIOD_H1;
         break;
      case PERIOD_M20:
         g_tf2 = PERIOD_H1;
         g_tf3 = PERIOD_H2;
         break;
      case PERIOD_M30:
         g_tf2 = PERIOD_H1;
         g_tf3 = PERIOD_H4;
         break;
      case PERIOD_H1:
         g_tf2 = PERIOD_H4;
         g_tf3 = PERIOD_D1;
         break;
      case PERIOD_H2:
         g_tf2 = PERIOD_H4;
         g_tf3 = PERIOD_H6;
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
//--- Timeframe handles
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

//--- Other indicators
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
   gAdaptedTakeProfit = InpTakeProfit * _Point; // Default

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

//--- Calculate average ATR
   double sum = 0;
   for(int i = 0; i < InpAtrHistoryDays; i++)
     {
      sum += atr_buffer[i];
     }
   double average_atr = sum / InpAtrHistoryDays;

//--- Adapt TP to volatility (scale by timeframe)
   double timeframe_multiplier = 1.0;
   switch((ENUM_TIMEFRAMES)InpBaseTimeframe)
     {
      case PERIOD_M15: timeframe_multiplier = 0.3; break;
      case PERIOD_M20: timeframe_multiplier = 0.4; break;
      case PERIOD_M30: timeframe_multiplier = 0.5; break;
      case PERIOD_H1:  timeframe_multiplier = 1.0; break;
      case PERIOD_H2:  timeframe_multiplier = 1.5; break;
      default: timeframe_multiplier = 1.0; break;
     }

   gAdaptedTakeProfit = average_atr * InpVolatilityMultiplier * timeframe_multiplier;

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

//--- Copy data from indicators with validation
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

//--- Require consensus across all timeframes
   if(trend1_up && trend2_up && trend3_up) return 1;
   if(trend1_down && trend2_down && trend3_down) return -1;

   return 0; // No consensus
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
   int day_of_week = current_time.day_of_week; // 0=Sun, 1=Mon, ..., 6=Sat

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
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
            PositionGetString(POSITION_SYMBOL) == _Symbol)
           {
            if(trade.PositionClose(ticket))
              {
               Print("Position #", ticket, " closed on new bar.");
              }
            else
              {
               Print("Failed to close position #", ticket, ". Error: ", trade.ResultRetcode());
              }
           }
        }
     }

//--- Recalculate the overall trend
   int newTrend = GetOverallTrend();
   if(newTrend != gOverallTrend)
     {
      Print("Trend changed from ", gOverallTrend, " to ", newTrend);
      gOverallTrend = newTrend;
     }

//--- Re-adapt parameters periodically
   static int bar_count = 0;
   bar_count++;
   if(bar_count >= 24) // Re-adapt every 24 bars
     {
      bar_count = 0;
      AdaptParameters();
     }

//--- Update display
   UpdateDisplay();
  }

//+------------------------------------------------------------------+
//| Check if the timeframe is one of the allowed ones                |
//+------------------------------------------------------------------+
bool CheckTimeframe()
  {
   ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)InpBaseTimeframe;
   //--- This function now validates the INPUT, not the chart timeframe
   switch(tf)
     {
      case PERIOD_M15:
      case PERIOD_M20:
      case PERIOD_M30:
      case PERIOD_H1:
      case PERIOD_H2:
         return true;
      default:
         return false;
     }
  }

//+------------------------------------------------------------------+
