# JulesGptClaude-Mql5-Experiment
Status: Experimental

### Description
This is an experimental MetaTrader 5 (MT5) Expert Advisor (EA) created by Jules (primary) + Claude + GPT. It is designed to trade gold pairs (XAUUSD, GOLD) using a specific trend-following and divergence strategy. It detects general trends, checks for divergence and is supposed to place an order in general trend direction when it returns to trend direction, in order to trade in direction with logical rebound protection. The idea is to improve bad trade avoidance, while improving general soundness.

## How to Use
1.  Place the active `JulesGptClaude-Mql5-Experiment_0_05.mq5` file into your `MQL5/Experts/` directory. The `Archive` folder contains previous versions for historical reference.
2.  Open the **MetaEditor** (F4).
3.  In the Navigator, find and open `JulesGptClaude-Mql5-Experiment_0_05.mq5`.
4.  click **"Compile"**.
5.  In the MT5 Strategy Tester (Ctrl+R), select the `JulesGptClaude-Mql5-Experiment_0_05` expert to test the latest version.

## Input Parameters
*   `InpBaseTimeframe`: **(v0.05)** The core timeframe for the EA's logic (M15, M30, etc.).
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

### Revisions
- **v0.01 (Archived)** - The first functional version. Implemented multi-timeframe trend, parameter adaptation, and a basic (flawed) divergence detection logic.
- **v0.02 (Archived)** - Added the `InpCloseOnBarEnd` feature and improved the initialization error logging to be more specific.
- **v0.03 (Archived)** - Major refactor based on external analysis. Overhauled risk management with percentage-based lot sizing and significantly improved divergence detection using Fractals and RSI level filters.
- **v0.04 (Archived)** - Added an enum-based Day Filter for trading days and refactored the `OnTick` logic into a more efficient `OnNewBar` function for once-per-bar calculations.
- **v0.05 (Active)** - Based on a new user-provided baseline. Adds a selectable `InpBaseTimeframe` to decouple the EA's entire logic from the chart's timeframe, allowing for much greater testing flexibility.
