# JulesExperimentMql5 - v3.0

This is an experimental MetaTrader 5 (MT5) Expert Advisor (EA) created by Jules. It is designed to trade gold pairs (XAUUSD, GOLD) using a specific trend-following and divergence strategy.

**This version (v3.0) is a major update based on a heavily revised and improved source code baseline. It adds a selectable base timeframe for running the EA's logic.**

## Strategy

The core trading strategy is based on three main components:

1.  **Multi-Timeframe Trend Analysis:** The EA first determines the dominant trend by analyzing three separate timeframes, all derived from the user-selected `InpBaseTimeframe`.
2.  **Robust RSI Divergence Entry:** Once a strong trend is established, the EA waits for a high-quality pullback signal using RSI divergence, identified with the Fractals indicator and filtered by RSI overbought/oversold levels.
3.  **Trade Execution:** When a valid, filtered divergence signal occurs on an allowed day, the EA executes a trade.

## Key Features in v3.0

*   **NEW - Selectable Base Timeframe:** A new dropdown menu (`InpBaseTimeframe`) allows you to choose the core timeframe for the EA's entire logic, independent of the chart it is attached to. This makes backtesting multiple strategies much faster and more flexible.
*   **Advanced Risk Management:** Includes settings for max daily trades and a max daily loss % to protect capital.
*   **Dynamic, Risk-Based Position Sizing:** The EA calculates the correct lot size for each trade based on a percentage of your account balance.
*   **High-Quality Signal Detection:** Uses Fractals and RSI level filters to significantly reduce false signals.
*   **Day Filter & Performance Optimizations:** Includes a dropdown to control which days of the week to trade and runs expensive calculations only once per bar.

## How to Use

1.  Place all `JulesExperimentalMql5_*.mq5` files into your `MQL5/Experts/` directory.
2.  Open the **MetaEditor** (F4).
3.  In the Navigator, find and open `JulesExperimentalMql5_003.mq5`.
4.  Press **F7** or click **"Compile"**.
5.  In the MT5 Strategy Tester (Ctrl+R), select the `JulesExperimentalMql5_003` expert to test the latest version.

## Input Parameters

### General
*   `InpBaseTimeframe`: **(New in v3.0)** The core timeframe for the EA's logic.
*   `InpMagicNumber`: A unique number to identify trades opened by this EA.
*   `InpMaxSpread`: The maximum allowed spread in points.
*   `InpCloseOnBarEnd`: If `true`, closes any open trade at the start of a new bar.
*   `InpDayFilter`: Dropdown menu to select which days of the week to trade.

### Risk Management
*   `InpLotSize`: The fixed lot size. Only used if `InpUseRiskPercent` is `false`.
*   `InpUseRiskPercent`: If `true`, the EA will automatically calculate the lot size based on `InpRiskPercent`.
*   `InpRiskPercent`: The percentage of the account balance to risk on a single trade.
*   `InpMaxDailyLoss`: The maximum percentage of the daily starting balance that can be lost before stopping for the day.
*   `InpMaxTradesPerDay`: The maximum number of trades allowed in a single day.

### Indicator & Signal Settings
*   `InpTakeProfit`: The Take Profit in points. Only used if `InpAdaptParameters` is `false`.
*   `InpStopLossRatio`: The Stop Loss size as a ratio of the Take Profit.
*   `InpRsiPeriod`: The period for the RSI indicator.
*   `InpDivergenceLookback`: The number of bars to look back on to find a divergence pattern.
*   `InpRsiOverbought`: The RSI level above which a bearish divergence is considered valid.
*   `InpRsiOversold`: The RSI level below which a bullish divergence is considered valid.
*   `InpMinFractalDistance`: The minimum number of bars required between two fractals to be considered a valid divergence.

### Parameter Adaptation Settings
*   `InpAdaptParameters`: Set to `true` to enable automatic TP/SL adaptation based on volatility (ATR).
*   `InpAtrPeriod`: The period for the ATR indicator.
*   `InpAtrHistoryDays`: The number of days of history to analyze for the ATR calculation.
*   `InpVolatilityMultiplier`: The multiplier for the ATR value when calculating the adapted Take Profit.
