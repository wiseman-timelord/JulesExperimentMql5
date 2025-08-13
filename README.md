# JulesExperimentMql5 - v2.1

This is an experimental MetaTrader 5 (MT5) Expert Advisor (EA) created by Jules. It is designed to trade gold pairs (XAUUSD, GOLD) using a specific trend-following and divergence strategy.

**This version (v2.1) adds a Day Filter and optimizes internal calculations for better performance.**

## Strategy

The core trading strategy is based on three main components:

1.  **Multi-Timeframe Trend Analysis:** The EA first determines the dominant trend by analyzing three separate timeframes. It uses the 50-period and 200-period Exponential Moving Averages (EMAs) to do this. A trade is only considered if all three timeframes are in agreement.
2.  **Robust RSI Divergence Entry:** Once a strong trend is established, the EA waits for a high-quality pullback signal using RSI divergence.
    *   **Enhanced Detection:** The EA uses the standard **Fractals indicator** to identify true swing highs and lows, making the divergence detection much more reliable.
    *   **RSI Filter:** A divergence signal is only considered valid if it occurs from an **overbought** (for sells) or **oversold** (for buys) RSI level, filtering out weak signals.
3.  **Trade Execution:** When a valid, filtered divergence signal occurs on an allowed day, the EA executes a trade.

## Key Features in v2.1

*   **NEW - Day Filter:** A new dropdown menu (`InpDayFilter`) allows you to easily control which days of the week the EA is active.
*   **NEW - Performance Optimization:** Expensive calculations (like trend analysis) are now only run once per bar, not on every tick, making the EA more efficient.
*   **Dynamic, Risk-Based Position Sizing:** The EA calculates the correct lot size for each trade based on a percentage of your account balance that you are willing to risk.
*   **Greatly Improved Signal Quality:** Uses Fractals and RSI level filters to significantly reduce false signals.
*   **On-Chart Display:** Shows the EA's status, detected trend, and target TP/SL levels.

## How to Use

1.  Place the `JulesExperimentalMql5_001.mq5` (archive) and `JulesExperimentalMql5_002.mq5` (latest) files into your `MQL5/Experts/` directory.
2.  Open the **MetaEditor** (F4).
3.  In the Navigator, find and open `JulesExperimentalMql5_002.mq5`.
4.  Press **F7** or click **"Compile"**.
5.  In the MT5 Strategy Tester (Ctrl+R), select the `JulesExperimentalMql5_002` expert to test the latest version.

## Input Parameters

*   `InpMagicNumber`: A unique number to identify trades opened by this EA.
*   `InpLotSize`: The fixed lot size. Only used if `InpUseRiskPercent` is `false`.
*   `InpMaxSpread`: The maximum allowed spread in points.
*   `InpTakeProfit`: The Take Profit in points. Only used if `InpAdaptParameters` is `false`.
*   `InpStopLossRatio`: The Stop Loss size as a ratio of the Take Profit (Default: 1.5).
*   `InpCloseOnBarEnd`: If `true`, closes any open trade at the start of a new bar.

### Day Filter
*   `InpDayFilter`: **(New in v2.1)** Dropdown menu to select which days of the week to trade.

### Risk Management
*   `InpUseRiskPercent`: If `true`, the EA will automatically calculate the lot size based on `InpRiskPercent`.
*   `InpRiskPercent`: The percentage of the account balance to risk on a single trade.

### Indicator Settings
*   `InpRsiPeriod`: The period for the RSI indicator.
*   `InpDivergenceLookback`: The number of bars to look back on to find a divergence pattern.
*   `InpRsiOverbought`: The RSI level above which a bearish divergence is considered valid.
*   `InpRsiOversold`: The RSI level below which a bullish divergence is considered valid.

### Parameter Adaptation Settings
*   `InpAdaptParameters`: Set to `true` to enable automatic TP/SL adaptation based on volatility (ATR).
*   `InpAtrPeriod`: The period for the ATR indicator.
*   `InpAtrHistoryDays`: The number of days of history to analyze for the ATR calculation.

### Revisions
- 001 - first working version ~1500 from 1000 in 1 year.
- 002 - supposedly corrupt version, earns 12000 from 1000 in 1 year. Interesting but not useful.
- 003 - 1600 from 1000 in 1 year (before adding timeframe filter). Improved version. 
