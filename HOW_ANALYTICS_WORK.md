# Covary Analytics: How It Works

This document explains the internal logic, statistical methods, and visualization techniques used to power Covary's analytics engine. The analytics suite is divided into four primary pillars, all accessible from the main `AnalyticsScreen`.

---

## 1. Correlation Matrix (`AnalyticsService` & `CorrelationMatrixScreen`)

The Correlation Matrix allows users to discover relationships between different tracked metrics (e.g., how sleep duration affects mood).

### Data Processing & Aggregation
Before correlations can be calculated, raw `Event` data from the Drift database is aggregated into daily values:
*   **Averages**: Subjective scales (Mood, Productivity) and quality-related metrics are averaged across the day.
*   **Maximums**: Daily totals (Total Screen Time, Sleep Duration, Steps) take the `MAX` value to ensure the most complete sync record is used.
*   **Sums**: Boolean toggles and counter metrics (e.g., number of coffees) are summed up.

### Statistical Method
The engine uses the **Spearman Rank Correlation Coefficient**.
1.  **Ranking**: Daily values are converted into ranks. If there are tied values, their ranks are averaged.
2.  **Pearson on Ranks**: The standard Pearson correlation formula is applied to these ranks.
3.  **Thresholds**: A strict minimum of **3 overlapping days** of data is required to compute a valid correlation to ensure research integrity. 

### Predictive Time Lag
Users can apply a "Time Lag" slider from 0 to 7 days. If a lag of 2 days is set, the engine correlates Metric A on Day *T* with Metric B on Day *T+2*. This helps identify predictive behaviors (e.g., "Does exercising today affect my mood two days later?").

### Visualization
*   **Color Mapping**: Positive correlations are shaded **Cyan**, while negative correlations are **Orange**. 
*   **Intensity**: The opacity of the cell color scales dynamically with the absolute magnitude of the correlation ($|r|$). Stronger correlations glow brighter.
*   **Filtering**: Correlations between -0.05 and 0.05 are considered negligible and are rendered as a simple dot (`·`) to reduce visual noise.
*   **Layout**: The grid uses a slanted header design to fit long metric names (like "ENTERTAINMENT") in a compact horizontal space.

---

## 2. HCI Metrics & Interaction Analysis (`InteractionScreen`)

Because Covary is an Ecological Momentary Assessment (EMA) tool, analyzing *how* the user interacts with the app is just as important as *what* they log.

### Key Metrics
*   **Response Speed (Latency)**: A core metric that measures the time (in milliseconds) from opening a notification to pressing save. Averages are displayed to evaluate "Survey Friction".
*   **Interaction Breakdown**: Every prompt interaction is logged as a `click` (immediate log), `snooze` (delayed), or `swipeAway` (ignored).
*   **Engagement Score**: The ratio of actual logs (`clicks`) vs total interactions. A score > 0.8 is flagged as "Exceptional".

### Fatigue Trend Visualization
A 14-day line chart (`fl_chart`) visualizes survey fatigue:
*   **Solid Green Line**: Represents proactive logs (`clicks`).
*   **Dotted Red Line**: Represents dismissals and snoozes (friction). 
*   *Insight*: If the red line overtakes the green line, the app dynamically updates its "Research Insight" card to warn about survey fatigue or poor prompt timing.

---

## 3. Data Quality & Compliance (`ComplianceScreen`)

This section ensures the ecological validity of the research data by monitoring consistency.

### Recall Reliability
This metric calculates the percentage of data logged "In-the-moment" (triggered manually or by a notification) versus retrospective logging. A higher percentage indicates higher data validity with less recall bias.

### Compliance Heatmap
*   **Logic**: The app compares the number of `SessionCompleted` meta-events on a given day against the total number of tracking windows the user has enabled.
*   **Visual Grid**: Displays a 14-day wrap grid. 
*   **Color Scaling**: Days with zero logs are drawn with the background surface color. Days with partial or full logs interpolate between a very dark green (`#0A1F0A`) and the primary theme color. This gives the user immediate visual feedback on their tracking streaks.

---

## 4. Usage Trends (`UsageTrendsScreen`)

This screen visualizes passive sensing data, specifically app usage categories and screen time.

### Filtering and Aggregation
*   **Time Ranges**: Users can filter by the last 7, 14, 30 days, or a custom date range.
*   **Day Filters**: Users can filter out weekends or workdays to see context-specific trends.
*   **Aggregation**: Data can be viewed as Daily points or grouped by Week (`W12`, `W13`).

### Delta Calculation
The engine compares the "Total Screen Time" of the currently selected period against the exact equivalent previous period to generate a percentage Delta (e.g., "+12.5% vs Prev. Period").

### Visualization Techniques
*   **Chart Toggling**: Users can swap between a smooth, curved Line Chart (with gradient fills below the line) and a Stacked Bar Chart.
*   **Interactive Tooltips**: Tapping the chart reveals a unified tooltip showing the exact minute breakdown for the top tracked categories.
*   **Hourly Drill-down**: Tapping a specific day on the Line Chart triggers a secondary database fetch to render an hourly breakdown bar chart for that specific day.

---

## 5. Lagged Trend Analysis (`LaggedTrendScreen`)

This screen provides a focused, two-metric "deep dive" that visualizes how one behavior predicts another with a time delay.

### Metric Selection
*   **Auto-Detection**: On launch, the engine exhaustively scans all enabled metric pairs across lags 0–7 and presents the pair with the highest |ρ| (absolute Spearman correlation).
*   **Manual Override**: Users can tap either metric chip to swap in any available metric from a bottom-sheet picker.

### Normalization
Both metrics are min-max normalized to 0.0–1.0 so they can be overlaid on the same Y-axis regardless of their native scale (e.g., Mood 1–5 vs Steps 0–20,000).
*   **Formula**: `(value - min) / (max - min)` per metric, computed over the visible date range.
*   **Edge case**: If all values are identical, the series normalizes to 0.5.

### Peak Lag Detection
The engine performs a sweep from lag 0 to lag 7 days, calling `calculateSpearmanCorrelation()` at each offset. The lag with the highest absolute ρ is selected as the "optimal lag."

### Date Range
Users can toggle between **7, 14, and 30 day** windows via choice chips. The chart and correlation coefficient recalculate live.

### Natural-Language Insight
A glassmorphic card renders a human-readable interpretation:
*   *Same-day*: "Your Sleep Quality peaks on days with high Mood."
*   *Lagged*: "Your Fatigue dips 2 days after low Social Media use."
*   The verb ("peaks" / "dips") is derived from the sign of ρ.

### Visualization
*   **Dual Line Chart**: Two smooth, curved `LineChartBarData` series with gradient fills below each line.
*   **Color Coding**: Metric A uses the primary theme color (Aquamarine), Metric B uses the secondary color (Deep Violet).
*   **Stats Cards**: "PEAK CORRELATION" (e.g., 0.82) and "OPTIMAL LAG" (e.g., 2 DAYS) are displayed with progress bars.

