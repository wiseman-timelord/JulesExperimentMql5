# The JulesGPTClaudeKimi-Mql5-Experiment
Status: Alpha (experimental until further notice).

Description:
Its an experiment, to see if Jules can automate making a profitable EA. This is main branch you are reading, while [THIS](https://github.com/wiseman-timelord/JulesGPTClaude-Mql5-Experiment/branches) shows the work being done recently by Jules . As the name suggests, this is an experimental MetaTrader 5 (MT5) Expert Advisor (EA) created by Jules (primary) + Claude + GPT + Kimi K1.5/K2. It is designed to trade gold pairs (XAUUSD, GOLD) using a specific trend-following and divergence strategy. It detects general trends, checks for divergence and is supposed to place an order in general trend direction when it returns to trend direction, in order to trade in direction with logical rebound protection. The philosophy behind the strategy is, while individual waves come and go, the tide has its generally predictable direction.

## How to Use
1. Place latest `JulesExperimentalMql5_###.mq5` file into your `MQL5/Experts/` directory.
2. Open the EA script **MetaEditor**  click **"Compile"**, then close the editor.
3. Move the `.set` file provided into the "~/profiles/" folder.
4. Run MetaTrader 5 and open Strategy tester.
3. In Strategy Tester, find and se;ect `JulesExperimentalMql5_#_##`. ensure to use the provided set file for default settings, and put on a gold pair, set data in Metatrader to M1/everyTick/ and mode to genetic backtest and for a time period of previous 1 Year. 
5. After configuration Then click start, though this may take some time, after it show how results are doing for the EA on the pair (though I still not sure if the results are trustworthy yet, more development required).
- Processing could take several hours even on a 20 thread processor, and each thread will require 1GB ram for each thread, for 1 year M1 Every Tick.
- OHLC may be ok if you select "Close At End Of Bar" to "True" in the EA, and it may be somewhat acurate with M1 OHLC, but personally I am going by the "Every Tick". The theory is in relevance to spikes, they will potentially break SL that in OHLC would have been still within safe zone.

### Input Params (not in the correct order currently)
*   `InpBaseTimeframe`: The core timeframe for the EA's logic (M15, M30, etc.).
*   `InpMagicNumber`: A unique number to identify trades opened by this EA.
*   `InpLotSize`: The fixed lot size. Only used if `InpUseRiskPercent` is `false`.
*   `InpMaxSpread`: The maximum allowed spread in points.
*   `InpTakeProfit`: The Take Profit in points. Only used if `InpAdaptParameters` is `false`.
*   `InpStopLossRatio`: The Stop Loss size as a ratio of the Take Profit.
*   `InpCloseOnBarEnd`: If `true`, closes any open trade at the start of a new bar.
*   `InpDayFilter`: Dropdown menu to select which days of the week to trade.
*   `InpUseRiskPercent`: If `true`, the EA will automatically calculate the lot size based on `InpRiskPercent`.
*   `InpRiskPercent`: The percentage of the account balance to risk on a single trade.
*   `InpMaxDailyLoss`: The max percentage of daily balance to lose before stopping for the day.
*   `InpMaxTradesPerDay`: The maximum number of trades allowed per day.
*   `InpRsiPeriod`: The period for the RSI indicator.
*   `InpDivergenceLookback`: The number of bars to look back on to find a divergence pattern.
*   `InpRsiOverbought`: The RSI level above which a bearish divergence is considered valid.
*   `InpRsiOversold`: The RSI level below which a bullish divergence is considered valid.
*   `InpMinFractalDistance`: The minimum bars required between two fractals.
*   `InpAdaptParameters`: Set to `true` to enable automatic TP/SL adaptation based on volatility (ATR).
*   `InpAtrPeriod`: The period for the ATR indicator.
*   `InpAtrHistoryDays`: The number of days of history to analyze for the ATR calculation.
*   `InpVolatilityMultiplier`: The multiplier for the ATR value when calculating the adapted TP.

## File Structure
```
.\JulesGptClaude-Mql5-Experiment_#.##.mq5 (current)
.\Archive\
.\Archive\JulesGptClaude-Mql5-Experiment_#.##.mq5 (archive)
```

### Development
- The perception is it needs to improve bad trade avoidance.
- Occasional focus on keeeping things optimized.
- Repeat checks for soundness/logic of code, ensuring Mql5 is the format.
