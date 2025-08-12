# JulesExperimentMql5

This is an experimental MetaTrader 5 (MT5) Expert Advisor (EA) created by Jules. It is designed to trade gold pairs (XAUUSD, GOLD) using a specific trend-following and divergence strategy.

## Strategy

The core trading strategy is based on three main components:

1.  **Multi-Timeframe Trend Analysis:** The EA first determines the dominant trend by analyzing three separate timeframes: the one on the chart (`BaseChartTimeFrame`) and two higher timeframes. It uses the 50-period and 200-period Exponential Moving Averages (EMAs) to do this. A trade is only considered if all three timeframes are in agreement (i.e., 50 EMA > 200 EMA for an uptrend on all three).
2.  **RSI Divergence Entry:** Once a strong trend is established, the EA waits for a temporary pullback or reversal signal in the form of RSI divergence on the `BaseChartTimeFrame`.
    *   In an **uptrend**, it looks for a **bullish divergence** (price makes a lower low, but the RSI indicator makes a higher low).
    *   In a **downtrend**, it looks for a **bearish divergence** (price makes a higher high, but the RSI indicator makes a lower high).
3.  **Trade Execution:** When a divergence signal occurs in the direction of the main trend, the EA executes a trade.

## Features

*   **On-Chart Display:** Shows the EA's status, detected trend, and target TP/SL levels.
*   **Symbol and Timeframe Validation:** Automatically checks to ensure the EA is running on a Gold pair and a valid timeframe (M15, M30, H1).
*   **Statistical Parameter Adaptation ("Machine Learning"):** The EA can optionally adapt its Take Profit and Stop Loss levels based on recent market volatility. It does this by calculating the Average True Range (ATR) over the last 30 days (by default) on the D1 timeframe and setting the TP as a multiple of this value. This helps the EA adjust to changing market conditions.
*   **Customizable Parameters:** All key parameters of the strategy can be configured through the EA's input settings.

## How to Use

### 1. Installation and Compilation

1.  Place the `JulesExperimentalMql5.mq5` file into the `MQL5/Experts/` directory of your MetaTrader 5 data folder. A sub-folder like `JulesExperimentMql5` is recommended. You can find your data folder by going to `File -> Open Data Folder` in your MT5 terminal.
2.  Open the **MetaEditor** from within MT5 (or by pressing the F4 key).
3.  In the MetaEditor's "Navigator" window, find the `JulesExperimentalMql5.mq5` file under `Experts`.
4.  Double-click the file to open it.
5.  Press the **F7** key or click the **"Compile"** button.
6.  If there are no errors, the EA is ready to be used in the MT5 terminal.

### 2. Running in the Strategy Tester

1.  Open the Strategy Tester in MT5 by going to `View -> Strategy Tester` (or pressing Ctrl+R).
2.  In the "Settings" tab of the tester:
    *   Select the `JulesExperimentalMql5` expert from the dropdown list.
    *   **Symbol:** Choose a gold pair, such as `XAUUSD`.
    *   **Date:** Select the date range you want to backtest.
    *   **Timeframe:** Choose one of the valid timeframes: `M15`, `M30`, or `H1`.
    *   **Modelling:** "Every tick" is the most accurate for testing.
3.  Go to the **"Inputs"** tab to configure the EA's parameters.
4.  Click the **"Start"** button to run the backtest. You can view the results in the "Graph" and "Backtest" tabs.

## Input Parameters

Here is a description of all the user-configurable inputs:

*   `InpMagicNumber`: A unique number to identify trades opened by this specific instance of the EA.
*   `InpLotSize`: The fixed lot size for each trade.
*   `InpMaxSpread`: The maximum allowed spread in points. If the current spread is higher, no trades will be opened.
*   `InpTakeProfit`: The Take Profit in points. This is only used if `InpAdaptParameters` is set to `false`.
*   `InpStopLossRatio`: The Stop Loss size as a ratio of the Take Profit. For example, a value of `2.0` means the Stop Loss will be twice as large as the Take Profit.
*   `InpDayFilter`: (Not yet implemented) A placeholder for future development to restrict trading to certain days.
*   `InpRsiPeriod`: The period for the RSI indicator.
*   `InpDivergenceLookback`: The number of bars to look back on to find a divergence pattern.
*   `InpAdaptParameters`: Set to `true` to enable the automatic TP/SL adaptation based on volatility. Set to `false` to use the fixed `InpTakeProfit` value.
*   `InpAtrPeriod`: The period for the ATR indicator used in parameter adaptation.
*   `InpAtrHistoryDays`: The number of days of history to analyze for the ATR calculation.
