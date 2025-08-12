# JulesExperimentMql5 - v2.0

This is an experimental MetaTrader 5 (MT5) Expert Advisor (EA) created by Jules. It is designed to trade gold pairs (XAUUSD, GOLD) using a specific trend-following and divergence strategy.

**This version (v2.0) includes a major overhaul of the risk management and signal detection systems based on performance analysis.**

## Strategy

The core trading strategy is based on three main components:

1.  **Multi-Timeframe Trend Analysis:** The EA first determines the dominant trend by analyzing three separate timeframes. It uses the 50-period and 200-period Exponential Moving Averages (EMAs) to do this. A trade is only considered if all three timeframes are in agreement.
2.  **Robust RSI Divergence Entry:** Once a strong trend is established, the EA waits for a high-quality pullback signal using RSI divergence.
    *   **Enhanced Detection:** The EA now uses the standard **Fractals indicator** to identify true swing highs and lows, making the divergence detection much more reliable.
    *   **RSI Filter:** A divergence signal is only considered valid if it occurs from an **overbought** (for sells) or **oversold** (for buys) RSI level, filtering out weak signals.
    *   **Logic:** In an **uptrend**, it looks for a **bullish divergence**. In a **downtrend**, it looks for a **bearish divergence**.
3.  **Trade Execution:** When a valid, filtered divergence signal occurs in the direction of the main trend, the EA executes a trade.

## Key Features in v2.0

*   **Dynamic, Risk-Based Position Sizing:** Instead of a fixed lot size, the EA can now calculate the correct lot size for each trade based on a percentage of your account balance that you are willing to risk.
*   **Greatly Improved Signal Quality:** By using Fractals and RSI level filters, the number of false signals has been significantly reduced.
*   **Safer Defaults:** The default Stop Loss to Take Profit ratio has been reduced to a more conservative 1.5.
*   **On-Chart Display:** Shows the EA's status, detected trend, and target TP/SL levels.
*   **Symbol and Timeframe Validation:** Automatically checks to ensure the EA is running on a Gold pair and a valid timeframe (M15, M30, H1).
*   **Statistical Parameter Adaptation:** The EA can still optionally adapt its Take Profit and Stop Loss levels based on recent market volatility using ATR.

## How to Use

### 1. Installation and Compilation

1.  Place the `JulesExperimentalMql5.mq5` file into the `MQL5/Experts/` directory of your MetaTrader 5 data folder.
2.  Open the **MetaEditor** from within MT5 (or by pressing F4).
3.  In the MetaEditor's "Navigator" window, find and open the `JulesExperimentalMql5.mq5` file.
4.  Press **F7** or click the **"Compile"** button.

### 2. Running in the Strategy Tester

1.  Open the Strategy Tester in MT5 (Ctrl+R).
2.  Select the `JulesExperimentalMql5` expert.
3.  **Symbol:** Choose a gold pair, such as `XAUUSD`.
4.  **Timeframe:** Choose `M15`, `M30`, or `H1`.
5.  Go to the **"Inputs"** tab to configure the parameters below.
6.  Click **"Start"** to run the backtest.

## Input Parameters

*   `InpMagicNumber`: A unique number to identify trades opened by this EA.
*   `InpLotSize`: The fixed lot size for each trade. **This is only used if `InpUseRiskPercent` is set to `false`**.
*   `InpMaxSpread`: The maximum allowed spread in points.
*   `InpTakeProfit`: The Take Profit in points. This is only used if `InpAdaptParameters` is `false`.
*   `InpStopLossRatio`: The Stop Loss size as a ratio of the Take Profit (Default: 1.5).
*   `InpCloseOnBarEnd`: If `true`, closes any open trade at the start of a new bar.

### Risk Management
*   `InpUseRiskPercent`: If `true`, the EA will automatically calculate the lot size based on `InpRiskPercent`. If `false`, it will use the fixed `InpLotSize`.
*   `InpRiskPercent`: The percentage of the account balance to risk on a single trade (e.g., 1.0 = 1% risk).

### Indicator Settings
*   `InpRsiPeriod`: The period for the RSI indicator.
*   `InpDivergenceLookback`: The number of bars to look back on to find a divergence pattern.
*   `InpRsiOverbought`: The RSI level above which a bearish divergence is considered valid.
*   `InpRsiOversold`: The RSI level below which a bullish divergence is considered valid.

### Parameter Adaptation Settings
*   `InpAdaptParameters`: Set to `true` to enable the automatic TP/SL adaptation based on volatility (ATR).
*   `InpAtrPeriod`: The period for the ATR indicator.
*   `InpAtrHistoryDays`: The number of days of history to analyze for the ATR calculation.
